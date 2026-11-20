import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/errors/api_failure.dart';
import '../../../core/state/load_after_build.dart';
import '../../market/data/market_repository.dart';
import '../../market/domain/market.dart';
import '../data/futures_api.dart';
import '../domain/futures_history.dart';
import 'history_controller.dart';

/// Whether the history screen shows Futures rather than Spot: switched
/// there, or chosen by the Assets section it was opened from.
final historyFuturesProvider = NotifierProvider<HistoryFutures, bool>(
  HistoryFutures.new,
);

class HistoryFutures extends Notifier<bool> {
  @override
  bool build() => false;

  void show({required bool futures}) => state = futures;
}

/// The Futures histories of plan 9.3 (T-123).
enum FuturesHistoryKind {
  positions,
  income,
  orders,
  trades,
  conditional,
  liquidations,
  margin;

  /// Its endpoint takes one pair only (`symbol` required).
  bool get needsSymbol =>
      this == orders || this == trades || this == conditional || this == margin;
}

@immutable
class FuturesHistoryState {
  const FuturesHistoryState({
    this.items,
    this.symbol,
    this.period,
    this.incomeType,
    this.marginAdded,
    this.failure,
  });

  /// Newest first: [ClosedPosition], [FuturesIncome], `FuturesOrder`,
  /// [FuturesTrade], `AlgoOrder` or [MarginChange]. Null while read.
  final List<Object>? items;

  /// Null is every pair, where the endpoint allows it.
  final String? symbol;
  final HistoryPeriod? period;

  /// Income only.
  final IncomeType? incomeType;

  /// Margin only: true additions, false reductions, null both.
  final bool? marginAdded;
  final ApiFailure? failure;

  FuturesHistoryState filters({
    String? symbol,
    bool clearSymbol = false,
    HistoryPeriod? period,
    bool clearPeriod = false,
    IncomeType? incomeType,
    bool clearIncomeType = false,
    bool? marginAdded,
    bool clearMarginAdded = false,
  }) => FuturesHistoryState(
    symbol: clearSymbol ? null : symbol ?? this.symbol,
    period: clearPeriod ? null : period ?? this.period,
    incomeType: clearIncomeType ? null : incomeType ?? this.incomeType,
    marginAdded: clearMarginAdded ? null : marginAdded ?? this.marginAdded,
  );
}

final futuresHistoryProvider = NotifierProvider.autoDispose
    .family<FuturesHistoryController, FuturesHistoryState, FuturesHistoryKind>(
      FuturesHistoryController.new,
    );

/// One Futures history, read whole (the endpoints have a `limit`, no
/// pages); a new filter reads again and an answer to an older one is
/// dropped. A history of one pair starts on the first Futures pair.
class FuturesHistoryController extends Notifier<FuturesHistoryState> {
  FuturesHistoryController(this.kind);

  /// Within every endpoint's range (liquidations take at most 100).
  static const limit = 100;

  final FuturesHistoryKind kind;
  int _request = 0;

  @override
  FuturesHistoryState build() {
    if (kind.needsSymbol) {
      ref.listen(
        marketRepositoryProvider(Market.futures).select((s) => s.pairs),
        (_, pairs) {
          if (state.symbol == null && pairs != null && pairs.isNotEmpty) {
            state = state.filters(symbol: pairs.first.symbol);
            unawaited(load());
          }
        },
      );
      final first = ref
          .read(marketRepositoryProvider(Market.futures))
          .pairs
          ?.firstOrNull
          ?.symbol;
      if (first != null) ref.loadAfterBuild(load);
      return FuturesHistoryState(symbol: first);
    }
    ref.loadAfterBuild(load);
    return const FuturesHistoryState();
  }

  Future<List<Object>> _read() async {
    final api = ref.read(futuresApiProvider);
    final to = state.period == null ? null : ref.read(clockProvider)().toUtc();
    final from = to?.subtract(state.period!.length);
    final symbol = state.symbol;
    return switch (kind) {
      FuturesHistoryKind.positions => await api.positionHistory(
        symbol: symbol,
        from: from,
        to: to,
        limit: limit,
      ),
      FuturesHistoryKind.income => await api.income(
        symbol: symbol,
        type: state.incomeType,
        from: from,
        to: to,
        limit: limit,
      ),
      FuturesHistoryKind.orders => await api.allOrders(
        symbol!,
        from: from,
        to: to,
        limit: limit,
      ),
      FuturesHistoryKind.trades => await api.userTrades(
        symbol!,
        from: from,
        to: to,
        limit: limit,
      ),
      FuturesHistoryKind.conditional => await api.allAlgoOrders(
        symbol!,
        from: from,
        to: to,
        limit: limit,
      ),
      FuturesHistoryKind.liquidations => await api.forceOrders(
        symbol: symbol,
        from: from,
        to: to,
        limit: limit,
      ),
      FuturesHistoryKind.margin => await api.marginHistory(
        symbol!,
        added: state.marginAdded,
        from: from,
        to: to,
        limit: limit,
      ),
    };
  }

  Future<void> load() async {
    if (kind.needsSymbol && state.symbol == null) return;
    final request = ++_request;
    state = state.filters();
    try {
      final items = await _read();
      if (!ref.mounted || request != _request) return;
      state = FuturesHistoryState(
        items: items,
        symbol: state.symbol,
        period: state.period,
        incomeType: state.incomeType,
        marginAdded: state.marginAdded,
      );
    } on ApiFailure catch (failure) {
      if (!ref.mounted || request != _request) return;
      state = FuturesHistoryState(
        symbol: state.symbol,
        period: state.period,
        incomeType: state.incomeType,
        marginAdded: state.marginAdded,
        failure: failure,
      );
    }
  }

  /// Null is every pair, only where the endpoint allows it.
  void selectSymbol(String? symbol) {
    if (symbol == null && kind.needsSymbol) return;
    state = state.filters(symbol: symbol, clearSymbol: symbol == null);
    unawaited(load());
  }

  void selectPeriod(HistoryPeriod? period) {
    state = state.filters(period: period, clearPeriod: period == null);
    unawaited(load());
  }

  void selectIncomeType(IncomeType? type) {
    state = state.filters(incomeType: type, clearIncomeType: type == null);
    unawaited(load());
  }

  void selectMarginAdded(bool? added) {
    state = state.filters(marginAdded: added, clearMarginAdded: added == null);
    unawaited(load());
  }
}
