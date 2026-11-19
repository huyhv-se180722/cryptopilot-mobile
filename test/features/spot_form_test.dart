import 'package:cryptopilot_mobile/core/auth/token_store.dart';
import 'package:cryptopilot_mobile/core/errors/api_failure.dart';
import 'package:cryptopilot_mobile/features/market/data/market_repository.dart';
import 'package:cryptopilot_mobile/features/market/domain/market.dart';
import 'package:cryptopilot_mobile/features/paper/application/spot_form_controller.dart';
import 'package:cryptopilot_mobile/features/paper/data/paper_repository.dart';
import 'package:cryptopilot_mobile/features/paper/domain/paper.dart';
import 'package:cryptopilot_mobile/features/paper/domain/paper_refusal.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/paper_fakes.dart';
import '../support/realtime_fakes.dart';

void main() {
  late FakeTransport transport;
  late FakePaperApi api;
  late ProviderContainer container;
  final form = spotFormProvider('BTCUSDT');

  /// The form with the BTC pair listed and a last price of 76,000.
  Future<SpotFormController> pump(WidgetTester tester) async {
    transport = FakeTransport();
    await tester.pumpWidget(
      ProviderScope(
        overrides: baseOverrides(
          store: MemoryTokenStore(storedFor('saved')),
          tokens: FakeAuthTokenApi(),
          transport: transport,
          paper: api,
        ),
        retry: (_, _) => null,
        child: Consumer(
          builder: (context, ref, _) {
            ref
              ..watch(form)
              ..watch(marketRepositoryProvider(Market.spot))
              ..watch(openOrdersProvider);
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
    transport.last.push('/topic/overview.SPOT', {
      'market': 'SPOT',
      'serverTime': '2026-11-19T02:00:00Z',
      'tickers': [
        {
          'market': 'SPOT',
          'symbol': 'BTCUSDT',
          'sourceTime': '2026-11-19T02:00:00Z',
          'lastPrice': '76000.00',
          'changePercent24h': '1',
          'quoteVolume24h': '1',
          'markPrice': null,
        },
      ],
    });
    await tester.pump();
    return container.read(form.notifier);
  }

  SpotFormState state() => container.read(form);

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 31));
  }

  setUp(() => api = FakePaperApi());

  testWidgets('a Limit Buy: required fields first, then GTC with a key; the '
      'amount empties, the price stays; Sell keeps its own inputs', (
    tester,
  ) async {
    final c = await pump(tester);
    expect(await c.submit(), isFalse);
    expect(state().errors.keys, {SpotField.price, SpotField.amount});
    expect(api.placed, isEmpty);

    c
      ..edit(SpotField.price, '75000.00')
      ..edit(SpotField.amount, '0.01000');
    expect(await c.submit(), isTrue);
    final request = api.placed.single;
    expect(request.type, SpotOrderType.limit);
    expect(request.toJson()['timeInForce'], 'GTC');
    expect(request.clientOrderId, hasLength(36));
    expect(state().buy.price, '75000.00');
    expect(state().buy.amount, isEmpty);
    expect(state().placed, 1);
    expect(container.read(openOrdersProvider).of('pair-BTC'), hasLength(1));

    c.selectSide(OrderSide.sell);
    expect(state().inputs.price, isEmpty);
    c.selectSide(OrderSide.buy);
    expect(state().inputs.price, '75000.00');
    await unmount(tester);
  });

  testWidgets('off the tick or step, or not positive, is refused on the '
      'phone', (tester) async {
    final c = await pump(tester);
    c
      ..edit(SpotField.price, '75000.005')
      ..edit(SpotField.amount, '0');
    await c.submit();
    expect(state().errors[SpotField.price]!.issue, InputIssue.offStep);
    expect(state().errors[SpotField.price]!.limit, '0.010000000000');
    expect(state().errors[SpotField.amount]!.issue, InputIssue.notPositive);
    // Editing a field clears its error.
    c.edit(SpotField.amount, '0.01');
    expect(state().errors.containsKey(SpotField.amount), isFalse);
    await unmount(tester);
  });

  testWidgets('Market by total sends what a Buy spends', (tester) async {
    final c = await pump(tester);
    c
      ..selectKind(SpotKind.market)
      ..setByTotal(true)
      ..edit(SpotField.total, '100');
    expect(await c.submit(), isTrue);
    final json = api.placed.single.toJson();
    expect(json['type'], 'MARKET');
    expect(json['quoteOrderQty'], '100');
    expect(json.containsKey('quantity'), isFalse);
    await unmount(tester);
  });

  testWidgets('a stop takes its type from where it lies against the last '
      'price', (tester) async {
    final c = await pump(tester);
    c
      ..selectKind(SpotKind.stopLimit)
      ..edit(SpotField.stop, '77000.00')
      ..edit(SpotField.price, '77100.00')
      ..edit(SpotField.amount, '0.01');
    await c.submit();
    expect(api.placed.last.type, SpotOrderType.stopLossLimit);

    c
      ..edit(SpotField.stop, '75000.00')
      ..edit(SpotField.price, '75100.00')
      ..edit(SpotField.amount, '0.01');
    await c.submit();
    expect(api.placed.last.type, SpotOrderType.takeProfitLimit);

    c
      ..selectSide(OrderSide.sell)
      ..selectKind(SpotKind.stopMarket)
      ..edit(SpotField.stop, '75000.00')
      ..edit(SpotField.amount, '0.01');
    await c.submit();
    expect(api.placed.last.type, SpotOrderType.stopLoss);
    expect(api.placed.last.side, OrderSide.sell);
    await unmount(tester);
  });

  testWidgets('an OCO Sell: take profit above, stop below the last price', (
    tester,
  ) async {
    final c = await pump(tester);
    c
      ..selectSide(OrderSide.sell)
      ..selectKind(SpotKind.oco)
      ..edit(SpotField.takeProfit, '75000.00')
      ..edit(SpotField.stop, '77000.00')
      ..edit(SpotField.amount, '0.01');
    await c.submit();
    expect(
      state().errors[SpotField.takeProfit]!.issue,
      InputIssue.takeProfitSide,
    );
    expect(state().errors[SpotField.stop]!.issue, InputIssue.stopSide);

    c
      ..edit(SpotField.takeProfit, '80000.00')
      ..edit(SpotField.stop, '70000.00');
    expect(await c.submit(), isTrue);
    final json = api.placedLists.single.toJson();
    expect(json['type'], 'OCO');
    expect((json['oco']! as Map)['quantity'], '0.01');
    expect((json['oco']! as Map).containsKey('stopLimitPrice'), isFalse);
    await unmount(tester);
  });

  testWidgets('a Limit Buy with TP/SL: the OCO sells around the limit '
      'price once it fills', (tester) async {
    final c = await pump(tester);
    c
      ..selectKind(SpotKind.limitTpSl)
      ..edit(SpotField.price, '75000.00')
      ..edit(SpotField.amount, '0.01')
      ..edit(SpotField.takeProfit, '74000.00')
      ..edit(SpotField.stop, '73000.00');
    await c.submit();
    expect(
      state().errors[SpotField.takeProfit]!.issue,
      InputIssue.takeProfitSide,
    );

    c.edit(SpotField.takeProfit, '78000.00');
    expect(await c.submit(), isTrue);
    final json = api.placedLists.single.toJson();
    expect(json['type'], 'OTOCO');
    expect((json['working']! as Map)['side'], 'BUY');
    expect((json['oco']! as Map)['side'], 'SELL');
    await unmount(tester);
  });

  testWidgets('a network failure keeps the key, so sending again cannot '
      'place twice; a server answer gives the next order a new key', (
    tester,
  ) async {
    final c = await pump(tester);
    c
      ..edit(SpotField.price, '75000.00')
      ..edit(SpotField.amount, '0.01');
    api.placeError = const NetworkFailure(timeout: true);
    expect(await c.submit(), isFalse);
    expect(state().failure, isA<NetworkFailure>());
    api.placeError = null;
    expect(await c.submit(), isTrue);
    expect(api.placed[0].clientOrderId, api.placed[1].clientOrderId);

    c.edit(SpotField.amount, '0.01');
    api.placeError = problem(
      400,
      'PAPER_PRICE_FILTER',
      'MSG15',
      args: ['price', '75000.00', '70000', 'MAX'],
    );
    await c.submit();
    final error = state().errors[SpotField.price]!;
    expect(error.refusal!.kind, RefusalKind.atMost);
    expect(error.refusal!.limit, '70000');
    api.placeError = null;
    await c.submit();
    expect(api.placed[3].clientOrderId, isNot(api.placed[2].clientOrderId));
    await unmount(tester);
  });

  testWidgets('a balance refusal is a notice of the whole order', (
    tester,
  ) async {
    final c = await pump(tester);
    c
      ..edit(SpotField.price, '75000.00')
      ..edit(SpotField.amount, '1');
    api.placeError = problem(
      400,
      'PAPER_INSUFFICIENT_BALANCE',
      'MSG01',
      args: ['USDT', '75000.00', '10000'],
    );
    await c.submit();
    expect(state().notice!.kind, RefusalKind.insufficientBalance);
    expect(state().errors, isEmpty);
    await unmount(tester);
  });

  testWidgets('the slider: a share of what is available, down to the step', (
    tester,
  ) async {
    final c = await pump(tester);
    c
      ..edit(SpotField.price, '30000.00')
      ..useShare(0.5, available: '10000');
    // 5,000 / 30,000 = 0.1666… → 0.16666 on a 0.00001 step.
    expect(state().buy.amount, '0.16666');
    c
      ..selectSide(OrderSide.sell)
      ..useShare(0.25, available: '0.10000000');
    expect(state().sell.amount, '0.025');
    await unmount(tester);
  });
}
