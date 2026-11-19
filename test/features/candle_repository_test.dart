import 'package:cryptopilot_mobile/core/auth/token_store.dart';
import 'package:cryptopilot_mobile/core/settings/settings.dart';
import 'package:cryptopilot_mobile/features/chart/application/candles_controller.dart';
import 'package:cryptopilot_mobile/features/chart/data/candle_cache.dart';
import 'package:cryptopilot_mobile/features/chart/data/candle_repository.dart';
import 'package:cryptopilot_mobile/features/market/domain/candle.dart';
import 'package:cryptopilot_mobile/features/market/domain/market.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/chart_fakes.dart';
import '../support/fakes.dart';
import '../support/realtime_fakes.dart';

void main() {
  late FakeTransport transport;
  late FakeMarketApi api;
  late MemorySettingsStore settings;
  late ProviderContainer container;
  const key = (market: Market.spot, symbol: 'BTCUSDT', tf: Timeframe.h1);
  const topic = '/topic/kline.SPOT.BTCUSDT.1h';
  final end = DateTime.utc(2026, 11, 7, 6);

  /// Charts that listen; changed without leaving the scope.
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
          settings: settings,
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
    // Nothing listens yet: no connection to open.
    if (watched.isEmpty) return;
    transport.last.onConnected();
    await tester.pump();
    await tester.pump();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 31));
  }

  Map<String, Object?> kline(DateTime openTime, String close) => {
    'market': 'SPOT',
    'symbol': 'BTCUSDT',
    'timeframe': '1h',
    'openTime': openTime.toIso8601String(),
    'closeTime': openTime
        .add(const Duration(minutes: 59, seconds: 59))
        .toIso8601String(),
    'open': '899.00',
    'high': '901.00',
    'low': '898.00',
    'close': close,
    'baseVolume': '1',
    'quoteVolume': '2000.00',
    'closed': false,
    'sourceTime': openTime.toIso8601String(),
  };

  setUp(() {
    api = FakeMarketApi()
      ..candlesBy['SPOT BTCUSDT 1h'] = candleRun(600, end: end);
    settings = MemorySettingsStore();
  });

  testWidgets('two charts of one pair and timeframe share one read and one '
      'subscription; it ends with the last chart', (tester) async {
    await pump(tester, [
      candleRepositoryProvider(key),
      candlesControllerProvider(key),
    ]);
    expect(api.candleCalls, ['SPOT BTCUSDT 1h 500']);
    expect(transport.last.subscriptions.keys, [topic]);
    expect(
      container.read(candleRepositoryProvider(key)).candles,
      hasLength(500),
    );

    listeners.value = [candlesControllerProvider(key)];
    await tester.pump();
    await tester.pump();
    expect(transport.last.subscriptions.keys, [topic]);

    listeners.value = [];
    await tester.pump();
    await tester.pump();
    expect(transport.last.subscriptions, isEmpty);
    await unmount(tester);
  });

  testWidgets('a kline updates the forming candle, a newer one goes last, '
      'an older one is ignored', (tester) async {
    final repository = candleRepositoryProvider(key);
    await pump(tester, [repository]);

    transport.last.push(topic, kline(end, '900.00'));
    await tester.pump();
    var state = container.read(repository);
    expect(state.candles, hasLength(501));
    expect(state.change, CandleChange.update);
    expect(state.candles!.last.closed, isFalse);

    transport.last.push(topic, kline(end, '902.00'));
    await tester.pump();
    state = container.read(repository);
    expect(state.candles, hasLength(501));
    expect(state.candles!.last.close, '902.00');

    final before = state.candles;
    transport.last.push(
      topic,
      kline(end.subtract(const Duration(hours: 3)), '1.00'),
    );
    await tester.pump();
    expect(container.read(repository).candles, same(before));
    await unmount(tester);
  });

  testWidgets('the chart gets the cached candles and then the fresh ones, '
      'each in turn', (tester) async {
    await CandleCache(
      settings,
    ).write(Market.spot, 'BTCUSDT', Timeframe.h1, candleRun(50, end: end));
    final seen = <bool>[];
    await pump(tester, []);
    container.listen(
      candlesControllerProvider(key),
      (_, next) => seen.add(next.fromCache),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump();
    }
    expect(seen, [true, false]);
    expect(
      container.read(candlesControllerProvider(key)).candles,
      hasLength(500),
    );
    await unmount(tester);
  });

  testWidgets('candles that cannot be read give the failure; Try again '
      'reads them', (tester) async {
    api.candlesError = problem(503, 'UNAVAILABLE', 'MSG43');
    await pump(tester, [candlesControllerProvider(key)]);
    expect(container.read(candlesControllerProvider(key)).failure, isNotNull);

    api.candlesError = null;
    await container.read(candlesControllerProvider(key).notifier).load();
    final state = container.read(candlesControllerProvider(key));
    expect(state.failure, isNull);
    expect(state.candles, hasLength(500));
    await unmount(tester);
  });
}
