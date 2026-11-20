import 'package:cryptopilot_mobile/core/errors/api_failure.dart';
import 'package:cryptopilot_mobile/core/json/json_read.dart';
import 'package:cryptopilot_mobile/features/community/data/community_api.dart';
import 'package:cryptopilot_mobile/features/community/domain/community.dart';
import 'package:cryptopilot_mobile/features/market/domain/market.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/http_fakes.dart';

/// T-133: the community data (backend develop 03352518 payloads).
Map<String, Object?> summaryJson({
  String id = 'p1',
  Object? cover,
  Object? myVote,
  String status = 'PUBLISHED',
}) => {
  'id': id,
  'author': {'userId': 'u1', 'displayName': 'Minh Tran', 'avatarUrl': null},
  'authorStanding': {
    'influenceScore': 12.5,
    'followers': 3,
    'followedByMe': false,
  },
  'title': 'BTC holds 76k',
  'excerpt': 'Support held twice\nwatching 78k',
  'postType': 'TEXT',
  'marketType': 'SPOT',
  'official': false,
  'officialCategory': null,
  'status': status,
  'sentiment': 'BULLISH',
  'coins': ['BTC'],
  'cover': cover,
  'likeCount': 12,
  'commentCount': 4,
  'viewCount': 120,
  'bullishCount': 8,
  'bearishCount': 3,
  'myVote': myVote,
  'likedByMe': true,
  'savedByMe': false,
  'createdAt': '2026-11-20T01:00:00Z',
  'updatedAt': '2026-11-20T01:05:00Z',
};

Map<String, Object?> detailJson() {
  final json = summaryJson()
    ..remove('excerpt')
    ..remove('cover');
  return {
    ...json,
    'content': 'Support held twice.\nWatching 78k.',
    'media': [
      {
        'publicId': 'm1',
        'mediaType': 'IMAGE',
        'url': 'https://res.cloudinary.com/x/image/upload/m1.png',
        'thumbnailUrl': null,
        'width': 1200,
        'height': 800,
        'durationSeconds': null,
      },
    ],
    'mine': true,
  };
}

Map<String, Object?> commentJson(
  String id, {
  List<Object?> replies = const [],
}) => {
  'id': id,
  'postId': 'p1',
  'parentCommentId': replies.isEmpty && id.startsWith('r') ? 'c1' : null,
  'author': {'userId': 'u2', 'displayName': 'An', 'avatarUrl': null},
  'content': 'Agree',
  'deleted': false,
  'hidden': false,
  'likeCount': 2,
  'likedByMe': false,
  'mine': false,
  'createdAt': '2026-11-20T02:00:00Z',
  'updatedAt': '2026-11-20T02:00:00Z',
  'replies': replies,
};

