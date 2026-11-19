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
    // A list still settling ignores taps.
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

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 31));
  }

  setUp(() => futures = FakeFuturesApi());

  testWidgets('the pair, mark, margin mode and leverage; a Limit Long is '
      'reviewed with its cost and liquidation price, then placed', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('BTCUSDT Perp'), findsOneWidget);
    expect(find.text('Mark 76,000.00'), findsOneWidget);
    expect(find.text('Cross'), findsOneWidget);
    expect(find.text('20x'), findsOneWidget);
    expect(find.text('Avbl 5,000.00 USDT'), findsOneWidget);

    await type(tester, 'price', '75000.00');
    await type(tester, 'size', '0.01');
    await show(tester, find.byKey(const Key('futures-BUY')));
    await tester.tap(find.byKey(const Key('futures-BUY')));
    await frames(tester);
    expect(find.byKey(const Key('futures-review')), findsOneWidget);
    expect(find.text('Cost 38.00 USDT'), findsOneWidget);
    expect(find.text('Est. liq. price 61,000.00'), findsOneWidget);
    await tester.tap(find.byKey(const Key('futures-confirm')));
    await frames(tester);
    expect(futures.placed.single.side, OrderSide.buy);
    expect(find.text('Demo order placed.'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('a BLOCKING warning leaves the order unconfirmable', (
    tester,
  ) async {
    futures.warningsAnswer = const OrderWarnings(
      warnings: [
        OrderWarning(
          type: 'INSUFFICIENT_MARGIN',
          severity: WarningSeverity.blocking,
          message: 'Not enough margin.',
        ),
      ],
    );
    await open(tester);
    await tester.tap(find.byKey(const Key('futures-kind')));
    await frames(tester);
    await tester.tap(find.text('Market').last);
    await frames(tester);
    // FE owner 2026-11-19 (T-131 fix): a BLOCKING side is disabled once the
    // form's preview has it; tapped before that, the sheet still blocks.
    await show(tester, find.byKey(const Key('futures-SELL')));
    await type(tester, 'size', '100');
    // Within the preview's 400 ms: back to the button at once, then tap.
    await tester.pump(const Duration(milliseconds: 150));
    await tester.ensureVisible(find.byKey(const Key('futures-SELL')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('futures-SELL')));
    await frames(tester);
    expect(find.text('Not enough margin.'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('futures-confirm')))
          .onPressed,
      isNull,
    );
    await tester.tapAt(const Offset(10, 10));
    await frames(tester);
    expect(find.byKey(const Key('futures-confirm')), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('futures-SELL')))
          .onPressed,
      isNull,
    );
    expect(futures.placed, isEmpty);
    await unmount(tester);
  });

  testWidgets('leverage within the bracket and the margin mode from their '
      'sheets', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('futures-leverage')));
    await frames(tester);
    expect(find.text('Leverage (max 125x)'), findsOneWidget);
    await tester.drag(
      find.byKey(const Key('leverage-slider')),
      const Offset(60, 0),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('leverage-save')));
    await frames(tester);
    expect(
      futures.calls.where((c) => c.startsWith('leverage BTCUSDT')),
      hasLength(1),
    );
    // Its "Done" snack bar has gone before the next sheet.
    await tester.pump(const Duration(seconds: 5));
    await frames(tester);

    await tester.tap(find.byKey(const Key('futures-margin-mode')));
    await frames(tester);
    await tester.tap(find.byKey(const Key('margin-ISOLATED')));
    await frames(tester);
    expect(futures.calls, contains('margin type BTCUSDT ISOLATED'));
    expect(find.text('Isolated'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('a position: market close, a 50 % limit close, its TP/SL and '
      'isolated margin', (tester) async {
    futures.positionList = [positionOf(marginType: MarginType.isolated)];
    await open(tester);
    const key = 'BTCUSDT-BOTH';
    await show(tester, find.byKey(const Key('position-$key')));
    expect(find.textContaining('PnL +1.00'), findsOneWidget);
    expect(find.textContaining('Margin ratio 0.40%'), findsOneWidget);
    expect(find.textContaining('+0.40%'), findsNothing);

    await tester.tap(find.byKey(const Key('close-$key')));
    await frames(tester);
    await tester.tap(find.byKey(const Key('close-percent-50')));
    await tester.enterText(find.byKey(const Key('close-price')), '77000');
    await tester.tap(find.byKey(const Key('close-confirm')));
    await frames(tester);
    expect(futures.calls, contains('close BTCUSDT BOTH 50 at 77000'));

    await show(tester, find.byKey(const Key('tpsl-$key')));
    await tester.tap(find.byKey(const Key('tpsl-$key')));
    await frames(tester);
    await tester.enterText(find.byKey(const Key('tpsl-sl')), '72000');
    await tester.pump();
    await tester.tap(find.byKey(const Key('tpsl-confirm')));
    await frames(tester);
    expect(futures.placedAlgo.single.type, 'STOP_MARKET');
    expect(futures.placedAlgo.single.closePosition, isTrue);

    await show(tester, find.byKey(const Key('margin-$key')));
    await tester.tap(find.byKey(const Key('margin-$key')));
    await frames(tester);
    await tester.enterText(find.byKey(const Key('margin-amount')), '10');
    await tester.tap(find.byKey(const Key('margin-confirm')));
    await frames(tester);
    expect(futures.calls, contains('margin add 10'));

    await show(tester, find.byKey(const Key('market-close-$key')));
    await tester.tap(find.byKey(const Key('market-close-$key')));
    await frames(tester);
    expect(futures.calls, isNot(contains('close BTCUSDT BOTH 100')));
    expect(
      find.text('Close the whole BTCUSDT demo position at market?'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('futures-ask-yes')));
    await frames(tester);
    expect(futures.calls, contains('close BTCUSDT BOTH 100'));
    await show(tester, find.byKey(const Key('futures-no-positions')));
    await unmount(tester);
  });

  testWidgets('close all asks first: Cancel keeps every position', (
    tester,
  ) async {
    futures.positionList = [positionOf()];
    await open(tester);
    await show(tester, find.byKey(const Key('futures-close-all')));
    await tester.tap(find.byKey(const Key('futures-close-all')));
    await frames(tester);
    await tester.tap(find.text('Cancel'));
    await frames(tester);
    expect(futures.calls, isNot(contains('close all')));

    await tester.tap(find.byKey(const Key('futures-close-all')));
    await frames(tester);
    await tester.tap(find.byKey(const Key('futures-ask-yes')));
    await frames(tester);
    expect(futures.calls, contains('close all'));
    await unmount(tester);
  });

  testWidgets('the funding rate under the mark once the ticker carries it', (
    tester,
  ) async {
    await open(tester);
    expect(find.byKey(const Key('futures-funding')), findsNothing);
    transport.last.push('/topic/overview.FUTURES', {
      'market': 'FUTURES',
      'serverTime': '2026-11-19T02:01:00Z',
      'tickers': [
        {
          'market': 'FUTURES',
          'symbol': 'BTCUSDT',
          'sourceTime': '2026-11-19T02:01:00Z',
          'lastPrice': '75990.00',
          'changePercent24h': null,
          'quoteVolume24h': null,
          'markPrice': '76000.00',
          'fundingRate': '0.0001',
        },
      ],
    });
    await frames(tester);
    expect(
      tester.widget<Text>(find.byKey(const Key('futures-funding'))).data,
      contains('0.0100%'),
    );
    await unmount(tester);
  });

  testWidgets('a plan without Futures: MSG29 from the server and Try again, no '
      'lock up front', (tester) async {
    futures.loadError = problem(
      403,
      'PLAN_FEATURE_NOT_INCLUDED',
      'MSG29',
      args: ['PRO'],
    );
    await open(tester);
    expect(
      find.text(
        'This feature is available on the PRO plan or higher. View plans?',
      ),
      findsOneWidget,
    );
    futures.loadError = null;
    await tester.tap(find.text('Try again'));
    await frames(tester);
    expect(find.byKey(const Key('trade-futures')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('a margin call shows its banner', (tester) async {
    await open(tester);
    transport.last.push('/user/queue/futures.marginCall', {
      'symbol': 'BTCUSDT',
      'positionSide': 'BOTH',
      'marginType': 'CROSSED',
      'markPrice': '62000',
      'marginRatio': '0.81',
      'maintenanceMargin': '3',
      'marginBalance': '3.7',
      'eventTime': '2026-11-19T02:00:00Z',
    });
    await frames(tester);
    expect(find.byKey(const Key('margin-call')), findsOneWidget);
    expect(
      find.textContaining('Margin call on BTCUSDT: margin ratio 81.00%'),
      findsOneWidget,
    );
    await unmount(tester);
  });

  for (final brightness in Brightness.values) {
    testWidgets('360 dp, ${brightness.name}: the Futures form and a position '
        'fit', (tester) async {
      tester.view
        ..physicalSize = const Size(360 * 3, 760 * 3)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      futures.positionList = [
        positionOf(amount: '-123.456', marginType: MarginType.isolated),
      ];
      await open(tester, brightness: brightness);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('futures-tpsl')));
      await frames(tester);
      expect(tester.takeException(), isNull);
      await tester.drag(list(), const Offset(0, -900));
      await frames(tester);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  }
}
