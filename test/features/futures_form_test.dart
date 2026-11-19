import 'package:cryptopilot_mobile/core/auth/token_store.dart';
import 'package:cryptopilot_mobile/core/errors/api_failure.dart';
import 'package:cryptopilot_mobile/features/market/data/market_repository.dart';
import 'package:cryptopilot_mobile/features/market/domain/market.dart';
import 'package:cryptopilot_mobile/features/paper/application/futures_form_controller.dart';
import 'package:cryptopilot_mobile/features/paper/domain/futures.dart';
import 'package:cryptopilot_mobile/features/paper/domain/paper.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/futures_fakes.dart';
import '../support/realtime_fakes.dart';

void main() {
  late FakeTransport transport;
  late FakeFuturesApi api;
  late ProviderContainer container;
  final form = futuresFormProvider('BTCUSDT');

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
    await tester.pump();
    return container.read(form.notifier);
  }

  FuturesFormState state() => container.read(form);

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 31));
  }

  setUp(() => api = FakeFuturesApi());

  testWidgets('a Limit Long: required fields, then the warnings, then the '
      'order with a key; the size empties', (tester) async {
    final c = await pump(tester);
    expect(await c.review(OrderSide.buy), isFalse);
    expect(state().issues.keys, {FuturesField.price, FuturesField.size});

    c
      ..edit(FuturesField.price, '75000.00')
      ..edit(FuturesField.size, '0.01000');
    expect(await c.review(OrderSide.buy), isTrue);
    expect(api.calls.last, 'warnings BUY 0.01000');
    expect(state().review!.cost, '38.00');
    expect(await c.place(OrderSide.buy), isTrue);
    final json = api.placed.single.toJson();
    expect(json['type'], 'LIMIT');
    expect(json['timeInForce'], 'GTC');
    expect(json['newClientOrderId'], hasLength(36));
    expect(state().size, isEmpty);
    expect(state().placed, 1);
    await unmount(tester);
  });

  testWidgets('a BLOCKING warning stops the order (TR-26)', (tester) async {
    api.warningsAnswer = const OrderWarnings(
      warnings: [
        OrderWarning(
          type: 'INSUFFICIENT_MARGIN',
          severity: WarningSeverity.blocking,
          message: 'Not enough margin.',
        ),
      ],
    );
    final c = await pump(tester);
    c
      ..selectKind(FuturesKind.market)
      ..edit(FuturesField.size, '10');
    expect(await c.review(OrderSide.sell), isFalse);
    expect(state().review!.blocked, isTrue);
    expect(await c.place(OrderSide.sell), isFalse);
    expect(api.placed, isEmpty);
    await unmount(tester);
  });

  testWidgets('a size in USDT is sent as the coin quantity, down to the step', (
    tester,
  ) async {
    final c = await pump(tester);
    c
      ..edit(FuturesField.price, '75000.00')
      ..setSizeInUsdt(true)
      ..edit(FuturesField.size, '1000');
    // 1000 / 75000 = 0.013333… → 0.01333 on a 0.00001 step.
    expect(c.quantity(), '0.01333');
    c.selectKind(FuturesKind.market);
    // Market: at the mark, 1000 / 76000 = 0.0131578… → 0.01315.
    expect(c.quantity(), '0.01315');
    await unmount(tester);
  });

  testWidgets('TP/SL do not go with reduce-only', (tester) async {
    final c = await pump(tester);
    c
      ..edit(FuturesField.price, '75000.00')
      ..edit(FuturesField.size, '0.01')
      ..setReduceOnly(true)
      ..setTpSl(true)
      ..edit(FuturesField.takeProfit, '80000.00')
      ..edit(FuturesField.stopLoss, '72000.00');
    expect(await c.review(OrderSide.buy), isFalse);
    expect(
      state().issues[FuturesField.takeProfit],
      FuturesIssue.tpSlWithReduceOnly,
    );
    await unmount(tester);
  });

  testWidgets('a Stop Market on Mark is a conditional order with no '
      'warnings call', (tester) async {
    final c = await pump(tester);
    c
      ..selectKind(FuturesKind.stopMarket)
      ..edit(FuturesField.trigger, '77000.00')
      ..edit(FuturesField.size, '0.01');
    expect(await c.review(OrderSide.buy), isTrue);
    expect(api.calls.where((x) => x.startsWith('warnings')), isEmpty);
    expect(await c.place(OrderSide.buy), isTrue);
    final json = api.placedAlgo.single.toJson();
    expect(json['type'], 'STOP_MARKET');
    expect(json['workingType'], 'MARK_PRICE');
    expect(json['triggerPrice'], '77000.00');
    await unmount(tester);
  });

  testWidgets('a network failure keeps the key for the retry', (tester) async {
    final c = await pump(tester);
    c
      ..selectKind(FuturesKind.market)
      ..edit(FuturesField.size, '0.01');
    await c.review(OrderSide.buy);
    api.placeError = const NetworkFailure(timeout: true);
    expect(await c.place(OrderSide.buy), isFalse);
    api.placeError = null;
    expect(await c.place(OrderSide.buy), isTrue);
    expect(api.placed[0].clientOrderId, api.placed[1].clientOrderId);
    await unmount(tester);
  });
}
