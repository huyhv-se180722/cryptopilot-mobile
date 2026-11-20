// The device check batch of the PARTIAL tasks (T-090, T-091, T-123…T-126,
// T-128, T-129, T-131…T-137) against a running backend (not part of
// `flutter test`):
//
//   flutter test integration_test/device_check_test.dart -d emulator-5554 \
//     --dart-define=LOGIN_EMAIL=... --dart-define=LOGIN_PASSWORD=... \
//     [--dart-define=DARK=true]
//
// Each screen is opened through the router, waited for, checked for render
// errors (overflow and the like) and announced as `SHOT:<name>` so a host
// loop can take `adb exec-out screencap`. Only the browser is faked.
import 'dart:async';

import 'package:cryptopilot_mobile/app.dart';
import 'package:cryptopilot_mobile/core/auth/token_store.dart';
import 'package:cryptopilot_mobile/core/router/app_router.dart';
import 'package:cryptopilot_mobile/core/settings/settings.dart';
import 'package:cryptopilot_mobile/core/web/web_links.dart';
import 'package:cryptopilot_mobile/features/community/presentation/community_widgets.dart';
import 'package:cryptopilot_mobile/features/journal/presentation/journal_view.dart';
import 'package:cryptopilot_mobile/features/plans/presentation/plans_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

const email = String.fromEnvironment('LOGIN_EMAIL');
const password = String.fromEnvironment('LOGIN_PASSWORD');
const dark = bool.fromEnvironment('DARK');

class NoBrowser implements WebLinks {
  final List<String> opened = [];

  @override
  Future<bool> open(String path) async {
    opened.add(path);
    return true;
  }

