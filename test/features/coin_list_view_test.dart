import 'dart:async';

import 'package:cryptopilot_mobile/app.dart';
import 'package:cryptopilot_mobile/core/auth/token_store.dart';
import 'package:cryptopilot_mobile/core/router/app_router.dart';
import 'package:cryptopilot_mobile/core/settings/settings.dart';
import 'package:cryptopilot_mobile/features/analysis/presentation/analysis_screen.dart';
import 'package:cryptopilot_mobile/features/market/domain/coin_market.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/realtime_fakes.dart';

/// T-137: the Coins list of Markets (A-67).
CoinRow coin(
  String symbol,
  int rank, {
  String supply = '1000000',
  String hourAgo = '100',
  String weekAgo = '100',
}) => CoinRow(
  symbol: symbol,
  name: symbol,
  rank: rank,
  spotSymbol: '${symbol}USDT',
  circulatingSupply: supply,
  price1hAgo: hourAgo,
  price7dAgo: weekAgo,
  sparkline7d: const [100, 104, 98, 110],
);

void main() {
  late FakeMarketApi api;
  late FakeTransport transport;

  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> open(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
  }) async {
    transport = FakeTransport();
    await tester.pumpWidget(
      ProviderScope(
        overrides: baseOverrides(
          store: MemoryTokenStore(storedFor('saved')),
          tokens: FakeAuthTokenApi(),
          transport: transport,
          market: api,
          settings: MemorySettingsStore(),
        ),
        retry: (_, _) => null,
        child: const CryptoPilotApp(),
      ),
    );
    await frames(tester);
    transport.last.onConnected();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(CryptoPilotApp)),
    );
    if (brightness == Brightness.dark) {
      unawaited(
        container.read(themeModeProvider.notifier).select(ThemeMode.dark),
      );
    }
    container.read(appRouterProvider).go('/markets');
    await frames(tester);
    await tester.tap(find.byKey(const Key('markets-coins')));
    await frames(tester);
    transport.last.push('/topic/overview.SPOT', {
      'market': 'SPOT',
      'serverTime': '2026-11-20T03:00:00Z',
      'tickers': [
        for (final (symbol, price, change) in [
          ('BTCUSDT', '110', '5.00'),
          ('ETHUSDT', '90', '-3.00'),
          ('SOLUSDT', '100', '1.00'),
        ])
          {
            'market': 'SPOT',
            'symbol': symbol,
            'lastPrice': price,
            'changePercent24h': change,
            'quoteVolume24h': '1000',
          },
      ],
    });
    await frames(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 31));
  }

  List<String> order(WidgetTester tester) => [
    for (final w in tester.widgetList(
      find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('coin-') &&
            !(w.key! as ValueKey<String>).value.startsWith('coin-line') &&
            !(w.key! as ValueKey<String>).value.startsWith('coin-letters') &&
            !(w.key! as ValueKey<String>).value.startsWith('coin-image') &&
            !(w.key! as ValueKey<String>).value.startsWith('coin-frame') &&
            !(w.key! as ValueKey<String>).value.startsWith('coin-list'),
      ),
    ))
      (w.key! as ValueKey<String>).value,
  ];

  setUp(() {
    api = FakeMarketApi()
      ..overviewValue = MarketOverview(
        asOf: DateTime.utc(2026, 11, 20),
        coins: [
          coin('BTC', 1, hourAgo: '100', weekAgo: '100'),
          coin('ETH', 2),
          coin('SOL', 3),
        ],
      );
  });

  testWidgets('by rank with the live price, the cap and the 7 d change '
      'from it', (tester) async {
    await open(tester);
    expect(order(tester), ['coin-BTC', 'coin-ETH', 'coin-SOL']);
    expect(find.text('110.00'), findsOneWidget);
    expect(find.text('+5.00%'), findsOneWidget);
    expect(find.textContaining('Mkt cap \$110.00M'), findsOneWidget);
    expect(find.textContaining('7d +10.00%'), findsOneWidget);
    expect(find.byKey(const Key('coin-line-BTC')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('Gainers and Losers sort by the 24 h change', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('coins-sort-gainers')));
    await tester.pump();
    expect(order(tester), ['coin-BTC', 'coin-SOL', 'coin-ETH']);
    await tester.tap(find.byKey(const Key('coins-sort-losers')));
    await tester.pump();
    expect(order(tester), ['coin-ETH', 'coin-SOL', 'coin-BTC']);
    await unmount(tester);
  });

  testWidgets('a coin opens its Spot analysis', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('coin-ETH')));
    await frames(tester);
    expect(find.byType(AnalysisScreen), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('a list that cannot be read offers Try again', (tester) async {
    api.overviewError = problem(503, 'UNAVAILABLE', 'MSG43');
    await open(tester);
    expect(find.text('Try again'), findsOneWidget);
    await unmount(tester);
  });

  for (final brightness in Brightness.values) {
    testWidgets('360 dp, ${brightness.name}: a coin row fits', (tester) async {
      tester.view
        ..physicalSize = const Size(360 * 3, 760 * 3)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      api.overviewValue = MarketOverview(
        asOf: DateTime.utc(2026, 11, 20),
        coins: [coin('BTC', 1, supply: '19800000000000')],
      );
      await open(tester, brightness: brightness);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  }
}
