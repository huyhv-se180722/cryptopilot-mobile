import 'dart:async';

import 'package:cryptopilot_mobile/app.dart';
import 'package:cryptopilot_mobile/core/auth/token_store.dart';
import 'package:cryptopilot_mobile/core/router/app_router.dart';
import 'package:cryptopilot_mobile/core/settings/settings.dart';
import 'package:cryptopilot_mobile/features/community/domain/community.dart';
import 'package:cryptopilot_mobile/features/community/presentation/community_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/community_fakes.dart';
import '../support/fakes.dart';
import '../support/realtime_fakes.dart';

/// T-133: SCR-24, SCR-25 and SCR-27 (A-64).
void main() {
  late FakeCommunityApi api;
  late FakeWebLinks web;
  late FakeTransport transport;

  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(CryptoPilotApp)));

  Future<void> open(
    WidgetTester tester,
    String location, {
    Brightness brightness = Brightness.light,
    // Runs once Home has read its blocks, before [location] opens.
    void Function()? beforePush,
  }) async {
    transport = FakeTransport();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...baseOverrides(
            store: MemoryTokenStore(storedFor('saved')),
            tokens: FakeAuthTokenApi(),
            transport: transport,
            web: web,
            settings: MemorySettingsStore(),
            clock: () => communityNow,
            community: api,
          ),
        ],
        retry: (_, _) => null,
        child: const CryptoPilotApp(),
      ),
    );
    await frames(tester);
    transport.last.onConnected();
    final container = containerOf(tester);
    if (brightness == Brightness.dark) {
      unawaited(
        container.read(themeModeProvider.notifier).select(ThemeMode.dark),
      );
    }
    beforePush?.call();
    unawaited(container.read(appRouterProvider).push(location));
    await frames(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 31));
  }

  Future<void> menu(WidgetTester tester, String menuKey, String item) async {
    await tester.tap(find.byKey(Key(menuKey)));
    await frames(tester);
    await tester.tap(find.byKey(Key(item)));
    await frames(tester);
  }

  setUp(() {
    api = FakeCommunityApi();
    web = FakeWebLinks();
  });

  group('SCR-24 feed', () {
    testWidgets('pinned official posts on top, then the feed; a like shows '
        'at once', (tester) async {
      api.pinnedItems = [
        postOf('o1', title: 'Platform update', official: true, author: 'Team'),
      ];
      await open(tester, '/community');
      expect(find.text('Pinned'), findsOneWidget);
      expect(find.text('Official'), findsOneWidget);
      expect(find.text('Platform update'), findsOneWidget);
      expect(find.text('BTC holds 76k'), findsOneWidget);
      expect(find.text('2h ago'), findsWidgets);
      expect(find.text('#BTC  Spot'), findsWidgets);

      await tester.tap(find.byKey(const Key('like-p1')));
      await frames(tester);
      expect(api.calls, contains('like p1 true'));
      expect(
        find.descendant(
          of: find.byKey(const Key('like-p1')),
          matching: find.text('13'),
        ),
        findsOneWidget,
      );
      await unmount(tester);
    });

    testWidgets('tabs, a coin from the pair list, a market and a search '
        'read the feed again', (tester) async {
      await open(tester, '/community');
      api.feedItems = [];
      await tester.tap(find.byKey(const Key('community-tab-saved')));
      await frames(tester);
      expect(api.calls.last, startsWith('feed SAVED'));
      expect(find.text('Posts you save appear here.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('community-coin')));
      await frames(tester);
      await tester.tap(find.byKey(const Key('community-coin-ETH')));
      await frames(tester);
      await tester.tap(find.byKey(const Key('community-market-FUTURES')));
      await frames(tester);
      expect(api.calls.last, 'feed SAVED coin=ETH market=FUTURES q=null p=1');
      expect(find.text('No posts match these filters.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('community-search-toggle')));
      await frames(tester);
      await tester.enterText(find.byKey(const Key('community-search')), 'e');
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        find.text('Type at least 2 characters to search.'),
        findsOneWidget,
      );
      expect(api.calls.last, isNot(contains('q=e')));
      await tester.enterText(find.byKey(const Key('community-search')), 'eth');
      await tester.pump(const Duration(milliseconds: 500));
      await frames(tester);
      expect(api.calls.last, 'feed SAVED coin=ETH market=FUTURES q=eth p=1');
      await unmount(tester);
    });

    testWidgets('writing a post opens the web (SCR-26, phase 2)', (
      tester,
    ) async {
      await open(tester, '/community');
      await tester.tap(find.byKey(const Key('community-new-post')));
      await tester.pump();
      expect(web.opened, ['/community/new']);
      await unmount(tester);
    });

    testWidgets('a failed feed offers Try again', (tester) async {
      await open(
        tester,
        '/community',
        beforePush: () =>
            api.failNext['feed'] = problem(503, 'UNAVAILABLE', 'MSG43'),
      );
      expect(find.text('Try again'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await frames(tester);
      expect(find.text('BTC holds 76k'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('SCR-25 post', () {
    testWidgets('a card opens the post: content, threads with replies '
        'indented, a deleted comment with replies kept', (tester) async {
      api.commentItems = [
        commentOf(
          'c1',
          deleted: true,
          replies: [commentOf('r1', author: 'Bao', parentId: 'c1')],
        ),
        commentOf('c2', author: 'Chi', mine: true),
      ];
      await open(tester, '/community');
      await tester.tap(find.byKey(const Key('post-p1')));
      await frames(tester);
      expect(find.byKey(const Key('post-content')), findsOneWidget);
      expect(find.text('Comments (4)'), findsOneWidget);
      expect(find.text('Comment deleted'), findsOneWidget);
      Offset avatarOf(String id) => tester.getTopLeft(
        find.descendant(
          of: find.byKey(Key('comment-$id')),
          matching: find.byType(MemberAvatar),
        ),
      );
      final reply = avatarOf('r1');
      final thread = avatarOf('c2');
      expect(reply.dx, greaterThan(thread.dx));
      // A reply has no Reply of its own (one level).
      expect(find.byKey(const Key('comment-reply-r1')), findsNothing);
      await unmount(tester);
    });

    testWidgets('comment, reply, edit and delete', (tester) async {
      await open(tester, '/community/p1');
      await tester.enterText(find.byKey(const Key('comment-input')), 'Nice');
      await tester.pump();
      await tester.tap(find.byKey(const Key('comment-send')));
      await frames(tester);
      expect(api.calls, contains('add p1 "Nice" parent=null'));

      await tester.ensureVisible(find.byKey(const Key('comment-reply-c1')));
      await tester.tap(find.byKey(const Key('comment-reply-c1')));
      await frames(tester);
      expect(find.text('Replying to An'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('comment-input')), 'Same');
      await tester.pump();
      await tester.tap(find.byKey(const Key('comment-send')));
      await frames(tester);
      expect(api.calls, contains('add p1 "Same" parent=c1'));
      expect(find.byKey(const Key('replying-to')), findsNothing);

      await tester.ensureVisible(find.byKey(const Key('comment-menu-c2')));
      await menu(tester, 'comment-menu-c2', 'comment-edit-c2');
      await tester.enterText(
        find.byKey(const Key('comment-edit-field')),
        'Edited',
      );
      await tester.tap(find.byKey(const Key('comment-edit-save')));
      await frames(tester);
      expect(api.calls, contains('edit c2 "Edited"'));

      await tester.ensureVisible(find.byKey(const Key('comment-menu-c2')));
      await menu(tester, 'comment-menu-c2', 'comment-delete-c2');
      expect(
        find.text(
          'If it has replies, it stays in the thread as "Comment deleted".',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('confirm-delete')));
      await frames(tester);
      expect(api.calls, contains('delete comment c2'));
      await unmount(tester);
    });

    testWidgets('Bullish then Bearish replaces the vote', (tester) async {
      await open(tester, '/community/p1');
      await tester.tap(find.byKey(const Key('vote-bullish')));
      await frames(tester);
      expect(find.text('Bullish 9'), findsOneWidget);
      await tester.tap(find.byKey(const Key('vote-bearish')));
      await frames(tester);
      expect(api.calls.where((c) => c.startsWith('vote')), [
        'vote p1 BULLISH',
        'vote p1 BEARISH',
      ]);
      expect(find.text('Bearish 4'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('a video opens in the browser', (tester) async {
      api.posts['v1'] = postOf(
        'v1',
        media: const [
          PostMedia(
            publicId: 'm1',
            kind: MediaKind.video,
            url: 'https://res.cloudinary.com/x/video/upload/m1.mp4',
          ),
        ],
      );
      await open(tester, '/community/v1');
      await tester.tap(find.byKey(const Key('medium-m1')));
      await tester.pump();
      expect(web.opened, ['https://res.cloudinary.com/x/video/upload/m1.mp4']);
      await unmount(tester);
    });

    testWidgets('a hidden or deleted post shows MSG41 (BR-47)', (tester) async {
      api.failNext['post'] = problem(404, 'POST_NOT_FOUND', 'MSG41');
      await open(tester, '/community/gone');
      expect(find.byKey(const Key('post-missing')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('an own post: no Report; Edit opens the web, Delete leaves '
        'the post', (tester) async {
      api.posts['p1'] = postOf('p1', mine: true);
      await open(tester, '/community');
      await tester.tap(find.byKey(const Key('post-p1')));
      await frames(tester);
      await tester.tap(find.byKey(const Key('post-menu')));
      await frames(tester);
      expect(find.byKey(const Key('post-report')), findsNothing);
      await tester.tap(find.byKey(const Key('post-edit-web')));
      await frames(tester);
      expect(web.opened, ['/community/p1/edit']);

      await menu(tester, 'post-menu', 'post-delete');
      await tester.tap(find.byKey(const Key('confirm-delete')));
      await frames(tester);
      expect(api.calls, contains('delete post p1'));
      expect(find.text('Post deleted.'), findsOneWidget);
      expect(find.byKey(const Key('post-p1')), findsNothing);
      await unmount(tester);
    });
  });

  group('SCR-27 report', () {
    testWidgets('OTHER needs details; a report ends with MSG34', (
      tester,
    ) async {
      await open(tester, '/community/p1');
      await menu(tester, 'post-menu', 'post-report');
      expect(find.text('Report post'), findsOneWidget);
      await tester.tap(find.byKey(const Key('report-OTHER')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('report-submit')));
      await frames(tester);
      expect(
        find.text('Describe the problem when you choose Other.'),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const Key('report-details')),
        'Fake giveaway',
      );
      await tester.tap(find.byKey(const Key('report-submit')));
      await frames(tester);
      expect(api.calls.last, 'report post p1 OTHER Fake giveaway');
      expect(
        find.text('Thank you, your report has been submitted.'),
        findsOneWidget,
      );
      await unmount(tester);
    });

    testWidgets('a comment reported twice is told so (BR-46)', (tester) async {
      api.failNext['report'] = problem(
        409,
        'COMMENT_ALREADY_REPORTED',
        'MSG34',
      );
      await open(tester, '/community/p1');
      await tester.ensureVisible(find.byKey(const Key('comment-menu-c1')));
      await menu(tester, 'comment-menu-c1', 'comment-report-c1');
      expect(find.text('Report comment'), findsOneWidget);
      await tester.tap(find.byKey(const Key('report-SPAM')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('report-submit')));
      await frames(tester);
      expect(
        find.text('You have already reported this comment.'),
        findsOneWidget,
      );
      await unmount(tester);
    });
  });

  for (final brightness in Brightness.values) {
    testWidgets('360 dp, ${brightness.name}: feed, post and report fit', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(360 * 3, 760 * 3)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      api.pinnedItems = [
        postOf(
          'o1',
          title: 'A long official announcement title that wraps on a phone',
          official: true,
          author: 'CryptoPilot Team (Official)',
        ),
      ];
      await open(tester, '/community', brightness: brightness);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('post-p1')));
      await frames(tester);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byKey(const Key('comment-reply-c1')));
      await tester.tap(find.byKey(const Key('comment-reply-c1')));
      await frames(tester);
      expect(tester.takeException(), isNull);
      await menu(tester, 'post-menu', 'post-report');
      expect(find.byKey(const Key('report-sheet')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  }
}
