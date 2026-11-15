import 'dart:async';

import 'package:cryptopilot_mobile/app.dart';
import 'package:cryptopilot_mobile/core/auth/token_store.dart';
import 'package:cryptopilot_mobile/core/format/decimal_format.dart';
import 'package:cryptopilot_mobile/core/i18n/app_localizations.dart';
import 'package:cryptopilot_mobile/core/router/app_router.dart';
import 'package:cryptopilot_mobile/core/settings/settings.dart';
import 'package:cryptopilot_mobile/core/theme/app_theme.dart';
import 'package:cryptopilot_mobile/core/theme/cp_colors.dart';
import 'package:cryptopilot_mobile/features/analysis/presentation/analysis_screen.dart';
import 'package:cryptopilot_mobile/features/chart/application/chart_prefs.dart';
import 'package:cryptopilot_mobile/features/market/domain/market.dart';
import 'package:cryptopilot_mobile/features/market/presentation/markets_screen.dart';
import 'package:cryptopilot_mobile/features/market/presentation/pair_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/chart_fakes.dart';
import '../support/fakes.dart';
import '../support/realtime_fakes.dart';

void main() {
  test('the spread is ask − bid, exact (SRS 3.3.2)', () {
    expect(subtractDecimal('76166.02', '76166.00'), '0.02');
    expect(subtractDecimal('0.30000001', '0.1'), '0.20000001');
    expect(subtractDecimal(null, '1'), isNull);
    expect(subtractDecimal('x', '1'), isNull);
  });

  group('SCR-10 pair analysis', () {
    late FakeTransport transport;
    late FakeMarketApi market;
    late FakeAnalysisApi analysis;
    late FakeNewsApi news;
    late FakeWebLinks web;
    late FakeChartSurface chart;
    late MemorySettingsStore settings;

    setUp(() {
      transport = FakeTransport();
      market = FakeMarketApi()
        ..candlesBy['SPOT BTCUSDT 1h'] = candleRun(500)
        ..candlesBy['SPOT BTCUSDT 4h'] = candleRun(
          500,
          step: const Duration(hours: 4),
        )
        ..candlesBy['FUTURES BTCUSDT 1h'] = candleRun(500);
      analysis = FakeAnalysisApi();
      news = FakeNewsApi();
      web = FakeWebLinks();
      chart = FakeChartSurface();
      settings = MemorySettingsStore();
    });

    Future<void> mount(
      WidgetTester tester, {
      Market on = Market.spot,
      String symbol = 'BTCUSDT',
      Brightness brightness = Brightness.light,
      bool actions = false,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...baseOverrides(
              store: MemoryTokenStore(storedFor('saved')),
              tokens: FakeAuthTokenApi(),
              transport: transport,
              market: market,
              analysis: analysis,
              news: news,
              web: web,
              chart: chart,
              settings: settings,
            ),
            if (actions)
              pairActionsProvider.overrideWithValue(
                (_, pair) => IconButton.outlined(
                  key: const Key('fake-pair-action'),
                  onPressed: () {},
                  icon: const Icon(Icons.star_border),
                ),
              ),
          ],
          retry: (_, _) => null,
          child: MaterialApp(
            theme: appTheme(brightness),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AnalysisScreen(market: on, symbol: symbol),
          ),
        ),
      );
      for (var i = 0; i < 8; i++) {
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

    Future<void> show(WidgetTester tester, Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.pump();
    }

    Finder within(String key, String text) => find.descendant(
      of: find.byKey(Key(key)),
      matching: find.text(text),
      matchRoot: true,
    );

    testWidgets('a Spot pair: price, chart with the BR-14 levels, score, '
        'components, statistics, news and MSG42', (tester) async {
      final semantics = tester.ensureSemantics();
      await mount(tester);
      transport.last.push('/topic/overview.SPOT', {
        'market': 'SPOT',
        'serverTime': '2026-11-06T01:48:10Z',
        'tickers': <Object?>[],
      });
      transport.last.push('/topic/ticker.SPOT.BTCUSDT', {
        'market': 'SPOT',
        'symbol': 'BTCUSDT',
        'lastPrice': '76166.01',
        'bestBid': '76166.00',
        'bestAsk': '76166.02',
        'high24h': '77000.5',
        'low24h': '75000',
        'changePercent24h': '-5.658',
        'baseVolume24h': '15234.5',
        'quoteVolume24h': '1139455120.42',
      });
      for (var i = 0; i < 3; i++) {
        await tester.pump();
      }

      // Header: pair, market, live price, signed change, Live (CR-09).
      expect(find.text('BTC/USDT'), findsOneWidget);
      expect(find.text('Spot'), findsOneWidget);
      expect(within('analysis-price', '76,166.01'), findsOneWidget);
      expect(find.text('−5.66%'), findsWidgets);
      expect(find.text('Live'), findsOneWidget);
      expect(
        find.text('H 77,000.50 · L 75,000.00 · Vol 1.14B'),
        findsOneWidget,
      );

      // Chart: 1h by default, 500 closed candles, the tick's precision, the
      // nearest levels as labelled lines.
      expect(market.candleCalls, contains('SPOT BTCUSDT 1h 500'));
      expect(analysis.calls, ['SPOT BTCUSDT 1h']);
      expect(chart.candles, hasLength(500));
      expect(chart.calls, contains('precision 2'));
      expect(
        [for (final line in chart.lines) '${line.label} ${line.price}'],
        ['Resistance 76208.2500000000', 'Support 75790.0000000000'],
      );
      expect(chart.lines.first.color, CpColors.light.negative);
      expect(chart.lines.last.color, CpColors.light.positive);
      expect(find.byKey(const Key('analysis-insufficient')), findsNothing);

      // Score card: total, preset name + version + timeframe, components.
      expect(within('score-value', '56'), findsOneWidget);
      expect(find.text('/ 100'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Setup score 56 out of 100'),
        findsOneWidget,
      );
      expect(find.text('Scalping v1 · 15m'), findsOneWidget);
      expect(find.byKey(const Key('score-capped')), findsNothing);
      for (final (label, value) in [
        ('Trend', '50'),
        ('Momentum', '80'),
        ('Volume', '26'),
        ('Level', '49'),
      ]) {
        expect(within('score-card', label), findsOneWidget);
        expect(within('score-card', value), findsOneWidget);
      }
      expect(find.text('Derivatives'), findsNothing);
      expect(find.byKey(const Key('components-locked')), findsNothing);
      expect(
        within(
          'score-card',
          'Information on CryptoPilot is for reference and education only '
              'and is not investment advice.',
        ),
        findsOneWidget,
      );

      // Statistics, the spread computed exactly.
      for (final (id, value) in [
        ('last', '76,166.01'),
        ('bid', '76,166.00'),
        ('ask', '76,166.02'),
        ('spread', '0.02'),
        ('high', '77,000.50'),
        ('low', '75,000.00'),
        ('change', '−5.66%'),
        ('volume', '15.23K'),
        ('turnover', '1.14B'),
      ]) {
        expect(within('stat-$id', value), findsOneWidget, reason: id);
      }

      // News of the base coin.
      expect(news.coinCalls, ['BTC']);
      expect(find.text('Latest BTC news'), findsOneWidget);
      expect(
        find.text('Bitcoin holds above 75,000 as funding cools'),
        findsOneWidget,
      );
      expect(find.text('CoinDesk · 2h ago · Bullish'), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
      await unmount(tester);
    });

    testWidgets('while the first read is under way each block shows its '
        'skeleton, the disclaimer already there', (tester) async {
      final gate = Completer<void>();
      analysis.hold = gate.future;
      market.candlesHold = gate.future;
      await mount(tester);

      expect(find.byKey(const Key('chart-skeleton')), findsOneWidget);
      expect(find.byKey(const Key('score-loading')), findsOneWidget);
      expect(find.byKey(const Key('analysis-disclaimer')), findsOneWidget);
      expect(find.byKey(const Key('score-value')), findsNothing);

      gate.complete();
      for (var i = 0; i < 6; i++) {
        await tester.pump();
      }
      expect(find.byKey(const Key('score-loading')), findsNothing);
      expect(within('score-value', '56'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('the pairs still loading: a spinner, then the screen', (
      tester,
    ) async {
      final gate = Completer<void>();
      market.hold = gate.future;
      await mount(tester);
      expect(find.byKey(const Key('analysis-loading')), findsOneWidget);
      expect(find.text('BTCUSDT'), findsOneWidget);

      gate.complete();
      for (var i = 0; i < 6; i++) {
        await tester.pump();
      }
      expect(find.byKey(const Key('analysis-loading')), findsNothing);
      expect(find.text('BTC/USDT'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('the pairs cannot be read: the reason and Try again', (
      tester,
    ) async {
      market.pairsError = networkDown;
      await mount(tester);
      expect(find.text('Try again'), findsOneWidget);

      market.pairsError = null;
      await tester.tap(find.text('Try again'));
      for (var i = 0; i < 6; i++) {
        await tester.pump();
      }
      expect(find.text('BTC/USDT'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('components locked (CR-08): a lock, MSG29 and the web plans', (
      tester,
    ) async {
      analysis.answers['SPOT BTCUSDT 1h'] = analysisJson(locked: true);
      await mount(tester);

      expect(find.byKey(const Key('components-locked')), findsOneWidget);
      expect(
        find.text(
          'This feature is available on the PRO plan or higher. View plans?',
        ),
        findsOneWidget,
      );
      expect(within('score-value', '56'), findsOneWidget);
      expect(within('score-card', 'Trend'), findsNothing);

      await show(tester, find.byKey(const Key('components-upgrade')));
      await tester.tap(find.byKey(const Key('components-upgrade')));
      expect(web.opened, ['/subscription']);
      await unmount(tester);
    });

    testWidgets('fewer than 200 closed candles: Insufficient data, never 0', (
      tester,
    ) async {
      analysis.answers['SPOT BTCUSDT 1h'] = analysisJson(
        score: null,
        short: true,
      );
      await mount(tester);

      expect(find.byKey(const Key('score-insufficient')), findsOneWidget);
      expect(within('score-card', 'Insufficient data'), findsOneWidget);
      expect(find.byKey(const Key('score-value')), findsNothing);
      expect(find.byKey(const Key('analysis-insufficient')), findsOneWidget);
      // The preset is still named.
      expect(find.text('Scalping v1 · 15m'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('a capped score (setup score v2) says why', (tester) async {
      final json = analysisJson(capReason: 'LOW_ROOM', scoredSide: 'LONG');
      (json['setupScore']! as Map)['presetVersion'] = 'v2';
      analysis.answers['SPOT BTCUSDT 1h'] = json;
      await mount(tester);

      expect(find.byKey(const Key('score-capped')), findsOneWidget);
      expect(
        find.text('Score capped: little room to the next level.'),
        findsOneWidget,
      );
      expect(find.text('Scalping v2 · 15m'), findsOneWidget);
      // On Spot the scored side is always LONG and is not shown (SRS 3.3.2).
      expect(find.text('Long'), findsNothing);
      await unmount(tester);
    });

    testWidgets('10 s without a price push: Delayed, Live again on the next '
        'one (CR-09)', (tester) async {
      await mount(tester);
      Map<String, Object?> overview() => {
        'market': 'SPOT',
        'serverTime': '2026-11-06T01:48:10Z',
        'tickers': <Object?>[],
      };
      transport.last.push('/topic/overview.SPOT', overview());
      await tester.pump();
      await tester.pump();
      expect(find.text('Live'), findsOneWidget);

      await tester.pump(const Duration(seconds: 11));
      await tester.pump();
      expect(find.text('Delayed'), findsOneWidget);

      transport.last.push('/topic/overview.SPOT', overview());
      await tester.pump();
      await tester.pump();
      expect(find.text('Live'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('another timeframe reads its own candles and analysis', (
      tester,
    ) async {
      await mount(tester);
      await tester.tap(find.text('4h'));
      for (var i = 0; i < 8; i++) {
        await tester.pump();
      }

      expect(market.candleCalls, contains('SPOT BTCUSDT 4h 500'));
      expect(analysis.calls, ['SPOT BTCUSDT 1h', 'SPOT BTCUSDT 4h']);
      expect(
        transport.last.subscriptions.keys,
        contains('/topic/analysis.SPOT.BTCUSDT.4h'),
      );
      expect(chart.candles!.last.openTime, DateTime.utc(2026, 11, 6, 8));
      await unmount(tester);
    });

    testWidgets('an indicator switched on reaches the chart and is kept on '
        'the device', (tester) async {
      await mount(tester);
      List<Object?> panels() => [
        for (final panel in chart.indicators!['panels']! as List)
          (panel as Map)['id'],
      ];
      expect(panels(), ['volume']);

      await tester.tap(find.byKey(const Key('open-indicators')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Bollinger Bands (20, 2)'), findsOneWidget);
      expect(find.text('MACD (12, 26, 9)'), findsOneWidget);
      await tester.tap(find.byKey(const Key('indicator-rsi')));
      await tester.pump();
      await tester.pump();

      expect(panels(), ['volume', 'rsi']);
      expect(
        settings.values[ChartIndicatorChoice.storageKey],
        'ema20,ema50,volume,rsi',
      );
      await tester.tap(find.byKey(const Key('indicator-volume')));
      await tester.pump();
      await tester.pump();
      expect(panels(), ['rsi']);
      expect(
        settings.values[ChartIndicatorChoice.storageKey],
        'ema20,ema50,rsi',
      );
      await unmount(tester);
    });

    testWidgets('the stored indicator choice is read back', (tester) async {
      settings.values[ChartIndicatorChoice.storageKey] = 'sma20,macd';
      await mount(tester);

      final payload = chart.indicators!;
      expect(
        [for (final o in payload['overlays']! as List) (o as Map)['id']],
        ['sma20'],
      );
      expect(
        [for (final p in payload['panels']! as List) (p as Map)['id']],
        ['macd'],
      );
      await unmount(tester);
    });

    testWidgets('the analysis cannot be read: the card says so and Try again '
        'reads it; the chart and the news stay', (tester) async {
      analysis.error = networkDown;
      await mount(tester);

      expect(find.byKey(const Key('chart-view')), findsOneWidget);
      expect(chart.candles, hasLength(500));
      expect(chart.lines, isEmpty);
      expect(find.byKey(const Key('score-value')), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const Key('score-card')),
          matching: find.text('Try again'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('analysis-disclaimer')), findsOneWidget);
      expect(
        find.text('Bitcoin holds above 75,000 as funding cools'),
        findsOneWidget,
      );

      analysis.error = null;
      await show(tester, within('score-card', 'Try again'));
      await tester.tap(within('score-card', 'Try again'));
      for (var i = 0; i < 6; i++) {
        await tester.pump();
      }
      expect(within('score-value', '56'), findsOneWidget);
      expect(chart.lines, hasLength(2));
      await unmount(tester);
    });

    testWidgets('news: none, a failure with Try again, and the web pages', (
      tester,
    ) async {
      news.articles = [];
      await mount(tester);
      expect(find.text('No BTC news in the last 7 days.'), findsOneWidget);
      await unmount(tester);

      transport = FakeTransport();
      news = FakeNewsApi()..error = networkDown;
      await mount(tester);
      final retry = find.descendant(
        of: find.byKey(const Key('pair-news')),
        matching: find.text('Try again'),
      );
      expect(retry, findsOneWidget);
      news.error = null;
      await show(tester, retry);
      await tester.tap(retry);
      for (var i = 0; i < 6; i++) {
        await tester.pump();
      }
      await show(tester, find.byKey(const Key('pair-news-a1')));
      await tester.tap(find.byKey(const Key('pair-news-a1')));
      await show(tester, find.byKey(const Key('pair-news-all')));
      await tester.tap(find.byKey(const Key('pair-news-all')));
      expect(web.opened, ['/news/a1', '/news?coin=BTC']);
      await unmount(tester);
    });

    testWidgets('the bar: the composed pair actions and Create plan on the '
        'web, pre-filled with the pair', (tester) async {
      await mount(tester, actions: true);
      expect(
        find.descendant(
          of: find.byKey(const Key('analysis-actions')),
          matching: find.byKey(const Key('fake-pair-action')),
        ),
        findsOneWidget,
      );
      expect(find.byTooltip('Create trading plan on the web'), findsOneWidget);
      await tester.tap(find.byKey(const Key('create-plan')));
      expect(web.opened, ['/plans/new?symbol=BTCUSDT']);
      await unmount(tester);
    });

    testWidgets('a Futures pair opens the same content on its candles; '
        'Create plan carries the market', (tester) async {
      await mount(tester, on: Market.futures);

      expect(find.text('Futures'), findsOneWidget);
      expect(market.candleCalls, contains('FUTURES BTCUSDT 1h 500'));
      expect(analysis.calls, ['FUTURES BTCUSDT 1h']);
      expect(within('score-card', 'Derivatives'), findsOneWidget);
      // No 24 h change on Futures (Q-91): not shown rather than made up.
      expect(find.byKey(const Key('analysis-change')), findsNothing);
      await tester.tap(find.byKey(const Key('create-plan')));
      expect(web.opened, ['/plans/new?symbol=BTCUSDT&market=futures']);
      await unmount(tester);
    });

    testWidgets('Futures outside the plan (SRS 3.3.3): MSG29 and the web '
        'plans, no chart', (tester) async {
      analysis.error = problem(
        403,
        'PLAN_FEATURE_NOT_INCLUDED',
        'MSG29',
        args: ['PRO'],
      );
      await mount(tester, on: Market.futures);

      expect(find.byKey(const Key('analysis-not-in-plan')), findsOneWidget);
      expect(
        find.text(
          'This feature is available on the PRO plan or higher. View plans?',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('chart-view')), findsNothing);
      expect(find.byKey(const Key('score-card')), findsNothing);
      await tester.tap(find.byKey(const Key('upgrade-open-web')));
      expect(web.opened, ['/subscription']);
      await unmount(tester);
    });

    for (final brightness in Brightness.values) {
      testWidgets('360 dp, ${brightness.name}: nothing overflows, with the '
          'longest content', (tester) async {
        tester.view
          ..physicalSize = const Size(360 * 3, 760 * 3)
          ..devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        analysis.answers['SPOT BTCUSDT 1h'] = analysisJson(
          locked: true,
          capReason: 'LOW_ROOM',
          short: true,
        );
        await mount(tester, brightness: brightness, actions: true);
        transport.last.push('/topic/ticker.SPOT.BTCUSDT', {
          'market': 'SPOT',
          'symbol': 'BTCUSDT',
          'lastPrice': '1234567.12345678',
          'bestBid': '1234567.12345677',
          'bestAsk': '1234567.12345679',
          'high24h': '1334567.12345678',
          'low24h': '1134567.12345678',
          'changePercent24h': '-15.658',
          'baseVolume24h': '15234.5',
          'quoteVolume24h': '1139455120.42',
        });
        await tester.pump();
        expect(tester.takeException(), isNull);

        await tester.drag(
          find.byKey(const Key('analysis-scroll')),
          const Offset(0, -2000),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('pair-news')), findsOneWidget);
        expect(
          Theme.of(tester.element(find.byType(AnalysisScreen))).brightness,
          brightness,
        );
        // Touch targets of at least 48 dp.
        for (final key in ['create-plan', 'fake-pair-action']) {
          expect(
            tester.getSize(find.byKey(Key(key))).height,
            greaterThanOrEqualTo(48),
            reason: key,
          );
        }
        await tester.drag(
          find.byKey(const Key('analysis-scroll')),
          const Offset(0, 2000),
        );
        await tester.pump();
        for (final key in ['analysis-timeframes', 'open-indicators']) {
          expect(
            tester.getSize(find.byKey(Key(key))).height,
            greaterThanOrEqualTo(48),
            reason: key,
          );
        }
        await unmount(tester);
      });
    }
  });

  group('SCR-10 in the app (router)', () {
    late FakeTransport transport;
    late FakeAnalysisApi analysis;
    late FakeWebLinks web;

    Future<void> frames(WidgetTester tester) async {
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    Future<void> pump(WidgetTester tester) async {
      transport = FakeTransport();
      web = FakeWebLinks();
      await tester.pumpWidget(
        ProviderScope(
          overrides: baseOverrides(
            store: MemoryTokenStore(storedFor('saved')),
            tokens: FakeAuthTokenApi(),
            transport: transport,
            analysis: analysis,
            web: web,
          ),
          retry: (_, _) => null,
          child: const CryptoPilotApp(),
        ),
      );
      await frames(tester);
      transport.last.onConnected();
      await frames(tester);
    }

    void go(WidgetTester tester, String location) => ProviderScope.containerOf(
      tester.element(find.byType(CryptoPilotApp)),
    ).read(appRouterProvider).go(location);

    AnalysisScreen shown(WidgetTester tester) =>
        tester.widget<AnalysisScreen>(find.byType(AnalysisScreen));

    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 31));
    }

    setUp(() => analysis = FakeAnalysisApi());

    testWidgets('a row of Home, Markets and the Watchlist opens the pair\'s '
        'analysis; Back returns to the list', (tester) async {
      await pump(tester);

      // SCR-08.
      await tester.tap(find.byKey(const Key('home-watch-BTCUSDT')));
      await frames(tester);
      expect(shown(tester).symbol, 'BTCUSDT');
      expect(shown(tester).market, Market.spot);
      await tester.pageBack();
      await frames(tester);
      expect(find.byType(AnalysisScreen), findsNothing);
      expect(find.byKey(const Key('home-watch-BTCUSDT')), findsOneWidget);

      // SCR-12, the Watchlist segment of the Markets tab.
      go(tester, '/markets');
      await frames(tester);
      await tester.tap(find.text('Watchlist'));
      await frames(tester);
      await tester.tap(find.byKey(const Key('watch-row-ETHUSDT')));
      await frames(tester);
      expect(shown(tester).symbol, 'ETHUSDT');
      await tester.pageBack();
      await frames(tester);

      // SCR-09, Futures tab.
      await tester.tap(find.text('Futures'));
      await frames(tester);
      await tester.tap(find.byKey(const Key('row-futures-BTCUSDT')));
      await frames(tester);
      expect(shown(tester).symbol, 'BTCUSDT');
      expect(shown(tester).market, Market.futures);
      await unmount(tester);
    });

    testWidgets('a pair disabled while it is open (MSG41): the screen says '
        'so and returns to Markets', (tester) async {
      await pump(tester);
      go(tester, '/analysis/spot/BTCUSDT');
      await frames(tester);
      expect(find.byType(AnalysisScreen), findsOneWidget);

      // The next closed candle's push reads the analysis again: 404.
      analysis.error = problem(404, 'PAIR_NOT_FOUND', 'MSG41');
      transport.last.push('/topic/analysis.SPOT.BTCUSDT.1h', {
        'symbol': 'BTCUSDT',
      });
      await frames(tester);

      expect(find.byType(AnalysisScreen), findsNothing);
      expect(find.byType(MarketsScreen), findsOneWidget);
      expect(find.text('This pair is no longer available.'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('a pair the board does not list, or an unknown market, '
        'returns to Markets', (tester) async {
      await pump(tester);
      go(tester, '/analysis/spot/DOGEUSDT');
      await frames(tester);
      expect(find.byType(AnalysisScreen), findsNothing);
      expect(find.byType(MarketsScreen), findsOneWidget);
      expect(find.text('This pair is no longer available.'), findsOneWidget);
      expect(analysis.calls, isEmpty);

      go(tester, '/analysis/options/BTCUSDT');
      await frames(tester);
      expect(find.byType(AnalysisScreen), findsNothing);
      expect(find.byType(MarketsScreen), findsOneWidget);
      await unmount(tester);
    });
  });
}
