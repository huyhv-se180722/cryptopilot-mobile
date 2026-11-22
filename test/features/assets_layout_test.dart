import 'dart:async';

import 'package:cryptopilot_mobile/app.dart';
import 'package:cryptopilot_mobile/core/auth/token_store.dart';
import 'package:cryptopilot_mobile/core/router/app_router.dart';
import 'package:cryptopilot_mobile/core/settings/settings.dart';
import 'package:cryptopilot_mobile/features/paper/application/assets_pnl_controller.dart';
import 'package:cryptopilot_mobile/features/market/domain/market.dart';
import 'package:cryptopilot_mobile/features/paper/domain/paper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/chart_fakes.dart';
import '../support/fakes.dart';
import '../support/futures_fakes.dart';
import '../support/paper_fakes.dart';
import '../support/realtime_fakes.dart';

/// T-150 (D-163): Assets with the total of both wallets, the 7-day change,
/// the round actions and the Spot / Futures split.
void main() {
  PaperEquity equity(String now, Map<DateTime, String> points) => PaperEquity(
    totalEquity: now,
    todayPnl: null,
    history: [
      for (final MapEntry(key: date, value: total) in points.entries)
        EquityPoint(date: date, totalEquity: total),
    ],
  );

  group('sevenDayChange', () {
    final clock = DateTime.utc(2026, 11, 6, 10);

    test('now less the start of the day six days back, with its percent', () {
      final week = sevenDayChange(
        equity('10250.00', {
          DateTime.utc(2026, 10, 30): '9000.00',
          DateTime.utc(2026, 10, 31): '10000.00',
          DateTime.utc(2026, 11, 6): '10200.00',
        }),
        clock,
      );
      expect(week?.change, '250');
      expect(week?.percent, '2.5');
    });

    test('a loss keeps its sign', () {
      final week = sevenDayChange(
        equity('9000', {DateTime.utc(2026, 10, 31): '10000'}),
        clock,
      );
      expect(week?.change, '-1000');
      expect(week?.percent, '-10');
    });

    test('no point on that day, or no equity: nothing, never a guess', () {
      expect(
        sevenDayChange(
          equity('10250.00', {DateTime.utc(2026, 11, 1): '10000.00'}),
          clock,
        ),
        isNull,
      );
      expect(sevenDayChange(null, clock), isNull);
    });

    test('a start of zero gives the change without a percent', () {
      final week = sevenDayChange(
        equity('5.00', {DateTime.utc(2026, 10, 31): '0'}),
        clock,
      );
      expect(week?.change, '5');
      expect(week?.percent, isNull);
    });
  });

  late FakeTransport transport;
  late FakePaperApi paper;
  late FakeMarketApi market;

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
          paper: paper,
          futures: FakeFuturesApi(),
          market: market,
          metricChart: FakeMetricSurface(),
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
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 31));
  }

  setUp(() {
    market = FakeMarketApi();
    // The fake clock is 2026-11-06 10:00 UTC: the 7-day start is 31 Oct.
    paper = FakePaperApi()
      ..equityAnswer = equity('15000.00', {
        DateTime.utc(2026, 10, 31): '14000.00',
        DateTime.utc(2026, 11, 6): '14900.00',
      });
  });

  testWidgets('a coin row shows the logo of its Spot pair (device check)', (
    tester,
  ) async {
    market.pairsBy[Market.spot] = [
      const MarketPair(
        pairId: 'pair-BTC',
        symbol: 'BTCUSDT',
        market: Market.spot,
        baseAsset: 'BTC',
        quoteAsset: 'USDT',
        baseAssetName: 'Bitcoin',
        tickSize: '0.010000000000',
        stepSize: '0.000010000000',
        displayOrder: 1,
        logoUrl: 'https://img.invalid/btc.png',
      ),
    ];
    await open(tester);
    final row = find.byKey(const Key('coin-BTC'), skipOffstage: false);
    expect(row, findsOneWidget);
    expect(
      find.descendant(
        of: row,
        matching: find.byKey(const Key('coin-frame')),
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    await unmount(tester);
  });

  for (final brightness in Brightness.values) {
    testWidgets('360 dp, ${brightness.name}: the total of both wallets, the '
        '7-day change, four round actions and the split fit', (tester) async {
      tester.view
        ..physicalSize = const Size(360 * 3, 760 * 3)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await open(tester, brightness: brightness);
      // Spot 10,000 + Futures 5,000 (the fakes' wallets).
      expect(
        find.descendant(
          of: find.byKey(const Key('assets-total')),
          matching: find.text('15,000.00 USDT', findRichText: true),
        ),
        findsOneWidget,
      );
      expect(
        find.text('7-day change  +1,000.00 (+7.14%)', findRichText: true),
        findsOneWidget,
      );
      for (final key in [
        'assets-transfer',
        'assets-history',
        'assets-trade',
        'assets-pnl',
      ]) {
        expect(find.byKey(Key(key)), findsOneWidget, reason: key);
      }
      expect(
        find.descendant(
          of: find.byKey(const Key('assets-split-spot')),
          matching: find.text('10,000.00 USDT'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('assets-split-futures')),
          matching: find.text('5,000.00 USDT'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  }

  testWidgets('the eye hides the total, the change and the split bars', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('assets-eye')));
    await frames(tester);
    expect(find.text('15,000.00 USDT', findRichText: true), findsNothing);
    expect(find.textContaining('+1,000.00', findRichText: true), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('assets-split')),
        matching: find.byType(LinearProgressIndicator),
      ),
      findsNothing,
    );
    await unmount(tester);
  });

  testWidgets('a coin row shows its worth in USDT; PnL scrolls to the '
      'equity, last in the list (assets_test taps a coin to Trade)', (
    tester,
  ) async {
    await open(tester);
    expect(
      find.descendant(
        of: find.byKey(const Key('coin-USDT')),
        matching: find.text('≈ 10,000.00 USDT'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('assets-pnl')));
    await frames(tester);
    expect(
      tester.getTopLeft(find.byKey(const Key('assets-equity'))).dy,
      lessThan(tester.view.physicalSize.height / tester.view.devicePixelRatio),
    );
    await unmount(tester);
  });
}
