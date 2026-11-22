import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/state/load_after_build.dart';
import '../data/paper_api.dart';
import '../data/paper_repository.dart';
import '../domain/paper.dart';

/// The equity periods of plan 9.3.
const equityPeriods = [7, 30, 90];

/// The account's change over the last 7 days (D-163; a client figure the
/// FE owner kept): the worth now less the start of the day six days back
/// (UTC, as the history is), with its percent of that start. Null without
/// that day's point: never a guess from another day.
({String change, String? percent})? sevenDayChange(
  PaperEquity? equity,
  DateTime now,
) {
  if (equity == null) return null;
  final utc = now.toUtc();
  final start = DateTime.utc(
    utc.year,
    utc.month,
    utc.day,
  ).subtract(const Duration(days: 6));
  final point = equity.history.where((p) => p.date == start).firstOrNull;
  final then = Decimal.tryParse(point?.totalEquity ?? '');
  final current = Decimal.tryParse(equity.totalEquity);
  if (then == null || current == null) return null;
  final change = current - then;
  final percent = then > Decimal.zero
      ? (change * Decimal.fromInt(100) / then)
            .toDecimal(scaleOnInfinitePrecision: 10)
            .round(scale: 2)
            .toString()
      : null;
  return (change: change.toString(), percent: percent);
}

@immutable
class AssetsPnlState {
  const AssetsPnlState({
    this.pnl,
    this.equity,
    this.days = 30,
    this.pnlFailure,
    this.equityFailure,
  });

  /// Each Spot coin's average cost and unrealised PnL; null while read.
  final SpotPnl? pnl;

  /// The worth with the start of each of the last [days]; null while read.
  final PaperEquity? equity;
  final int days;
  final ApiFailure? pnlFailure;
  final ApiFailure? equityFailure;
}

final assetsPnlProvider =
    NotifierProvider.autoDispose<AssetsPnlController, AssetsPnlState>(
      AssetsPnlController.new,
    );

/// Spot PnL and the equity history of the Assets tab (plan 9.3, T-123),
/// read once the account is open and again when the Spot wallet changes;
/// an answer to an older period is dropped.
class AssetsPnlController extends Notifier<AssetsPnlState> {
  int _request = 0;

  @override
  AssetsPnlState build() {
    ref.listen(paperAccountProvider.select((s) => s.spot), (before, now) {
      if (before != null && now != null && !identical(before, now)) {
        unawaited(loadPnl());
      }
    });
    ref.loadAfterBuild(load);
    return const AssetsPnlState();
  }

  Future<void> load() async {
    try {
      await ref.read(paperAccountProvider.notifier).opened;
    } on ApiFailure {
      return;
    }
    if (!ref.mounted) return;
    await Future.wait([loadPnl(), loadEquity()]);
  }

  Future<void> loadPnl() async {
    try {
      final pnl = await ref.read(paperApiProvider).spotPnl();
      if (ref.mounted) state = _with(pnl: pnl, clearPnlFailure: true);
    } on ApiFailure catch (failure) {
      if (ref.mounted) state = _with(pnlFailure: failure);
    }
  }

  Future<void> loadEquity() async {
    final request = ++_request;
    final days = state.days;
    try {
      final equity = await ref.read(paperApiProvider).equity(days: days);
      if (!ref.mounted || request != _request) return;
      state = _with(equity: equity, clearEquityFailure: true);
    } on ApiFailure catch (failure) {
      if (ref.mounted && request == _request) {
        state = _with(equityFailure: failure);
      }
    }
  }

  void selectDays(int days) {
    if (days == state.days) return;
    state = AssetsPnlState(pnl: state.pnl, days: days);
    unawaited(loadEquity());
  }

  AssetsPnlState _with({
    SpotPnl? pnl,
    PaperEquity? equity,
    ApiFailure? pnlFailure,
    ApiFailure? equityFailure,
    bool clearPnlFailure = false,
    bool clearEquityFailure = false,
  }) => AssetsPnlState(
    pnl: pnl ?? state.pnl,
    equity: equity ?? state.equity,
    days: state.days,
    pnlFailure: clearPnlFailure ? null : pnlFailure ?? state.pnlFailure,
    equityFailure: clearEquityFailure
        ? null
        : equityFailure ?? state.equityFailure,
  );
}
