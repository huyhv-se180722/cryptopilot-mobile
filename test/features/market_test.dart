import 'dart:async';

import 'package:cryptopilot_mobile/core/auth/token_store.dart';
import 'package:cryptopilot_mobile/core/i18n/app_localizations.dart';
import 'package:cryptopilot_mobile/core/theme/app_theme.dart';
import 'package:cryptopilot_mobile/features/market/application/market_board.dart';
import 'package:cryptopilot_mobile/features/market/domain/market.dart';
import 'package:cryptopilot_mobile/features/market/presentation/market_widgets.dart';
import 'package:cryptopilot_mobile/features/market/presentation/markets_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/realtime_fakes.dart';

/// Payloads as backend develop 6d8a3d9 sent them (2026-11-06).
const spotStats = {
  'symbol': 'BTCUSDT',
  'serverTime': '2026-11-06T01:48:09.822309100Z',
  'ticker': {
    'asOf': '2026-11-06T01:48:00Z',
    'lastPrice': '76166.010000000000',
    'bestBid': '76166.000000000000',
    'bestAsk': '76166.010000000000',
    'high24h': '80918.010000000000',
    'low24h': '75208.420000000000',
    'changePercent24h': '-5.6580000000',
    'baseVolume24h': '26063.786160000000',
    'quoteVolume24h': '2020233955.092655100000',
  },
};

const futuresStats = {
  'symbol': 'BTCUSDT',
  'serverTime': '2026-11-06T01:48:09.898691200Z',
  'price': {
    'asOf': '2026-11-06T01:48:00Z',
    'markPrice': '76135.945028990000',
    'indexPrice': '76175.736086960000',
    'fundingRate': '0.00007967',
    'nextFundingTime': '2026-11-06T08:00:00Z',
  },
  'openInterest': null,
};

Map<String, Object?> overview(
  String market,
  List<Map<String, Object?>> tickers,
) => {
  'market': market,
  'serverTime': '2026-11-06T01:48:10Z',
  'tickers': tickers,
};

Map<String, Object?> tick(
  String symbol,
  String last,
  String change,
  String quoteVolume,
) => {
  'market': 'SPOT',
  'symbol': symbol,
  'sourceTime': '2026-11-06T01:48:10Z',
  'lastPrice': last,
  'changePercent24h': change,
  'quoteVolume24h': quoteVolume,
  'markPrice': null,
};

