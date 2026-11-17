import 'package:cryptopilot_mobile/core/auth/token_store.dart';
import 'package:cryptopilot_mobile/core/json/json_read.dart';
import 'package:cryptopilot_mobile/features/analysis/application/analysis_controller.dart';
import 'package:cryptopilot_mobile/features/analysis/domain/analysis.dart';
import 'package:cryptopilot_mobile/features/market/domain/candle.dart';
import 'package:cryptopilot_mobile/features/market/domain/market.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/realtime_fakes.dart';

void main() {
  group('decoders (backend develop 9090dc07 payloads)', () {
    test('a Spot analysis with indicators, levels, components and score', () {
      final a = decodeAnalysis(analysisJson());
      expect(a.market, Market.spot);
      expect(a.indicators['ema200'], '77867.9229098132');
      expect(a.nearestSupport, '75790.0000000000');
      expect(a.componentsLocked, isFalse);
      expect(a.components!.level, '1.09');
      expect(a.components!.derivatives, isNull);
      expect(a.setupScore!.score, 56);
      expect(a.setupScore!.preset, 'SCALPING');
      expect(a.setupScore!.dominantSide, isNull);
    });

    test('a Futures score has derivatives and the dominant side', () {
      final a = decodeAnalysis(analysisJson(market: 'FUTURES'));
      expect(a.components!.derivatives, '75.43');
      expect(a.setupScore!.components!.derivatives, '50.07');
      expect(a.setupScore!.dominantSide, DominantSide.long);
    });

    test('FREE: components locked and null (CR-08); fewer than 200 candles: '
        'no score', () {
      final a = decodeAnalysis(analysisJson(locked: true, score: null));
      expect(a.componentsLocked, isTrue);
      expect(a.components, isNull);
      expect(a.setupScore!.components, isNull);
      expect(a.setupScore!.score, isNull);
    });

    test('a shape the contract does not allow is refused', () {
      expect(
        () => decodeAnalysis({...analysisJson()}..remove('componentsLocked')),
        throwsA(isA<DecodeException>()),
      );
      expect(
        () => decodeAnalysis({...analysisJson(), 'nearestSupport': 75790}),
        throwsA(isA<DecodeException>()),
      );
      final unknownSide = analysisJson(market: 'FUTURES');
      (unknownSide['setupScore']! as Map)['dominantSide'] = 'UP';
      expect(
        () => decodeAnalysis(unknownSide),
        throwsA(isA<DecodeException>()),
      );
    });

    test('setup score v2: the scored side and why the score was capped', () {
      final spot = decodeAnalysis(
        analysisJson(capReason: 'LOW_ROOM', scoredSide: 'LONG'),
      );
      expect(spot.setupScore!.capReason, CapReason.lowRoom);
      expect(spot.setupScore!.scoredSide, ScoredSide.long);
      final futures = decodeAnalysis(
        analysisJson(market: 'FUTURES', scoredSide: 'SHORT'),
      );
      expect(futures.setupScore!.scoredSide, ScoredSide.short);
      expect(futures.setupScore!.capReason, isNull);

      // A v1 row, or a server before v2: both absent.
      final v1 = decodeAnalysis(analysisJson());
      expect(v1.setupScore!.capReason, isNull);
      expect(v1.setupScore!.scoredSide, isNull);
      // Sent as null (no candle analysed yet).
      final nulls = analysisJson();
      (nulls['setupScore']! as Map)
        ..['capReason'] = null
        ..['scoredSide'] = null;
      expect(decodeAnalysis(nulls).setupScore!.scoredSide, isNull);
    });

    test('a scored side or cap reason the app does not know is refused', () {
      for (final (key, value) in [
        ('capReason', 'TOO_HIGH'),
        ('scoredSide', 'NEUTRAL'),
        ('scoredSide', 1),
      ]) {
        final json = analysisJson();
        (json['setupScore']! as Map)[key] = value;
        expect(
          () => decodeAnalysis(json),
          throwsA(isA<DecodeException>()),
          reason: '$key $value',
        );
      }
    });

    test('a timeframe without an analysed candle: components all null, the '
        'preset score still there (found on the emulator, 1d)', () {
      final json = analysisJson()
        ..['openTime'] = null
        ..['calculatedAt'] = null
        ..['nearestSupport'] = null
        ..['nearestResistance'] = null
        ..['indicators'] = {for (final key in Indicators.keys) key: null}
        ..['components'] = {
          'formulaVersion': null,
          'trend': null,
          'momentum': null,
          'volume': null,
          'level': null,
        };
      final a = decodeAnalysis(json);
      expect(a.components!.formulaVersion, isNull);
      expect(a.components!.trend, isNull);
      expect(a.indicators['ema200'], isNull);
      expect(a.setupScore!.score, 56);
      expect(a.setupScore!.components!.formulaVersion, 'v1');
    });

    test('Futures metrics with the stored period (BR-10)', () {
      final m = decodeFuturesMetrics({
        'symbol': 'BTCUSDT',
        // The server writes seven fraction digits.
        'from': '2026-11-06T09:33:15.396665700Z',
        'to': '2026-11-07T09:33:15.396665700Z',
        'openInterest': [
          {
            'time': '2026-11-06T09:35:00Z',
            'openInterest': '95532.229000000000',
            'openInterestValue': '7273680617.71650000',
          },
        ],
        'longShortRatio': [
          {
            'time': '2026-11-06T09:35:00Z',
            'longShortRatio': '3.23010000',
            'longAccountRatio': '0.76360000',
            'shortAccountRatio': '0.23640000',
          },
        ],
        'fundingSettlements': [
          {
            'fundingTime': '2026-11-06T16:00:00Z',
            'fundingRate': '0.00009043',
            'markPrice': '75832.700000000000',
          },
        ],
        'availableFrom': {
          'openInterest': '2026-09-29T14:20:00Z',
          'longShortRatio': '2026-09-29T14:20:00Z',
          'fundingSettlements': '2026-09-29T16:00:00Z',
        },
      });
      expect(m.from, DateTime.utc(2026, 11, 6, 9, 33, 15, 396, 665));
      expect(m.openInterest.single.second, '7273680617.71650000');
      expect(m.longShortRatio.single.value, '3.23010000');
      expect(m.openInterestSince, DateTime.utc(2026, 9, 29, 14, 20));
    });
  });

  group('AnalysisController (D-126)', () {
    late FakeTransport transport;
    late FakeAnalysisApi api;
    late ProviderContainer container;
    const spot = (market: Market.spot, symbol: 'BTCUSDT', tf: Timeframe.h1);
    const futures = (
      market: Market.futures,
      symbol: 'BTCUSDT',
      tf: Timeframe.h1,
    );

    Future<void> pump(WidgetTester tester, AnalysisKey key) async {
      transport = FakeTransport();
      await tester.pumpWidget(
        ProviderScope(
          overrides: baseOverrides(
            store: MemoryTokenStore(storedFor('saved')),
            tokens: FakeAuthTokenApi(),
            transport: transport,
            analysis: api,
          ),
          retry: (_, _) => null,
          child: Consumer(
            builder: (context, ref, _) {
              ref.watch(analysisControllerProvider(key));
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
      await tester.pump();
    }

    Set<String> subscribed() => transport.last.subscriptions.keys.toSet();

    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 31));
    }

    setUp(() => api = FakeAnalysisApi());

    testWidgets('with components: both analysis topics after the REST read', (
      tester,
    ) async {
      await pump(tester, spot);
      expect(subscribed(), {
        '/topic/ticker.SPOT.BTCUSDT',
        '/topic/analysis.SPOT.BTCUSDT.1h',
        '/topic/analysis.SPOT.BTCUSDT.1h.components',
      });
      await unmount(tester);
    });

    testWidgets('components locked: never the .components topic (its '
        'ERROR frame would close the connection)', (tester) async {
      api.answers['SPOT BTCUSDT 1h'] = analysisJson(locked: true);
      await pump(tester, spot);
      expect(subscribed(), {
        '/topic/ticker.SPOT.BTCUSDT',
        '/topic/analysis.SPOT.BTCUSDT.1h',
      });
      await unmount(tester);
    });

    testWidgets('Futures outside the plan: MSG29, no analysis topic', (
      tester,
    ) async {
      api.error = problem(403, 'PLAN_FEATURE_NOT_INCLUDED', 'MSG29');
      await pump(tester, futures);
      expect(subscribed(), {'/topic/ticker.FUTURES.BTCUSDT'});
      expect(
        container.read(analysisControllerProvider(futures)).notInPlan,
        isTrue,
      );
      await unmount(tester);
    });

    testWidgets('a push carries no score: the analysis is read again', (
      tester,
    ) async {
      await pump(tester, spot);
      expect(api.calls, ['SPOT BTCUSDT 1h']);
      api.answers['SPOT BTCUSDT 1h'] = analysisJson(
        score: 61,
        support: '75800.0000000000',
      );
      transport.last.push('/topic/analysis.SPOT.BTCUSDT.1h', {
        'market': 'SPOT',
        'symbol': 'BTCUSDT',
        'timeframe': '1h',
        'openTime': '2026-11-07T09:00:00Z',
      });
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(api.calls, hasLength(2));
      final a = container.read(analysisControllerProvider(spot)).analysis!;
      expect(a.setupScore!.score, 61);
      expect(a.nearestSupport, '75800.0000000000');
      await unmount(tester);
    });

    testWidgets('a pair disabled while open answers MSG41 (SRS 3.3.2)', (
      tester,
    ) async {
      await pump(tester, spot);
      api.error = problem(404, 'RESOURCE_NOT_FOUND', 'MSG41');
      transport.last.push('/topic/analysis.SPOT.BTCUSDT.1h', {'x': 1});
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(container.read(analysisControllerProvider(spot)).pairGone, isTrue);
      await unmount(tester);
    });

    testWidgets('a network failure after a good read keeps what is shown', (
      tester,
    ) async {
      await pump(tester, spot);
      api.error = networkDown;
      transport.last.push('/topic/analysis.SPOT.BTCUSDT.1h', {'x': 1});
      await tester.pump();
      await tester.pump();
      final state = container.read(analysisControllerProvider(spot));
      expect(state.analysis, isNotNull);
      expect(state.failure, isNull);
      await unmount(tester);
    });

    testWidgets('the ticker topic keeps the statistics live', (tester) async {
      await pump(tester, spot);
      transport.last.push('/topic/ticker.SPOT.BTCUSDT', {
        'market': 'SPOT',
        'symbol': 'BTCUSDT',
        'sourceTime': '2026-11-07T09:00:00Z',
        'lastPrice': '76100.10',
        'bestBid': '76100.00',
        'bestAsk': '76100.20',
      });
      await tester.pump();
      await tester.pump();
      final ticker = container.read(analysisControllerProvider(spot)).ticker!;
      expect(ticker.bestAsk, '76100.20');
      await unmount(tester);
    });
  });

  group('Futures metrics (SRS 3.3.3)', () {
    testWidgets('read from the chosen days back, a minute late', (
      tester,
    ) async {
      final api = FakeAnalysisApi();
      await tester.pumpWidget(
        ProviderScope(
          overrides: baseOverrides(
            store: MemoryTokenStore(storedFor('saved')),
            tokens: FakeAuthTokenApi(),
            analysis: api,
          ),
          retry: (_, _) => null,
          child: Consumer(
            builder: (context, ref, _) {
              ref.watch(futuresMetricsProvider((symbol: 'BTCUSDT', days: 7)));
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      // now = 2026-11-06T10:00Z; 7 days back plus one minute.
      expect(api.metricCalls, ['BTCUSDT 2026-10-30T10:01:00.000Z']);

      await tester.pump(const Duration(minutes: 5));
      await tester.pump();
      expect(api.metricCalls, hasLength(2), reason: 'read again every 5 min');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 31));
    });
  });
}
