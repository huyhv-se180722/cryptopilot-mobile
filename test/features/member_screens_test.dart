import 'dart:async';

import 'package:cryptopilot_mobile/app.dart';
import 'package:cryptopilot_mobile/core/auth/token_store.dart';
import 'package:cryptopilot_mobile/core/router/app_router.dart';
import 'package:cryptopilot_mobile/core/settings/settings.dart';
import 'package:cryptopilot_mobile/features/community/domain/community.dart';
import 'package:cryptopilot_mobile/features/community/presentation/member_screen.dart';
import 'package:cryptopilot_mobile/features/community/presentation/post_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/community_fakes.dart';
import '../support/fakes.dart';
import '../support/realtime_fakes.dart';

/// T-136: member pages, follows, blocks and mentions (A-66, D-99).
void main() {
  late FakeCommunityApi api;
  late FakeWebLinks web;

  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> open(
    WidgetTester tester,
    String location, {
    Brightness brightness = Brightness.light,
  }) async {
    final transport = FakeTransport();
    await tester.pumpWidget(
      ProviderScope(
        overrides: baseOverrides(
          store: MemoryTokenStore(storedFor('saved')),
          tokens: FakeAuthTokenApi(),
          transport: transport,
          web: web,
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
    final container = ProviderScope.containerOf(
      tester.element(find.byType(CryptoPilotApp)),
    );
    if (brightness == Brightness.dark) {
      unawaited(
        container.read(themeModeProvider.notifier).select(ThemeMode.dark),
      );
    }
    unawaited(container.read(appRouterProvider).push(location));
    await frames(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 31));
  }

  Future<void> menu(WidgetTester tester, String item) async {
    await tester.tap(find.byKey(const Key('member-menu')));
    await frames(tester);
    await tester.tap(find.byKey(Key(item)));
    await frames(tester);
  }

  setUp(() {
    api = FakeCommunityApi();
    web = FakeWebLinks();
  });

  testWidgets('an author on a post card opens their page: head, coins, '
      'follow', (tester) async {
    api.members['u-Minh Tran'] = memberOf('u-Minh Tran');
    await open(tester, '/community');
    await tester.tap(find.byKey(const Key('author-u-Minh Tran')).first);
    await frames(tester);
    expect(find.byType(MemberScreen), findsOneWidget);
    expect(find.text('Swing trader, BTC and ETH.'), findsOneWidget);
    expect(find.text('Joined Oct 2026'), findsOneWidget);
    expect(
      find.text('72.5 Influence Score · 64.0 Analytical Depth'),
      findsOneWidget,
    );
    expect(find.text('BTC 60%'), findsOneWidget);
    await tester.tap(find.byKey(const Key('member-follow')));
    await frames(tester);
    expect(api.calls, contains('follow u-Minh Tran true'));
    expect(
      find.descendant(
        of: find.byKey(const Key('member-follow')),
        matching: find.text('Following'),
      ),
      findsOneWidget,
    );
    await unmount(tester);
  });

  testWidgets('their posts, then comments that open the post; followers '
      'lead to other members', (tester) async {
    api.memberCommentItems = [
      MemberComment(
        commentId: 'mc1',
        postId: 'p1',
        reply: false,
        content: 'Agree with the support',
        likes: 2,
        createdAt: communityNow.subtract(const Duration(hours: 1)),
        postTitle: 'BTC holds 76k',
      ),
    ];
    await open(tester, '/community/members/u1');
    expect(
      api.calls,
      contains('feed LATEST coin=null market=null q=null p=1 author=u1'),
    );
    // The posts sit below the head: drag it away first.
    await tester.drag(find.byType(NestedScrollView), const Offset(0, -500));
    await frames(tester);
    expect(find.byKey(const Key('post-p1')), findsOneWidget);
    await tester.tap(find.text('Comments'));
    await frames(tester);
    expect(find.text('Commented on BTC holds 76k · 1h ago'), findsOneWidget);
    await tester.tap(find.byKey(const Key('member-comment-mc1')));
    await frames(tester);
    expect(find.byType(PostScreen), findsOneWidget);
    await tester.pageBack();
    await frames(tester);
    await tester.drag(find.byType(NestedScrollView), const Offset(0, 600));
    await frames(tester);

    await tester.tap(find.byKey(const Key('member-followers')));
    await frames(tester);
    expect(find.text('Followers'), findsOneWidget);
    await tester.tap(find.byKey(const Key('person-u-An')));
    await frames(tester);
    expect(api.calls, contains('member u-An'));
    await unmount(tester);
  });

  testWidgets('block asks first, then says so; unblock comes back', (
    tester,
  ) async {
    await open(tester, '/community/members/u1');
    await menu(tester, 'member-block');
    expect(find.text('Block Minh Tran?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('member-block-confirm')));
    await frames(tester);
    expect(api.calls, contains('block u1 true'));
    expect(
      find.text(
        'Minh Tran is blocked. You no longer see their posts and '
        'comments.',
      ),
      findsWidgets,
    );
    expect(find.byKey(const Key('member-unblock')), findsOneWidget);
    expect(find.byKey(const Key('member-follow')), findsNothing);
    await unmount(tester);
  });

  testWidgets('your own page lists the members you block; unblock removes '
      'one', (tester) async {
    api.members['me'] = memberOf('me', me: true);
    await open(tester, '/community/members/me');
    expect(find.byKey(const Key('member-follow')), findsNothing);
    await menu(tester, 'member-blocks');
    expect(find.text('Blocked members'), findsOneWidget);
    await tester.tap(find.byKey(const Key('unblock-u-An')));
    await frames(tester);
    expect(api.calls, contains('block u-An false'));
    expect(find.byKey(const Key('person-u-An')), findsNothing);
    expect(find.text('An is no longer blocked.'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('a member gone or blocking you shows MSG41', (tester) async {
    api.failNext['member'] = problem(404, 'MEMBER_NOT_FOUND', 'MSG41');
    await open(tester, '/community/members/gone');
    expect(find.byKey(const Key('member-missing')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('@ mentions a member found by name; only one still in the '
      'text is told', (tester) async {
    await open(tester, '/community/p1');
    await tester.tap(find.byKey(const Key('comment-mention')));
    await frames(tester);
    await tester.enterText(find.byKey(const Key('mention-search')), 'an');
    await tester.pump(const Duration(milliseconds: 400));
    await frames(tester);
    await tester.tap(find.byKey(const Key('mention-u-An')));
    await frames(tester);
    final input = find.byKey(const Key('comment-input'));
    expect(tester.widget<TextField>(input).controller!.text, '@An ');
    await tester.enterText(input, '@An good call');
    await tester.pump();
    await tester.tap(find.byKey(const Key('comment-send')));
    await frames(tester);
    expect(
      api.calls,
      contains('add p1 "@An good call" parent=null mentions=u-An'),
    );
    await unmount(tester);
  });

  testWidgets('the feed has a Following tab', (tester) async {
    await open(tester, '/community');
    await tester.ensureVisible(
      find.byKey(const Key('community-tab-following')),
    );
    await tester.tap(find.byKey(const Key('community-tab-following')));
    await frames(tester);
    expect(api.calls.last, startsWith('feed FOLLOWING'));
    await unmount(tester);
  });

  for (final brightness in Brightness.values) {
    testWidgets('360 dp, ${brightness.name}: a member page fits', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(360 * 3, 760 * 3)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      api.members['u1'] = memberOf(
        'u1',
        name: 'A Rather Long Display Name Of A Member',
      );
      await open(tester, '/community/members/u1', brightness: brightness);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Reactions'));
      await frames(tester);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  }
}
