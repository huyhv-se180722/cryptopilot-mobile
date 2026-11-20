import 'package:cryptopilot_mobile/core/auth/token_store.dart';
import 'package:cryptopilot_mobile/core/i18n/app_localizations.dart';
import 'package:cryptopilot_mobile/core/json/json_read.dart';
import 'package:cryptopilot_mobile/core/theme/app_theme.dart';
import 'package:cryptopilot_mobile/features/market/application/market_overview.dart';
import 'package:cryptopilot_mobile/features/market/data/market_api.dart';
import 'package:cryptopilot_mobile/features/market/domain/coin_market.dart';
import 'package:cryptopilot_mobile/features/market/presentation/markets_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/http_fakes.dart';
import '../support/realtime_fakes.dart';

/// T-134 (A-65): the whole market's figures of `GET /market/coins`.
Map<String, Object?> coinsJson() => {
  'asOf': '2026-11-20T03:00:00Z',
  'global': {
    'marketCapUsd': '2614000000000',
    'marketCapChange24hPercent': '-1.84',
    'volume24hUsd': '98400000000',
    'bitcoinDominancePercent': '58.21',
    'asOf': '2026-11-20T02:55:00Z',
  },
  'fearGreed': {
    'value': 22,
    'classification': 'Extreme Fear',
    'asOf': '2026-11-20T00:00:00Z',
  },
  'altcoinSeason': {'index': 31, 'altcoins': 9, 'days': 90},
  'openInterest': {
    'valueUsd': '41200000000',
    'change24hPercent': '3.10',
    'lastDay': [
      {'at': '2026-11-19T03:00:00Z', 'valueUsd': '40000000000'},
    ],
  },
  'coins': [
    {'symbol': 'BTC', 'name': 'Bitcoin'},
  ],
};

void main() {
  test('every figure of the whole market', () {
    final o = decodeMarketOverview(coinsJson());
    expect(o.asOf, DateTime.utc(2026, 11, 20, 3));
    expect(o.global!.marketCapUsd, '2614000000000');
    expect(o.global!.marketCapChange24hPercent, '-1.84');
    expect(o.global!.bitcoinDominancePercent, '58.21');
    expect(o.fearGreed!.value, 22);
    expect(o.altcoinSeason!.index, 31);
    expect(o.openInterest!.change24hPercent, '3.10');
  });

  test('a figure not known is absent, never zero', () {
    final o = decodeMarketOverview({
      'asOf': '2026-11-20T03:00:00Z',
      'global': {'marketCapUsd': '2614000000000'},
      'coins': const <Object?>[],
    });
    expect(o.global!.volume24hUsd, isNull);
    expect(o.global!.marketCapChange24hPercent, isNull);
    expect(o.fearGreed, isNull);
    expect(o.altcoinSeason, isNull);
    expect(o.openInterest, isNull);
  });

  test('a figure of the wrong kind is refused', () {
    expect(
      () => decodeMarketOverview({
        ...coinsJson(),
        'global': {'marketCapUsd': 2614000000000},
      }),
      throwsA(isA<DecodeException>()),
    );
    expect(
      () => decodeMarketOverview({
        ...coinsJson(),
        'fearGreed': {'value': '22', 'classification': 'Fear'},
      }),
      throwsA(isA<DecodeException>()),
    );
  });

  test('read from market/coins', () async {
    final adapter = RecordingAdapter()..answers.add((200, coinsJson()));
    await DioMarketApi(dioOn(adapter)).overview();
    expect(adapter.requests.single.path, 'market/coins');
  });

  test('the five Fear & Greed bands of the web', () {
    expect(fearGreedBand(24), FearGreedBand.extremeFear);
    expect(fearGreedBand(25), FearGreedBand.fear);
    expect(fearGreedBand(45), FearGreedBand.neutral);
    expect(fearGreedBand(55), FearGreedBand.neutral);
    expect(fearGreedBand(56), FearGreedBand.greed);
    expect(fearGreedBand(75), FearGreedBand.extremeGreed);
  });

  group('strip', () {
    late FakeMarketApi api;

    Future<void> render(
      WidgetTester tester, {
      Brightness brightness = Brightness.light,
    }) async {
      final transport = FakeTransport();
      await tester.pumpWidget(
        ProviderScope(
          overrides: baseOverrides(
            store: MemoryTokenStore(storedFor('saved')),
            tokens: FakeAuthTokenApi(),
            transport: transport,
            market: api,
          ),
          retry: (_, _) => null,
          child: MaterialApp(
            theme: appTheme(brightness),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const MarketsScreen(),
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

    Future<void> scrollStrip(WidgetTester tester, String key) =>
        tester.scrollUntilVisible(
          find.byKey(Key(key)),
          120,
          scrollable: find
              .descendant(
                of: find.byKey(const Key('market-overview')),
                matching: find.byType(Scrollable),
              )
              .first,
        );

    setUp(() => api = FakeMarketApi());

    testWidgets('the whole market above the Spot list', (tester) async {
      await render(tester);
      expect(find.text('\$2.61T'), findsOneWidget);
      expect(find.text('−1.84%'), findsOneWidget);
      expect(find.text('\$98.40B'), findsOneWidget);
      expect(find.text('58.2%'), findsOneWidget);
      await scrollStrip(tester, 'overview-fear-greed');
      expect(find.text('22'), findsOneWidget);
      expect(find.text('Extreme fear'), findsOneWidget);
      await scrollStrip(tester, 'overview-open-interest');
      expect(find.text('31/100'), findsOneWidget);
      expect(find.text('\$41.20B'), findsOneWidget);
      expect(find.text('+3.10%'), findsOneWidget);
      expect(api.overviewCalls, 1);
      await unmount(tester);
    });

    testWidgets('a figure not known shows --', (tester) async {
      api.overviewValue = MarketOverview(
        asOf: DateTime.utc(2026, 11, 20),
        global: const GlobalMarket(marketCapUsd: '2614000000000'),
      );
      await render(tester);
      expect(find.text('\$2.61T'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('overview-volume')),
          matching: find.text('--'),
        ),
        findsOneWidget,
      );
      await scrollStrip(tester, 'overview-open-interest');
      expect(
        find.descendant(
          of: find.byKey(const Key('overview-open-interest')),
          matching: find.text('--'),
        ),
        findsOneWidget,
      );
      await unmount(tester);
    });

    testWidgets('figures that cannot be read leave the list alone', (
      tester,
    ) async {
      api.overviewError = problem(503, 'UNAVAILABLE', 'MSG43');
      await render(tester);
      expect(find.byKey(const Key('overview-cap')), findsNothing);
      expect(find.byKey(const Key('search-spot')), findsOneWidget);
      await unmount(tester);
    });

    for (final brightness in Brightness.values) {
      testWidgets('360 dp, ${brightness.name}: every card fits', (
        tester,
      ) async {
        tester.view
          ..physicalSize = const Size(360 * 3, 760 * 3)
          ..devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        await render(tester, brightness: brightness);
        expect(tester.takeException(), isNull);
        await scrollStrip(tester, 'overview-open-interest');
        expect(tester.takeException(), isNull);
        await unmount(tester);
      });
    }
  });
}
