import 'package:cryptopilot_mobile/core/auth/token_store.dart';
import 'package:cryptopilot_mobile/core/i18n/app_localizations.dart';
import 'package:cryptopilot_mobile/core/theme/app_theme.dart';
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
}
