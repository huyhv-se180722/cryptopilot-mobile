import 'package:cryptopilot_mobile/features/community/application/member_controllers.dart';
import 'package:cryptopilot_mobile/features/community/application/post_controller.dart';
import 'package:cryptopilot_mobile/features/community/data/community_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/community_fakes.dart';
import '../support/fakes.dart';

/// T-136: member pages, follows, blocks, lists and mentions (A-66).
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
    for (var i = 0; i < 8; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  MemberState member() => container.read(memberProvider('u1'));
  MemberController ctl() => container.read(memberProvider('u1').notifier);

  test('the page head, then the coins they post about', () async {
    container.listen(memberProvider('u1'), (_, _) {});
    await settle();
    expect(member().profile!.author.displayName, 'Minh Tran');
    expect(member().coins.single.symbol, 'BTC');
  });

  test('a member gone or blocking the caller is missing (MSG41)', () async {
    api.failNext['member'] = problem(404, 'MEMBER_NOT_FOUND', 'MSG41');
    container.listen(memberProvider('u1'), (_, _) {});
    await settle();
    expect(member().missing, isTrue);
  });

  test('follow shows at once and is put back when refused', () async {
    container.listen(memberProvider('u1'), (_, _) {});
    await settle();
    expect(await ctl().toggleFollow(), isNull);
    expect(member().profile!.followedByMe, isTrue);
    expect(member().profile!.followers, 13);

    api.failNext['follow'] = problem(503, 'UNAVAILABLE', 'MSG43');
    expect(await ctl().toggleFollow(), isNotNull);
    expect(member().profile!.followedByMe, isTrue);
  });

  test('your own page has no follow or block', () async {
    api.members['u1'] = memberOf('u1', me: true);
    container.listen(memberProvider('u1'), (_, _) {});
    await settle();
    await ctl().toggleFollow();
    await ctl().toggleBlock();
    expect(api.calls.where((c) => c.startsWith('follow')), isEmpty);
    expect(api.calls.where((c) => c.startsWith('block')), isEmpty);
  });

  test('blocking stops following', () async {
    api.members['u1'] = memberOf('u1', following: true);
    container.listen(memberProvider('u1'), (_, _) {});
    await settle();
    await ctl().toggleBlock();
    expect(member().profile!.blockedByMe, isTrue);
    expect(member().profile!.followedByMe, isFalse);
  });

  test('the lists: posts are the feed by author, then comments, '
      'followers and the caller\'s blocks', () async {
    for (final list in MemberList.values) {
      container.listen(
        memberListProvider((memberId: 'u1', list: list)),
        (_, _) {},
      );
    }
    await settle();
    expect(
      api.calls,
      containsAll([
        'feed LATEST coin=null market=null q=null p=1 author=u1',
        'member comments u1 p=1',
        'member reactions u1 p=1',
        'followers u1',
        'following u1',
        'blocked',
      ]),
    );
    final blocked = container.read(
      memberListProvider((memberId: 'u1', list: MemberList.blocked)),
    );
    expect(blocked.items, hasLength(2));
    container
        .read(
          memberListProvider((
            memberId: 'u1',
            list: MemberList.blocked,
          )).notifier,
        )
        .removeAuthor('u-An');
    expect(
      container
          .read(memberListProvider((memberId: 'u1', list: MemberList.blocked)))
          .items,
      hasLength(1),
    );
  });

  test('a mention search asks only for 1 to 50 characters', () async {
    expect(await container.read(mentionSearchProvider('  ').future), isEmpty);
    final found = await container.read(mentionSearchProvider('an').future);
    expect(found.map((a) => a.displayName), ['An']);
    expect(api.calls, ['search members an']);
  });

  test('a comment sends the members it mentions, at most 10', () async {
    container.listen(postProvider('p1'), (_, _) {});
    await settle();
    await container
        .read(postProvider('p1').notifier)
        .addComment('Hi @An', mentions: [for (var i = 0; i < 12; i++) 'u$i']);
    expect(
      api.calls.last,
      'add p1 "Hi @An" parent=null mentions=u0,u1,u2,u3,u4,u5,u6,u7,u8,u9',
    );
  });

  test('an administrator is neither followed nor blocked: no error, the '
      'buttons go (Q-98)', () async {
    container.listen(memberProvider('u1'), (_, _) {});
    await settle();
    api.failNext['follow'] = problem(409, 'RELATION_NOT_ALLOWED', 'MSG43');
    expect(await ctl().toggleFollow(), isNull);
    expect(member().profile!.followedByMe, isFalse);
    expect(member().profile!.followers, 12);
    expect(member().relationsAllowed, isFalse);
    await ctl().load();
    expect(member().relationsAllowed, isFalse);
  });
}
