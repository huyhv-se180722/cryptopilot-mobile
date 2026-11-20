import 'package:cryptopilot_mobile/core/json/json_read.dart';
import 'package:cryptopilot_mobile/features/community/data/community_api.dart';
import 'package:cryptopilot_mobile/features/community/domain/community.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/http_fakes.dart';
import 'community_test.dart' show commentJson;

/// T-136 (A-66, D-99): member pages, follows, blocks and mentions.
Map<String, Object?> memberJson() => {
  'userId': 'u1',
  'displayName': 'Minh Tran',
  'avatarUrl': null,
  'joinedAt': '2026-10-01T00:00:00Z',
  'posts': 8,
  'likesReceived': 40,
  'followers': 12,
  'following': 3,
  'followedByMe': false,
  'blockedByMe': false,
  'me': false,
  'bio': 'Swing trader',
  'websiteUrl': 'https://example.com',
  'bannerUrl': null,
  'influenceScore': 72.5,
  'depthScore': 64,
};

Map<String, Object?> page(List<Object?> items) => {
  'items': items,
  'page': 1,
  'pageSize': 20,
  'total': items.length,
};

void main() {
  group('decoders', () {
    test('a member page head; the scores may come as whole numbers', () {
      final m = decodeMemberProfile(memberJson());
      expect(m.author.displayName, 'Minh Tran');
      expect(m.followers, 12);
      expect(m.influenceScore, 72.5);
      expect(m.depthScore, 64.0);
      expect(m.websiteUrl, 'https://example.com');
      expect(
        () => decodeMemberProfile({...memberJson(), 'followers': '12'}),
        throwsA(isA<DecodeException>()),
      );
    });

    test('a member comment with its post, a coin they post about', () {
      final c = decodeMemberComment({
        'commentId': 'c1',
        'postId': 'p1',
        'reply': true,
        'content': 'Agree',
        'likes': 2,
        'createdAt': '2026-11-20T01:00:00Z',
        'postTitle': 'BTC holds',
        'postExcerpt': null,
      });
      expect((c.postId, c.reply, c.postTitle), ('p1', true, 'BTC holds'));
      final t = decodeTokenMention({
        'symbol': 'BTC',
        'name': 'Bitcoin',
        'posts': 6,
        'sharePercent': 60,
        'bullishPosts': 4,
        'bearishPosts': 1,
        'lastPostAt': '2026-11-20T01:00:00Z',
      });
      expect((t.symbol, t.sharePercent), ('BTC', 60.0));
    });
  });

  group('DioCommunityApi', () {
    late RecordingAdapter adapter;
    late CommunityApi api;

    setUp(() {
      adapter = RecordingAdapter();
      api = DioCommunityApi(dioOn(adapter));
    });

    test('member page, follow, block and their lists', () async {
      final engaged = {'active': true, 'count': 13};
      adapter.answers
        ..add((200, memberJson()))
        ..add((200, engaged))
        ..add((200, engaged))
        ..add((200, engaged))
        ..add((200, <Object?>[]))
        ..add((200, page(const [])))
        ..add((200, page(const [])))
        ..add((200, page(const [])))
        ..add((200, page(const [])))
        ..add((200, page(const [])))
        ..add((200, <Object?>[]));
      await api.member('u1');
      await api.follow('u1', on: true);
      await api.follow('u1', on: false);
      await api.block('u1', on: true);
      await api.tokenMentions('u1', limit: 5);
      await api.memberComments('u1', page: 2);
      await api.memberReactions('u1');
      await api.followers('u1');
      await api.followingOf('u1');
      await api.blocked();
      await api.searchMembers('an');
      expect(
        [for (final r in adapter.requests) '${r.method} ${r.path}'],
        [
          'GET community/members/u1',
          'POST community/members/u1/follow',
          'DELETE community/members/u1/follow',
          'POST community/members/u1/block',
          'GET community/members/u1/token-mentions',
          'GET community/members/u1/comments',
          'GET community/members/u1/reactions',
          'GET community/members/u1/followers',
          'GET community/members/u1/following',
          'GET community/blocks',
          'GET community/members',
        ],
      );
      expect(adapter.requests[4].queryParameters['limit'], 5);
      expect(adapter.requests[5].queryParameters['page'], 2);
      expect(adapter.requests.last.queryParameters['q'], 'an');
    });

    test('a member\'s posts are the feed with their id; a comment names '
        'its mentions only when it has some', () async {
      adapter.answers
        ..add((200, page(const [])))
        ..add((200, commentJson('c9')))
        ..add((200, commentJson('c10')));
      await api.feed(author: 'u1');
      await api.addComment('p1', 'Hi @An', mentions: ['u-An']);
      await api.addComment('p1', 'Plain');
      expect(adapter.requests[0].queryParameters['author'], 'u1');
      expect(adapter.requests[1].data, {
        'content': 'Hi @An',
        'mentions': ['u-An'],
      });
      expect(adapter.requests[2].data, {'content': 'Plain'});
    });
  });
}
