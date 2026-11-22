import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/message_text.dart';
import '../../../core/format/decimal_format.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/cp_colors.dart';
import '../application/market_overview.dart';
import '../application/market_board.dart';
import '../domain/market.dart';
import 'coin_list_view.dart';
import 'market_overview_strip.dart';
import 'market_widgets.dart';
import 'pair_actions.dart';

/// The segments of the Markets tab.
/// In tab order; Coins last so the earlier indexes stay (T-137).
enum MarketsSegment { watchlist, spot, futures, coins }

/// The tabs as shown. The mockup's Watchlist, Coins, Spot, Futures order
/// scrolls the Watchlist tab off a 360 dp bar when Spot opens first, so the
/// order stays (T-151, plan 8b); one list keeps the tabs and pages aligned.
const marketsTabOrder = MarketsSegment.values;

/// A request to show a segment, e.g. Home's "See all" of its watchlist; the
/// Markets tab follows it and clears it.
final marketsSegmentRequestProvider =
    NotifierProvider<MarketsSegmentRequest, MarketsSegment?>(
      MarketsSegmentRequest.new,
    );

class MarketsSegmentRequest extends Notifier<MarketsSegment?> {
  @override
  MarketsSegment? build() => null;

  void request(MarketsSegment segment) => state = segment;

  void clear() => state = null;
}

/// The Markets tab: Watchlist (SCR-12) first, as the exchanges put their
/// favourites, then SCR-09 Spot and Futures.
class MarketsScreen extends StatelessWidget {
  const MarketsScreen({this.watchlist, this.actions = const [], super.key});

  /// The watchlist segment; filled by T-089 slice 3.
  final Widget? watchlist;

  /// Header actions other features add (the bell), composed by the router.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return DefaultTabController(
      length: marketsTabOrder.length,
      initialIndex: marketsTabOrder.indexOf(MarketsSegment.spot),
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.navMarkets),
          actions: [
            IconButton(
              key: const Key('open-alerts'),
              tooltip: l.navAlerts,
              icon: const Icon(Icons.alarm),
              onPressed: () => context.push('/alerts'),
            ),
            ...actions,
            IconButton(
              key: const Key('open-account'),
              tooltip: l.navAccount,
              icon: const Icon(Icons.account_circle_outlined),
              onPressed: () => context.push('/account'),
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              for (final segment in marketsTabOrder)
                switch (segment) {
                  MarketsSegment.watchlist => Tab(text: l.marketWatchlist),
                  MarketsSegment.coins => Tab(
                    key: const Key('markets-coins'),
                    text: l.marketCoins,
                  ),
                  MarketsSegment.spot => Tab(text: l.marketSpot),
                  MarketsSegment.futures => Tab(text: l.marketFutures),
                },
            ],
          ),
        ),
        body: _FollowSegmentRequests(
          child: TabBarView(
            children: [
              for (final segment in marketsTabOrder)
                switch (segment) {
                  MarketsSegment.watchlist =>
                    watchlist ?? Center(child: Text(l.tabComingTitle)),
                  MarketsSegment.coins => const CoinListView(),
                  MarketsSegment.spot => const MarketBoardView(
                    market: Market.spot,
                  ),
                  MarketsSegment.futures => const MarketBoardView(
                    market: Market.futures,
                  ),
                },
            ],
          ),
        ),
      ),
    );
  }
}

class _FollowSegmentRequests extends ConsumerStatefulWidget {
  const _FollowSegmentRequests({required this.child});

  final Widget child;

  @override
  ConsumerState<_FollowSegmentRequests> createState() =>
      _FollowSegmentRequestsState();
}

class _FollowSegmentRequestsState
    extends ConsumerState<_FollowSegmentRequests> {
  void _follow(MarketsSegment? segment) {
    if (segment == null) return;
    DefaultTabController.of(
      context,
    ).animateTo(marketsTabOrder.indexOf(segment));
    ref.read(marketsSegmentRequestProvider.notifier).clear();
  }

  @override
  void initState() {
    super.initState();
    // A request made before the tab was first built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _follow(ref.read(marketsSegmentRequestProvider));
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(marketsSegmentRequestProvider, (_, next) => _follow(next));
    return widget.child;
  }
}

class MarketBoardView extends ConsumerWidget {
  const MarketBoardView({required this.market, super.key});

  final Market market;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final provider = marketBoardProvider(market);
    // Everything but the prices: each row listens to its own ticker, and the
    // rows keep their list while the order stays (T-138).
    ref.watch(
      provider.select(
        (b) => (b.pairs, b.failure, b.rows, b.delayed, b.sort, b.descending),
      ),
    );
    final board = ref.read(provider);
    final notifier = ref.read(provider.notifier);
    final rows = board.rows;

