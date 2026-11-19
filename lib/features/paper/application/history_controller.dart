import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/auth/session_controller.dart';
import '../data/paper_api.dart';
import '../domain/paper.dart';

/// The histories of plan 9.3, each with only the filters its endpoint has.
enum HistoryKind { orders, fills, ledger, transfers }

/// Quick ranges turned into from–to; null is every time.
enum HistoryPeriod {
  day(Duration(days: 1)),
  week(Duration(days: 7)),
  month(Duration(days: 30)),
  quarter(Duration(days: 90));

  const HistoryPeriod(this.length);
  final Duration length;
}

@immutable
class HistoryState {
  const HistoryState({
    this.items,
    this.total = 0,
    this.page = 0,
    this.period,
    this.status,
    this.ledgerType,
    this.loadingMore = false,
    this.failure,
  });

  /// [PaperOrder], [PaperFill], [LedgerEntry] or [Transfer], newest first.
  final List<Object>? items;
  final int total;
  final int page;

  /// Orders, fills and the ledger only (transfers have no range).
  final HistoryPeriod? period;

  /// Orders only.
  final OrderStatus? status;

  /// The ledger only.
  final LedgerType? ledgerType;
  final bool loadingMore;
  final ApiFailure? failure;

  bool get hasMore => items != null && items!.length < total;
}

final historyControllerProvider = NotifierProvider.autoDispose
    .family<HistoryController, HistoryState, HistoryKind>(
      HistoryController.new,
    );

/// One history, page after page; a new filter starts again from page 1 and
/// an answer to an older filter is dropped.
class HistoryController extends Notifier<HistoryState> {
  HistoryController(this.kind);

  static const pageSize = 20;

  final HistoryKind kind;
  int _request = 0;

  @override
  HistoryState build() {
    unawaited(Future.microtask(load));
    return const HistoryState();
  }

  Future<PaperPage<Object>> _read(int page) async {
    final api = ref.read(paperApiProvider);
    final to = state.period == null ? null : ref.read(clockProvider)().toUtc();
    final from = to?.subtract(state.period!.length);
    return switch (kind) {
      HistoryKind.orders => await api.orders(
        status: state.status,
        from: from,
        to: to,
        page: page,
        pageSize: pageSize,
      ),
      HistoryKind.fills => await api.fills(
        from: from,
        to: to,
        page: page,
        pageSize: pageSize,
      ),
      HistoryKind.ledger => await api.ledger(
        type: state.ledgerType,
        from: from,
        to: to,
        page: page,
        pageSize: pageSize,
      ),
      HistoryKind.transfers => await api.transfers(
        page: page,
        pageSize: pageSize,
      ),
    };
  }

  Future<void> load() async {
    final request = ++_request;
    state = HistoryState(
      period: state.period,
      status: state.status,
      ledgerType: state.ledgerType,
    );
    try {
      final page = await _read(1);
      if (!ref.mounted || request != _request) return;
      state = HistoryState(
        items: page.items,
        total: page.total,
        page: page.page,
        period: state.period,
        status: state.status,
        ledgerType: state.ledgerType,
      );
    } on ApiFailure catch (failure) {
      if (ref.mounted && request == _request) {
        state = HistoryState(
          period: state.period,
          status: state.status,
          ledgerType: state.ledgerType,
          failure: failure,
        );
      }
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.loadingMore) return;
    final request = _request;
    state = _with(loadingMore: true);
    try {
      final page = await _read(state.page + 1);
      if (!ref.mounted || request != _request) return;
      state = HistoryState(
        items: [...?state.items, ...page.items],
        total: page.total,
        page: page.page,
        period: state.period,
        status: state.status,
        ledgerType: state.ledgerType,
      );
    } on ApiFailure {
      if (ref.mounted && request == _request) state = _with(loadingMore: false);
    }
  }

  void selectPeriod(HistoryPeriod? period) {
    state = HistoryState(
      period: period,
      status: state.status,
      ledgerType: state.ledgerType,
    );
    unawaited(load());
  }

  void selectStatus(OrderStatus? status) {
    state = HistoryState(
      period: state.period,
      status: status,
      ledgerType: state.ledgerType,
    );
    unawaited(load());
  }

  void selectLedgerType(LedgerType? type) {
    state = HistoryState(
      period: state.period,
      status: state.status,
      ledgerType: type,
    );
    unawaited(load());
  }

  HistoryState _with({required bool loadingMore}) => HistoryState(
    items: state.items,
    total: state.total,
    page: state.page,
    period: state.period,
    status: state.status,
    ledgerType: state.ledgerType,
    loadingMore: loadingMore,
    failure: state.failure,
  );
}
