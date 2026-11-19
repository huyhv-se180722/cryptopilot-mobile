import 'dart:async';

import 'package:cryptopilot_mobile/app.dart';
import 'package:cryptopilot_mobile/core/auth/token_store.dart';
import 'package:cryptopilot_mobile/core/router/app_router.dart';
import 'package:cryptopilot_mobile/core/settings/settings.dart';
import 'package:cryptopilot_mobile/features/paper/domain/futures.dart';
import 'package:cryptopilot_mobile/features/paper/domain/paper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/futures_fakes.dart';
import '../support/realtime_fakes.dart';

/// T-131: the Futures form judged while typed and the position details.
void main() {
  late FakeTransport transport;
  late FakeFuturesApi futures;
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
          futures: futures,
          market: market,
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
    container.read(appRouterProvider).go('/trade');
    await frames(tester);
    await tester.tap(find.text('Futures'));
    await frames(tester);
    transport.last.push('/topic/overview.FUTURES', {
      'market': 'FUTURES',
      'serverTime': '2026-11-19T02:00:00Z',
      'tickers': [
        {
          'market': 'FUTURES',
          'symbol': 'BTCUSDT',
          'sourceTime': '2026-11-19T02:00:00Z',
          'lastPrice': '75990.00',
          'changePercent24h': null,
          'quoteVolume24h': null,
          'markPrice': '76000.00',
        },
      ],
    });
    await frames(tester);
  }

  Finder list() => find
      .descendant(
        of: find.byKey(const Key('trade-futures')),
        matching: find.byType(Scrollable),
      )
      .first;

  Future<void> show(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 150, scrollable: list());
    await frames(tester);
  }

  Future<void> type(WidgetTester tester, String field, String value) =>
      tester.enterText(
        find.descendant(
          of: find.byKey(Key('futures-field-$field')),
          matching: find.byType(TextField),
        ),
        value,
      );

  String fieldText(WidgetTester tester, String field) => tester
      .widget<TextField>(
        find.descendant(
          of: find.byKey(Key('futures-field-$field')),
          matching: find.byType(TextField),
        ),
      )
      .controller!
      .text;

  String textOf(WidgetTester tester, String key) =>
      tester.widget<Text>(find.byKey(Key(key))).data!;

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 31));
  }

  const position = FuturesPosition(
    symbol: 'BTCUSDT',
    side: PositionSide.both,
    amount: '0.010',
    entryPrice: '76000.00',
    markPrice: '76100.00',
    unrealizedProfit: '1.00',
    marginType: MarginType.crossed,
    liquidationPrice: '61000.00',
    marginRatio: '0.0040',
    leverage: 20,
    positionInitialMargin: '38.05',
  );

  AlgoOrder guard(String id, String type, String trigger) => AlgoOrder(
    algoId: id,
    symbol: 'BTCUSDT',
    side: OrderSide.sell,
    type: type,
    triggerPrice: trigger,
    status: 'NEW',
    positionSide: PositionSide.both,
    closePosition: true,
  );

  setUp(() {
    futures = FakeFuturesApi();
    market = FakeMarketApi();
  });

  testWidgets('while typed: each side shows its cost and Max, a BLOCKING '
      'warning by its name under its side only; the sheet still holds the '
      'order back', (tester) async {
    futures.warningsFor[OrderSide.sell] = const OrderWarnings(
      cost: '38.00',
      warnings: [
        OrderWarning(
          type: 'INSUFFICIENT_MARGIN',
          severity: WarningSeverity.blocking,
          message: 'Not enough margin.',
        ),
      ],
    );
    await open(tester);
    await type(tester, 'price', '75000.00');
    await type(tester, 'size', '0.01');
    await show(tester, find.byKey(const Key('futures-SELL')));
    await frames(tester);
    expect(textOf(tester, 'futures-info-BUY'), 'Cost 38.00 · Max 1.300 BTC');
    expect(textOf(tester, 'futures-info-SELL'), 'Cost 38.00 · Max 1.200 BTC');
    expect(
      find.byKey(const Key('inline-warning-SELL-INSUFFICIENT_MARGIN')),
      findsOneWidget,
    );
    expect(find.text('Insufficient margin'), findsOneWidget);
    expect(
      find.byKey(const Key('inline-warning-BUY-INSUFFICIENT_MARGIN')),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('futures-size-usdt')));
    await frames(tester);
    await type(tester, 'size', '760');
    await show(tester, find.byKey(const Key('futures-SELL')));
    await frames(tester);
    expect(textOf(tester, 'futures-info-BUY'), contains('Max 97,500.00 USDT'));

    await tester.tap(find.byKey(const Key('futures-SELL')));
    await frames(tester);
    expect(find.text('Not enough margin.'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('futures-confirm')))
          .onPressed,
      isNull,
    );
    expect(futures.placed, isEmpty);
    await unmount(tester);
  });

  testWidgets('−/+ step the price from the mark and the size by its step; '
      'the slider takes a share of the smaller Max', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('futures-plus-price')));
    await tester.pump();
    expect(fieldText(tester, 'price'), '76000.01');
    await tester.tap(find.byKey(const Key('futures-minus-size')));
    await tester.pump();
    expect(fieldText(tester, 'size'), '0.00001');
    await frames(tester);

    await tester.drag(
      find.byKey(const Key('futures-share')),
      const Offset(1000, 0),
    );
    await tester.pump();
    expect(fieldText(tester, 'size'), '1.2');
    await unmount(tester);
  });

  testWidgets('a position shows its leverage, PnL with ROE and its TP / SL', (
    tester,
  ) async {
    futures
      ..positionList = [position]
      ..algoList = [
        guard('a-1', 'TAKE_PROFIT_MARKET', '80000.00'),
        guard('a-2', 'STOP_MARKET', '72000.00'),
      ];
    await open(tester);
    const key = 'BTCUSDT-BOTH';
    await show(tester, find.byKey(const Key('position-$key')));
    expect(textOf(tester, 'position-title-$key'), 'BTCUSDT · Long · 20x');
    expect(textOf(tester, 'position-pnl-$key'), 'PnL +1.00 (+2.63%)');
    expect(textOf(tester, 'tpsl-line-$key'), 'TP 80,000.00 · SL 72,000.00');
    await unmount(tester);
  });

  testWidgets('the Futures order book beside the form, read on FUTURES; a '
      'level tapped fills the price', (tester) async {
    await open(tester);
    expect(find.byKey(const Key('trade-book')), findsOneWidget);
    expect(market.bookCalls, contains('depth FUTURES BTCUSDT'));
    await tester.tap(find.byKey(const Key('book-76001')));
    await tester.pump();
    expect(fieldText(tester, 'price'), '76001');
    await unmount(tester);
  });

  testWidgets('funding with its countdown from the pair ticker, as on SCR-11', (
    tester,
  ) async {
    await open(tester);
    expect(find.byKey(const Key('futures-funding-countdown')), findsNothing);
    transport.last.push('/topic/ticker.FUTURES.BTCUSDT', {
      'market': 'FUTURES',
      'symbol': 'BTCUSDT',
      'markPrice': '76000.00',
      'fundingRate': '0.0001',
      'nextFundingTime': '2026-11-06T13:12:45Z',
    });
    await frames(tester);
    expect(textOf(tester, 'futures-funding'), contains('0.0100%'));
    // now = 2026-11-06T10:00Z in the fakes.
    expect(
      find.descendant(
        of: find.byKey(const Key('futures-funding-countdown')),
        matching: find.text('03:12:45'),
      ),
      findsOneWidget,
    );
    await unmount(tester);
  });

  for (final brightness in Brightness.values) {
    testWidgets('360 dp, ${brightness.name}: warnings, Cost / Max and a '
        'detailed position fit', (tester) async {
      tester.view
        ..physicalSize = const Size(360 * 3, 760 * 3)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      futures
        ..warningsAnswer = const OrderWarnings(
          cost: '123456.78',
          warnings: [
            OrderWarning(
              type: 'SL_BEYOND_LIQUIDATION',
              severity: WarningSeverity.blocking,
              message: 'x',
            ),
            OrderWarning(
              type: 'HIGH_FUNDING_RATE',
              severity: WarningSeverity.warning,
              message: 'y',
            ),
            OrderWarning(
              type: 'WIDE_STOP_LOSS',
              severity: WarningSeverity.info,
              message: 'z',
            ),
          ],
        )
        ..positionList = [position]
        ..algoList = [guard('a-1', 'STOP_MARKET', '72000.00')];
      await open(tester, brightness: brightness);
      await type(tester, 'price', '75000.00');
      await type(tester, 'size', '0.01');
      await frames(tester);
      expect(tester.takeException(), isNull);
      await tester.drag(list(), const Offset(0, -1200));
      await frames(tester);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  }
}
