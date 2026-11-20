import 'dart:async';

import 'package:cryptopilot_mobile/app.dart';
import 'package:cryptopilot_mobile/core/auth/token_store.dart';
import 'package:cryptopilot_mobile/core/router/app_router.dart';
import 'package:cryptopilot_mobile/core/settings/settings.dart';
import 'package:cryptopilot_mobile/features/paper/application/trade_controller.dart';
import 'package:cryptopilot_mobile/features/paper/domain/futures.dart';
import 'package:cryptopilot_mobile/features/paper/domain/futures_calculator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/futures_fakes.dart';
import '../support/realtime_fakes.dart';

/// T-123: the Futures calculator (TR-25), five tabs worked out by the
/// server.
void main() {
  late FakeTransport transport;
  late FakeFuturesApi api;

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
          futures: api,
          settings: MemorySettingsStore(),
        ),
        retry: (_, _) => null,
        child: const CryptoPilotApp(),
      ),
    );
    await frames(tester);
    transport.last.onConnected();
    final app = ProviderScope.containerOf(
      tester.element(find.byType(CryptoPilotApp)),
    );
    if (brightness == Brightness.dark) {
      unawaited(app.read(themeModeProvider.notifier).select(ThemeMode.dark));
    }
    app.read(tradeFuturesProvider.notifier).show(futures: true);
    app.read(appRouterProvider).go('/trade');
    await frames(tester);
    await tester.tap(find.byKey(const Key('futures-calculator')));
    await frames(tester);
  }

  Future<void> type(WidgetTester tester, String key, String value) async {
    await tester.enterText(
      find.descendant(
        of: find.byKey(Key(key)),
        matching: find.byType(TextField),
      ),
      value,
    );
    await tester.pump();
  }

  // The sheet is a lazy list: a button below the fold is not built yet.
  Future<void> calculate(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.byKey(const Key('calc-go')),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('calc')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('calc-go')));
    await frames(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 31));
  }

  setUp(() => api = FakeFuturesApi());

  test('each tab sends only its own fields', () {
    const pnl = CalcRequest(
      tab: CalcTab.pnl,
      symbol: 'BTCUSDT',
      long: false,
      leverage: 10,
      entryPrice: '76000',
      exitPrice: '75000',
      quantity: '0.01',
    );
    expect(pnl.toJson(), {
      'symbol': 'BTCUSDT',
      'side': 'SHORT',
      'leverage': 10,
      'entryPrice': '76000',
      'exitPrice': '75000',
      'quantity': '0.01',
    });
    const liq = CalcRequest(
      tab: CalcTab.liquidation,
      symbol: 'BTCUSDT',
      leverage: 10,
      entryPrice: '76000',
      quantity: '0.01',
      marginType: MarginType.isolated,
    );
    expect(liq.toJson().containsKey('walletBalance'), isFalse);
    expect(liq.toJson()['marginType'], 'ISOLATED');
    const open = CalcRequest(
      tab: CalcTab.openPrice,
      symbol: 'BTCUSDT',
      lots: [CalcLot(price: '76000', quantity: '0.01')],
    );
    expect(open.toJson(), {
      'symbol': 'BTCUSDT',
      'lots': [
        {'price': '76000', 'quantity': '0.01'},
      ],
    });
    expect(decodeCalcResult({'pnl': '10.00', 'roe': '26.32'}).roe, '26.32');
  });

  testWidgets('PnL: the fields are required, then the server works it out '
      'at the pair\'s leverage', (tester) async {
    api.calcAnswer = const CalcResult(
      initialMargin: '38.00',
      pnl: '10.00',
      roe: '26.32',
    );
    await open(tester);
    expect(find.byKey(const Key('calc')), findsOneWidget);
    await calculate(tester);
    expect(find.text('Required.'), findsWidgets);
    expect(api.calcRequests, isEmpty);

    await type(tester, 'calc-entry', '76000');
    await type(tester, 'calc-exit', '77000');
    await type(tester, 'calc-quantity', '0.01');
    await calculate(tester);
    final request = api.calcRequests.single;
    expect(request.tab, CalcTab.pnl);
    expect(request.leverage, 20);
    expect(request.long, isTrue);
    // A gain carries its sign (the colour is not the only cue).
    await tester.scrollUntilVisible(
      find.text('+26.32%'),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('calc')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('+26.32%'), findsOneWidget);
    expect(find.text('+10.00'), findsOneWidget);
    expect(find.text('38.00'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('liquidation of an isolated position needs no wallet; open '
      'price takes the parts typed', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('calc-tab-liquidation')));
    await frames(tester);
    await tester.tap(find.byKey(const Key('calc-margin-ISOLATED')));
    await frames(tester);
    await type(tester, 'calc-entry', '76000');
    await type(tester, 'calc-quantity', '0.01');
    await calculate(tester);
    expect(api.calcRequests.last.marginType, MarginType.isolated);
    expect(api.calcRequests.last.walletBalance, isNull);

    await tester.ensureVisible(find.byKey(const Key('calc-tab-openPrice')));
    await tester.tap(find.byKey(const Key('calc-tab-openPrice')));
    await frames(tester);
    await calculate(tester);
    expect(find.text('Enter at least one price and quantity.'), findsOneWidget);
    await type(tester, 'calc-lot-0-price', '76000');
    await type(tester, 'calc-lot-0-quantity', '0.01');
    await type(tester, 'calc-lot-1-price', '74000');
    await type(tester, 'calc-lot-1-quantity', '0.03');
    await calculate(tester);
    expect(api.calcRequests.last.lots, hasLength(2));
    await unmount(tester);
  });

  testWidgets('a position past the leverage is refused in words', (
    tester,
  ) async {
    api.calcError = problem(409, 'PAPER_MAX_POSITION_AT_LEVERAGE', 'MSG15');
    await open(tester);
    await tester.tap(find.byKey(const Key('calc-tab-liquidation')));
    await frames(tester);
    await tester.tap(find.byKey(const Key('calc-margin-ISOLATED')));
    await frames(tester);
    await type(tester, 'calc-entry', '76000');
    await type(tester, 'calc-quantity', '900');
    await calculate(tester);
    expect(
      find.text(
        'This position is larger than the leverage allows. '
        'Lower the leverage or the size.',
      ),
      findsOneWidget,
    );
    await unmount(tester);
  });

  for (final brightness in Brightness.values) {
    testWidgets('360 dp, ${brightness.name}: every tab fits', (tester) async {
      tester.view
        ..physicalSize = const Size(360 * 3, 760 * 3)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await open(tester, brightness: brightness);
      for (final tab in CalcTab.values) {
        await tester.ensureVisible(find.byKey(Key('calc-tab-${tab.path}')));
        await tester.tap(find.byKey(Key('calc-tab-${tab.path}')));
        await frames(tester);
        expect(tester.takeException(), isNull, reason: tab.path);
      }
      await unmount(tester);
    });
  }
}