  @override
  Future<bool> openAddress(String address) async {
    opened.add(address);
    return true;
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('device check of every PARTIAL task', (tester) async {
    expect(email, isNotEmpty, reason: 'pass --dart-define=LOGIN_EMAIL');
    final problems = <String>[];
    await SecureTokenStore().clear();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [webLinksProvider.overrideWithValue(NoBrowser())],
        retry: (_, _) => null,
        child: const CryptoPilotApp(),
      ),
    );

    Future<bool> waitFor(Finder finder, {int seconds = 30}) async {
      for (var i = 0; i < seconds * 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (finder.evaluate().isNotEmpty) return true;
      }
      return false;
    }

    Future<void> settle([int ms = 1500]) async {
      for (var i = 0; i < ms ~/ 100; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    /// Checks the screen, then holds it for the host's screenshot.
    Future<void> shot(String name, Finder expected) async {
      final shown = await waitFor(expected);
      await settle();
      final error = tester.takeException();
      if (!shown) problems.add('$name: $expected never showed');
      if (error != null) problems.add('$name: $error');
      // ignore: avoid_print
      print('SHOT:$name');
      await settle(2500);
    }

    // Sign in.
    await waitFor(find.byKey(const Key('login-submit')));
    await tester.enterText(find.byKey(const Key('login-email')), email);
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('login-password')),
        matching: find.byType(TextField),
      ),
      password,
    );
    await tester.tap(find.byKey(const Key('login-submit')));
    expect(await waitFor(find.byType(NavigationBar)), isTrue);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(CryptoPilotApp)),
    );
    if (dark) {
      await container.read(themeModeProvider.notifier).select(ThemeMode.dark);
    }
    final GoRouter router = container.read(appRouterProvider);
    Future<void> go(String location) async {
      router.go(location);
      await settle(500);
    }

    Future<void> push(String location) async {
      router.go(Routes.home);
      await settle(300);
      unawaited(router.push<void>(location));
      await settle(500);
    }

    Future<void> tapFirst(Finder finder) async {
      if (finder.evaluate().isEmpty) return;
      await tester.tap(finder.first);
      await settle(500);
    }

    // Home (T-125 view models, T-133 block).
    await go(Routes.home);
    await shot('01-home', find.byKey(const Key('home-watchlist')));
    await tester.scrollUntilVisible(
      find.byKey(const Key('home-community')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await shot('02-home-community', find.byKey(const Key('home-community')));

    // Markets: logos (T-132) and the overview strip (T-134).
    await go(Routes.markets);
    await shot('03-markets-spot', find.byKey(const Key('market-overview')));
    await tester.tap(find.widgetWithText(Tab, 'Futures'));
    await shot('04-markets-futures', find.byKey(const Key('market-overview')));
    await tester.tap(find.widgetWithText(Tab, 'Watchlist'));
    await shot('05-watchlist', find.byType(Scrollable));

    // Analysis SCR-10 / SCR-11 (T-090).
    await push('/analysis/spot/BTCUSDT');
    await shot('06-analysis-spot', find.byKey(const Key('analysis-price')));
    await settle(3000);
    await shot(
      '07-analysis-spot-chart',
      find.byKey(const Key('analysis-price')),
    );
    await push('/analysis/futures/BTCUSDT');
    await shot('08-analysis-futures', find.byKey(const Key('analysis-price')));

    // Plans, plan detail and the journal (T-091).
    await go(Routes.plans);
    await shot('09-plans-positions', find.byKey(const Key('plans-tabs')));
    await tester.tap(find.byKey(const Key('plans-tab-active')));
    await shot('10-plans-active', find.byKey(const Key('plans-tabs')));
    await tapFirst(find.byType(PlanRow));
    if (await waitFor(find.byKey(const Key('plan-detail')), seconds: 10)) {
      await shot('11-plan-detail', find.byKey(const Key('plan-detail')));
    }
    await go('/plans?tab=journal');
    await shot('12-journal', find.byKey(const Key('plans-tabs')));
    await tapFirst(find.byType(JournalRow));
    if (await waitFor(find.byKey(const Key('journal-entry')), seconds: 10)) {
      await shot('13-journal-entry', find.byKey(const Key('journal-entry')));
    }

    // Trade: Spot (T-128), Futures (T-129, T-131), calculator (T-123).
    await go('/trade?market=spot');
    await shot('14-trade-spot', find.byKey(const Key('trade-segment')));
    await go('/trade?market=futures');
    await shot('15-trade-futures', find.byKey(const Key('trade-segment')));
    if (find.byKey(const Key('futures-calculator')).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(const Key('futures-calculator')));
      await shot('16-futures-calculator', find.byKey(const Key('calc')));
      await tester.tapAt(const Offset(20, 20));
      await settle(800);
    }

    // Assets and its histories (T-128, T-123).
    await go(Routes.assets);
    await shot('17-assets', find.byType(Scrollable));
    await push(Routes.assetsHistory);
    await shot('18-assets-history', find.byType(Scrollable));

    // Academy (T-124).
    await push(Routes.academy);
    await shot('19-academy', find.byKey(const Key('academy-list')));
    await push(Routes.academyGlossary);
    await shot('20-glossary', find.byType(Scrollable));

    // AI assistant with the style chip (T-126).
    await push(Routes.ai);
    await shot('21-ai', find.byType(Scrollable));
    await push(Routes.aiNew);
    await shot('22-ai-new', find.byKey(const Key('ai-input')));

    // Community (T-133).
    await push(Routes.community);
    await shot('23-community', find.byType(Scrollable));
    await tapFirst(find.byType(PostCard));
    if (await waitFor(find.byKey(const Key('post-detail')), seconds: 10)) {
      await shot('24-community-post', find.byKey(const Key('post-detail')));
    }

    // Writing a post (T-135), a member page (T-136), the Coins list (T-137).
    await push('/community/new');
    await shot('27-composer', find.byKey(const Key('composer')));
    await push(Routes.community);
    await waitFor(find.byType(PostCard));
    final author = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('author-'),
    );
    await tapFirst(author);
    if (await waitFor(find.byKey(const Key('member-tabs')), seconds: 10)) {
      await shot('28-member', find.byKey(const Key('member-tabs')));
    }
    await go(Routes.markets);
    await tester.tap(find.byKey(const Key('markets-coins')));
    await shot('29-coins', find.byKey(const Key('coin-list')));

    // Notifications and the account (T-125).
    await push(Routes.notifications);
    await shot('25-notifications', find.byType(Scrollable));
    await push(Routes.account);
    await shot('26-account', find.text(email));

    // ignore: avoid_print
    print('PROBLEMS:${problems.length}');
    for (final p in problems) {
      // ignore: avoid_print
      print('PROBLEM:$p');
    }
    await SecureTokenStore().clear();
    expect(problems, isEmpty);
  });
}
