import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/json/json_read.dart';
import '../../../core/realtime/realtime_hub.dart';
import '../../market/data/market_api.dart';
import '../../market/domain/candle.dart';
import '../../market/domain/market.dart';
import '../data/candle_cache.dart';

typedef CandleKey = ({Market market, String symbol, Timeframe tf});

/// How the last state differs from the one before, so the chart page gets
/// one `update` per kline instead of the whole list again.
enum CandleChange { reset, update, prepend }

@immutable
class CandlesState {
  const CandlesState({
    this.candles,
    this.fromCache = false,
    this.failure,
    this.change = CandleChange.reset,
    this.prepended = 0,
    this.loadingOlder = false,
    this.olderDone = false,
  });

  /// Oldest first; the last one may be forming ([Candle.closed] false).
  final List<Candle>? candles;

  /// Drawn from the device while the fresh ones load.
  final bool fromCache;
  final ApiFailure? failure;
  final CandleChange change;

  /// Candles put in front by the last [CandleChange.prepend].
  final int prepended;
  final bool loadingOlder;
  final bool olderDone;

  CandlesState copyWith({
    List<Candle>? candles,
    bool? fromCache,
    ApiFailure? failure,
    bool clearFailure = false,
    CandleChange? change,
    int? prepended,
    bool? loadingOlder,
    bool? olderDone,
  }) => CandlesState(
    candles: candles ?? this.candles,
    fromCache: fromCache ?? this.fromCache,
    failure: clearFailure ? null : failure ?? this.failure,
    change: change ?? this.change,
    prepended: prepended ?? this.prepended,
    loadingOlder: loadingOlder ?? this.loadingOlder,
    olderDone: olderDone ?? this.olderDone,
  );
}

final candlesControllerProvider = NotifierProvider.autoDispose
    .family<CandlesController, CandlesState, CandleKey>(CandlesController.new);

/// The candles of one chart (ADR-012 / D-144): the cached ones at once, the
/// fresh 500 closed ones read at the same time (SRS 3.3.2), the forming one
/// from `/topic/kline.{M}.{S}.{tf}`, older ones on demand.
class CandlesController extends Notifier<CandlesState> {
  CandlesController(this.key);

  /// The page size when the Trader reaches the left edge.
  static const olderPage = 300;

  final CandleKey key;

  MarketApi get _api => ref.read(marketApiProvider);
  CandleCache get _cache => ref.read(candleCacheProvider);

  @override
  CandlesState build() {
    final kline = ref
        .read(realtimeHubProvider.notifier)
        .watch('/topic/kline.${key.market.wire}.${key.symbol}.${key.tf.wire}')
        .listen(_onKline);
    ref.onDispose(() => unawaited(kline.cancel()));
    unawaited(Future.microtask(load));
    return const CandlesState();
  }

  Future<void> load() async {
    final cached = _cache.read(key.market, key.symbol, key.tf);
    final fresh = _api.candles(key.market, key.symbol, key.tf);
    // Whichever comes first draws; the cache never replaces fresh candles.
    unawaited(
      cached.then((list) {
        if (!ref.mounted || list == null || list.isEmpty) return;
        if (state.candles != null && !state.fromCache) return;
        state = state.copyWith(
          candles: list,
          fromCache: true,
          change: CandleChange.reset,
        );
      }),
    );
    try {
      final list = await fresh;
      if (!ref.mounted) return;
      state = state.copyWith(
        candles: _withForming(list),
        fromCache: false,
        clearFailure: true,
        change: CandleChange.reset,
        olderDone: false,
      );
      unawaited(_cache.write(key.market, key.symbol, key.tf, list));
    } on ApiFailure catch (failure) {
      if (ref.mounted) state = state.copyWith(failure: failure);
    }
  }

  /// Keeps a forming candle that arrived before the REST answer.
  List<Candle> _withForming(List<Candle> closed) {
    final last = state.candles?.lastOrNull;
    if (last == null || last.closed || state.fromCache) return closed;
    if (closed.isNotEmpty && !last.openTime.isAfter(closed.last.openTime)) {
      return closed;
    }
    return [...closed, last];
  }

  void _onKline(Object? body) {
    final Candle candle;
    try {
      candle = decodeCandle(body);
    } on DecodeException {
      return;
    }
    final list = state.candles;
    if (list == null || list.isEmpty || state.fromCache) return;
    final last = list.last;
    if (candle.openTime == last.openTime) {
      state = state.copyWith(
        candles: [...list.sublist(0, list.length - 1), candle],
        change: CandleChange.update,
      );
    } else if (candle.openTime.isAfter(last.openTime)) {
      state = state.copyWith(
        candles: [...list, candle],
        change: CandleChange.update,
      );
    }
  }

  /// Older closed candles in front of the first one (the left edge).
  Future<void> loadOlder() async {
    final list = state.candles;
    if (list == null ||
        list.isEmpty ||
        state.fromCache ||
        state.loadingOlder ||
        state.olderDone) {
      return;
    }
    state = state.copyWith(loadingOlder: true);
    try {
      final first = list.first.openTime;
      final older = [
        for (final c in await _api.candles(
          key.market,
          key.symbol,
          key.tf,
          limit: olderPage,
          to: first,
        ))
          if (c.openTime.isBefore(first)) c,
      ];
      if (!ref.mounted) return;
      final now = state.candles ?? list;
      state = state.copyWith(
        candles: [...older, ...now],
        change: older.isEmpty ? state.change : CandleChange.prepend,
        prepended: older.length,
        loadingOlder: false,
        olderDone: older.isEmpty,
      );
    } on ApiFailure {
      if (ref.mounted) state = state.copyWith(loadingOlder: false);
    }
  }
}