void main() {
  group('decoders', () {
    test('a feed card: excerpt, cover, counts and my reactions', () {
      final post = decodePost(
        summaryJson(
          cover: {
            'publicId': 'm1',
            'mediaType': 'VIDEO',
            'url': 'https://res.cloudinary.com/x/video/upload/m1.mp4',
            'thumbnailUrl': 'https://res.cloudinary.com/x/video/upload/m1.jpg',
            'width': null,
            'height': null,
            'durationSeconds': 42,
          },
          myVote: 'BEARISH',
        ),
      );
      expect(post.text, 'Support held twice\nwatching 78k');
      expect(post.market, Market.spot);
      expect(post.sentiment, PostSentiment.bullish);
      expect(post.media.single.kind, MediaKind.video);
      expect(post.media.single.durationSeconds, 42);
      expect(post.myVote, PostSentiment.bearish);
      expect(post.likedByMe, isTrue);
      expect(post.mine, isFalse);
      expect(post.edited, isTrue);
    });

    test('the detail: the whole content, every medium and mine', () {
      final post = decodePost(detailJson());
      expect(post.text, 'Support held twice.\nWatching 78k.');
      expect(post.media.single.kind, MediaKind.image);
      expect(post.mine, isTrue);
    });

    test('comments: one level of replies, oldest first as sent', () {
      final page = decodeCommentPage({
        'items': [
          commentJson('c1', replies: [commentJson('r1')]),
          commentJson('c2'),
        ],
        'page': 1,
        'pageSize': 20,
        'total': 2,
      });
      expect(page.items.map((c) => c.id), ['c1', 'c2']);
      expect(page.items.first.replies.single.parentId, 'c1');
      expect(page.hasMore, isFalse);
    });

    test('a page knows when more follow', () {
      final page = decodePostPage({
        'items': [summaryJson()],
        'page': 1,
        'pageSize': 1,
        'total': 5,
      });
      expect(page.hasMore, isTrue);
    });

    test('engagement and vote answers', () {
      final like = decodeEngagement({'active': true, 'count': 13});
      expect((like.active, like.count), (true, 13));
      final vote = decodeVote({
        'myVote': null,
        'bullishCount': 7,
        'bearishCount': 3,
      });
      expect(vote.myVote, isNull);
      expect(vote.bullishCount, 7);
    });

    test('an unknown value or a missing count is refused', () {
      expect(
        () => decodePost(summaryJson(status: 'ARCHIVED')),
        throwsA(isA<DecodeException>()),
      );
      expect(
        () => decodePost({...summaryJson(), 'postType': 'POLL'}),
        throwsA(isA<DecodeException>()),
      );
      expect(
        () => decodePost(summaryJson()..remove('likeCount')),
        throwsA(isA<DecodeException>()),
      );
      expect(
        () => decodeVote({
          'myVote': 'NEUTRAL',
          'bullishCount': 1,
          'bearishCount': 0,
        }),
        throwsA(isA<DecodeException>()),
      );
    });
  });

  group('DioCommunityApi', () {
    late RecordingAdapter adapter;
    late CommunityApi api;

    setUp(() {
      adapter = RecordingAdapter();
      api = DioCommunityApi(dioOn(adapter));
    });

    Map<String, Object?> page(List<Object?> items) => {
      'items': items,
      'page': 1,
      'pageSize': 20,
      'total': items.length,
    };

    test('the feed sends its tab, filters and page; pinned asks 3', () async {
      adapter.answers
        ..add((200, page([summaryJson()])))
        ..add((200, page(const [])));
      await api.feed(
        tab: FeedTab.mostLiked,
        coin: 'BTC',
        market: Market.futures,
        query: 'support',
        page: 2,
      );
      await api.pinned();
      final feed = adapter.requests[0];
      expect(feed.path, 'posts');
      expect(feed.queryParameters, {
        'tab': 'MOST_LIKED',
        'coin': 'BTC',
        'market': 'FUTURES',
        'q': 'support',
        'page': 2,
        'pageSize': 20,
      });
      expect(adapter.requests[1].path, 'posts/pinned');
      expect(adapter.requests[1].queryParameters['pageSize'], 3);
    });

    test('comments: a reply names its parent, edit and delete', () async {
      adapter.answers
        ..add((200, commentJson('r9')))
        ..add((200, commentJson('c1')))
        ..add((204, null))
        ..add((204, null));
      await api.addComment('p1', 'Agree', parentId: 'c1');
      await api.editComment('c1', 'Edited');
      await api.deleteComment('c1');
      await api.deletePost('p1');
      final [add, edit, delete, deletePost] = adapter.requests;
      expect((add.method, add.path), ('POST', 'posts/p1/comments'));
      expect(add.data, {'content': 'Agree', 'parentCommentId': 'c1'});
      expect((edit.method, edit.path), ('PUT', 'comments/c1'));
      expect((delete.method, delete.path), ('DELETE', 'comments/c1'));
      expect((deletePost.method, deletePost.path), ('DELETE', 'posts/p1'));
    });

    test(
      'like, save and vote go on with POST/PUT and off with DELETE',
      () async {
        final engaged = {'active': true, 'count': 1};
        final voted = {
          'myVote': 'BULLISH',
          'bullishCount': 1,
          'bearishCount': 0,
        };
        adapter.answers
          ..add((200, engaged))
          ..add((200, engaged))
          ..add((200, engaged))
          ..add((200, engaged))
          ..add((200, voted))
          ..add((200, voted));
        await api.likePost('p1', like: true);
        await api.likePost('p1', like: false);
        await api.savePost('p1', save: true);
        await api.likeComment('c1', like: true);
        await api.vote('p1', PostSentiment.bullish);
        await api.vote('p1', null);
        expect(
          [for (final r in adapter.requests) '${r.method} ${r.path}'],
          [
            'POST posts/p1/like',
            'DELETE posts/p1/like',
            'POST posts/p1/save',
            'POST comments/c1/like',
            'PUT posts/p1/vote',
            'DELETE posts/p1/vote',
          ],
        );
        expect(adapter.requests[4].data, {'sentiment': 'BULLISH'});
      },
    );

    test('a report sends its reason, the description only when given; a '
        'repeated one keeps its code', () async {
      adapter.answers
        ..add((201, {'id': 'rp1'}))
        ..add((
          409,
          {
            'status': 409,
            'code': 'COMMENT_ALREADY_REPORTED',
            'messageCode': 'MSG34',
          },
        ));
      await api.reportPost('p1', ReportReason.spam);
      expect(adapter.requests[0].path, 'posts/p1/reports');
      expect(adapter.requests[0].data, {'reason': 'SPAM'});
      await expectLater(
        api.reportComment('c1', ReportReason.other, description: 'Scam link'),
        throwsA(
          isA<ProblemFailure>().having(
            (f) => f.code,
            'code',
            'COMMENT_ALREADY_REPORTED',
          ),
        ),
      );
      expect(adapter.requests[1].data, {
        'reason': 'OTHER',
        'description': 'Scam link',
      });
    });
  });
}
