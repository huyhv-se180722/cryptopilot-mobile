import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/json/json_read.dart';
import '../../../core/realtime/realtime_hub.dart';
import '../../../core/state/load_after_build.dart';
import '../../../core/state/poll_gate.dart';
import '../domain/market.dart';
import 'market_api.dart';

/// The pairs and prices of one market as every screen sees them.
@immutable
class MarketData {
  const MarketData({
    this.pairs,
    this.failure,
    this.tickers = const {},
    this.delayed = false,
  });

  final List<MarketPair>? pairs;
  final ApiFailure? failure;
  final Map<String, Ticker> tickers;

  /// No push for [MarketRepository.staleAfterSeconds] s: prices are read by
  /// REST instead.
  final bool delayed;

  MarketData copyWith({
    List<MarketPair>? pairs,
    ApiFailure? failure,
    bool clearFailure = false,
    Map<String, Ticker>? tickers,
    bool? delayed,
  }) => MarketData(
    pairs: pairs ?? this.pairs,
    failure: clearFailure ? null : failure ?? this.failure,
    tickers: tickers ?? this.tickers,
    delayed: delayed ?? this.delayed,
  );
}

final marketRepositoryProvider = NotifierProvider.autoDispose
    .family<MarketRepository, MarketData, Market>(MarketRepository.new);

/// One source of truth for a market's pairs and prices (D-150), shared by
/// Markets, Home, the Watchlist, alerts and analysis: pairs by REST, prices
/// from `/topic/overview.{M}` (pushed every 2 s and once right after
/// SUBSCRIBE). Without a push for 10 s the market is Delayed and the rows on
/// screen are read by REST every 10 s while it stays so (CR-09; Q-65: no
/// list endpoint, so only the visible rows, at most [maxPolled]). Subscribed
/// while a screen listens, unsubscribed with the last one.
class MarketRepository extends Notifier<MarketData> {
  MarketRepository(this.market);

  /// Seconds without a push before the market is Delayed (CR-09).
  static const staleAfterSeconds = 10;

  /// Seconds between two REST rounds while Delayed.
  static const pollEverySeconds = 10;
  static const maxPolled = 10;

  final Market market;
  final Set<String> _visible = {};

  /// Counted by a one-second timer, not read from the wall clock, so a
  /// changed device clock cannot make the prices look live or stale.
  int _sincePush = 0;
  int _sincePoll = 0;
  bool _polling = false;

  @override
  MarketData build() {
    final subscription = ref
        .read(realtimeHubProvider.notifier)
        .watch('/topic/overview.${market.wire}')
        .listen(_onOverview);
    final liveness = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    ref.onDispose(() {
      liveness.cancel();
      unawaited(subscription.cancel());
    });
    ref.loadAfterBuild(load);
    return const MarketData();
  }

  Future<void> load() async {
    // A provider read with no listener is gone before its first load.
    if (!ref.mounted) return;
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
    final gate = ref.read(pollGateProvider);
    // The hub closes its socket in the background on purpose: time away
    // neither counts towards Delayed nor reads anything (T-138).
    if (!gate.foreground) return;
    _sincePush++;
    _sincePoll++;
    final stale = _sincePush > staleAfterSeconds;
    if (stale != state.delayed) state = state.copyWith(delayed: stale);
    if (stale && gate.open && _sincePoll >= pollEverySeconds) {
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

  /// Pairs again, and the visible rows when Delayed.
  Future<void> refresh() async {
    await load();
    if (state.delayed) await _poll();
  }

  /// Rows report themselves while built, so only they are polled.
  void markVisible(String symbol, {required bool visible}) =>
      visible ? _visible.add(symbol) : _visible.remove(symbol);
}

typedef PairKey = ({Market market, String symbol});

/// One pair's live statistics.
@immutable
class PairTicker {
  const PairTicker({this.ticker, this.failure});

  final Ticker? ticker;

  /// The REST read failed (MSG41 when the pair is no longer enabled).
  final ApiFailure? failure;
}

final pairTickerProvider = NotifierProvider.autoDispose
    .family<PairTickerRepository, PairTicker, PairKey>(
      PairTickerRepository.new,
    );

/// One pair's statistics: REST first, then `/topic/ticker.{M}.{S}`; a push
/// that came before the REST answer is kept.
class PairTickerRepository extends Notifier<PairTicker> {
  PairTickerRepository(this.key);

  final PairKey key;

  @override
  PairTicker build() {
    final subscription = ref
        .read(realtimeHubProvider.notifier)
        .watch('/topic/ticker.${key.market.wire}.${key.symbol}')
        .listen(_onTicker);
    ref.onDispose(() => unawaited(subscription.cancel()));
    ref.loadAfterBuild(_read);
    return const PairTicker();
  }

  Future<void> _read() async {
    if (!ref.mounted) return;
    try {
      final ticker = await ref
          .read(marketApiProvider)
          .stats(key.market, key.symbol);
      if (ref.mounted && state.ticker == null) {
        state = PairTicker(ticker: ticker);
      }
    } on ApiFailure catch (failure) {
      if (ref.mounted) {
        state = PairTicker(ticker: state.ticker, failure: failure);
      }
    }
  }

  void _onTicker(Object? body) {
    try {
      state = PairTicker(ticker: decodeTickerUpdate(body));
    } on DecodeException {
      // A bad push is dropped; the next one replaces it.
    }
  }
}
