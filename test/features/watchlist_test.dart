import 'package:cryptopilot_mobile/core/auth/token_store.dart';
import 'package:cryptopilot_mobile/core/i18n/app_localizations.dart';
import 'package:cryptopilot_mobile/core/theme/app_theme.dart';
import 'package:cryptopilot_mobile/features/market/presentation/markets_screen.dart';
import 'package:cryptopilot_mobile/features/market/presentation/pair_sheet.dart';
import 'package:cryptopilot_mobile/features/watchlist/domain/watchlist.dart';
import 'package:cryptopilot_mobile/features/watchlist/presentation/watchlist_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/realtime_fakes.dart';

void main() {
  group('decoders (backend develop 6d8a3d9 payloads)', () {
    test('watchlist with its plan limit', () {
      final watchlist = decodeWatchlist({
        'items': [
          {
            'id': '01a18807-624d-74ef-8125-aace703ea262',
            'pairId': '01a18804-7883-752f-86a8-6efe55cebd85',
            'symbol': 'BTCUSDT',
            'spotListed': true,
            'futuresListed': true,
            'label': 'Core',
            'note': 'Main holding, watch the 80k support',
            'sortOrder': 0,
            'activeAlerts': 2,
            'addedAt': '2026-10-29T14:19:07.725895Z',
          },
        ],
        'limit': 50,
      });
      expect(watchlist.limit, 50);
      expect(watchlist.items.single.activeAlerts, 2);
    });

    test('setup score of the preset, null score without enough candles', () {
      final score = decodeSetupScore({
        'setupScore': {
          'score': 25,
          'preset': 'SCALPING',
          'presetVersion': 'v1',
          'timeframe': '15m',
        },
      })!;
      expect(score.score, 25);
      expect(score.timeframe, '15m');
      expect(
        decodeSetupScore({
          'setupScore': {
            'score': null,
            'preset': 'SWING',
            'presetVersion': 'v1',
            'timeframe': '4h',
          },
        })!.score,
        isNull,
      );
    });
  });

  group('SCR-12', () {
    late FakeTransport transport;
    late FakeWatchlistApi api;

    Future<void> pump(WidgetTester tester, {List<WatchItem>? items}) async {
      transport = FakeTransport();
      api = FakeWatchlistApi();
      if (items != null) api.items = items;
      await tester.pumpWidget(
        ProviderScope(
          overrides: baseOverrides(
            store: MemoryTokenStore(storedFor('saved')),
            tokens: FakeAuthTokenApi(),
            transport: transport,
            watchlist: api,
          ),
          retry: (_, _) => null,
          child: MaterialApp(
            theme: appTheme(Brightness.light),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const WatchlistView(),
          ),
        ),
      );
      for (var i = 0; i < 6; i++) {
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
      await tester.pump();
      await tester.pump();
      // Let the Add pair button finish its entrance before it takes taps.
      await tester.pump(const Duration(milliseconds: 500));
    }

    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 31));
    }

    testWidgets('groups by label with price, score and alerts', (tester) async {
      await pump(tester);

      expect(find.text('CORE'), findsOneWidget);
      expect(find.text('OTHER'), findsOneWidget);
      expect(find.text('3 / 5 pairs'), findsOneWidget);
      expect(find.text('76,166.01'), findsOneWidget);
      expect(find.text('−5.66%'), findsOneWidget);
      expect(find.text('Score 72 · 2 alerts'), findsOneWidget);
      expect(find.text('No alerts'), findsNWidgets(2));
      await unmount(tester);
    });

    testWidgets('removing a pair with alerts asks MSG26 and then confirms', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.byKey(const Key('watch-menu-BTCUSDT')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Remove').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text('Removing BTCUSDT will also delete 2 alerts. Continue?'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('confirm-remove')));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(api.removeCalls, [
        'watch-BTC confirm=false n=null',
        'watch-BTC confirm=true n=2',
      ]);
      expect(find.byKey(const Key('watch-row-BTCUSDT')), findsNothing);
      await unmount(tester);
    });

    testWidgets('Add pair lists every pair once and adds with MSG25', (
      tester,
    ) async {
      await pump(tester, items: [watchOf('BTC'), watchOf('ETH')]);
      await tester.tap(find.byKey(const Key('add-pair')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final btc = find.byKey(const Key('add-BTCUSDT'));
      expect(btc, findsOneWidget);
      expect(
        find.descendant(
          of: btc,
          matching: find.text('Bitcoin · Spot · Futures'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: btc, matching: find.text('Added')),
        findsOneWidget,
      );

      await tester.enterText(find.byKey(const Key('add-pair-search')), 'sol');
      await tester.pump();
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('add-SOLUSDT')),
          matching: find.text('Add'),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(api.added, ['pair-SOL']);
      expect(find.text('SOLUSDT added to watchlist.'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('the plan limit answer MSG27 stays in the sheet', (
      tester,
    ) async {
      await pump(tester, items: [watchOf('BTC')]);
      api.addError = problem(
        409,
        'PLAN_LIMIT_REACHED',
        'MSG27',
        args: ['5', 'watchlist items', 'FREE'],
      );
      await tester.tap(find.byKey(const Key('add-pair')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('add-ETHUSDT')),
          matching: find.text('Add'),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.text(
          'You have reached the limit of 5 watchlist items of the FREE plan. Upgrade to increase the limit?',
        ),
        findsOneWidget,
      );
      await unmount(tester);
    });
  });

  group('SCR-09 pair sheet: WatchToggle', () {
    late FakeTransport transport;
    late FakeWatchlistApi api;

    /// The Markets tab as `main.dart` composes it: the pair sheet carries the
    /// watchlist's toggle through [pairActionsProvider].
    Future<void> openSheet(
      WidgetTester tester, {
      required List<WatchItem> items,
      required String symbol,
    }) async {
      transport = FakeTransport();
      api = FakeWatchlistApi()..items = items;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...baseOverrides(
              store: MemoryTokenStore(storedFor('saved')),
              tokens: FakeAuthTokenApi(),
              transport: transport,
              watchlist: api,
            ),
            pairActionsProvider.overrideWithValue(
              (_, pair) => WatchToggle(pair: pair),
            ),
          ],
          retry: (_, _) => null,
          child: MaterialApp(
            theme: appTheme(Brightness.light),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const MarketsScreen(watchlist: WatchlistView()),
          ),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump();
      }
      transport.last.onConnected();
      await tester.pump();
      await tester.tap(find.byKey(Key('row-spot-$symbol')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 31));
    }

    Finder toggleText(String text) => find.descendant(
      of: find.byKey(const Key('watch-toggle')),
      matching: find.text(text),
    );

    testWidgets('an unwatched pair is added with MSG25 and shows Watching', (
      tester,
    ) async {
      await openSheet(tester, items: [watchOf('BTC')], symbol: 'SOLUSDT');
      expect(toggleText('Add to watchlist'), findsOneWidget);

      await tester.tap(find.byKey(const Key('watch-toggle')));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(api.added, ['pair-SOL']);
      expect(find.text('SOLUSDT added to watchlist.'), findsOneWidget);
      expect(toggleText('Watching'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('a watched pair with alerts asks MSG26 before it goes', (
      tester,
    ) async {
      await openSheet(
        tester,
        items: [watchOf('BTC', alerts: 2)],
        symbol: 'BTCUSDT',
      );
      expect(toggleText('Watching'), findsOneWidget);

      await tester.tap(find.byKey(const Key('watch-toggle')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.text('Removing BTCUSDT will also delete 2 alerts. Continue?'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('confirm-remove')));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(api.removeCalls, [
        'watch-BTC confirm=false n=null',
        'watch-BTC confirm=true n=2',
      ]);
      expect(toggleText('Add to watchlist'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('360 dp, dark', () {
    Future<void> render(WidgetTester tester, {required int tab}) async {
      tester.view
        ..physicalSize = const Size(360 * 3, 760 * 3)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final transport = FakeTransport();
      await tester.pumpWidget(
        ProviderScope(
          overrides: baseOverrides(
            store: MemoryTokenStore(storedFor('saved')),
            tokens: FakeAuthTokenApi(),
            transport: transport,
          ),
          retry: (_, _) => null,
          child: MaterialApp(
            theme: appTheme(Brightness.dark),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const MarketsScreen(watchlist: WatchlistView()),
          ),
        ),
      );
      for (var i = 0; i < 6; i++) {
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
            'quoteVolume24h': '2020233955.09',
          },
        ],
      });
      await tester.pump();
      await tester.pump();
      if (tab == 0) {
        await tester.tap(find.text('Watchlist'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        // The watchlist and its scores load once the segment is built.
        for (var i = 0; i < 6; i++) {
          await tester.pump();
        }
      }
    }

    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 31));
    }

    testWidgets('the Spot list fits without overflow', (tester) async {
      await render(tester, tab: 1);
      expect(tester.takeException(), isNull);
      expect(find.text('76,166.01'), findsOneWidget);
      expect(find.text('−5.66%'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('the watchlist fits without overflow', (tester) async {
      await render(tester, tab: 0);
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('watch-row-BTCUSDT')), findsOneWidget);
      expect(find.text('Score 72 · 2 alerts'), findsOneWidget);
      await unmount(tester);
    });
  });
}
