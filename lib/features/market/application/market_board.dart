import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/format/decimal_format.dart';
import '../../../core/json/json_read.dart';
import '../../../core/realtime/realtime_hub.dart';
import '../data/market_api.dart';
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

  /// No push for [MarketBoard.staleAfterSeconds] s: the list is read by REST instead.
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

/// SCR-09 for one market: pairs by REST, prices from `/topic/overview.{M}`
/// (pushed every 2 s and once right after SUBSCRIBE). Without a push for
/// 10 s the list is Delayed and the rows on screen are read by REST every
/// 10 s while it stays so (CR-09; Q-65: no list endpoint, so only the
/// visible rows, at most [maxPolled]).
class MarketBoard extends Notifier<MarketBoardState> {
  MarketBoard(this.market);

  /// Seconds without a push before the list is Delayed (CR-09).
  static const staleAfterSeconds = 10;

  /// Seconds between two REST rounds while Delayed.
  static const pollEverySeconds = 10;
  static const maxPolled = 10;

  final Market market;
  final Set<String> _visible = {};

  /// Counted by a one-second timer, not read from the wall clock, so a
  /// changed device clock cannot make the list look live or stale.
  int _sincePush = 0;
  int _sincePoll = 0;
  bool _polling = false;

  @override
  MarketBoardState build() {
    final subscription = ref
        .read(realtimeHubProvider.notifier)
        .watch('/topic/overview.${market.wire}')
        .listen(_onOverview);
    final liveness = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    ref.onDispose(() {
      liveness.cancel();
      unawaited(subscription.cancel());
    });
    unawaited(Future.microtask(load));
    return const MarketBoardState();
  }

  Future<void> load() async {
    try {
      final pairs = await ref.read(marketApiProvider).pairs(market);
      if (ref.mounted) state = state.copyWith(pairs: pairs, clearFailure: true);
    } on ApiFailure catch (failure) {
      if (ref.mounted) state = state.copyWith(failure: failure);
    }
  }

  void _onOverview(Object? body) {
    final List<Ticker> updates;
    try {
      updates = decodeOverview(body);
    } on DecodeException {
      return;
    }
    _sincePush = 0;
    final tickers = {...state.tickers};
    for (final update in updates) {
      final known = tickers[update.symbol];
      tickers[update.symbol] = known == null ? update : known.merge(update);
    }
    state = state.copyWith(tickers: tickers, delayed: false);
  }

  void _tick() {
    _sincePush++;
    _sincePoll++;
    final stale = _sincePush > staleAfterSeconds;
    if (stale != state.delayed) state = state.copyWith(delayed: stale);
    if (stale && _sincePoll >= pollEverySeconds) {
      _sincePoll = 0;
      unawaited(_poll());
    }
  }

  Future<void> _poll() async {
    if (_polling) return;
    _polling = true;
    try {
      final api = ref.read(marketApiProvider);
      for (final symbol in _visible.take(maxPolled).toList()) {
        try {
          final ticker = await api.stats(market, symbol);
          if (!ref.mounted) return;
          final known = state.tickers[symbol];
          state = state.copyWith(
            tickers: {
              ...state.tickers,
              symbol: known == null ? ticker : known.merge(ticker),
            },
          );
        } on ApiFailure {
          // The next round tries again; the row keeps its last value.
        }
      }
    } finally {
      _polling = false;
    }
  }

  /// Pull to refresh: pairs again, and the visible rows when Delayed.
  Future<void> refresh() async {
    await load();
    if (state.delayed) await _poll();
  }

  /// Rows report themselves while built, so only they are polled.
  void markVisible(String symbol, {required bool visible}) =>
      visible ? _visible.add(symbol) : _visible.remove(symbol);

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
