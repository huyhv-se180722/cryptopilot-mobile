import 'package:cryptopilot_mobile/core/auth/token_store.dart';
import 'package:cryptopilot_mobile/core/i18n/app_localizations.dart';
import 'package:cryptopilot_mobile/core/theme/app_theme.dart';
import 'package:cryptopilot_mobile/core/theme/cp_colors.dart';
import 'package:cryptopilot_mobile/features/market/domain/coin_market.dart';
import 'package:cryptopilot_mobile/features/market/presentation/market_widgets.dart';
import 'package:cryptopilot_mobile/features/market/presentation/markets_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/realtime_fakes.dart';

/// T-151 (D-163): the list style of Markets and Home.
void main() {
  group('ChangeText', () {
    Future<void> show(WidgetTester tester, Brightness brightness) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(brightness),
          home: const Scaffold(
            body: Column(
              children: [
                ChangeText(percent: '2.41'),
                ChangeText(percent: '-1.27'),
                ChangeText(percent: '0.001'),
                ChangeText(percent: null),
              ],
            ),
          ),
        ),
      );
    }

    for (final brightness in Brightness.values) {
      testWidgets('${brightness.name}: sign, colour and arrow agree', (
        tester,
      ) async {
        final cp = brightness == Brightness.dark
            ? CpColors.dark
            : CpColors.light;
        await show(tester, brightness);
        expect(
          tester.widget<Text>(find.text('+2.41%')).style!.color,
          cp.positive,
        );
        // The formatter writes the minus sign U+2212.
        expect(
          tester.widget<Text>(find.text('−1.27%')).style!.color,
          cp.negative,
        );
        expect(find.byIcon(Icons.arrow_drop_up), findsOneWidget);
        expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget);
        // Rounded to zero: no sign, no arrow, muted.
        expect(tester.widget<Text>(find.text('0.00%')).style!.color, cp.muted);
        expect(find.text('--'), findsOneWidget);
      });
    }
  });

  group('Markets', () {
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

    setUp(() => api = FakeMarketApi());

    testWidgets('Fear & Greed on a dial, read out with its band; the cap '
        'change has its arrow', (tester) async {
      final semantics = tester.ensureSemantics();
      await render(tester);
      await tester.scrollUntilVisible(
        find.byKey(const Key('overview-fear-greed')),
        120,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('market-overview')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(
        find.byKey(const Key('overview-fear-greed-gauge')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Fear & Greed, 22, Extreme fear'),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('overview-cap')),
          matching: find.byIcon(Icons.arrow_drop_down),
        ),
        findsOneWidget,
      );
      semantics.dispose();
      await unmount(tester);
    });

    testWidgets('Spot rows write the change as text, no pill; Coins has its '
        'column names', (tester) async {
      api.overviewValue = MarketOverview(
        asOf: DateTime.utc(2026, 11, 20),
        coins: const [CoinRow(symbol: 'BTC', name: 'Bitcoin', rank: 1)],
      );
      await render(tester);
      expect(find.byType(ChangeText), findsWidgets);
      expect(find.byType(ChangePill), findsNothing);
      await tester.tap(find.byKey(const Key('markets-coins')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('coins-header')), findsOneWidget);
      expect(find.text('Price / 24h'), findsOneWidget);
      // Left-aligned like the other filters, without a check mark.
      final top = tester.widget<ChoiceChip>(
        find.byKey(const Key('coins-sort-top')),
      );
      expect(top.showCheckmark, isFalse);
      expect(
        tester.getTopLeft(find.byKey(const Key('coins-sort-top'))).dx,
        lessThan(40),
      );
      await unmount(tester);
    });

    testWidgets('360 dp: the 7-day line narrows so the cap and the 7-day '
        'change keep their room (device check)', (tester) async {
      tester.view
        ..physicalSize = const Size(360 * 3, 760 * 3)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      api.overviewValue = MarketOverview(
        asOf: DateTime.utc(2026, 11, 20),
        coins: const [
          CoinRow(
            symbol: 'BTC',
            name: 'Bitcoin',
            rank: 1,
            spotSymbol: 'BTCUSDT',
            sparkline7d: [100, 104, 98, 110],
          ),
        ],
      );
      await render(tester);
      await tester.ensureVisible(find.byKey(const Key('markets-coins')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('markets-coins')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.getSize(find.byKey(const Key('coin-line-BTC'))).width, 44);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    for (final brightness in Brightness.values) {
      testWidgets('360 dp, ${brightness.name}: Spot rows and the dial fit', (
        tester,
      ) async {
        tester.view
          ..physicalSize = const Size(360 * 3, 760 * 3)
          ..devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        await render(tester, brightness: brightness);
        expect(tester.takeException(), isNull);
        await unmount(tester);
      });
    }
  });
}
