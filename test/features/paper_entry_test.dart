import 'package:cryptopilot_mobile/app.dart';
import 'package:cryptopilot_mobile/core/auth/token_store.dart';
import 'package:cryptopilot_mobile/core/router/app_router.dart';
import 'package:cryptopilot_mobile/features/home/presentation/home_screen.dart';
import 'package:cryptopilot_mobile/features/market/presentation/pair_actions.dart';
import 'package:cryptopilot_mobile/features/paper/presentation/assets_screen.dart';
import 'package:cryptopilot_mobile/features/paper/presentation/trade_entry.dart';
import 'package:cryptopilot_mobile/features/paper/presentation/trade_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/paper_fakes.dart';
import '../support/realtime_fakes.dart';

void main() {
  late FakeTransport transport;
  late FakePaperApi paper;

  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> start(WidgetTester tester) async {
    transport = FakeTransport();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...baseOverrides(
            store: MemoryTokenStore(storedFor('saved')),
            tokens: FakeAuthTokenApi(),
            transport: transport,
            paper: paper,
          ),
          pairActionsProvider.overrideWithValue(
            (_, pair) => TradeDemoButton(pair: pair),
          ),
        ],
        retry: (_, _) => null,
        child: const CryptoPilotApp(),
      ),
    );
    await frames(tester);
    transport.last.onConnected();
    await frames(tester);
  }

  Finder homeList() => find
      .descendant(
        of: find.byType(HomeScreen),
        matching: find.byType(Scrollable),
      )
      .first;

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 31));
  }

  setUp(() => paper = FakePaperApi());

  testWidgets('Home invites before the account is open, without opening it; '
      'Assets opens it, and Home then shows its worth and today', (
    tester,
  ) async {
    await start(tester);
    await tester.scrollUntilVisible(
      find.byKey(const Key('home-demo')),
      300,
      scrollable: homeList(),
    );
    expect(find.text('Practise trading with virtual funds'), findsOneWidget);
    expect(paper.calls, contains('equity'));
    expect(paper.calls, isNot(contains('open')));

    await tester.tap(find.byKey(const Key('home-demo')));
    await frames(tester);
    expect(find.byType(AssetsScreen), findsOneWidget);
    expect(paper.calls, contains('open'));

    ProviderScope.containerOf(
      tester.element(find.byType(CryptoPilotApp)),
    ).read(appRouterProvider).go('/home');
    await frames(tester);
    await tester.scrollUntilVisible(
      find.byKey(const Key('home-demo')),
      300,
      scrollable: homeList(),
    );
    expect(
      find.textContaining('15,000.00 USDT', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('Today -12.50', findRichText: true),
      findsOneWidget,
    );
    await unmount(tester);
  });

  testWidgets('Trade (demo) on a pair\'s analysis opens Trade on that pair, '
      'in Futures for a Futures pair', (tester) async {
    await start(tester);
    final router = ProviderScope.containerOf(
      tester.element(find.byType(CryptoPilotApp)),
    ).read(appRouterProvider);
    // FE owner 2026-11-19: T-129 gives Futures pairs the entry T-128 held
    // back ("a Futures pair has none yet").
    router.go('/analysis/futures/ETHUSDT');
    await frames(tester);
    await tester.tap(find.byKey(const Key('trade-demo-ETHUSDT')));
    await frames(tester);
    expect(find.byKey(const Key('trade-futures')), findsOneWidget);
    expect(find.text('ETHUSDT Perp'), findsOneWidget);

    router.go('/analysis/spot/ETHUSDT');
    await frames(tester);
    await tester.tap(find.byKey(const Key('trade-demo-ETHUSDT')));
    await frames(tester);
    expect(find.byType(TradeScreen), findsOneWidget);
    expect(find.text('ETH/USDT'), findsOneWidget);
    await unmount(tester);
  });
}
