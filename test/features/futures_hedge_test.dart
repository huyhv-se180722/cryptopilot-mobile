import 'dart:async';

import 'package:cryptopilot_mobile/app.dart';
import 'package:cryptopilot_mobile/core/auth/token_store.dart';
import 'package:cryptopilot_mobile/core/router/app_router.dart';
import 'package:cryptopilot_mobile/core/settings/settings.dart';
import 'package:cryptopilot_mobile/features/paper/application/futures_form_controller.dart';
import 'package:cryptopilot_mobile/features/paper/application/trade_controller.dart';
import 'package:cryptopilot_mobile/features/paper/domain/futures.dart';
import 'package:cryptopilot_mobile/features/paper/domain/paper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/futures_fakes.dart';
import '../support/realtime_fakes.dart';

/// T-123: hedge mode (TR-14b): a Long and a Short per pair, opened and
/// closed from the Open and Close tabs.
void main() {
  late FakeTransport transport;
  late FakeFuturesApi api;
  late ProviderContainer app;
  final form = futuresFormProvider('BTCUSDT');

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
    app = ProviderScope.containerOf(
      tester.element(find.byType(CryptoPilotApp)),
    );
    if (brightness == Brightness.dark) {
      unawaited(app.read(themeModeProvider.notifier).select(ThemeMode.dark));
    }
    app.read(tradeFuturesProvider.notifier).show(futures: true);
    app.read(appRouterProvider).go('/trade');
    await frames(tester);
    transport.last.push('/topic/overview.FUTURES', {
      'market': 'FUTURES',
      'serverTime': '2026-11-19T02:00:00Z',
      'tickers': [
        {
          'market': 'FUTURES',
          'symbol': 'BTCUSDT',
          'sourceTime': '2026-11-19T02:00:00Z',
          'lastPrice': '76000.00',
          'changePercent24h': null,
          'quoteVolume24h': null,
          'markPrice': '76000.00',
        },
      ],
    });
    await frames(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 31));
  }

  setUp(() => api = FakeFuturesApi());

  testWidgets('one-way to hedge from the mode sheet: Open and Close tabs, '
      'no reduce-only, the Close tab names what it closes', (tester) async {
    await open(tester);
    expect(find.text('One-way'), findsOneWidget);
    expect(find.byKey(const Key('futures-reduce-only')), findsOneWidget);
    expect(find.byKey(const Key('futures-open-close')), findsNothing);

    await tester.tap(find.byKey(const Key('futures-position-mode')));
    await frames(tester);
    await tester.tap(find.byKey(const Key('mode-hedge')));
    await frames(tester);
    expect(api.calls, contains('set mode hedge'));
    expect(find.byKey(const Key('futures-open-close')), findsOneWidget);
    expect(find.byKey(const Key('futures-reduce-only')), findsNothing);

    await tester.tap(find.text('Close').first);
    await frames(tester);
    expect(find.text('Close Long'), findsOneWidget);
    expect(find.text('Close Short'), findsOneWidget);
    expect(find.byKey(const Key('futures-tpsl')), findsNothing);
    await unmount(tester);
  });

  testWidgets('in hedge mode an order names its side: Buy opens the Long, '
      'Sell on the Close tab closes it; never reduce-only', (tester) async {
    api.hedge = true;
    await open(tester);
    final c = app.read(form.notifier)
      ..setReduceOnly(true)
      ..edit(FuturesField.price, '75000.00')
      ..edit(FuturesField.size, '0.01');
    expect(await c.review(OrderSide.buy), isTrue);
    expect(await c.place(OrderSide.buy), isTrue);
    var json = api.placed.last.toJson();
    expect(json['positionSide'], 'LONG');
    expect(json.containsKey('reduceOnly'), isFalse);

    c
      ..setClosing(true)
      ..edit(FuturesField.size, '0.01');
    expect(await c.review(OrderSide.sell), isTrue);
    expect(await c.place(OrderSide.sell), isTrue);
    json = api.placed.last.toJson();
    expect(json['side'], 'SELL');
    expect(json['positionSide'], 'LONG');

    c.edit(FuturesField.size, '0.01');
    expect(await c.review(OrderSide.buy), isTrue);
    expect(await c.place(OrderSide.buy), isTrue);
    expect(api.placed.last.toJson()['positionSide'], 'SHORT');
    await unmount(tester);
  });

  testWidgets('a switch refused while a position is open is told', (
    tester,
  ) async {
    api.changeError = problem(409, 'PAPER_POSITION_MODE', 'MSG43');
    await open(tester);
    await tester.tap(find.byKey(const Key('futures-position-mode')));
    await frames(tester);
    await tester.tap(find.byKey(const Key('mode-hedge')));
    await frames(tester);
    expect(
      find.text(
        'Close every Futures position and cancel every order to change the '
        'position mode.',
      ),
      findsOneWidget,
    );
    expect(find.text('One-way'), findsOneWidget);
    await unmount(tester);
  });

  for (final brightness in Brightness.values) {
    testWidgets('360 dp, ${brightness.name}: the hedge form with its Open and '
        'Close tabs, GTD and the trailing stop fits', (tester) async {
      tester.view
        ..physicalSize = const Size(360 * 3, 760 * 3)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      api.hedge = true;
      await open(tester, brightness: brightness);
      expect(find.byKey(const Key('futures-open-close')), findsOneWidget);
      expect(tester.takeException(), isNull);

      final c = app.read(form.notifier)..setTimeInForce(FuturesTimeInForce.gtd);
      await frames(tester);
      expect(find.byKey(const Key('futures-gtd-24')), findsOneWidget);
      expect(tester.takeException(), isNull);
      c.selectKind(FuturesKind.trailingStop);
      await frames(tester);
      expect(find.byKey(const Key('futures-field-callback')), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Close').first);
      await frames(tester);
      expect(find.text('Close Long'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  }
}
