import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/format/decimal_format.dart';
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
  });

  final List<MarketPair>? pairs;
  final ApiFailure? failure;
  final Map<String, Ticker> tickers;

  /// No push for [MarketRepository.staleAfterSeconds] s: the list is read by REST instead.
  final bool delayed;
  final String query;
  final BoardSort sort;
  final bool descending;

  /// Searched and sorted; ties and [BoardSort.none] keep the display order.
  List<MarketPair> get rows {
    final all = pairs ?? const <MarketPair>[];
    final found = [
      for (final pair in all)
        if (pair.matches(query)) pair,
    ];
    if (sort == BoardSort.none) return found;
    String? key(MarketPair pair) {
      final ticker = tickers[pair.symbol];
      return switch (sort) {
        BoardSort.volume => ticker?.quoteVolume24h,
        BoardSort.price => ticker?.displayPrice,
        BoardSort.change => ticker?.changePercent24h,
        BoardSort.none => null,
      };
    }

    final sorted = [...found]
      ..sort((a, b) {
        final byValue = compareDecimal(key(a), key(b));
        if (byValue != 0) return descending ? -byValue : byValue;
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
    pairs: pairs ?? this.pairs,
    failure: clearFailure ? null : failure ?? this.failure,
    tickers: tickers ?? this.tickers,
    delayed: delayed ?? this.delayed,
    query: query ?? this.query,
    sort: sort ?? this.sort,
    descending: descending ?? this.descending,
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
      state = state.copyWith(
        pairs: data.pairs,
        failure: data.failure,
        clearFailure: data.failure == null,
        tickers: data.tickers,
        delayed: data.delayed,
      );
    });
    final data = ref.read(marketRepositoryProvider(market));
    return MarketBoardState(
      pairs: data.pairs,
      failure: data.failure,
      tickers: data.tickers,
      delayed: data.delayed,
    );
  }

  Future<void> load() => _data.load();

  /// Pull to refresh: pairs again, and the visible rows when Delayed.
  Future<void> refresh() => _data.refresh();

  /// Rows report themselves while built, so only they are polled.
  void markVisible(String symbol, {required bool visible}) =>
      _data.markVisible(symbol, visible: visible);

  void search(String query) => state = state.copyWith(query: query);

  /// Binance-style header: first tap sorts descending, then ascending, then
  /// back to the display order.
  void toggleSort(BoardSort key) {
    if (state.sort != key) {
      state = state.copyWith(sort: key, descending: true);
    } else if (state.descending) {
      state = state.copyWith(descending: false);
    } else {
      state = state.copyWith(sort: BoardSort.none, descending: true);
    }
  }
}
