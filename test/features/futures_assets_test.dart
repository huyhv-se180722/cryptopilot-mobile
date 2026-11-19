import 'dart:async';

import 'package:cryptopilot_mobile/app.dart';
import 'package:cryptopilot_mobile/core/auth/token_store.dart';
import 'package:cryptopilot_mobile/core/router/app_router.dart';
import 'package:cryptopilot_mobile/core/settings/settings.dart';
import 'package:cryptopilot_mobile/features/paper/domain/futures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/futures_fakes.dart';
import '../support/paper_fakes.dart';
import '../support/realtime_fakes.dart';

/// The Futures part of Assets (T-129, plan 9.3).
void main() {
  late FakeTransport transport;
  late FakePaperApi paper;
  late FakeFuturesApi futures;

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
          paper: paper,
          futures: futures,
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
    container.read(appRouterProvider).go('/assets');
    await frames(tester);
  }

  Finder list() => find
      .descendant(
        of: find.byKey(const Key('assets-list')),
        matching: find.byType(Scrollable),
      )
      .first;

  Future<void> show(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 150, scrollable: list());
    await frames(tester);
  }

  String trailingOf(WidgetTester tester, String key) =>
      (tester.widget<ListTile>(find.byKey(Key(key))).trailing! as Text).data!;

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 31));
  }

  setUp(() {
    paper = FakePaperApi();
    futures = FakeFuturesApi()
      ..accountAnswer = const FuturesAccount(
        walletBalance: '5000.00',
        unrealizedProfit: '-12.40',
        marginBalance: '4987.60',
        availableBalance: '4900.00',
        maxWithdrawAmount: '3000.00',
      );
  });

  testWidgets('the Futures account: signed unrealized PnL, margin balance '
      'and available, hidden with the other amounts', (tester) async {
    await open(tester);
    await show(tester, find.byKey(const Key('futures-available')));
    expect(trailingOf(tester, 'futures-pnl'), '-12.40');
    expect(trailingOf(tester, 'futures-margin-balance'), '4,987.60');
    expect(trailingOf(tester, 'futures-available'), '4,900.00');

    futures.accountAnswer = const FuturesAccount(
      walletBalance: '5000.00',
      unrealizedProfit: '8.00',
      marginBalance: '5008.00',
      availableBalance: '4900.00',
      maxWithdrawAmount: '3000.00',
    );
    transport.last.push('/user/queue/futures.account', {'e': 'ACCOUNT_UPDATE'});
    await tester.pump(const Duration(milliseconds: 600));
    await frames(tester);
    expect(trailingOf(tester, 'futures-pnl'), '+8.00');

    await tester.drag(list(), const Offset(0, 2000));
    await frames(tester);
    await tester.tap(find.byKey(const Key('assets-eye')));
    await frames(tester);
    await show(tester, find.byKey(const Key('futures-available')));
    expect(trailingOf(tester, 'futures-pnl'), isNot(contains('8.00')));
    expect(trailingOf(tester, 'futures-available'), isNot(contains('4,900')));
    await unmount(tester);
  });

  testWidgets('out of Futures at most its max withdraw amount, though the '
      'wallet holds more', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('assets-transfer')));
    await frames(tester);
    await tester.tap(find.byKey(const Key('transfer-swap')));
    await frames(tester);
    await tester.enterText(find.byKey(const Key('transfer-amount')), '4000');
    await tester.tap(find.byKey(const Key('transfer-send')));
    await frames(tester);
    expect(find.textContaining('More than can leave Futures'), findsOneWidget);
    expect(paper.transferKeys, isEmpty);

    await tester.tap(find.byKey(const Key('transfer-max')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('transfer-send')));
    await frames(tester);
    expect(paper.calls, contains('transfer FUTURES 3000.00'));
    await unmount(tester);
  });

  testWidgets('a plan without Futures leaves the Spot part whole and the '
      'Futures account empty', (tester) async {
    futures.loadError = problem(
      403,
      'PLAN_FEATURE_NOT_INCLUDED',
      'MSG29',
      args: ['PRO'],
    );
    await open(tester);
    expect(find.byKey(const Key('coin-BTC')), findsOneWidget);
    await show(tester, find.byKey(const Key('futures-available')));
    expect(trailingOf(tester, 'futures-pnl'), '--');
    expect(trailingOf(tester, 'futures-available'), '--');
    await unmount(tester);
  });

  testWidgets('Trade (demo) of the Futures wallet opens Trade on Futures', (
    tester,
  ) async {
    await open(tester);
    await show(tester, find.byKey(const Key('assets-trade-futures')));
    await tester.tap(find.byKey(const Key('assets-trade-futures')));
    await frames(tester);
    expect(find.byKey(const Key('trade-futures')), findsOneWidget);
    expect(find.text('BTCUSDT Perp'), findsOneWidget);
    await unmount(tester);
  });

  for (final brightness in Brightness.values) {
    testWidgets('360 dp, ${brightness.name}: the Futures part fits', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(360 * 3, 760 * 3)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      futures.accountAnswer = const FuturesAccount(
        walletBalance: '123456789.12',
        unrealizedProfit: '-1234567.89',
        marginBalance: '122222221.23',
        availableBalance: '120000000.00',
        maxWithdrawAmount: '100000000.00',
      );
      await open(tester, brightness: brightness);
      await show(tester, find.byKey(const Key('futures-available')));
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  }
}
