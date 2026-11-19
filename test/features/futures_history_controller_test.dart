import 'package:cryptopilot_mobile/core/auth/token_store.dart';
import 'package:cryptopilot_mobile/core/errors/api_failure.dart';
import 'package:cryptopilot_mobile/features/market/data/market_repository.dart';
import 'package:cryptopilot_mobile/features/market/domain/market.dart';
import 'package:cryptopilot_mobile/features/paper/application/futures_history_controller.dart';
import 'package:cryptopilot_mobile/features/paper/application/history_controller.dart';
import 'package:cryptopilot_mobile/features/paper/domain/futures_history.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/futures_fakes.dart';
import '../support/realtime_fakes.dart';

/// T-123: each Futures history with only its endpoint's filters.
void main() {
  late FakeFuturesApi api;
  late ProviderContainer container;

  Future<void> pump(WidgetTester tester, FuturesHistoryKind kind) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: baseOverrides(
          store: MemoryTokenStore(storedFor('saved')),
          tokens: FakeAuthTokenApi(),
          transport: FakeTransport(),
          futures: api,
        ),
        retry: (_, _) => null,
        child: Consumer(
          builder: (context, ref, _) {
            ref
              ..watch(futuresHistoryProvider(kind))
              ..watch(marketRepositoryProvider(Market.futures));
            return const SizedBox();
          },
        ),
      ),
    );
    container = ProviderScope.containerOf(
      tester.element(find.byType(Consumer)),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump();
    }
  }

  List<String> reads() => api.calls
      .where(
        (c) => !const {
          'account',
          'positions',
          'open orders',
          'open algo',
        }.contains(c),
      )
      .toList();

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 31));
  }

  setUp(() => api = FakeFuturesApi());

  testWidgets('closed positions of every pair, then of the last week', (
    tester,
  ) async {
    await pump(tester, FuturesHistoryKind.positions);
    expect(reads(), ['positionHistory * -..- 100']);
    container
        .read(futuresHistoryProvider(FuturesHistoryKind.positions).notifier)
        .selectPeriod(HistoryPeriod.week);
    await tester.pump();
    // now = 2026-11-06T10:00Z in the fakes.
    expect(
      reads().last,
      'positionHistory * 2026-10-30T10:00:00.000Z..2026-11-06T10:00:00.000Z 100',
    );
    await unmount(tester);
  });

  testWidgets('orders need a pair: the first Futures pair, never all', (
    tester,
  ) async {
    await pump(tester, FuturesHistoryKind.orders);
    expect(reads(), ['allOrders BTCUSDT -..- 100']);
    final c = container.read(
      futuresHistoryProvider(FuturesHistoryKind.orders).notifier,
    );
    c.selectSymbol(null);
    await tester.pump();
    expect(reads(), hasLength(1));
    c.selectSymbol('ETHUSDT');
    await tester.pump();
    expect(reads().last, 'allOrders ETHUSDT -..- 100');
    await unmount(tester);
  });

  testWidgets('income by type; margin changes by addition or reduction', (
    tester,
  ) async {
    await pump(tester, FuturesHistoryKind.income);
    container
        .read(futuresHistoryProvider(FuturesHistoryKind.income).notifier)
        .selectIncomeType(IncomeType.fundingFee);
    await tester.pump();
    expect(reads().last, 'income * FUNDING_FEE -..- 100');
    await unmount(tester);

    api.calls.clear();
    await pump(tester, FuturesHistoryKind.margin);
    container
        .read(futuresHistoryProvider(FuturesHistoryKind.margin).notifier)
        .selectMarginAdded(false);
    await tester.pump();
    expect(reads().last, 'marginHistory BTCUSDT 2 -..- 100');
    await unmount(tester);
  });

  testWidgets('a refused read keeps the filters and tells why', (tester) async {
    api.historyError = const NetworkFailure();
    await pump(tester, FuturesHistoryKind.liquidations);
    final state = container.read(
      futuresHistoryProvider(FuturesHistoryKind.liquidations),
    );
    expect(state.items, isNull);
    expect(state.failure, isA<NetworkFailure>());
    api.historyError = null;
    container
        .read(futuresHistoryProvider(FuturesHistoryKind.liquidations).notifier)
        .selectSymbol('BTCUSDT');
    await tester.pump();
    expect(
      container
          .read(futuresHistoryProvider(FuturesHistoryKind.liquidations))
          .items,
      isEmpty,
    );
    expect(reads().last, 'forceOrders BTCUSDT -..- 100');
    await unmount(tester);
  });
}
