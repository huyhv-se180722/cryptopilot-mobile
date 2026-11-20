import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/state/load_after_build.dart';
import '../../market/domain/market.dart';
import '../data/community_api.dart';
import '../domain/community.dart';

/// What the feed shows (SCR-24): a tab, a coin, a market and a search of
/// 2 to 100 characters (shorter is no search).
@immutable
class FeedFilter {
  const FeedFilter({
    this.tab = FeedTab.latest,
    this.coin,
    this.market,
    this.query = '',
  });

  final FeedTab tab;
  final String? coin;
  final Market? market;
  final String query;

  /// The search the backend takes, or null.
  String? get search {
    final q = query.trim();
    return q.length < 2 ? null : (q.length > 100 ? q.substring(0, 100) : q);
  }

  bool get filtered => coin != null || market != null || search != null;

  FeedFilter copyWith({
    FeedTab? tab,
    String? coin,
    bool clearCoin = false,
    Market? market,
    bool clearMarket = false,
    String? query,
  }) => FeedFilter(
    tab: tab ?? this.tab,
    coin: clearCoin ? null : coin ?? this.coin,
    market: clearMarket ? null : market ?? this.market,
    query: query ?? this.query,
  );

  @override
  bool operator ==(Object other) =>
      other is FeedFilter &&
      other.tab == tab &&
      other.coin == coin &&
      other.market == market &&
      other.search == search;

  @override
  int get hashCode => Object.hash(tab, coin, market, search);
}

@immutable
class FeedState {
  const FeedState({
    this.filter = const FeedFilter(),
    this.items,
    this.more = false,
    this.pinned = const [],
    this.failure,
    this.loadingMore = false,
  });

  final FeedFilter filter;

  /// Null until the first page arrives.
  final List<Post>? items;

  /// The server has a next page.
  final bool more;

  /// Official posts on top of Latest without a filter (BR-61).
  final List<Post> pinned;
  final ApiFailure? failure;
  final bool loadingMore;

  bool get hasMore => items != null && more;

  FeedState copyWith({
    List<Post>? items,
    bool? more,
    List<Post>? pinned,
    ApiFailure? failure,
    bool clearFailure = false,
    bool? loadingMore,
  }) => FeedState(
    filter: filter,
    items: items ?? this.items,
    more: more ?? this.more,
    pinned: pinned ?? this.pinned,
    failure: clearFailure ? null : failure ?? this.failure,
    loadingMore: loadingMore ?? this.loadingMore,
  );
}

final feedProvider = NotifierProvider.autoDispose<FeedController, FeedState>(
  FeedController.new,
);

/// The community feed: 20 posts a page, likes and saves applied at once
/// and put back when the server refuses.
class FeedController extends Notifier<FeedState> {
  static const pageSize = 20;

  int _generation = 0;
  int _page = 0;

  @override
  FeedState build() {
    ref.loadAfterBuild(load);
    return const FeedState();
  }

  CommunityApi get _api => ref.read(communityApiProvider);

  /// A new filter reads the feed again from its first page.
  void setFilter(FeedFilter filter) {
    if (filter == state.filter) {
      // Only the typed text changed below the search threshold.
      state = FeedState(
        filter: filter,
        items: state.items,
        more: state.more,
        pinned: state.pinned,
        failure: state.failure,
        loadingMore: state.loadingMore,
      );
      return;
    }
    state = FeedState(filter: filter, pinned: state.pinned);
    unawaited(load());
  }

  Future<void> load() async {
    final generation = ++_generation;
    final filter = state.filter;
    final withPinned = filter.tab == FeedTab.latest && !filter.filtered;
    // The pinned posts are extra: the feed still shows when they fail.
    final pinned = withPinned
        ? _api.pinned().then(
            (p) => p.items,
            onError: (Object _) => const <Post>[],
          )
        : Future.value(const <Post>[]);
    try {
      final page = await _api.feed(
        tab: filter.tab,
        coin: filter.coin,
        market: filter.market,
        query: filter.search,
        pageSize: pageSize,
      );
      final top = await pinned;
      if (!ref.mounted || generation != _generation) return;
      _page = 1;
      final pinnedIds = {for (final p in top) p.id};
      state = FeedState(
        filter: filter,
        // A pinned post is not repeated below.
        items: [
          for (final p in page.items)
            if (!pinnedIds.contains(p.id)) p,
        ],
        more: page.hasMore,
        pinned: top,
      );
    } on ApiFailure catch (failure) {
      if (!ref.mounted || generation != _generation) return;
      state = state.copyWith(failure: failure);
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.loadingMore) return;
    final generation = _generation;
    final filter = state.filter;
    state = state.copyWith(loadingMore: true);
    try {
      final page = await _api.feed(
        tab: filter.tab,
        coin: filter.coin,
        market: filter.market,
        query: filter.search,
        page: _page + 1,
        pageSize: pageSize,
      );
      if (!ref.mounted || generation != _generation) return;
      _page += 1;
      final known = {
        for (final p in state.items!) p.id,
        for (final p in state.pinned) p.id,
      };
      state = state.copyWith(
        items: [
          ...state.items!,
          for (final p in page.items)
            if (!known.contains(p.id)) p,
        ],
        more: page.hasMore,
        loadingMore: false,
      );
    } on ApiFailure {
      if (!ref.mounted || generation != _generation) return;
      state = state.copyWith(loadingMore: false);
    }
  }

  /// The card of [post] as the detail now has it.
  void replace(Post post) {
    List<Post> swap(List<Post> list) => [
      for (final p in list) p.id == post.id ? _keepCard(p, post) : p,
    ];
    state = state.copyWith(
      items: state.items == null ? null : swap(state.items!),
      pinned: swap(state.pinned),
    );
  }

  /// A deleted post leaves the feed.
  void remove(String id) {
    state = state.copyWith(
      items: [
        for (final p in state.items ?? const <Post>[])
          if (p.id != id) p,
      ],
      pinned: [
        for (final p in state.pinned)
          if (p.id != id) p,
      ],
    );
  }

  /// Applied at once; null when the server agreed, its refusal otherwise.
  Future<ApiFailure?> toggleLike(Post post) => _toggle(
    post,
    optimistic: post.copyWith(
      likedByMe: !post.likedByMe,
      likeCount: post.likeCount + (post.likedByMe ? -1 : 1),
    ),
    send: () => _api.likePost(post.id, like: !post.likedByMe),
    settle: (e) => post.copyWith(likedByMe: e.active, likeCount: e.count),
  );

  Future<ApiFailure?> toggleSave(Post post) => _toggle(
    post,
    optimistic: post.copyWith(savedByMe: !post.savedByMe),
    send: () => _api.savePost(post.id, save: !post.savedByMe),
    settle: (e) => post.copyWith(savedByMe: e.active),
  );

  Future<ApiFailure?> _toggle(
    Post post, {
    required Post optimistic,
    required Future<Engagement> Function() send,
    required Post Function(Engagement) settle,
  }) async {
    replace(optimistic);
    try {
      final engagement = await send();
      if (ref.mounted) replace(settle(engagement));
      return null;
    } on ApiFailure catch (failure) {
      if (ref.mounted) replace(post);
      return failure;
    }
  }

  /// A feed card keeps its excerpt and cover; the reactions follow [from].
  static Post _keepCard(Post card, Post from) => card.copyWith(
    likedByMe: from.likedByMe,
    likeCount: from.likeCount,
    savedByMe: from.savedByMe,
    commentCount: from.commentCount,
    vote: Vote(
      myVote: from.myVote,
      bullishCount: from.bullishCount,
      bearishCount: from.bearishCount,
    ),
  );
}