    Widget body;
    if (board.pairs == null && board.failure != null) {
      body = _Message(
        text: failureText(l, board.failure!),
        action: TextButton(
          onPressed: notifier.load,
          child: Text(l.commonRetry),
        ),
      );
    } else if (board.pairs == null) {
      body = const ListSkeleton();
    } else if (rows.isEmpty) {
      body = _Message(text: l.msg41);
    } else {
      body = ListView.builder(
        key: PageStorageKey('board-${market.path}'),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: rows.length,
        itemBuilder: (_, index) => MarketRow(pair: rows[index]),
      );
    }

    return Column(
      children: [
        const MarketOverviewStrip(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: Key('search-${market.path}'),
                  onChanged: notifier.search,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: context.cp.raised,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    hintText: l.marketSearch,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              LiveBadge(delayed: board.delayed),
            ],
          ),
        ),
        _SortHeader(board: board, onSort: notifier.toggleSort, market: market),
        const Divider(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(marketOverviewProvider);
              await notifier.refresh();
            },
            child: body,
          ),
        ),
      ],
    );
  }
}

class _SortHeader extends StatelessWidget {
  const _SortHeader({
    required this.board,
    required this.onSort,
    required this.market,
  });

  final MarketBoardState board;
  final void Function(BoardSort) onSort;
  final Market market;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    Widget head(
      String label,
      BoardSort key, {
      TextAlign align = TextAlign.start,
    }) {
      final active = board.sort == key;
      final icon = !active
          ? Icons.unfold_more
          : (board.descending ? Icons.arrow_downward : Icons.arrow_upward);
      final style = Theme.of(context).textTheme.labelSmall?.copyWith(
        color: active ? context.cp.text : context.cp.muted,
      );
      return InkWell(
        key: Key('sort-${key.name}-${market.path}'),
        onTap: () => onSort(key),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: style,
                  textAlign: align,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, size: 12, color: style?.color),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: head(l.marketSortVolume, BoardSort.volume),
            ),
          ),
          // Price over change in the rows: both sorts at the right edge.
          head(l.marketSortPrice, BoardSort.price),
          const SizedBox(width: 8),
          head(l.marketSortChange, BoardSort.change),
        ],
      ),
    );
  }
}

/// One pair: base/quote and volume (Futures: funding) on the left, the price
/// over the 24 h change as coloured text on the right (D-163). Reports itself as
/// visible while built on a shown tab, so the Delayed fallback reads only
/// what is on screen (a hidden tab or a route pushed over it turns
/// [TickerMode] off, which also pauses the row's ticker, T-138).
class MarketRow extends ConsumerStatefulWidget {
  const MarketRow({required this.pair, super.key});

  final MarketPair pair;

  @override
  ConsumerState<MarketRow> createState() => _MarketRowState();
}

class _MarketRowState extends ConsumerState<MarketRow> {
  late final MarketBoard _board;
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    _board = ref.read(marketBoardProvider(widget.pair.market).notifier);
  }

  @override
  void dispose() {
    _board.markVisible(widget.pair.symbol, visible: false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shown = TickerMode.valuesOf(context).enabled;
    if (shown != _shown) {
      _shown = shown;
      // Only a set of symbols the next REST round reads; no state changes.
      _board.markVisible(widget.pair.symbol, visible: shown);
    }
    final l = AppLocalizations.of(context);
    final pair = widget.pair;
    final text = Theme.of(context).textTheme;
    final ticker = ref.watch(
      marketBoardProvider(pair.market).select((s) => s.tickers[pair.symbol]),
    );
    final futures = pair.market == Market.futures;
    final secondary = futures
        ? l.marketFundingShort(formatFractionAsPercent(ticker?.fundingRate))
        : l.marketVolumeShort(formatCompact(ticker?.quoteVolume24h));
    return InkWell(
      key: Key('row-${pair.market.path}-${pair.symbol}'),
      onTap: () => openPairAnalysis(context, pair),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            CoinLogo(symbol: pair.baseAsset, url: pair.logoUrl),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: pair.baseAsset,
                          style: text.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(
                          text: '/${pair.quoteAsset}',
                          style: text.bodySmall?.copyWith(
                            color: context.cp.muted,
                          ),
                        ),
                        if (futures)
                          TextSpan(
                            text: '  ${l.marketPerpetual}',
                            style: text.labelSmall?.copyWith(
                              color: context.cp.muted,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    secondary,
                    style: text.bodySmall?.copyWith(color: context.cp.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Price over its 24 h change, right-aligned (D-163).
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatPrice(ticker?.displayPrice, pair.tickSize),
                  textAlign: TextAlign.right,
                  style: text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 2),
                ChangeText(percent: ticker?.changePercent24h),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    children: [
      Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.search_off, size: 32, color: context.cp.muted),
            const SizedBox(height: 8),
            Text(text, textAlign: TextAlign.center),
            ?action,
          ],
        ),
      ),
    ],
  );
}
