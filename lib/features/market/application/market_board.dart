import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../data/market_repository.dart';
import '../domain/market.dart';

enum BoardSort { none, volume, price, change }

@immutable
class MarketBoardState {
  const MarketBoardState({
    this.pairs,
    this.failure,
    this.tickers = const {},
    this.delayed = false,
    this.query = '',
    this.sort = BoardSort.none,
    this.descending = true,
    this.ordered,
  });

  final List<MarketPair>? pairs;
  final ApiFailure? failure;
  final Map<String, Ticker> tickers;

  /// No push for [MarketRepository.staleAfterSeconds] s: the list is read by REST instead.
  final bool delayed;
  final String query;
  final BoardSort sort;
  final bool descending;

  /// [rows] as the board last gave them: the same list while the order
  /// stays, so a price push alone does not rebuild the list (T-138).
  final List<MarketPair>? ordered;

  /// Searched and sorted; ties and [BoardSort.none] keep the display order.
  List<MarketPair> get rows => ordered ?? order();

  /// [rows] worked out again from the pairs, prices, search and sort.
  List<MarketPair> order() {
    final all = pairs ?? const <MarketPair>[];
    final found = [
      for (final pair in all)
        if (pair.matches(query)) pair,
    ];
    if (sort == BoardSort.none) return found;
    // Each value parsed once, not on every comparison.
    final keys = <String, Decimal?>{
      for (final pair in found)
        pair.symbol: Decimal.tryParse(
          switch (sort) {
                BoardSort.volume => tickers[pair.symbol]?.quoteVolume24h,
                BoardSort.price => tickers[pair.symbol]?.displayPrice,
                BoardSort.change => tickers[pair.symbol]?.changePercent24h,
                BoardSort.none => null,
              } ??
              '',
        ),
    };
    int byValue(MarketPair a, MarketPair b) {
      final x = keys[a.symbol];
      final y = keys[b.symbol];
      // Unreadable values sort first, as compareDecimal does.
      if (x == null || y == null) {
        return (x == null ? 0 : 1) - (y == null ? 0 : 1);
      }
      return x.compareTo(y);
    }

    final sorted = [...found]
      ..sort((a, b) {
        final value = byValue(a, b);
        if (value != 0) return descending ? -value : value;
        return a.displayOrder.compareTo(b.displayOrder);
      });
    return sorted;
  }

  MarketBoardState copyWith({
    List<MarketPair>? pairs,
    ApiFailure? failure,
    bool clearFailure = false,
    Map<String, Ticker>? tickers,
    bool? delayed,
    String? query,
    BoardSort? sort,
    bool? descending,
  }) => MarketBoardState(
    // Worked out again by the board, which keeps the list while it is equal.
    pairs: pairs ?? this.pairs,
    failure: clearFailure ? null : failure ?? this.failure,
    tickers: tickers ?? this.tickers,
    delayed: delayed ?? this.delayed,
    query: query ?? this.query,
    sort: sort ?? this.sort,
    descending: descending ?? this.descending,
  );

  MarketBoardState withOrder(List<MarketPair> rows) => MarketBoardState(
    pairs: pairs,
    failure: failure,
    tickers: tickers,
    delayed: delayed,
    query: query,
    sort: sort,
    descending: descending,
    ordered: rows,
  );
}

final marketBoardProvider = NotifierProvider.autoDispose
    .family<MarketBoard, MarketBoardState, Market>(MarketBoard.new);

/// SCR-09 for one market: the search and the sort over the market's pairs
/// and prices, which come from [MarketRepository] (D-150). The search ends
/// with the tab, as its field does.
class MarketBoard extends Notifier<MarketBoardState> {
  MarketBoard(this.market);

  final Market market;

  /// Held, not read on each call: a row reports itself gone after the tab
  /// that showed it may have released this board.
  late MarketRepository _data;

  @override
  MarketBoardState build() {
    _data = ref.read(marketRepositoryProvider(market).notifier);
    ref.listen(marketRepositoryProvider(market), (_, data) {
      _set(
        state.copyWith(
          pairs: data.pairs,
          failure: data.failure,
          clearFailure: data.failure == null,
          tickers: data.tickers,
          delayed: data.delayed,
        ),
      );
    });
    final data = ref.read(marketRepositoryProvider(market));
    final first = MarketBoardState(
      pairs: data.pairs,
      failure: data.failure,
      tickers: data.tickers,
      delayed: data.delayed,
    );
    return first.withOrder(first.order());
  }

  /// Every new state, with [MarketBoardState.ordered] kept when equal.
  void _set(MarketBoardState next) {
    final fresh = next.order();
    final previous = state.ordered;
    state = next.withOrder(
      previous != null && listEquals(previous, fresh) ? previous : fresh,
    );
  }

  Future<void> load() => _data.load();

  /// Pull to refresh: pairs again, and the visible rows when Delayed.
  Future<void> refresh() => _data.refresh();

  /// Rows report themselves while built, so only they are polled.
  void markVisible(String symbol, {required bool visible}) =>
      _data.markVisible(symbol, visible: visible);

  void search(String query) => _set(state.copyWith(query: query));

  /// Binance-style header: first tap sorts descending, then ascending, then
  /// back to the display order.
  void toggleSort(BoardSort key) {
    if (state.sort != key) {
      _set(state.copyWith(sort: key, descending: true));
    } else if (state.descending) {
      _set(state.copyWith(descending: false));
    } else {
      _set(state.copyWith(sort: BoardSort.none, descending: true));
    }
  }
}