void main() {
  group('decoders (checked against the running backend)', () {
    test('a pair page entry', () {
      final pair = decodePair({
        'pairId': '01a18804-7883-752f-86a8-6efe55cebd85',
        'symbol': 'BTCUSDT',
        'market': 'SPOT',
        'baseAsset': 'BTC',
        'quoteAsset': 'USDT',
        'baseAssetName': 'BTC',
        'logoUrl': null,
        'tickSize': '0.010000000000',
        'stepSize': '0.000010000000',
        'minNotional': '5.00000000',
        'displayOrder': 1,
      });
      expect(pair.market, Market.spot);
      expect(pair.tickSize, '0.010000000000');
    });

    test('Spot stats carry the 24 h ticker', () {
      final ticker = decodeSpotStats(spotStats);
      expect(ticker.lastPrice, '76166.010000000000');
      expect(ticker.changePercent24h, '-5.6580000000');
    });

    test('Futures stats carry mark, index and funding only', () {
      final ticker = decodeFuturesStats(futuresStats);
      expect(ticker.lastPrice, isNull);
      expect(ticker.displayPrice, '76135.945028990000');
      expect(ticker.nextFundingTime, DateTime.utc(2026, 11, 6, 8));
    });

    test('an overview lists every streamed pair', () {
      final tickers = decodeOverview(
        overview('SPOT', [tick('BTCUSDT', '1', '2', '3')]),
      );
      expect(tickers.single.symbol, 'BTCUSDT');
    });
  });

  group('SCR-09 market board', () {
    late FakeTransport transport;
    late FakeMarketApi api;

    Future<void> pump(WidgetTester tester) async {
      transport = FakeTransport();
      api = FakeMarketApi();
      await tester.pumpWidget(
        ProviderScope(
          overrides: baseOverrides(
            store: MemoryTokenStore(),
            tokens: FakeAuthTokenApi(),
            transport: transport,
            market: api,
          ),
          retry: (_, _) => null,
          child: MaterialApp(
            theme: appTheme(Brightness.light),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const MarketsScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      transport.last.onConnected();
      await tester.pump();
    }

    Future<void> push(
      WidgetTester tester,
      List<Map<String, Object?>> tickers,
    ) async {
      transport.last.push('/topic/overview.SPOT', overview('SPOT', tickers));
      // Broadcast streams deliver in a microtask: one pump for the event, one
      // for the frame it schedules.
      await tester.pump();
      await tester.pump();
    }

    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 31));
    }

    testWidgets('lists the pairs with live prices, signed changes and volume', (
      tester,
    ) async {
      await pump(tester);
      await push(tester, [
        tick('BTCUSDT', '76166.015', '-5.658', '2020233955.09'),
        tick('ETHUSDT', '3402.1', '0.8', '900000000'),
      ]);

      expect(find.text('76,166.02'), findsOneWidget);
      expect(find.text('−5.66%'), findsOneWidget);
      expect(find.text('+0.80%'), findsOneWidget);
      expect(find.text('Vol 2.02B'), findsOneWidget);
      expect(find.text('Live'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('search narrows by symbol or coin name; nothing gives MSG41', (
      tester,
    ) async {
      await pump(tester);
      await tester.enterText(find.byKey(const Key('search-spot')), 'bitcoin');
      await tester.pump();
      expect(find.byKey(const Key('row-spot-BTCUSDT')), findsOneWidget);
      expect(find.byKey(const Key('row-spot-ETHUSDT')), findsNothing);

      await tester.enterText(find.byKey(const Key('search-spot')), 'zzz');
      await tester.pump();
      expect(find.text('No results found.'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('the change header sorts down, up, then back to the order', (
      tester,
    ) async {
      await pump(tester);
      await push(tester, [
        tick('BTCUSDT', '1', '-1', '1'),
        tick('ETHUSDT', '1', '5', '1'),
        tick('SOLUSDT', '1', '2', '1'),
      ]);
      double y(String symbol) =>
          tester.getTopLeft(find.byKey(Key('row-spot-$symbol'))).dy;

      await tester.tap(find.byKey(const Key('sort-change-spot')));
      await tester.pump();
      expect(
        y('ETHUSDT') < y('SOLUSDT') && y('SOLUSDT') < y('BTCUSDT'),
        isTrue,
      );

      await tester.tap(find.byKey(const Key('sort-change-spot')));
      await tester.pump();
      expect(
        y('BTCUSDT') < y('SOLUSDT') && y('SOLUSDT') < y('ETHUSDT'),
        isTrue,
      );

      await tester.tap(find.byKey(const Key('sort-change-spot')));
      await tester.pump();
      expect(
        y('BTCUSDT') < y('ETHUSDT') && y('ETHUSDT') < y('SOLUSDT'),
        isTrue,
      );
      await unmount(tester);
    });

    testWidgets(
      'without pushes for 10 s it is Delayed and polls the rows shown',
      (tester) async {
        await pump(tester);
        await push(tester, [tick('BTCUSDT', '1', '1', '1')]);
        await tester.pump(const Duration(seconds: 11));
        await tester.pump();

        expect(find.text('Delayed'), findsOneWidget);
        expect(api.statsCalls.toSet(), {'BTCUSDT', 'ETHUSDT', 'SOLUSDT'});
        expect(find.text('100.50'), findsWidgets);

        await push(tester, [tick('BTCUSDT', '2', '1', '1')]);
        expect(find.text('Live'), findsOneWidget);
        await unmount(tester);
      },
    );

    testWidgets('a pair opens its 24 h sheet', (tester) async {
      await pump(tester);
      await push(tester, [tick('BTCUSDT', '76166.01', '-5.658', '1')]);
      await tester.tap(find.byKey(const Key('row-spot-BTCUSDT')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('24h high'), findsOneWidget);
      expect(find.text('Best bid'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('the first read shows the list skeleton', (tester) async {
      final gate = Completer<void>();
      transport = FakeTransport();
      api = FakeMarketApi()..hold = gate.future;
      await tester.pumpWidget(
        ProviderScope(
          overrides: baseOverrides(
            store: MemoryTokenStore(),
            tokens: FakeAuthTokenApi(),
            transport: transport,
            market: api,
          ),
          retry: (_, _) => null,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MarketsScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byType(ListSkeleton), findsOneWidget);

      gate.complete();
      await tester.pump();
      await tester.pump();
      expect(find.byType(ListSkeleton), findsNothing);
      expect(find.byKey(const Key('row-spot-BTCUSDT')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('a failed pair read offers to try again', (tester) async {
      transport = FakeTransport();
      api = FakeMarketApi()..pairsError = networkDown;
      await tester.pumpWidget(
        ProviderScope(
          overrides: baseOverrides(
            store: MemoryTokenStore(),
            tokens: FakeAuthTokenApi(),
            transport: transport,
            market: api,
          ),
          retry: (_, _) => null,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MarketsScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.text(
          'Unable to reach the server. Check your connection and try again.',
        ),
        findsOneWidget,
      );
      api.pairsError = null;
      await tester.tap(find.text('Try again'));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('row-spot-BTCUSDT')), findsOneWidget);
      unawaited(Future<void>.value());
      await unmount(tester);
    });
  });

  test('sort keys compare decimals, not text', () {
    final state = MarketBoardState(
      pairs: [pairOf('BTC', 1), pairOf('ETH', 2)],
      tickers: const {
        'BTCUSDT': Ticker(symbol: 'BTCUSDT', quoteVolume24h: '900'),
        'ETHUSDT': Ticker(symbol: 'ETHUSDT', quoteVolume24h: '10000'),
      },
      sort: BoardSort.volume,
    );
    expect(state.rows.first.symbol, 'ETHUSDT');
  });
}
