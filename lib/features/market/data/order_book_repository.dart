import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/json/json_read.dart';
import '../../../core/realtime/realtime_hub.dart';
import '../../../core/realtime/reload_on_reconnect.dart';
import '../../../core/state/load_after_build.dart';
import '../../../core/state/poll_gate.dart';
import '../domain/market.dart';
import '../domain/order_book.dart';
import 'market_api.dart';
import 'market_repository.dart';

typedef BookKey = ({Market market, String symbol});

@immutable
class OrderBook {
  const OrderBook({
    this.depth,
    this.trades = const [],
    this.failure,
    this.delayed = false,
  });

  /// Null until the first depth is read.
  final DepthSnapshot? depth;

  /// Newest first, at most [OrderBookRepository.keepTrades].
  final List<MarketTrade> trades;
  final ApiFailure? failure;

  /// No depth pushed for [MarketRepository.staleAfterSeconds]: the book is
  /// read by REST every [MarketRepository.pollEverySeconds] instead (CR-09).
  final bool delayed;
}

final orderBookProvider = NotifierProvider.autoDispose
    .family<OrderBookRepository, OrderBook, BookKey>(OrderBookRepository.new);

/// A pair's order book and market trades (TR-03): REST first, then
/// `/topic/depth.{M}.{S}` (a whole snapshot) and `/topic/trades.{M}.{S}`
/// (the trades since the last push, oldest first), pushed every 100 ms.
/// The screen is given at most one change per [repaint]: the latest depth
/// and every trade since. Subscribed while a screen listens. Without a depth
/// push for 10 s it is Delayed and read by REST every 10 s; a new connection
/// reads both again, so no trade missed meanwhile leaves a hole (CR-09,
/// T-138).
class OrderBookRepository extends Notifier<OrderBook> {
  OrderBookRepository(this.key);

  static const repaint = Duration(milliseconds: 250);
  static const keepTrades = 50;

  final BookKey key;
  DepthSnapshot? _depth;
  final List<MarketTrade> _incoming = [];
  Timer? _flush;

  /// Counted by a one-second timer, as in [MarketRepository].
  int _sincePush = 0;
  int _sincePoll = 0;
  int _depthPushes = 0;
  bool _reading = false;

  String get _suffix => '${key.market.wire}.${key.symbol}';

  @override
  OrderBook build() {
    final hub = ref.read(realtimeHubProvider.notifier);
    final depth = hub.watch('/topic/depth.$_suffix').listen(_onDepth);
    final trades = hub.watch('/topic/trades.$_suffix').listen(_onTrades);
    final liveness = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    ref
      ..onDispose(() {
        _flush?.cancel();
        liveness.cancel();
        unawaited(depth.cancel());
        unawaited(trades.cancel());
      })
      ..reloadOnReconnect(() => unawaited(_readAgain()));
    ref.loadAfterBuild(load);
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
        delayed: state.delayed,
      );
    } on ApiFailure catch (failure) {
      if (ref.mounted) {
        state = OrderBook(
          depth: state.depth,
          trades: state.trades,
          failure: failure,
          delayed: state.delayed,
        );
      }
    }
  }

  /// Both again, replacing what is shown: after a reconnect and while
  /// Delayed. A depth pushed during the read is newer and stays; the trades
  /// read are joined with the ones shown by id.
  Future<void> _readAgain() async {
    if (!ref.mounted || _reading) return;
    _reading = true;
    final pushes = _depthPushes;
    final api = ref.read(marketApiProvider);
    try {
      final results = await Future.wait([
        api.depth(key.market, key.symbol),
        api.trades(key.market, key.symbol, limit: keepTrades),
      ]);
      if (!ref.mounted) return;
      final read = results[1] as List<MarketTrade>;
      final newest = read.isEmpty ? null : read.first.id;
      state = OrderBook(
        depth: pushes == _depthPushes
            ? results[0] as DepthSnapshot
            : state.depth,
        trades: _cap([
          for (final t in state.trades)
            if (newest != null && t.id > newest) t,
          ...read,
        ]),
        delayed: state.delayed,
      );
    } on ApiFailure {
      // What is shown stays, still marked Delayed; the next round tries again.
    } finally {
      _reading = false;
    }
  }

  void _tick() {
    final gate = ref.read(pollGateProvider);
    // Time in the background neither counts nor reads (T-138).
    if (!gate.foreground) return;
    _sincePush++;
    _sincePoll++;
    final stale = _sincePush > MarketRepository.staleAfterSeconds;
    if (stale != state.delayed) {
      state = OrderBook(
        depth: state.depth,
        trades: state.trades,
        failure: state.failure,
        delayed: stale,
      );
    }
    if (stale && gate.open && _sincePoll >= MarketRepository.pollEverySeconds) {
      _sincePoll = 0;
      unawaited(_readAgain());
    }
  }

  static List<MarketTrade> _cap(List<MarketTrade> trades) =>
      trades.length > keepTrades ? trades.sublist(0, keepTrades) : trades;

  void _onDepth(Object? body) {
    try {
      _depth = decodeDepth(body);
    } on DecodeException {
      return;
    }
    _sincePush = 0;
    _depthPushes++;
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
      trades: _cap(trades),
      delayed: _sincePush > MarketRepository.staleAfterSeconds,
    );
  }
}
