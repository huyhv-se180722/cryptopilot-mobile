import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/state/load_after_build.dart';
import '../data/community_api.dart';
import '../domain/community.dart';
import 'feed_controller.dart';

@immutable
class MemberState {
  const MemberState({
    this.profile,
    this.failure,
    this.coins = const [],
    this.relationsAllowed = true,
  });

  /// Null until it arrives.
  final MemberProfile? profile;
  final ApiFailure? failure;

  /// The coins they post about most.
  final List<TokenMention> coins;

  /// False once the server said this member is neither followed nor
  /// blocked (an administrator, `RELATION_NOT_ALLOWED`; Q-98).
  final bool relationsAllowed;

  MemberState copyWith({MemberProfile? profile, bool? relationsAllowed}) =>
      MemberState(
        profile: profile ?? this.profile,
        failure: failure,
        coins: coins,
        relationsAllowed: relationsAllowed ?? this.relationsAllowed,
      );

  /// No such member, banned, or blocking the caller (404 MSG41).
  bool get missing =>
      profile == null &&
      switch (failure) {
        ProblemFailure(:final problem) => problem.messageCode == 'MSG41',
        _ => false,
      };
}

final memberProvider = NotifierProvider.autoDispose
    .family<MemberController, MemberState, String>(MemberController.new);

/// A member page (A-66, D-99): its head, the coins they post about, and
/// follow and block, applied at once and put back when refused.
class MemberController extends Notifier<MemberState> {
  MemberController(this.id);

  final String id;
  int _generation = 0;

  @override
  MemberState build() {
    ref.loadAfterBuild(load);
    return const MemberState();
  }

  CommunityApi get _api => ref.read(communityApiProvider);

  Future<void> load() async {
    final generation = ++_generation;
    try {
      final profile = await _api.member(id);
      if (!ref.mounted || generation != _generation) return;
      state = state.copyWith(profile: profile);
    } on ApiFailure catch (failure) {
      if (!ref.mounted || generation != _generation) return;
      state = MemberState(failure: failure);
      return;
    }
    try {
      final coins = await _api.tokenMentions(id);
      if (!ref.mounted || generation != _generation) return;
      state = MemberState(
        profile: state.profile,
        coins: coins,
        relationsAllowed: state.relationsAllowed,
      );
    } on ApiFailure {
      // The coins are extra: the page shows without them.
    }
  }

  Future<ApiFailure?> toggleFollow() async {
    final profile = state.profile;
    if (profile == null || profile.me) return null;
    final on = !profile.followedByMe;
    state = state.copyWith(
      profile: profile.copyWith(
        followedByMe: on,
        followers: profile.followers + (on ? 1 : -1),
      ),
    );
    try {
      final e = await _api.follow(id, on: on);
      if (ref.mounted) {
        state = state.copyWith(
          profile: state.profile!.copyWith(
            followedByMe: e.active,
            followers: e.count,
          ),
        );
      }
      return null;
    } on ApiFailure catch (failure) {
      if (!ref.mounted) return failure;
      if (_notAllowed(failure)) {
        state = state.copyWith(profile: profile, relationsAllowed: false);
        return null;
      }
      state = state.copyWith(profile: profile);
      return failure;
    }
  }

  /// Administrators are neither followed nor blocked (D-99).
  static bool _notAllowed(ApiFailure failure) =>
      failure is ProblemFailure && failure.code == 'RELATION_NOT_ALLOWED';

  /// Blocking hides their posts and comments: the feed reads again.
  Future<ApiFailure?> toggleBlock() async {
    final profile = state.profile;
    if (profile == null || profile.me) return null;
    final on = !profile.blockedByMe;
    try {
      final e = await _api.block(id, on: on);
      if (!ref.mounted) return null;
      state = state.copyWith(
        profile: profile.copyWith(
          blockedByMe: e.active,
          followedByMe: e.active ? false : profile.followedByMe,
        ),
      );
      if (ref.exists(feedProvider)) {
        unawaited(ref.read(feedProvider.notifier).load());
      }
      return null;
    } on ApiFailure catch (failure) {
      if (_notAllowed(failure) && ref.mounted) {
        state = state.copyWith(relationsAllowed: false);
        return null;
      }
      return failure;
    }
  }
}

