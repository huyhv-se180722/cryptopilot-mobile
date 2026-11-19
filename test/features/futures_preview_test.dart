import 'package:cryptopilot_mobile/core/auth/token_store.dart';
import 'package:cryptopilot_mobile/core/errors/api_failure.dart';
import 'package:cryptopilot_mobile/features/market/data/market_repository.dart';
import 'package:cryptopilot_mobile/features/market/domain/market.dart';
import 'package:cryptopilot_mobile/features/paper/application/futures_form_controller.dart';
import 'package:cryptopilot_mobile/features/paper/application/futures_preview_controller.dart';
import 'package:cryptopilot_mobile/features/paper/data/futures_repository.dart';
import 'package:cryptopilot_mobile/features/paper/domain/futures.dart';
import 'package:cryptopilot_mobile/features/paper/domain/paper.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/futures_fakes.dart';
import '../support/realtime_fakes.dart';

/// T-131: the Futures form judged while it is typed (plan 9.2).
void main() {
  late FakeTransport transport;
  late FakeFuturesApi api;
  late ProviderContainer container;
  final form = futuresFormProvider('BTCUSDT');
  final preview = futuresPreviewProvider('BTCUSDT');

  Future<FuturesFormController> pump(WidgetTester tester) async {
    transport = FakeTransport();
    await tester.pumpWidget(
      ProviderScope(
        overrides: baseOverrides(
          store: MemoryTokenStore(storedFor('saved')),
          tokens: FakeAuthTokenApi(),
          transport: transport,
          futures: api,
        ),
        retry: (_, _) => null,
        child: Consumer(
          builder: (context, ref, _) {
            ref
              ..watch(form)
              ..watch(preview)
              ..watch(futuresProvider)
              ..watch(futuresSettingsProvider('BTCUSDT'))
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
    transport.last.onConnected();
    transport.last.push('/topic/overview.FUTURES', {
      'market': 'FUTURES',
      'serverTime': '2026-11-19T02:00:00Z',
      'tickers': [
        {
          'market': 'FUTURES',
          'symbol': 'BTCUSDT',
          'sourceTime': '2026-11-19T02:00:00Z',
          'lastPrice': '74000.00',
          'changePercent24h': null,
          'quoteVolume24h': null,
          'markPrice': '76000.00',
        },
      ],
    });
    await tester.pump(const Duration(milliseconds: 500));
    api.calls.clear();
    api.maxRequests.clear();
    api.warningRequests.clear();
    return container.read(form.notifier);
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump(FuturesPreviewController.settle);
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
  }

  FuturesPreview state() => container.read(preview);

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 31));
  }

  setUp(() => api = FakeFuturesApi());

  testWidgets('a Limit typed in two edits is judged once for each side: '
      'warnings, cost and Max at the limit price and the leverage', (
    tester,
  ) async {
    final c = await pump(tester);
    c.edit(FuturesField.price, '75000.00');
    await tester.pump(const Duration(milliseconds: 100));
    c.edit(FuturesField.size, '0.01');
    await settle(tester);
    expect(api.warningRequests.map((r) => r.side), [
      OrderSide.buy,
      OrderSide.sell,
    ]);
    expect(api.calls.where((c) => c.startsWith('max ')), [
      'max LONG 20x 75000.00 5000.00',
      'max SHORT 20x 75000.00 5000.00',
    ]);
    expect(state().of(OrderSide.buy).warnings!.cost, '38.00');
    expect(state().of(OrderSide.buy).max!.maxQuantity, '1.300');
    expect(state().sharedMax!.maxQuantity, '1.200');
    expect(state().loading, isFalse);
    await unmount(tester);
  });

  testWidgets('a BLOCKING warning on one side blocks that side only; Max is '
      'worked out from the budget the warnings name', (tester) async {
    api.warningsFor[OrderSide.sell] = const OrderWarnings(
      budget: '1200.00',
      warnings: [
        OrderWarning(
          type: 'SL_BEYOND_LIQUIDATION',
          severity: WarningSeverity.blocking,
          message: 'Beyond liquidation.',
        ),
      ],
    );
    final c = await pump(tester);
    c
      ..edit(FuturesField.price, '75000.00')
      ..edit(FuturesField.size, '0.01');
    await settle(tester);
    expect(state().of(OrderSide.sell).blocked, isTrue);
    expect(state().of(OrderSide.buy).blocked, isFalse);
    expect(api.maxRequests.last.walletBalance, '1200.00');
    await unmount(tester);
  });

  testWidgets('Market without a size: no warnings yet, Max at the mark; a '
      'failed Max leaves it out and keeps the warnings', (tester) async {
    final c = await pump(tester);
    c.selectKind(FuturesKind.market);
    await settle(tester);
    expect(api.warningRequests, isEmpty);
    expect(api.maxRequests.first.entryPrice, '76000.00');
    expect(state().of(OrderSide.buy).warnings, isNull);

    api.maxError = const NetworkFailure();
    c.edit(FuturesField.size, '0.01');
    await settle(tester);
    expect(state().of(OrderSide.buy).warnings, isNotNull);
    expect(state().of(OrderSide.buy).max, isNull);
    await unmount(tester);
  });

  testWidgets('−/+ by the tick from the mark, by the step, by 1 USDT, never '
      'below one step; a share of the Max in the coin or in USDT', (
    tester,
  ) async {
    final c = await pump(tester);
    FuturesFormState f() => container.read(form);
    c.step(FuturesField.price, up: true);
    expect(f().price, '76000.01');
    c
      ..edit(FuturesField.price, '76000.015')
      ..step(FuturesField.price, up: false);
    expect(f().price, '76000.01');
    c.step(FuturesField.size, up: false);
    expect(f().size, '0.00001');
    c
      ..setSizeInUsdt(true)
      ..edit(FuturesField.size, '10')
      ..step(FuturesField.size, up: true);
    expect(f().size, '11');

    const max = MaxOpen(maxQuantity: '1.200', maxNotional: '90000.00');
    c.useShare(50, max);
    expect(f().size, '45000.00');
    c
      ..setSizeInUsdt(false)
      ..useShare(25, max);
    expect(f().size, '0.3');
    c.useShare(0, max);
    expect(f().size, isEmpty);
    await unmount(tester);
  });
}
