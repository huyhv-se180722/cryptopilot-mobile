import 'package:cryptopilot_mobile/core/auth/token_store.dart';
import 'package:cryptopilot_mobile/core/json/json_read.dart';
import 'package:cryptopilot_mobile/features/market/data/order_book_repository.dart';
import 'package:cryptopilot_mobile/features/market/domain/market.dart';
import 'package:cryptopilot_mobile/features/market/domain/order_book.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/realtime_fakes.dart';

void main() {
  group('order book shapes (backend develop 5c2398cb)', () {
    test('depth levels are [price, quantity] strings; a number is refused', () {
      final depth = decodeDepth({
        'market': 'SPOT',
        'symbol': 'BTCUSDT',
        'lastUpdateId': 1,
        'receivedAt': '2026-11-19T02:00:00Z',
        'bids': [
          ['76000.00', '1.5'],
        ],
        'asks': <Object?>[],
      });
      expect(depth.bids.single, const BookLevel('76000.00', '1.5'));
      expect(
        () => decodeDepth({
          'bids': [
            [76000, 1],
          ],
          'asks': <Object?>[],
        }),
        throwsA(isA<DecodeException>()),
      );
    });

    test('trades carry who took the other side', () {
      final trades = decodeMarketTrades({
        'market': 'SPOT',
        'symbol': 'BTCUSDT',
        'trades': [
          {
            'id': 9,
            'price': '76000.10',
            'quantity': '0.01',
            'time': '2026-11-19T02:00:00Z',
            'buyerMaker': true,
          },
        ],
      });
      expect(trades.single.buyerMaker, isTrue);
    });

    test(
      'levels gather on the tick: bids down, asks up, quantities summed',
      () {
        const bids = [
          BookLevel('76000.40', '1'),
          BookLevel('76000.10', '2'),
          BookLevel('75999.90', '3'),
        ];
        expect(groupLevels(bids, '1', bids: true), const [
          BookLevel('76000', '3'),
          BookLevel('75999', '3'),
        ]);
        const asks = [BookLevel('76000.10', '1'), BookLevel('76000.90', '2')];
        expect(groupLevels(asks, '1', bids: false), const [
          BookLevel('76001', '3'),
        ]);
        expect(groupLevels(bids, '0.01', bids: true, count: 2), hasLength(2));
      },
    );

    test('the B/S share of the levels shown', () {
      expect(
        bidShare(const [BookLevel('1', '3')], const [BookLevel('2', '1')]),
        0.75,
      );
      expect(bidShare(const [], const []), 0.5);
    });
  });

  group('OrderBookRepository', () {
    late FakeTransport transport;
    late FakeMarketApi api;
    late ProviderContainer container;
    const key = (market: Market.spot, symbol: 'BTCUSDT');
    final listeners = ValueNotifier<List<ProviderListenable<Object?>>>([]);

    Future<void> pump(WidgetTester tester) async {
      transport = FakeTransport();
      api = FakeMarketApi();
      listeners.value = [orderBookProvider(key)];
      await tester.pumpWidget(
        ProviderScope(
          overrides: baseOverrides(
            store: MemoryTokenStore(storedFor('saved')),
            tokens: FakeAuthTokenApi(),
            transport: transport,
            market: api,
          ),
          retry: (_, _) => null,
          child: ValueListenableBuilder(
            valueListenable: listeners,
            builder: (_, watched, _) => Consumer(
              builder: (context, ref, _) {
                for (final provider in watched) {
                  ref.watch(provider);
                }
                return const SizedBox();
              },
            ),
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

    Map<String, Object?> depth(String bid) => {
      'bids': [
        [bid, '1'],
      ],
      'asks': [
        ['76100.00', '1'],
      ],
    };

    Map<String, Object?> trades(List<int> ids) => {
      'trades': [
        for (final id in ids)
          {
            'id': id,
            'price': '76000',
            'quantity': '0.1',
            'time': '2026-11-19T02:00:00Z',
            'buyerMaker': false,
          },
      ],
    };

    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 31));
    }

    testWidgets('REST first; pushes reach the screen at most every 250 ms, '
        'the latest depth and every trade, newest first', (tester) async {
      await pump(tester);
      expect(api.bookCalls, ['depth SPOT BTCUSDT', 'trades SPOT BTCUSDT']);
      expect(transport.last.subscriptions.keys.toSet(), {
        '/topic/depth.SPOT.BTCUSDT',
        '/topic/trades.SPOT.BTCUSDT',
      });
      expect(
        container.read(orderBookProvider(key)).depth!.bids.first.price,
        '76000.00',
      );

      var changes = 0;
      final counting = container.listen(
        orderBookProvider(key),
        (_, _) => changes++,
      );
      transport.last
        ..push('/topic/depth.SPOT.BTCUSDT', depth('76010.00'))
        ..push('/topic/trades.SPOT.BTCUSDT', trades([1, 2]))
        ..push('/topic/depth.SPOT.BTCUSDT', depth('76020.00'))
        ..push('/topic/trades.SPOT.BTCUSDT', trades([3]));
      await tester.pump(const Duration(milliseconds: 100));
      expect(changes, 0);
      await tester.pump(const Duration(milliseconds: 200));
      expect(changes, 1);
      final book = container.read(orderBookProvider(key));
      expect(book.depth!.bids.first.price, '76020.00');
      expect([for (final t in book.trades) t.id], [3, 2, 1]);

      counting.close();
      listeners.value = [];
      await tester.pump();
      await tester.pump();
      expect(transport.last.subscriptions, isEmpty);
      await unmount(tester);
    });

    testWidgets('a depth that cannot be read gives the failure', (
      tester,
    ) async {
      transport = FakeTransport();
      await pump(tester);
      api.depthError = problem(404, 'NOT_FOUND', 'MSG41');
      await container.read(orderBookProvider(key).notifier).load();
      expect(container.read(orderBookProvider(key)).failure, isNotNull);
      // What was shown stays.
      expect(container.read(orderBookProvider(key)).depth, isNotNull);
      await unmount(tester);
    });
  });
}
