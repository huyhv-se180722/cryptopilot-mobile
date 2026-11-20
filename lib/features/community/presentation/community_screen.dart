import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/errors/message_text.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/cp_colors.dart';
import '../../market/domain/market.dart';
import '../../market/presentation/market_widgets.dart';
import '../application/feed_controller.dart';
import '../domain/community.dart';
import 'coin_picker.dart';
import 'community_widgets.dart';

String feedTabName(AppLocalizations l, FeedTab tab) => switch (tab) {
  FeedTab.latest => l.communityTabLatest,
  FeedTab.trending => l.communityTabTrending,
  FeedTab.mostLiked => l.communityTabMostLiked,
  FeedTab.saved => l.communityTabSaved,
  FeedTab.mine => l.communityTabMine,
  FeedTab.following => l.communityTabFollowing,
};

/// SCR-24 (A-64): the community feed; writing a post opens the web
/// (SCR-26 stays there in phase 1).
class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  bool _searching = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  FeedController get _feed => ref.read(feedProvider.notifier);

  void _onSearch(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _feed.setFilter(ref.read(feedProvider).filter.copyWith(query: text));
    });
  }

  Future<void> _react(Future<ApiFailure?> action) async {
    final failure = await action;
    if (failure == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(failureText(AppLocalizations.of(context), failure)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(feedProvider);
    final filter = state.filter;
    return DefaultTabController(
      length: FeedTab.values.length,
      initialIndex: filter.tab.index,
      child: Scaffold(
        appBar: AppBar(
          title: _searching
              ? TextField(
                  key: const Key('community-search'),
                  controller: _search,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: l.communitySearch,
                    border: InputBorder.none,
                  ),
                  onChanged: _onSearch,
                )
              : Text(l.communityTitle),
          actions: [
            IconButton(
              key: const Key('community-search-toggle'),
              tooltip: _searching ? l.communityClearFilters : l.communitySearch,
              icon: Icon(_searching ? Icons.close : Icons.search),
              onPressed: () {
                setState(() => _searching = !_searching);
                if (!_searching && _search.text.isNotEmpty) {
                  _search.clear();
                  _feed.setFilter(filter.copyWith(query: ''));
                }
              },
            ),
            IconButton(
              key: const Key('community-new-post'),
              tooltip: l.composerNew,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => unawaited(context.push('/community/new')),
            ),
          ],
          bottom: TabBar(
            key: const Key('community-tabs'),
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            onTap: (i) =>
                _feed.setFilter(filter.copyWith(tab: FeedTab.values[i])),
            tabs: [
              for (final tab in FeedTab.values)
                Tab(
                  key: Key('community-tab-${tab.name}'),
                  text: feedTabName(l, tab),
                ),
            ],
          ),
        ),
        body: Column(
          children: [
            _FilterBar(filter: filter, onChanged: _feed.setFilter),
            if (_searching &&
                _search.text.trim().isNotEmpty &&
                filter.search == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Text(
                  l.communitySearchShort,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _feed.load,
                child: _FeedBody(
                  state: state,
                  onLike: (p) => _react(_feed.toggleLike(p)),
                  onSave: (p) => _react(_feed.toggleSave(p)),
                  onMore: _feed.loadMore,
                  onRetry: _feed.load,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterBar extends ConsumerWidget {
  const _FilterBar({required this.filter, required this.onChanged});

  final FeedFilter filter;
  final ValueChanged<FeedFilter> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final coins = listedCoins(ref);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          InputChip(
            key: const Key('community-coin'),
            avatar: filter.coin == null
                ? const Icon(Icons.toll_outlined, size: 18)
                : CoinLogo(symbol: filter.coin!, size: 18),
            label: Text(filter.coin ?? l.communityCoinAll),
            selected: filter.coin != null,
            showCheckmark: false,
            onPressed: () async {
              final coin = await showCoinPicker(
                context,
                coins,
                keyPrefix: 'community-coin',
                current: filter.coin,
                allowAll: true,
              );
              if (coin == null) return;
              onChanged(
                coin.isEmpty
                    ? filter.copyWith(clearCoin: true)
                    : filter.copyWith(coin: coin),
              );
            },
            onDeleted: filter.coin == null
                ? null
                : () => onChanged(filter.copyWith(clearCoin: true)),
          ),
          const SizedBox(width: 8),
          for (final (market, label) in [
            (null, l.communityMarketAll),
            (Market.spot, l.marketSpot),
            (Market.futures, l.marketFutures),
          ])
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                key: Key('community-market-${market?.wire ?? 'ALL'}'),
                label: Text(label),
                selected: filter.market == market,
                onSelected: (_) => onChanged(
                  market == null
                      ? filter.copyWith(clearMarket: true)
                      : filter.copyWith(market: market),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FeedBody extends StatelessWidget {
  const _FeedBody({
    required this.state,
    required this.onLike,
    required this.onSave,
    required this.onMore,
    required this.onRetry,
  });

  final FeedState state;
  final ValueChanged<Post> onLike;
  final ValueChanged<Post> onSave;
  final Future<void> Function() onMore;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cp = context.cp;
    final items = state.items;
    if (items == null && state.failure != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 96),
          Icon(Icons.cloud_off, size: 40, color: cp.muted),
          const SizedBox(height: 12),
          Center(child: Text(failureText(l, state.failure!))),
          Center(
            child: TextButton(onPressed: onRetry, child: Text(l.commonRetry)),
          ),
        ],
      );
    }
    if (items == null) return const ListSkeleton();
    if (items.isEmpty && state.pinned.isEmpty) {
      final filter = state.filter;
      final message = filter.filtered
          ? l.communityEmptyFiltered
          : switch (filter.tab) {
              FeedTab.saved => l.communityEmptySaved,
              FeedTab.mine => l.communityEmptyMine,
              FeedTab.following => l.communityEmptyFollowing,
              _ => l.communityEmpty,
            };
      return ListView(
        key: Key('community-empty-${filter.tab.name}'),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 96),
          Icon(Icons.forum_outlined, size: 48, color: cp.muted),
          const SizedBox(height: 12),
          Center(child: Text(message, textAlign: TextAlign.center)),
        ],
      );
    }
    final rows = [
      for (final post in state.pinned)
        PostCard(
          post: post,
          pinned: true,
          onLike: () => onLike(post),
          onSave: () => onSave(post),
        ),
      for (final post in items)
        PostCard(
          post: post,
          onLike: () => onLike(post),
          onSave: () => onSave(post),
        ),
    ];
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.extentAfter < 400) unawaited(onMore());
        return false;
      },
      child: ListView.separated(
        key: const Key('community-feed'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: rows.length + (state.hasMore ? 1 : 0),
        separatorBuilder: (_, _) => Divider(height: 1, color: cp.border),
        itemBuilder: (_, i) => i < rows.length
            ? rows[i]
            : const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
      ),
    );
  }
}
