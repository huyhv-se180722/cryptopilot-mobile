import 'package:cryptopilot_mobile/core/auth/token_store.dart';
import 'package:cryptopilot_mobile/core/errors/api_failure.dart';
import 'package:cryptopilot_mobile/features/paper/data/paper_repository.dart';
import 'package:cryptopilot_mobile/features/paper/domain/paper.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/paper_fakes.dart';
import '../support/realtime_fakes.dart';

void main() {
  late FakeTransport transport;
  late FakePaperApi api;
  late ProviderContainer container;

  Future<void> pump(
    WidgetTester tester,
    List<ProviderListenable<Object?>> watched,
  ) async {
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
            for (final provider in watched) {
              ref.watch(provider);
            }
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
    await tester.pump();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 31));
  }

  Map<String, Object?> orderPush(String id, String status) => {
    'orderId': id,
    'clientOrderId': null,
    'pairId': 'pair-BTC',
    'symbol': 'BTCUSDT',
    'market': 'SPOT',
    'side': 'BUY',
    'type': 'LIMIT',
    'timeInForce': 'GTC',
    'price': '70000.00',
    'quantity': '0.01',
    'quoteOrderQty': null,
    'executedQuantity': '0',
    'cumQuote': '0',
    'avgPrice': null,
    'status': status,
    'statusReason': null,
    'placedAt': '2026-11-19T04:00:00Z',
    'closedAt': null,
    'stopPrice': null,
    'trailingDelta': null,
    'triggeredAt': null,
    'listId': null,
  };

  setUp(() => api = FakePaperApi());

  group('PaperAccountRepository', () {
    testWidgets('opens the account once, then reads the Spot wallet; a '
        'balance push changes it and the totals are read again', (
      tester,
    ) async {
      await pump(tester, [paperAccountProvider]);
      expect(api.calls, ['open', 'wallet SPOT']);
      expect(transport.last.subscriptions.keys, contains(balancesQueue));
      expect(
        container.read(paperAccountProvider).spotBalance('USDT')!.free,
        '10000.00000000',
      );

      transport.last.push(balancesQueue, {
        'wallet': 'SPOT',
        'coinId': 'c',
        'asset': 'USDT',
        'free': '9240.00000000',
        'locked': '0',
        'total': '9240.00000000',
      });
      await tester.pump();
      expect(
        container.read(paperAccountProvider).spotBalance('USDT')!.free,
        '9240.00000000',
      );
      await tester.pump(PaperAccountRepository.settle);
      await tester.pump();
      expect(api.calls, ['open', 'wallet SPOT', 'wallet SPOT']);
      await unmount(tester);
    });

    testWidgets('a reconnection reads the wallet again (missed pushes are '
        'not replayed)', (tester) async {
      await pump(tester, [paperAccountProvider]);
      transport.last.drop();
      await tester.pump(const Duration(seconds: 2));
      transport.last.onConnected();
      await tester.pump();
      await tester.pump();
      expect(api.calls.where((c) => c == 'wallet SPOT'), hasLength(2));
      expect(api.calls.where((c) => c == 'open'), hasLength(1));
      await unmount(tester);
    });

    testWidgets('an account that cannot be opened says so; Try again opens '
        'it', (tester) async {
      api.openError = problem(503, 'UNAVAILABLE', 'MSG43');
      await pump(tester, [paperAccountProvider]);
      expect(container.read(paperAccountProvider).failure, isNotNull);
      expect(container.read(paperAccountProvider).spot, isNull);

      api.openError = null;
      container.read(paperAccountProvider.notifier).retry();
      await tester.pump();
      await tester.pump();
      expect(container.read(paperAccountProvider).spot, isNotNull);
      await unmount(tester);
    });
  });

  group('OpenOrdersRepository', () {
    testWidgets('read once the account is open; a push adds a new order and '
        'takes out a finished one', (tester) async {
      api.open = [paperOrderOf('o-1')];
      await pump(tester, [openOrdersProvider]);
      expect(api.calls, ['open', 'wallet SPOT', 'open orders']);
      expect(container.read(openOrdersProvider).of('pair-BTC'), hasLength(1));

      transport.last.push(ordersQueue, orderPush('o-2', 'NEW'));
      await tester.pump();
      expect(
        [for (final o in container.read(openOrdersProvider).orders!) o.orderId],
        ['o-2', 'o-1'],
      );
      transport.last.push(ordersQueue, orderPush('o-1', 'FILLED'));
      await tester.pump();
      expect(
        [for (final o in container.read(openOrdersProvider).orders!) o.orderId],
        ['o-2'],
      );
      await unmount(tester);
    });

    testWidgets('cancelling one order of a group cancels the group; cancel '
        'all takes the pair\'s orders', (tester) async {
      api.open = [
        paperOrderOf('a', listId: 'list-1'),
        paperOrderOf('b', listId: 'list-1'),
        paperOrderOf('c'),
        paperOrderOf('d', pairId: 'pair-ETH', symbol: 'ETHUSDT'),
      ];
      await pump(tester, [openOrdersProvider]);
      final repository = container.read(openOrdersProvider.notifier);
      await repository.cancel(api.open.first);
      expect(api.calls.last, 'cancel list list-1');
      expect([
        for (final o in container.read(openOrdersProvider).orders!) o.orderId,
      ], unorderedEquals(['c', 'd']));
      await repository.cancelAll('pair-BTC');
      expect(
        [for (final o in container.read(openOrdersProvider).orders!) o.orderId],
        ['d'],
      );
      await unmount(tester);
    });

    testWidgets('a refused cancel throws and keeps the order', (tester) async {
      api.open = [paperOrderOf('o-1')];
      await pump(tester, [openOrdersProvider]);
      api.cancelError = problem(409, 'PAPER_ORDER_NOT_OPEN', 'MSG43');
      await expectLater(
        container.read(openOrdersProvider.notifier).cancel(api.open.first),
        throwsA(isA<ProblemFailure>()),
      );
      expect(container.read(openOrdersProvider).orders, hasLength(1));
      expect(
        container.read(openOrdersProvider).orders!.single.status,
        OrderStatus.newOrder,
      );
      await unmount(tester);
    });
  });
}
