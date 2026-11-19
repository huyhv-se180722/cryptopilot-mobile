import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/json/json_read.dart';
import '../../../core/realtime/realtime_hub.dart';
import '../domain/futures.dart';
import '../domain/paper.dart';
import 'futures_api.dart';
import 'paper_repository.dart';

const futuresQueues = [
  '/user/queue/futures.orders',
  '/user/queue/futures.account',
  '/user/queue/futures.algo',
];
const futuresConfigQueue = '/user/queue/futures.config';
const marginCallQueue = '/user/queue/futures.marginCall';

@immutable
class FuturesState {
  const FuturesState({
    this.account,
    this.positions,
    this.orders = const [],
    this.algoOrders = const [],
    this.failure,
    this.marginCall,
    this.marginCalls = 0,
  });

  final FuturesAccount? account;

  /// Open positions of every pair; null until read.
  final List<FuturesPosition>? positions;
  final List<FuturesOrder> orders;
  final List<AlgoOrder> algoOrders;
  final ApiFailure? failure;

  /// The latest margin call; [marginCalls] grows by one at each.
  final MarginCall? marginCall;
  final int marginCalls;

  FuturesState copyWith({
    FuturesAccount? account,
    List<FuturesPosition>? positions,
    List<FuturesOrder>? orders,
    List<AlgoOrder>? algoOrders,
    ApiFailure? failure,
    bool clearFailure = false,
    MarginCall? marginCall,
    int? marginCalls,
  }) => FuturesState(
    account: account ?? this.account,
    positions: positions ?? this.positions,
    orders: orders ?? this.orders,
    algoOrders: algoOrders ?? this.algoOrders,
    failure: clearFailure ? null : failure ?? this.failure,
    marginCall: marginCall ?? this.marginCall,
    marginCalls: marginCalls ?? this.marginCalls,
  );
}

final futuresProvider =
    NotifierProvider.autoDispose<FuturesRepository, FuturesState>(
      FuturesRepository.new,
    );

/// The paper Futures account, positions and open orders (D-154), shared by
/// Trade and Assets. A push on a Futures queue makes it read its REST state
/// again, the pushes of one change gathered for [settle]; the margin call
/// alone is decoded, for its banner. Read again after a reconnection.
class FuturesRepository extends Notifier<FuturesState> {
  static const settle = Duration(milliseconds: 500);

  Timer? _reload;

  FuturesApi get _api => ref.read(futuresApiProvider);

  @override
  FuturesState build() {
    ref.listen(paperAccountProvider, (_, _) {});
    final hub = ref.read(realtimeHubProvider.notifier);
    final subscriptions = [
      for (final queue in futuresQueues)
        hub.watch(queue).listen((_) => _soon()),
      hub.watch(marginCallQueue).listen(_onMarginCall),
    ];
    ref
      ..listen(realtimeHubProvider.select((s) => s.generation), (before, now) {
        if (before != null && before > 0 && now != before) unawaited(load());
      })
      ..onDispose(() {
        _reload?.cancel();
        for (final s in subscriptions) {
          unawaited(s.cancel());
        }
      });
    unawaited(Future.microtask(load));
    return const FuturesState();
  }

  void _soon() {
    _reload?.cancel();
    _reload = Timer(settle, () => unawaited(load()));
  }

  Future<void> load() async {
    try {
      await ref.read(paperAccountProvider.notifier).opened;
      if (!ref.mounted) return;
      late final FuturesAccount account;
      late final List<FuturesPosition> positions;
      late final List<FuturesOrder> orders;
      late final List<AlgoOrder> algoOrders;
      await Future.wait([
        _api.account().then((v) => account = v),
        _api.positions().then((v) => positions = v),
        _api.openOrders().then((v) => orders = v),
        _api.openAlgoOrders().then((v) => algoOrders = v),
      ]);
      if (!ref.mounted) return;
      state = state.copyWith(
        account: account,
        positions: positions,
        orders: orders,
        algoOrders: algoOrders,
        clearFailure: true,
      );
    } on ApiFailure catch (failure) {
      if (ref.mounted) state = state.copyWith(failure: failure);
    }
  }

  void _onMarginCall(Object? body) {
    try {
      state = state.copyWith(
        marginCall: decodeMarginCall(body),
        marginCalls: state.marginCalls + 1,
      );
    } on DecodeException {
      return;
    }
    _soon();
  }

  /// Runs a change, then reads the state again; throws its [ApiFailure].
  Future<void> _change(Future<void> Function(FuturesApi api) change) async {
    await change(_api);
    if (ref.mounted) await load();
  }

  Future<void> cancelOrder(FuturesOrder order) =>
      _change((api) => api.cancelOrder(order.symbol, order.orderId));

  /// A new price and quantity for an open Limit (T-123).
  Future<void> amendOrder(
    FuturesOrder order, {
    required String price,
    required String quantity,
  }) => _change(
    (api) => api.amendOrder(
      FuturesAmendRequest(
        symbol: order.symbol,
        orderId: order.orderId,
        side: order.side,
        quantity: quantity,
        price: price,
      ),
    ),
  );

