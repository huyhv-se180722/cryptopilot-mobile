import 'dart:async';

import 'package:cryptopilot_mobile/app.dart';
import 'package:cryptopilot_mobile/core/auth/token_store.dart';
import 'package:cryptopilot_mobile/core/router/app_router.dart';
import 'package:cryptopilot_mobile/core/settings/settings.dart';
import 'package:cryptopilot_mobile/features/academy/presentation/academy_links.dart';
import 'package:cryptopilot_mobile/features/community/presentation/community_screen.dart';
import 'package:cryptopilot_mobile/features/community/presentation/post_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/community_fakes.dart';
import '../support/fakes.dart';
import '../support/realtime_fakes.dart';

/// T-133 (A-64): the ways into the community.
void main() {
  late FakeCommunityApi api;
  late FakeTransport transport;

  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> start(WidgetTester tester) async {
    transport = FakeTransport();
    await tester.pumpWidget(
      ProviderScope(
        overrides: baseOverrides(
          store: MemoryTokenStore(storedFor('saved')),
          tokens: FakeAuthTokenApi(),
          transport: transport,
          settings: MemorySettingsStore(),
          clock: () => communityNow,
          community: api,
        ),
        retry: (_, _) => null,
        child: const CryptoPilotApp(),
      ),
    );
    await frames(tester);
    transport.last.onConnected();
    await frames(tester);
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

  setUp(() => api = FakeCommunityApi());

  testWidgets('Home: the pinned post, then the newest; See all opens the '
      'feed, a row the post', (tester) async {
    api
      ..pinnedItems = [postOf('o1', title: 'Platform update', official: true)]
      ..feedItems = [postOf('p1'), postOf('p2', title: 'ETH lagging')];
    await start(tester);
    await scrollTo(tester, find.byKey(const Key('home-community')));
    final block = find.byKey(const Key('home-community'));
    expect(
      find.descendant(of: block, matching: find.text('Platform update')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: block,
        matching: find.text('Minh Tran · 2h ago · 12 likes · 4 comments'),
      ),
      findsNWidgets(3),
    );
    expect(api.calls, contains('pinned'));

    await tester.tap(
      find.descendant(of: block, matching: find.text('See all')),
    );
    await frames(tester);
    expect(find.byType(CommunityScreen), findsOneWidget);
    await tester.pageBack();
    await frames(tester);

    await scrollTo(tester, find.byKey(const Key('home-post-p1')));
    await tester.tap(find.byKey(const Key('home-post-p1')));
    await frames(tester);
    expect(find.byType(PostScreen), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('Home: a failed block offers Try again', (tester) async {
    api.failAlways['pinned'] = problem(503, 'UNAVAILABLE', 'MSG43');
    await start(tester);
    await scrollTo(tester, find.byKey(const Key('home-community')));
    expect(
      find.descendant(
        of: find.byKey(const Key('home-community')),
        matching: find.text('Try again'),
      ),
      findsOneWidget,
    );
    await unmount(tester);
  });

  testWidgets('Account opens the community', (tester) async {
    await start(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(CryptoPilotApp)),
    );
    unawaited(container.read(appRouterProvider).push('/account'));
    await frames(tester);
    await tester.scrollUntilVisible(
      find.byKey(const Key('open-community')),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const Key('open-community')));
    await frames(tester);
    expect(find.byType(CommunityScreen), findsOneWidget);
    await unmount(tester);
  });

  test('a lesson link to /community opens the app (T-133)', () {
    final target = academyLinkTarget('/community');
    expect(target, isA<AppScreen>());
    expect((target as AppScreen).location, '/community');
    expect(target.tab, isFalse);
  });
}
