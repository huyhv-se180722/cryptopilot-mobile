import 'dart:async';

import 'package:cryptopilot_mobile/app.dart';
import 'package:cryptopilot_mobile/core/auth/token_store.dart';
import 'package:cryptopilot_mobile/core/router/app_router.dart';
import 'package:cryptopilot_mobile/core/settings/settings.dart';
import 'package:cryptopilot_mobile/features/paper/domain/futures.dart';
import 'package:cryptopilot_mobile/features/paper/domain/futures_history.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/futures_fakes.dart';
import '../support/paper_fakes.dart';
import '../support/realtime_fakes.dart';

/// T-123: the Futures histories inside the history screen (plan 9.3).
void main() {
  late FakeTransport transport;
  late FakeFuturesApi futures;

  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> open(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
  }) async {
    transport = FakeTransport();
    await tester.pumpWidget(
      ProviderScope(
        overrides: baseOverrides(
          store: MemoryTokenStore(storedFor('saved')),
          tokens: FakeAuthTokenApi(),
          transport: transport,
          paper: FakePaperApi(),
          futures: futures,
          settings: MemorySettingsStore(),
        ),
        retry: (_, _) => null,
        child: const CryptoPilotApp(),
      ),
    );
    await frames(tester);
    transport.last.onConnected();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(CryptoPilotApp)),
    );
    if (brightness == Brightness.dark) {
      unawaited(
        container.read(themeModeProvider.notifier).select(ThemeMode.dark),
      );
    }
    container.read(appRouterProvider).go('/assets');
    await frames(tester);
    await tester.scrollUntilVisible(
      find.byKey(const Key('assets-futures-history')),
      150,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('assets-list')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await frames(tester);
    await tester.tap(find.byKey(const Key('assets-futures-history')));
    await frames(tester);
  }

  List<String> reads() => futures.calls
      .where(
        (c) =>
            c.startsWith('positionHistory') ||
            c.startsWith('income') ||
            c.startsWith('allOrders') ||
            c.startsWith('forceOrders'),
      )
      .toList();

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 31));
  }

  final closed = ClosedPosition(
    positionId: 'p-1',
    symbol: 'BTCUSDT',
    side: PositionSide.both,
    long: false,
    marginType: MarginType.crossed,
    leverage: 10,
    maxQuantity: '0.020',
    closedQuantity: '0.020',
    entryPrice: '76000',
    avgClosePrice: '75000',
    realizedPnl: '20',
    fundingFee: '-0.5',
    liquidationFee: '0',
    netProfit: '19.5',
    closeReason: 'MANUAL',
    openTime: DateTime.utc(2026, 11, 5),
    closeTime: DateTime.utc(2026, 11, 6),
  );

  setUp(() {
    futures = FakeFuturesApi()
      ..closedList = [closed]
      ..incomeList = [
        FuturesIncome(
          typeWire: 'FUNDING_FEE',
          income: '-0.50',
          time: DateTime.utc(2026, 11, 6),
          tranId: 'i-1',
          symbol: 'BTCUSDT',
        ),
      ];
  });

  testWidgets('from the Futures part of Assets: closed positions with their '
      'net profit, then income by type', (tester) async {
    await open(tester);
    expect(find.byKey(const Key('fh-positions')), findsOneWidget);
    expect(find.byKey(const Key('fh-position-p-1')), findsOneWidget);
    expect(find.text('BTCUSDT · Short · 10x'), findsOneWidget);
    expect(find.text('+19.5'), findsOneWidget);
    expect(reads(), ['positionHistory * -..- 100']);

    await tester.tap(find.text('Income'));
    await frames(tester);
    expect(find.byKey(const Key('fh-income-i-1')), findsOneWidget);
    expect(find.text('-0.50 USDT'), findsOneWidget);
    await tester.tap(find.byKey(const Key('fh-income-type')));
    await frames(tester);
    await tester.tap(find.text('FUNDING_FEE').last);
    await frames(tester);
    expect(reads().last, 'income * FUNDING_FEE -..- 100');
    await unmount(tester);
  });

  testWidgets('orders of one pair (no "All pairs"); liquidations of every '
      'pair; back to Spot keeps its own tabs', (tester) async {
    await open(tester);
    await tester.tap(find.text('Orders'));
    await frames(tester);
    expect(reads(), contains('allOrders BTCUSDT -..- 100'));
    expect(find.byKey(const Key('fh-empty-orders')), findsOneWidget);
    await tester.tap(find.byKey(const Key('fh-symbol-orders')));
    await frames(tester);
    expect(find.text('All pairs'), findsNothing);
    await tester.tap(find.text('ETHUSDT Perp').last);
    await frames(tester);
    expect(reads().last, 'allOrders ETHUSDT -..- 100');

    await tester.ensureVisible(find.text('Liquidations'));
    await tester.pump();
    await tester.tap(find.text('Liquidations'));
    await frames(tester);
    expect(reads().last, 'forceOrders * -..- 100');

    await tester.tap(find.text('Spot'));
    await frames(tester);
    expect(find.text('Ledger'), findsOneWidget);
    expect(find.text('Liquidations'), findsNothing);
    await unmount(tester);
  });

  for (final brightness in Brightness.values) {
    testWidgets('360 dp, ${brightness.name}: the Futures history fits', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(360 * 3, 760 * 3)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await open(tester, brightness: brightness);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Income'));
      await frames(tester);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  }
}
