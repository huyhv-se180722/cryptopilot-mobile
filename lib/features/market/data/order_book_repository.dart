import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/json/json_read.dart';
import '../../../core/realtime/realtime_hub.dart';
import '../domain/market.dart';
import '../domain/order_book.dart';
import 'market_api.dart';

typedef BookKey = ({Market market, String symbol});

@immutable
class OrderBook {
  const OrderBook({this.depth, this.trades = const [], this.failure});

  /// Null until the first depth is read.
  final DepthSnapshot? depth;

  /// Newest first, at most [OrderBookRepository.keepTrades].
  final List<MarketTrade> trades;
  final ApiFailure? failure;
}

final orderBookProvider = NotifierProvider.autoDispose
    .family<OrderBookRepository, OrderBook, BookKey>(OrderBookRepository.new);

/// A pair's order book and market trades (TR-03): REST first, then
/// `/topic/depth.{M}.{S}` (a whole snapshot) and `/topic/trades.{M}.{S}`
/// (the trades since the last push, oldest first), pushed every 100 ms.
/// The screen is given at most one change per [repaint]: the latest depth
/// and every trade since. Subscribed while a screen listens.
class OrderBookRepository extends Notifier<OrderBook> {
  OrderBookRepository(this.key);

  static const repaint = Duration(milliseconds: 250);
  static const keepTrades = 50;

  final BookKey key;
  DepthSnapshot? _depth;
  final List<MarketTrade> _incoming = [];
  Timer? _flush;

  String get _suffix => '${key.market.wire}.${key.symbol}';

  @override
  OrderBook build() {
    final hub = ref.read(realtimeHubProvider.notifier);
    final depth = hub.watch('/topic/depth.$_suffix').listen(_onDepth);
    final trades = hub.watch('/topic/trades.$_suffix').listen(_onTrades);
    ref.onDispose(() {
      _flush?.cancel();
      unawaited(depth.cancel());
      unawaited(trades.cancel());
    });
    unawaited(Future.microtask(load));
    return const OrderBook();
  }

  Future<void> load() async {
    // A provider read with no listener is gone before its first load.
    if (!ref.mounted) return;
    final api = ref.read(marketApiProvider);
    try {
      final results = await Future.wait([
        api.depth(key.market, key.symbol),
        api.trades(key.market, key.symbol, limit: keepTrades),
      ]);
      if (!ref.mounted) return;
      final depth = results[0] as DepthSnapshot;
      final trades = results[1] as List<MarketTrade>;
      state = OrderBook(
        // A push that came first is newer than the REST answer.
        depth: state.depth ?? depth,
        trades: state.trades.isNotEmpty ? state.trades : trades,
      );
    } on ApiFailure catch (failure) {
      if (ref.mounted) {
        state = OrderBook(
          depth: state.depth,
          trades: state.trades,
          failure: failure,
        );
      }
    }
  }

  void _onDepth(Object? body) {
    try {
      _depth = decodeDepth(body);
    } on DecodeException {
      return;
    }
    _schedule();
  }

  void _onTrades(Object? body) {
    try {
      _incoming.addAll(decodeMarketTrades(body));
    } on DecodeException {
      return;
    }
    _schedule();
  }

  void _schedule() => _flush ??= Timer(repaint, _apply);

  void _apply() {
    _flush = null;
    if (!ref.mounted) return;
    final trades = [..._incoming.reversed, ...state.trades];
    _incoming.clear();
    state = OrderBook(
      depth: _depth ?? state.depth,
      trades: trades.length > keepTrades
          ? trades.sublist(0, keepTrades)
          : trades,
    );
  }
}
