import 'package:cryptopilot_mobile/features/community/application/feed_controller.dart';
import 'package:cryptopilot_mobile/features/community/application/post_controller.dart';
import 'package:cryptopilot_mobile/features/community/data/community_api.dart';
import 'package:cryptopilot_mobile/features/community/domain/community.dart';
import 'package:cryptopilot_mobile/features/market/domain/market.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/community_fakes.dart';
import '../support/fakes.dart';

/// T-133: the feed and post view models.
void main() {
  late FakeCommunityApi api;
  late ProviderContainer container;

  setUp(() {
    api = FakeCommunityApi();
    container = ProviderContainer(
      overrides: [communityApiProvider.overrideWithValue(api)],
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
  });

  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  FeedState feed() => container.read(feedProvider);
  FeedController feeder() => container.read(feedProvider.notifier);

  group('feed', () {
    void start() => container.listen(feedProvider, (_, _) {});

    test(
      'Latest without a filter shows the pinned posts once, on top',
      () async {
        api.pinnedItems = [postOf('p1', official: true)];
        start();
        await settle();
        expect(
          api.calls,
          unorderedEquals([
            'feed LATEST coin=null market=null q=null p=1',
            'pinned',
          ]),
        );
        expect(feed().pinned.map((p) => p.id), ['p1']);
        expect(feed().items!.map((p) => p.id), ['p2']);
      },
    );

    test('a filter reads again from page 1 without the pinned posts; a '
        'search starts at 2 characters', () async {
      start();
      await settle();
      api.calls.clear();
      feeder().setFilter(
        feed().filter.copyWith(tab: FeedTab.mostLiked, coin: 'BTC'),
      );
      await settle();
      feeder().setFilter(feed().filter.copyWith(query: 'b'));
      await settle();
      feeder().setFilter(
        feed().filter.copyWith(query: 'btc', market: Market.futures),
      );
      await settle();
      expect(api.calls, [
        'feed MOST_LIKED coin=BTC market=null q=null p=1',
        'feed MOST_LIKED coin=BTC market=FUTURES q=btc p=1',
      ]);
      expect(feed().pinned, isEmpty);
    });

    test('pinned posts that fail leave the feed showing', () async {
      api.failNext['pinned'] = problem(503, 'UNAVAILABLE', 'MSG43');
      start();
      await settle();
      expect(feed().items, hasLength(2));
      expect(feed().failure, isNull);
    });

    test('load more joins the next page once', () async {
      api.feedItems = [for (var i = 0; i < 25; i++) postOf('p$i')];
      start();
      await settle();
      expect(feed().items, hasLength(20));
      expect(feed().hasMore, isTrue);
      await feeder().loadMore();
      expect(feed().items, hasLength(25));
      expect(feed().hasMore, isFalse);
    });

    test('a like shows at once and is put back when refused', () async {
      start();
      await settle();
      final post = feed().items!.first;
      final ok = await feeder().toggleLike(post);
      expect(ok, isNull);
      expect(feed().items!.first.likedByMe, isTrue);
      expect(feed().items!.first.likeCount, 13);

      api.failNext['save'] = problem(404, 'NOT_FOUND', 'MSG41');
      final refused = await feeder().toggleSave(feed().items!.first);
      expect(refused, isNotNull);
      expect(feed().items!.first.savedByMe, isFalse);
    });

    test('a failed first page is shown; a retry reads it again', () async {
      api.failNext['feed'] = problem(503, 'UNAVAILABLE', 'MSG43');
      start();
      await settle();
      expect(feed().failure, isNotNull);
      await feeder().load();
      expect(feed().items, hasLength(2));
    });
  });

  group('post', () {
    PostState post() => container.read(postProvider('p1'));
    PostController ctl() => container.read(postProvider('p1').notifier);

    void start() => container.listen(postProvider('p1'), (_, _) {});

    test('the post, then its threads with their replies', () async {
      start();
      await settle();
      expect(post().post!.id, 'p1');
      expect(post().comments!.map((c) => c.id), ['c1', 'c2']);
      expect(post().comments!.first.replies.single.id, 'r1');
    });

    test('hidden or deleted for the caller: missing (MSG41, BR-47)', () async {
      api.failNext['post'] = problem(404, 'POST_NOT_FOUND', 'MSG41');
      start();
      await settle();
      expect(post().missing, isTrue);
      expect(api.calls.where((c) => c.startsWith('comments')), isEmpty);
    });

    test('a reply joins its thread, a comment the end; the count follows '
        'in the feed too', () async {
      container.listen(feedProvider, (_, _) {});
      start();
      await settle();
      expect(await ctl().addComment('  Nice  ', parentId: 'c1'), isNull);
      expect(await ctl().addComment('Thanks'), isNull);
      expect(api.calls, contains('add p1 "Nice" parent=c1'));
      expect(post().comments!.first.replies.map((r) => r.content), [
        'Agree',
        'Nice',
      ]);
      expect(post().comments!.last.content, 'Thanks');
      expect(post().post!.commentCount, 6);
      expect(
        container
            .read(feedProvider)
            .items!
            .firstWhere((p) => p.id == 'p1')
            .commentCount,
        6,
      );
      // Nothing sent for an empty or too long text.
      api.calls.clear();
      await ctl().addComment('   ');
      await ctl().addComment('x' * 2001);
      expect(api.calls, isEmpty);
    });

    test('edit keeps the replies; delete reads the threads again', () async {
      start();
      await settle();
      final mine = post().comments!.last;
      await ctl().editComment(mine, 'Edited');
      expect(post().comments!.last.content, 'Edited');
      api.calls.clear();
      await ctl().deleteComment(mine);
      expect(api.calls, ['delete comment c2', 'comments p1 p=1 size=20']);
      expect(post().post!.commentCount, 3);
    });

    test(
      'a vote replaces the earlier one; the same again takes it back',
      () async {
        start();
        await settle();
        await ctl().vote(PostSentiment.bullish);
        expect(post().post!.myVote, PostSentiment.bullish);
        expect(post().post!.bullishCount, 9);
        await ctl().vote(PostSentiment.bullish);
        expect(api.calls.where((c) => c.startsWith('vote')), [
          'vote p1 BULLISH',
          'vote p1 null',
        ]);
        expect(post().post!.myVote, isNull);
      },
    );

    test('a comment like shows at once, even on a reply', () async {
      start();
      await settle();
      final reply = post().comments!.first.replies.single;
      await ctl().toggleCommentLike(reply);
      expect(post().comments!.first.replies.single.likedByMe, isTrue);
      expect(post().comments!.first.replies.single.likeCount, 3);
    });

    test('a report: submitted, already reported (BR-46), other refusals '
        'are thrown', () async {
      start();
      await settle();
      expect(
        await ctl().report(ReportReason.spam, description: '  '),
        ReportOutcome.submitted,
      );
      expect(api.calls.last, 'report post p1 SPAM null');
      api.failNext['report'] = problem(
        409,
        'COMMENT_ALREADY_REPORTED',
        'MSG34',
      );
      expect(
        await ctl().report(
          ReportReason.other,
          description: 'Scam link',
          comment: post().comments!.first,
        ),
        ReportOutcome.alreadyReported,
      );
      api.failNext['report'] = problem(409, 'POST_REPORT_OWN_POST', 'MSG43');
      await expectLater(ctl().report(ReportReason.spam), throwsA(anything));
    });

    test('deleting an own post takes it out of the feed', () async {
      container.listen(feedProvider, (_, _) {});
      start();
      await settle();
      expect(await ctl().deletePost(), isNull);
      expect(
        container.read(feedProvider).items!.map((p) => p.id),
        isNot(contains('p1')),
      );
    });
  });
}
