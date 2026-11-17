import 'dart:async';

import 'package:cryptopilot_mobile/core/auth/token_store.dart';
import 'package:cryptopilot_mobile/core/i18n/app_localizations.dart';
import 'package:cryptopilot_mobile/core/json/json_read.dart';
import 'package:cryptopilot_mobile/core/settings/settings.dart';
import 'package:cryptopilot_mobile/core/theme/app_theme.dart';
import 'package:cryptopilot_mobile/features/chart/application/candles_controller.dart';
import 'package:cryptopilot_mobile/features/chart/data/candle_cache.dart';
import 'package:cryptopilot_mobile/features/chart/domain/chart_indicators.dart';
import 'package:cryptopilot_mobile/features/chart/domain/chart_time.dart';
import 'package:cryptopilot_mobile/features/chart/presentation/chart_surface.dart';
import 'package:cryptopilot_mobile/features/chart/presentation/chart_view.dart';
import 'package:cryptopilot_mobile/features/market/domain/candle.dart';
import 'package:cryptopilot_mobile/features/market/domain/market.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/chart_fakes.dart';
import '../support/fakes.dart';
import '../support/realtime_fakes.dart';

void main() {
  group('candles (backend develop 25ba960 payloads)', () {
    test('a REST candle is closed; a kline says whether it closed', () {
      final rest = decodeCandle({
        'openTime': '2026-11-07T05:00:00Z',
        'closeTime': '2026-11-07T05:59:59.999Z',
        'open': '75906.680000000000',
        'high': '76052.930000000000',
        'low': '75891.390000000000',
        'close': '76034.010000000000',
        'baseVolume': '340.871000000000',
        'quoteVolume': '25903076.449948400000',
        'tradeCount': 28408,
      });
      expect(rest.closed, isTrue);
      expect(rest.close, '76034.010000000000');
      expect(rest.openTime, DateTime.utc(2026, 11, 7, 5));

      final kline = decodeCandle({
        'market': 'SPOT',
        'symbol': 'BTCUSDT',
        'timeframe': '1h',
        'openTime': '2026-11-07T06:00:00Z',
        'closeTime': '2026-11-07T06:59:59.999Z',
        'open': '76034.01',
        'high': '76070.01',
        'low': '76014.00',
        'close': '76056.11',
        'baseVolume': '275.28',
        'quoteVolume': '20933062.95',
        'closed': false,
        'sourceTime': '2026-11-07T06:20:00Z',
      });
      expect(kline.closed, isFalse);
    });

    test('a price that is not a decimal string is refused', () {
      Map<String, Object?> body(Object? close) => {
        'openTime': '2026-11-07T05:00:00Z',
        'open': '1',
        'high': '1',
        'low': '1',
        'close': close,
        'quoteVolume': '1',
      };
      expect(
        () => decodeCandle(body(76034.01)),
        throwsA(isA<DecodeException>()),
      );
      expect(() => decodeCandle(body('abc')), throwsA(isA<DecodeException>()));
      expect(
        () => decodeCandles({'candles': 'none'}),
        throwsA(isA<DecodeException>()),
      );
    });

    test('decimals of a tick size', () {
      expect(decimalsOf('0.01000000'), 2);
      expect(decimalsOf('0.00001000'), 5);
      expect(decimalsOf('1.00000000'), 0);
      expect(decimalsOf(null), 2);
    });
  });

  group('device cache (ADR-012 item 5)', () {
    test('keeps the last 500 closed candles and reads them back', () async {
      final cache = CandleCache(MemorySettingsStore());
      final forming = Candle(
        openTime: DateTime.utc(2026, 11, 7),
        open: '1',
        high: '1',
        low: '1',
        close: '1',
        quoteVolume: '1',
        closed: false,
      );
      await cache.write(Market.spot, 'BTCUSDT', Timeframe.h1, [
        ...candleRun(520),
        forming,
      ]);
      final back = await cache.read(Market.spot, 'BTCUSDT', Timeframe.h1);
      expect(back, hasLength(500));
      expect(back!.every((c) => c.closed), isTrue);
      expect(back.last.close, '619.00');
      expect(await cache.read(Market.spot, 'BTCUSDT', Timeframe.h4), isNull);
    });

    test('what no longer decodes is dropped, not shown', () async {
      final store = MemorySettingsStore()
        ..values['chart.candles.SPOT.BTCUSDT.1h'] = '[{"open":1}]';
      final cache = CandleCache(store);
      expect(await cache.read(Market.spot, 'BTCUSDT', Timeframe.h1), isNull);
    });
  });

  group('indicator choice (SRS 3.3.2, BR-12)', () {
    test('is stored as keys and read back; nothing stored gives the '
        'defaults', () {
      expect(ChartIndicator.parse(null), ChartIndicator.defaults);
      final picked = {ChartIndicator.sma20, ChartIndicator.rsi};
      expect(ChartIndicator.format(picked), 'sma20,rsi');
      expect(ChartIndicator.parse('sma20,rsi'), picked);
      expect(ChartIndicator.parse(''), isEmpty);
    });

    test('the page gets only the chosen overlays and panels, in order', () {
      final candles = candleRun(60);
      final payload = indicatorPayload(candles, {
        ChartIndicator.macd,
        ChartIndicator.ema20,
        ChartIndicator.rsi,
        ChartIndicator.bollinger,
      });
      expect(payload['times'], hasLength(60));
      final overlays = payload['overlays']! as List;
      expect(
        [for (final o in overlays) (o as Map)['id']],
        ['ema20', 'bb', 'bb', 'bb'],
      );
      final panels = payload['panels']! as List;
      expect([for (final p in panels) (p as Map)['id']], ['rsi', 'macd']);
      final rsi = ((panels.first as Map)['series'] as List).single as Map;
      expect(rsi['levels'], [30, 70]);
      final ema20 = (overlays.first as Map)['values'] as List;
      expect(ema20.take(19).every((v) => v == null), isTrue);
      expect(ema20[19], isNotNull);
    });
  });

  group('time axis (BR-08)', () {
    test('intraday candles move by the device zone, daily ones stay UTC', () {
      const vietNam = Duration(hours: 7);
      for (final tf in [Timeframe.m15, Timeframe.h1, Timeframe.h4]) {
        expect(chartOffset(tf, vietNam), vietNam, reason: tf.wire);
      }
      expect(chartOffset(Timeframe.d1, vietNam), Duration.zero);
    });

    test('the zone is named as an exchange names it', () {
      expect(zoneLabel(Duration.zero), 'UTC');
      expect(zoneLabel(const Duration(hours: 7)), 'UTC+7');
      expect(zoneLabel(const Duration(hours: 5, minutes: 30)), 'UTC+5:30');
      expect(zoneLabel(-const Duration(hours: 3, minutes: 30)), 'UTC-3:30');
      expect(zoneLabel(-const Duration(hours: 8)), 'UTC-8');
    });
  });

  group('ChartView', () {
    late FakeTransport transport;
    late FakeMarketApi market;
    late FakeChartSurface surface;
    late MemorySettingsStore settings;
    const key = (market: Market.spot, symbol: 'BTCUSDT', tf: Timeframe.h1);

    Future<void> pump(
      WidgetTester tester, {
      Set<ChartIndicator> indicators = ChartIndicator.defaults,
      Brightness brightness = Brightness.light,
      bool fresh = true,
      Duration zone = Duration.zero,
      CandleKey candleKey = key,
    }) async {
      transport = FakeTransport();
      surface = FakeChartSurface();
      if (fresh) {
        market = FakeMarketApi()
          ..candlesBy['SPOT BTCUSDT 1h'] = candleRun(
            800,
            end: DateTime.utc(2026, 11, 7, 6),
          );
        settings = MemorySettingsStore();
      }
      await tester.pumpWidget(
        ProviderScope(
          overrides: baseOverrides(
            store: MemoryTokenStore(storedFor('saved')),
            tokens: FakeAuthTokenApi(),
            transport: transport,
            market: market,
            chart: surface,
            settings: settings,
            zone: zone,
          ),
          retry: (_, _) => null,
          child: MaterialApp(
            theme: appTheme(brightness),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ListView(
                children: [
                  ChartView(
                    candleKey: candleKey,
                    precision: 2,
                    indicators: indicators,
                    lines: const [
                      ChartPriceLine(
                        price: '760.00',
                        label: 'S',
                        color: Color(0xFF087F5B),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump();
      }
    }

    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 31));
    }

    Map<String, Object?> kline(
      String close, {
      required bool closed,
      DateTime? openTime,
    }) => {
      'market': 'SPOT',
      'symbol': 'BTCUSDT',
      'timeframe': '1h',
      'openTime': (openTime ?? DateTime.utc(2026, 11, 7, 6)).toIso8601String(),
      'closeTime': '2026-11-07T06:59:59.999Z',
      'open': '899.00',
      'high': '901.00',
      'low': '898.00',
      'close': close,
      'baseVolume': '1',
      'quoteVolume': '2000.00',
      'closed': closed,
      'sourceTime': '2026-11-07T06:20:00Z',
    };

    Future<void> push(WidgetTester tester, Map<String, Object?> body) async {
      transport.last.push('/topic/kline.SPOT.BTCUSDT.1h', body);
      await tester.pump();
      await tester.pump();
    }

    testWidgets('500 closed candles (SRS 3.3.2), theme, precision, lines and '
        'indicators reach the page', (tester) async {
      await pump(tester);
      expect(market.candleCalls, ['SPOT BTCUSDT 1h 500']);
      expect(surface.calls, contains('candles 500 shift 0'));
      expect(surface.calls, containsAll(['theme', 'precision 2', 'lines 1']));
      expect(surface.calls.last, 'indicators');
      expect(surface.lines.single.price, '760.00');
      expect(find.byKey(const Key('chart-skeleton')), findsNothing);
      await unmount(tester);
    });

    testWidgets('the axis shows the device zone and says so; the offset '
        'reaches the page before the candles (BR-08)', (tester) async {
      await pump(tester, zone: const Duration(hours: 7));

      expect(surface.calls, contains('offset 25200'));
      expect(
        surface.calls.indexOf('offset 25200'),
        lessThan(surface.calls.indexOf('candles 500 shift 0')),
      );
      expect(find.text('Times in UTC+7'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('daily candles keep UTC whatever the device zone', (
      tester,
    ) async {
      await pump(
        tester,
        zone: const Duration(hours: 7),
        candleKey: (market: Market.spot, symbol: 'BTCUSDT', tf: Timeframe.d1),
      );

      expect(surface.calls, contains('offset 0'));
      expect(surface.calls, isNot(contains('offset 25200')));
      expect(find.text('Times in UTC'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('a skeleton until candles come; a failure offers Try again', (
      tester,
    ) async {
      final gate = Completer<void>();
      market = FakeMarketApi()
        ..candlesHold = gate.future
        ..candlesBy['SPOT BTCUSDT 1h'] = candleRun(10);
      settings = MemorySettingsStore();
      await pump(tester, fresh: false);
      expect(find.byKey(const Key('chart-skeleton')), findsOneWidget);

      market
        ..candlesHold = null
        ..candlesError = networkDown;
      gate.complete();
      await tester.pump();
      await tester.pump();
      expect(
        find.text(
          'Unable to reach the server. Check your connection and try again.',
        ),
        findsOneWidget,
      );
      market.candlesError = null;
      await tester.tap(find.text('Try again'));
      await tester.pump();
      await tester.pump();
      expect(surface.calls, contains('candles 10 shift 0'));
      await unmount(tester);
    });

    testWidgets('the cached candles draw first, then the fresh ones', (
      tester,
    ) async {
      await pump(tester);
      await unmount(tester);

      // Same device: the fresh read is slow this time.
      final gate = Completer<void>();
      market.candlesHold = gate.future;
      await pump(tester, fresh: false);
      // The fresh read has not answered yet: these 500 come from the device.
      expect(market.candleCalls, hasLength(2));
      expect(surface.calls, contains('candles 500 shift 0'));
      final fromCache = surface.calls.length;

      gate.complete();
      await tester.pump();
      await tester.pump();
      expect(
        surface.calls.skip(fromCache),
        contains('candles 500 shift 0'),
        reason: 'the fresh candles replace the cached ones',
      );
      await unmount(tester);
    });

    testWidgets('a forming candle updates alone; a close moves the '
        'indicators', (tester) async {
      await pump(tester);
      transport.last.onConnected();
      await tester.pump();
      surface.calls.clear();

      await push(tester, kline('900.50', closed: false));
      expect(surface.calls, ['update 900.50 forming']);

      await push(tester, kline('900.75', closed: true));
      expect(surface.calls, [
        'update 900.50 forming',
        'update 900.75',
        'indicators',
      ]);
      await unmount(tester);
    });

    testWidgets('the left edge reads 300 older candles once, then stops', (
      tester,
    ) async {
      await pump(tester);
      surface.calls.clear();
      surface.askMore();
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(market.candleCalls.last, 'SPOT BTCUSDT 1h 300 to');
      expect(surface.calls, contains('candles 800 shift 300'));

      surface.askMore();
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(market.candleCalls.where((c) => c.endsWith('to')), hasLength(2));

      surface.askMore();
      await tester.pump();
      await tester.pump();
      expect(
        market.candleCalls.where((c) => c.endsWith('to')),
        hasLength(2),
        reason: 'nothing older is left',
      );
      await unmount(tester);
    });

    testWidgets('the dark theme reaches the page', (tester) async {
      await pump(tester, brightness: Brightness.dark);
      expect(surface.theme!.bg, contains('13,20,36'));
      await unmount(tester);
    });
  });
}