/// The lists of a member page and of the people screens.
enum MemberList { posts, comments, reactions, followers, following, blocked }

typedef MemberListKey = ({String memberId, MemberList list});

@immutable
class PagedState<T> {
  const PagedState({this.items, this.more = false, this.failure});

  /// Null until the first page arrives.
  final List<T>? items;
  final bool more;
  final ApiFailure? failure;
}

final memberListProvider = NotifierProvider.autoDispose
    .family<MemberListController, PagedState<Object>, MemberListKey>(
      MemberListController.new,
    );

/// One list of a member, 20 a page: their posts (the feed by author),
/// comments, reactions, followers and following; [MemberList.blocked] is
/// the caller's own blocks whatever the member.
class MemberListController extends Notifier<PagedState<Object>> {
  MemberListController(this.key);

  static const pageSize = 20;

  final MemberListKey key;
  int _generation = 0;
  int _page = 0;
  bool _loading = false;

  @override
  PagedState<Object> build() {
    ref.loadAfterBuild(load);
    return const PagedState();
  }

  Future<CommunityPage<Object>> _fetch(int page) async {
    final api = ref.read(communityApiProvider);
    final id = key.memberId;
    return switch (key.list) {
      MemberList.posts => await api.feed(
        author: id,
        page: page,
        pageSize: pageSize,
      ),
      MemberList.comments => await api.memberComments(
        id,
        page: page,
        pageSize: pageSize,
      ),
      MemberList.reactions => await api.memberReactions(
        id,
        page: page,
        pageSize: pageSize,
      ),
      MemberList.followers => await api.followers(
        id,
        page: page,
        pageSize: pageSize,
      ),
      MemberList.following => await api.followingOf(
        id,
        page: page,
        pageSize: pageSize,
      ),
      MemberList.blocked => await api.blocked(page: page, pageSize: pageSize),
    };
  }

  Future<void> load() async {
    final generation = ++_generation;
    try {
      final page = await _fetch(1);
      if (!ref.mounted || generation != _generation) return;
      _page = 1;
      state = PagedState(items: page.items, more: page.hasMore);
    } on ApiFailure catch (failure) {
      if (!ref.mounted || generation != _generation) return;
      state = PagedState(items: state.items, failure: failure);
    }
  }

  Future<void> loadMore() async {
    if (!state.more || _loading || state.items == null) return;
    _loading = true;
    final generation = _generation;
    try {
      final page = await _fetch(_page + 1);
      if (!ref.mounted || generation != _generation) return;
      _page += 1;
      state = PagedState(
        items: [...state.items!, ...page.items],
        more: page.hasMore,
      );
    } on ApiFailure {
      // The next scroll asks again.
    } finally {
      _loading = false;
    }
  }

  /// Unblocks [userId] from the blocked list, which they leave; the feed
  /// reads again with their posts.
  Future<ApiFailure?> unblock(String userId) async {
    try {
      await ref.read(communityApiProvider).block(userId, on: false);
      if (!ref.mounted) return null;
      removeAuthor(userId);
      if (ref.exists(feedProvider)) {
        unawaited(ref.read(feedProvider.notifier).load());
      }
      return null;
    } on ApiFailure catch (failure) {
      return failure;
    }
  }

  /// A member unblocked from the blocked list leaves it.
  void removeAuthor(String userId) {
    final items = state.items;
    if (items == null) return;
    state = PagedState(
      items: [
        for (final i in items)
          if (i is! Author || i.userId != userId) i,
      ],
      more: state.more,
    );
  }
}

/// Members whose name holds [query] (1 to 50 characters) for a mention.
final mentionSearchProvider = FutureProvider.autoDispose
    .family<List<Author>, String>((ref, query) {
      final q = query.trim();
      if (q.isEmpty || q.length > 50) return const [];
      return ref.read(communityApiProvider).searchMembers(q);
    });