  Future<void> cancelAlgoOrder(AlgoOrder order) =>
      _change((api) => api.cancelAlgoOrder(order.symbol, order.algoId));

  Future<void> cancelAll(String symbol) =>
      _change((api) => api.cancelAll(symbol));

  /// [percent] of the position by Market, or by Limit at [price].
  Future<void> close(
    FuturesPosition position, {
    required int percent,
    String? price,
  }) => _change(
    (api) => api.closePosition(
      symbol: position.symbol,
      side: position.side,
      percent: percent,
      price: price,
    ),
  );

  Future<void> closeAll() => _change((api) => api.closeAll());

  Future<void> changeMargin(
    FuturesPosition position, {
    required String amount,
    required bool add,
  }) => _change(
    (api) => api.changeMargin(
      symbol: position.symbol,
      side: position.side,
      amount: amount,
      add: add,
    ),
  );

  /// The position's TP and/or SL, each closing the whole position when met.
  Future<void> setTpSl(
    FuturesPosition position, {
    String? takeProfit,
    String? stopLoss,
    required WorkingType working,
    required String Function() key,
  }) => _change((api) async {
    final side = position.short ? OrderSide.buy : OrderSide.sell;
    for (final (type, price) in [
      ('TAKE_PROFIT_MARKET', takeProfit),
      ('STOP_MARKET', stopLoss),
    ]) {
      if (price == null) continue;
      await api.placeAlgoOrder(
        AlgoOrderRequest(
          symbol: position.symbol,
          side: side,
          positionSide: position.side,
          type: type,
          triggerPrice: price,
          working: working,
          closePosition: true,
          clientAlgoId: key(),
        ),
      );
    }
  });
}

@immutable
class FuturesSettings {
  const FuturesSettings({this.config, this.maxLeverage, this.failure});

  final SymbolConfig? config;
  final int? maxLeverage;
  final ApiFailure? failure;
}

final futuresSettingsProvider = NotifierProvider.autoDispose
    .family<FuturesSettingsRepository, FuturesSettings, String>(
      FuturesSettingsRepository.new,
    );

/// A pair's leverage and margin mode (`symbolConfig`, `leverageBracket`),
/// read again when `/user/queue/futures.config` says they changed.
class FuturesSettingsRepository extends Notifier<FuturesSettings> {
  FuturesSettingsRepository(this.symbol);

  final String symbol;

  FuturesApi get _api => ref.read(futuresApiProvider);

  @override
  FuturesSettings build() {
    ref.listen(paperAccountProvider, (_, _) {});
    final config = ref
        .read(realtimeHubProvider.notifier)
        .watch(futuresConfigQueue)
        .listen((_) => unawaited(load()));
    ref.onDispose(() => unawaited(config.cancel()));
    unawaited(Future.microtask(load));
    return const FuturesSettings();
  }

  Future<void> load() async {
    try {
      await ref.read(paperAccountProvider.notifier).opened;
      if (!ref.mounted) return;
      late final SymbolConfig config;
      late final int maxLeverage;
      await Future.wait([
        _api.symbolConfig(symbol).then((v) => config = v),
        _api.maxLeverage(symbol).then((v) => maxLeverage = v),
      ]);
      if (ref.mounted) {
        state = FuturesSettings(config: config, maxLeverage: maxLeverage);
      }
    } on ApiFailure catch (failure) {
      if (ref.mounted) {
        state = FuturesSettings(
          config: state.config,
          maxLeverage: state.maxLeverage,
          failure: failure,
        );
      }
    }
  }

  /// Throws the [ApiFailure] of a refusal.
  Future<void> setLeverage(int leverage) async {
    await _api.setLeverage(symbol, leverage);
    if (ref.mounted) await load();
  }

  Future<void> setMarginType(MarginType type) async {
    await _api.setMarginType(symbol, type);
    if (ref.mounted) await load();
  }
}

@immutable
class FuturesMode {
  const FuturesMode({this.hedge, this.failure});

  /// Null until read: true in hedge mode (a Long and a Short per pair).
  final bool? hedge;
  final ApiFailure? failure;
}

final futuresModeProvider =
    NotifierProvider<FuturesModeRepository, FuturesMode>(
      FuturesModeRepository.new,
    );

/// One-way or hedge mode of the Futures account (TR-14b, T-123): read
/// once the account is open; a switch the server refuses (an order or a
/// position open, PAPER_POSITION_MODE) is thrown to the screen.
class FuturesModeRepository extends Notifier<FuturesMode> {
  @override
  FuturesMode build() {
    unawaited(Future.microtask(load));
    return const FuturesMode();
  }

  Future<void> load() async {
    try {
      await ref.read(paperAccountProvider.notifier).opened;
      final hedge = await ref.read(futuresApiProvider).positionMode();
      state = FuturesMode(hedge: hedge);
    } on ApiFailure catch (failure) {
      state = FuturesMode(hedge: state.hedge, failure: failure);
    }
  }

  Future<void> set({required bool hedge}) async {
    final now = await ref
        .read(futuresApiProvider)
        .setPositionMode(hedge: hedge);
    state = FuturesMode(hedge: now);
  }
}
