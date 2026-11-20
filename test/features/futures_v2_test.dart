import 'package:cryptopilot_mobile/app.dart';
import 'package:cryptopilot_mobile/core/auth/token_store.dart';
import 'package:cryptopilot_mobile/core/router/app_router.dart';
import 'package:cryptopilot_mobile/core/settings/settings.dart';
import 'package:cryptopilot_mobile/features/market/data/market_repository.dart';
import 'package:cryptopilot_mobile/features/market/domain/market.dart';
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

/// T-123: the second-version Futures orders (plan 9.4): time in force,
/// the trailing stop and a Limit edited in place.
void main() {
  late FakeTransport transport;
  late FakeFuturesApi api;
  late ProviderContainer container;
  final form = futuresFormProvider('BTCUSDT');

  void pushTicker() => transport.last.push('/topic/overview.FUTURES', {
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
    pushTicker();
    await tester.pump();
    return container.read(form.notifier);
  }

  FuturesFormState state() => container.read(form);

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 31));
  }

  setUp(() => api = FakeFuturesApi());

  testWidgets('a Limit goes IOC, GTX, or GTD expiring the hours chosen '
      'after it is sent', (tester) async {
    final c = await pump(tester);
    c
      ..setTimeInForce(FuturesTimeInForce.ioc)
      ..edit(FuturesField.price, '75000.00')
      ..edit(FuturesField.size, '0.01');
    expect(await c.review(OrderSide.buy), isTrue);
    expect(await c.place(OrderSide.buy), isTrue);
    expect(api.placed.last.toJson()['timeInForce'], 'IOC');
    expect(api.placed.last.toJson().containsKey('goodTillDate'), isFalse);

    c
      ..setTimeInForce(FuturesTimeInForce.gtd)
      ..setGtdHours(1)
      ..edit(FuturesField.size, '0.01');
    expect(await c.review(OrderSide.sell), isTrue);
    expect(await c.place(OrderSide.sell), isTrue);
    final json = api.placed.last.toJson();
    expect(json['timeInForce'], 'GTD');
    // now = 2026-11-06T10:00Z in the fakes.
    expect(json['goodTillDate'], '2026-11-06T11:00:00.000Z');
    await unmount(tester);
  });

  testWidgets('a trailing stop: a callback of 0.1 to 20 by 0.1, no trigger, '
      'an activation price only when typed', (tester) async {
    final c = await pump(tester);
    c.selectKind(FuturesKind.trailingStop);
    expect(state().fields, [
      FuturesField.callback,
      FuturesField.activation,
      FuturesField.size,
    ]);
    c
      ..edit(FuturesField.callback, '25')
      ..edit(FuturesField.size, '0.01');
    expect(await c.review(OrderSide.sell), isFalse);
    expect(state().issues[FuturesField.callback], FuturesIssue.outOfRange);
    c.edit(FuturesField.callback, '0.15');
    expect(await c.review(OrderSide.sell), isFalse);
    expect(state().issues[FuturesField.callback], FuturesIssue.offStep);

    c.edit(FuturesField.callback, '1.5');
    expect(await c.review(OrderSide.sell), isTrue);
    expect(await c.place(OrderSide.sell), isTrue);
    var json = api.placedAlgo.last.toJson();
    expect(json['type'], 'TRAILING_STOP_MARKET');
    expect(json['callbackRate'], '1.5');
    expect(json.containsKey('triggerPrice'), isFalse);
    expect(json.containsKey('activatePrice'), isFalse);

    c
      ..edit(FuturesField.size, '0.01')
      ..edit(FuturesField.activation, '80000.00');
    expect(await c.review(OrderSide.sell), isTrue);
    expect(await c.place(OrderSide.sell), isTrue);
    json = api.placedAlgo.last.toJson();
    expect(json['activatePrice'], '80000.00');
    expect(c.entryPrice(), '80000.00');
    await unmount(tester);
  });

  testWidgets('an open Limit is edited in place: its price and quantity '
      'start from its own; a 360 dp form with GTD and the trailing stop '
      'fits', (tester) async {
    tester.view
      ..physicalSize = const Size(360 * 3, 760 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    api.orderList = [
      FuturesOrder(
        orderId: 'o-1',
        symbol: 'BTCUSDT',
        side: OrderSide.buy,
        positionSide: PositionSide.both,
        type: 'LIMIT',
        origQty: '0.010',
        executedQty: '0',
        status: OrderStatus.newOrder,
        time: DateTime.utc(2026, 11, 19),
        price: '75000.00',
      ),
    ];
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
    Future<void> frames() async {
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    await frames();
    transport.last.onConnected();
    final app = ProviderScope.containerOf(
      tester.element(find.byType(CryptoPilotApp)),
    );
    app.read(tradeFuturesProvider.notifier).show(futures: true);
    app.read(appRouterProvider).go('/trade');
    await frames();
    pushTicker();
    await frames();

    final c = app.read(form.notifier)..setTimeInForce(FuturesTimeInForce.gtd);
    await frames();
    expect(find.byKey(const Key('futures-gtd-24')), findsOneWidget);
    expect(tester.takeException(), isNull);
    c.selectKind(FuturesKind.trailingStop);
    await frames();
    expect(find.byKey(const Key('futures-field-callback')), findsOneWidget);
    expect(tester.takeException(), isNull);

    final list = find
        .descendant(
          of: find.byKey(const Key('trade-futures')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.byKey(const Key('futures-amend-o-1')),
      200,
      scrollable: list,
    );
    await frames();
    await tester.tap(find.byKey(const Key('futures-amend-o-1')));
    await frames();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('amend-quantity')))
          .controller!
          .text,
      '0.010',
    );
    await tester.enterText(find.byKey(const Key('amend-price')), '75500.00');
    await tester.pump();
    await tester.tap(find.byKey(const Key('amend-confirm')));
    await frames();
    expect(api.calls, contains('amend o-1 75500.00 0.010'));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 31));
  });
}
