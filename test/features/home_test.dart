import 'package:cryptopilot_mobile/core/auth/token_store.dart';
import 'package:cryptopilot_mobile/core/errors/api_failure.dart';
import 'package:cryptopilot_mobile/core/format/decimal_format.dart';
import 'package:cryptopilot_mobile/core/i18n/app_localizations.dart';
import 'package:cryptopilot_mobile/core/json/json_read.dart';
import 'package:cryptopilot_mobile/core/theme/app_theme.dart';
import 'package:cryptopilot_mobile/features/home/presentation/home_screen.dart';
import 'package:cryptopilot_mobile/features/journal/domain/performance.dart';
import 'package:cryptopilot_mobile/features/market/domain/market.dart';
import 'package:cryptopilot_mobile/features/news/domain/news.dart';
import 'package:cryptopilot_mobile/features/plans/domain/plan.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../support/fakes.dart';
import '../support/realtime_fakes.dart';

void main() {
  group('decoders (backend develop 25ba960 payloads)', () {
    test('a plan summary, its pair named by id only', () {
      final page = decodePlanPage({
        'items': [
          {
            'id': 'p1',
            'pairId': '01a18804-7883-752f-86a8-6efe55cebd85',
            'market': 'FUTURES',
            'direction': 'SHORT',
            'entryType': 'LIMIT',
            'entryPrice': '76000.000000000000',
            'expectedFillPrice': null,
            'stopLoss': '78000.000000000000',
            'takeProfit': '70000.000000000000',
            'leverage': 5,
            'riskAmount': '40.000000000000',
            'riskRewardRatio': '3.0000',
            'status': 'EXECUTED',
            'createdAt': '2026-11-06T10:00:00Z',
            'activatedAt': '2026-11-06T10:01:00Z',
            'expiresAt': null,
            'invalidatedAt': null,
            'invalidationReason': null,
            'positionStatus': 'OPEN',
          },
        ],
        'page': 1,
        'pageSize': 5,
        'total': 12,
      });
      final plan = page.items.single;
      expect(page.total, 12);
      expect(plan.direction, PlanDirection.short);
      expect(plan.leverage, 5);
      expect(plan.positionState, PositionState.open);
      expect(
        () => decodePlanSummary({
          'id': 'p',
          'pairId': 'x',
          'market': 'SPOT',
          'direction': 'LONG',
          'entryType': 'LIMIT',
          'status': 'PAUSED',
          'createdAt': '2026-11-06T10:00:00Z',
        }),
        throwsA(isA<DecodeException>()),
      );
    });

    test('a news article and the performance summary', () {
      final article = decodeNewsArticle({
        'articleId': 'a1',
        'title': 'Bitcoin holds',
        'originalTitle': 'Bitcoin holds',
        'source': 'CoinDesk',
        'originalUrl': 'https://example.com/a1',
        'publishedAt': '2026-11-07T01:00:00Z',
        'summary': null,
        'sentiment': 'BEARISH',
        'coins': [
          {'symbol': 'BTC', 'primary': true},
          {'symbol': 'ETH', 'primary': false},
        ],
        'imageUrl': null,
      });
      expect(article.sentiment, NewsSentiment.bearish);
      expect(article.coins, ['BTC', 'ETH']);

      final summary = decodePerformanceSummary({
        'from': null,
        'to': '2026-11-08',
        'trades': 8,
        'wins': 5,
        'losses': 3,
        'breakeven': 0,
        'winRate': 0.625,
        'totalNetPnl': -304.12,
        'provisionalTrades': 0,
        'totalFees': 1.2,
        'totalFunding': 0,
        'advanced': null,
      });
      expect(summary.winRate, '0.625');
      expect(summary.totalNetPnl, '-304.12');
    });
  });

  test('amounts and ratios carry their sign as words', () {
    expect(formatSignedDecimal('-304.12'), '−304.12');
    expect(formatSignedDecimal('12.4'), '+12.40');
    expect(formatSignedDecimal('0.001'), '0.00');
    expect(formatRatioAsPercent('0.625'), '62.5%');
  });

  group('SCR-08 Home', () {
    late FakeTransport transport;
    late FakePlanApi plans;
    late FakePerformanceApi performance;
    late FakeNewsApi news;
    late FakeWebLinks web;

    Future<void> pump(
      WidgetTester tester, {
      Brightness brightness = Brightness.light,
      void Function()? setUp,
    }) async {
      transport = FakeTransport();
      plans = FakePlanApi();
      performance = FakePerformanceApi();
      news = FakeNewsApi();
      web = FakeWebLinks();
      setUp?.call();
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
          GoRoute(
            path: '/markets',
            builder: (_, _) => const Scaffold(body: Text('MARKETS TAB')),
          ),
          GoRoute(
            path: '/notifications',
            builder: (_, _) => const Scaffold(body: Text('SCR-15')),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: baseOverrides(
            store: MemoryTokenStore(storedFor('saved')),
            tokens: FakeAuthTokenApi(),
            transport: transport,
            plans: plans,
            performance: performance,
            news: news,
            web: web,
          ),
          retry: (_, _) => null,
          child: MaterialApp.router(
            routerConfig: router,
            theme: appTheme(brightness),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      for (var i = 0; i < 8; i++) {
        await tester.pump();
      }
      transport.last.onConnected();
      transport.last.push('/topic/overview.SPOT', {
        'market': 'SPOT',
        'serverTime': '2026-11-06T01:48:10Z',
        'tickers': [
          {
            'market': 'SPOT',
            'symbol': 'BTCUSDT',
            'lastPrice': '76166.01',
            'changePercent24h': '-5.66',
          },
        ],
      });
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }
    }

    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 31));
    }

    Future<void> scrollTo(WidgetTester tester, Finder finder) async {
      await tester.scrollUntilVisible(
        finder,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
    }

    testWidgets('the watchlist block shows live prices and the disclaimer', (
      tester,
    ) async {
      await pump(tester);
      expect(find.byKey(const Key('home-watch-BTCUSDT')), findsOneWidget);
      expect(find.text('76,166.01'), findsOneWidget);
      expect(find.text('−5.66%'), findsOneWidget);
      await scrollTo(tester, find.byKey(const Key('home-disclaimer')));
      expect(find.byKey(const Key('home-disclaimer')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('plans: active count, open positions, executed tab', (
      tester,
    ) async {
      await pump(tester);
      await scrollTo(tester, find.byKey(const Key('home-plans')));
      expect(find.text('Active (1)'), findsOneWidget);
      expect(find.text('1 open position'), findsOneWidget);
      expect(
        find.text('Entry 74,000.00 · SL 72,000.00 · TP 80,000.00'),
        findsOneWidget,
      );
      expect(plans.calls, containsAll(['ACTIVE 5', 'EXECUTED 100']));

      await tester.tap(find.text('Executed'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Position open'), findsOneWidget);
      expect(find.text('Position closed'), findsOneWidget);

      await tester.tap(find.byKey(const Key('home-plan-p2')));
      await tester.pump();
      expect(web.opened, ['/plans/p2']);
      await unmount(tester);
    });

    testWidgets('performance shows signed net P/L and win rate', (
      tester,
    ) async {
      await pump(tester);
      await scrollTo(tester, find.byKey(const Key('home-net-pnl')));
      expect(find.text('−304.12'), findsOneWidget);
      expect(find.text('62.5%'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      await unmount(tester);
    });

    for (final (name, missing) in [
      ('a problem body', problem(404, 'RESOURCE_NOT_FOUND', 'MSG41')),
      // Spring's own answer for a path it does not know (backend 66fb7cf).
      ('no problem code', const UnexpectedFailure(status: 404)),
    ]) {
      testWidgets('a backend without the performance API says so ($name)', (
        tester,
      ) async {
        await pump(tester, setUp: () => performance.error = missing);
        await scrollTo(tester, find.byKey(const Key('home-performance')));
        expect(find.text('Performance is not available yet.'), findsOneWidget);
        await unmount(tester);
      });
    }

    testWidgets('one failed block offers Try again; the others stay', (
      tester,
    ) async {
      await pump(tester, setUp: () => news.error = networkDown);
      await scrollTo(tester, find.byKey(const Key('home-news')));
      expect(
        find.text(
          'Unable to reach the server. Check your connection and try again.',
        ),
        findsOneWidget,
      );
      // The other blocks still read.
      expect(plans.calls, contains('ACTIVE 5'));
      news.error = null;
      await tester.tap(find.text('Try again'));
      await tester.pump();
      await tester.pump();
      expect(
        find.text('Bitcoin holds above 75,000 as funding cools'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('home-news-a1')));
      await tester.pump();
      expect(web.opened, ['/news/a1']);
      await unmount(tester);
    });

    testWidgets('empty blocks say so', (tester) async {
      await pump(
        tester,
        setUp: () {
          plans.active = [];
          news.articles = [];
          performance.summaryValue = const PerformanceSummary(
            trades: 0,
            wins: 0,
            losses: 0,
            totalNetPnl: '0',
          );
        },
      );
      await scrollTo(tester, find.byKey(const Key('home-plans')));
      expect(find.text('No active plans.'), findsOneWidget);
      await scrollTo(tester, find.byKey(const Key('home-news')));
      expect(find.text('No closed trades yet.'), findsOneWidget);
      expect(find.text('No news in the last 7 days.'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('See all of the watchlist and the notifications', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.text('See all').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('MARKETS TAB'), findsOneWidget);
      await unmount(tester);
    });

    for (final brightness in Brightness.values) {
      testWidgets('fits 360 dp in the ${brightness.name} theme', (
        tester,
      ) async {
        tester.view
          ..physicalSize = const Size(360 * 3, 760 * 3)
          ..devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        await pump(
          tester,
          brightness: brightness,
          setUp: () => plans.active = [
            planOf('wide', market: Market.futures, leverage: 125),
          ],
        );
        expect(tester.takeException(), isNull);
        await scrollTo(tester, find.byKey(const Key('home-disclaimer')));
        expect(tester.takeException(), isNull);
        await unmount(tester);
      });
    }
  });
}
