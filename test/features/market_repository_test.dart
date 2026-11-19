import 'package:cryptopilot_mobile/core/auth/token_store.dart';
import 'package:cryptopilot_mobile/core/errors/api_failure.dart';
import 'package:cryptopilot_mobile/features/market/application/market_board.dart';
import 'package:cryptopilot_mobile/features/market/data/market_repository.dart';
import 'package:cryptopilot_mobile/features/market/domain/market.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/realtime_fakes.dart';

/// Stats that fail, for the pair ticker's failure.
class _FailingStats extends FakeMarketApi {
  Object? statsError;

  @override
  Future<Ticker> stats(Market market, String symbol) async {
    if (statsError case final error?) throw error;
    return super.stats(market, symbol);
  }
}

void main() {
  late FakeTransport transport;
  late _FailingStats api;
  late ProviderContainer container;

  /// Which screens listen: each entry watches one provider while it is in
  /// the list; [listeners] changes them without leaving the scope.
  final listeners = ValueNotifier<List<ProviderListenable<Object?>>>([]);

  Future<void> pump(
    WidgetTester tester,
    List<ProviderListenable<Object?>> watched,
  ) async {
    transport = FakeTransport();
    listeners.value = watched;
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
    await tester.pump();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 31));
  }

  Set<String> subscribed() => transport.last.subscriptions.keys.toSet();

  Map<String, Object?> overview(Map<String, String> lastPrices) => {
    'market': 'SPOT',
    'serverTime': '2026-11-19T01:00:00Z',
    'tickers': [
      for (final MapEntry(:key, :value) in lastPrices.entries)
        {
          'market': 'SPOT',
          'symbol': key,
          'sourceTime': '2026-11-19T01:00:00Z',
          'lastPrice': value,
          'changePercent24h': '1.0',
          'quoteVolume24h': '1000',
          'markPrice': null,
        },
    ],
  };

  setUp(() => api = _FailingStats());

  group('MarketRepository (D-150)', () {
    testWidgets('the board and a screen that shows prices share one '
        'subscription; it ends with the last of them', (tester) async {
      final repository = marketRepositoryProvider(Market.spot);
      await pump(tester, [
        marketBoardProvider(Market.spot),
        repository.select((d) => d.pairs),
      ]);
      expect(subscribed(), {'/topic/overview.SPOT'});
      expect(container.read(repository).pairs, hasLength(3));

      listeners.value = [repository.select((d) => d.pairs)];
      await tester.pump();
      await tester.pump();
      expect(subscribed(), {'/topic/overview.SPOT'});

      listeners.value = [];
      await tester.pump();
      await tester.pump();
      expect(subscribed(), isEmpty);
      await unmount(tester);
    });

    testWidgets('the board keeps its search and sort while prices change', (
      tester,
    ) async {
      final board = marketBoardProvider(Market.spot);
      await pump(tester, [board]);
      container.read(board.notifier)
        ..search('eth')
        ..toggleSort(BoardSort.price);
      transport.last.push(
        '/topic/overview.SPOT',
        overview({'BTCUSDT': '70000', 'ETHUSDT': '3000'}),
      );
      await tester.pump();
      final state = container.read(board);
      expect(state.query, 'eth');
      expect(state.sort, BoardSort.price);
      expect(state.tickers['ETHUSDT']!.lastPrice, '3000');
      expect(state.rows.single.symbol, 'ETHUSDT');
      await unmount(tester);
    });

    testWidgets('10 s without a push: Delayed, only the visible rows are '
        'read, at most 10; a push makes it Live again', (tester) async {
      final repository = marketRepositoryProvider(Market.spot);
      await pump(tester, [repository]);
      final data = container.read(repository.notifier);
      for (var i = 0; i < 12; i++) {
        data.markVisible('C${i}USDT', visible: true);
      }
      data.markVisible('C0USDT', visible: false);

      await tester.pump(const Duration(seconds: 10));
      expect(container.read(repository).delayed, isFalse);
      expect(api.statsCalls, isEmpty);

      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(container.read(repository).delayed, isTrue);
      expect(api.statsCalls, hasLength(MarketRepository.maxPolled));
      expect(api.statsCalls, isNot(contains('C0USDT')));
      expect(container.read(repository).tickers['C1USDT']!.lastPrice, '100.5');

      transport.last.push('/topic/overview.SPOT', overview({'BTCUSDT': '1'}));
      await tester.pump();
      expect(container.read(repository).delayed, isFalse);
      await unmount(tester);
    });

    testWidgets('pairs that cannot be read give the failure; Try again '
        'clears it', (tester) async {
      api.pairsError = problem(503, 'UNAVAILABLE', 'MSG43');
      final repository = marketRepositoryProvider(Market.spot);
      await pump(tester, [repository]);
      expect(container.read(repository).failure, isNotNull);
      expect(container.read(repository).pairs, isNull);

      api.pairsError = null;
      await container.read(repository.notifier).load();
      expect(container.read(repository).failure, isNull);
      expect(container.read(repository).pairs, hasLength(3));
      await unmount(tester);
    });
  });

  group('PairTickerRepository', () {
    const btc = (market: Market.spot, symbol: 'BTCUSDT');

    testWidgets('REST first, then the ticker topic; a bad push is dropped', (
      tester,
    ) async {
      final pair = pairTickerProvider(btc);
      await pump(tester, [pair]);
      expect(subscribed(), {'/topic/ticker.SPOT.BTCUSDT'});
      expect(api.statsCalls, ['BTCUSDT']);
      expect(container.read(pair).ticker!.lastPrice, '100.5');

      transport.last.push('/topic/ticker.SPOT.BTCUSDT', {
        'market': 'SPOT',
        'symbol': 'BTCUSDT',
        'sourceTime': '2026-11-19T01:00:00Z',
        'lastPrice': '76100.10',
      });
      await tester.pump();
      expect(container.read(pair).ticker!.lastPrice, '76100.10');

      transport.last.push('/topic/ticker.SPOT.BTCUSDT', {'lastPrice': 1});
      await tester.pump();
      expect(container.read(pair).ticker!.lastPrice, '76100.10');

      listeners.value = [];
      await tester.pump();
      await tester.pump();
      expect(subscribed(), isEmpty);
      await unmount(tester);
    });

    testWidgets('a pair no longer enabled: the failure says MSG41', (
      tester,
    ) async {
      api.statsError = problem(404, 'PAIR_NOT_FOUND', 'MSG41');
      final pair = pairTickerProvider(btc);
      await pump(tester, [pair]);
      final failure = container.read(pair).failure;
      expect(failure, isA<ProblemFailure>());
      expect((failure! as ProblemFailure).problem.messageCode, 'MSG41');
      await unmount(tester);
    });
  });
}
