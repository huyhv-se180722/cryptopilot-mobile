import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/errors/api_failure.dart';
import '../../watchlist/application/watchlist_controller.dart';
import '../data/alert_api.dart';
import '../domain/alert.dart';

@immutable
class AlertsState {
  const AlertsState({
    this.items,
    this.status,
    this.type,
    this.page = 0,
    this.total = 0,
    this.failure,
    this.loadingMore = false,
  });

  /// Null until the first page arrives.
  final List<Alert>? items;
  final AlertStatus? status;
  final AlertType? type;
  final int page;
  final int total;
  final ApiFailure? failure;
  final bool loadingMore;

  bool get filtered => status != null || type != null;
  bool get hasMore => items != null && items!.length < total;

  AlertsState copyWith({
    List<Alert>? items,
    int? page,
    int? total,
    ApiFailure? failure,
    bool clearFailure = false,
    bool? loadingMore,
  }) => AlertsState(
    items: items ?? this.items,
    status: status,
    type: type,
    page: page ?? this.page,
    total: total ?? this.total,
    failure: clearFailure ? null : failure ?? this.failure,
    loadingMore: loadingMore ?? this.loadingMore,
  );
}

final alertsControllerProvider =
    NotifierProvider<AlertsController, AlertsState>(AlertsController.new);

/// SCR-13 (UC-14): the Trader's alerts newest first, 20 a page (CR-04),
/// filtered by status and type on the server. Every write reads the list
/// again, and the watchlist too: its alert counts change, and a create may
/// have added the pair (BR-16).
class AlertsController extends Notifier<AlertsState> {
  static const pageSize = 20;

  /// Bumped by every load, so the answer of an older filter is dropped.
  int _generation = 0;

  @override
  AlertsState build() {
    // Another account, or none: start over.
    final signedIn = ref.watch(
      sessionControllerProvider.select((session) => session is SignedIn),
    );
    if (signedIn) unawaited(Future.microtask(load));
    return const AlertsState();
  }

  AlertApi get _api => ref.read(alertApiProvider);

  /// The first page of the current filter, keeping the shown rows meanwhile.
  Future<void> load() => _loadFirst(state.status, state.type);

  Future<void> setFilter({AlertStatus? status, AlertType? type}) {
    state = AlertsState(status: status, type: type);
    return _loadFirst(status, type);
  }

  Future<void> _loadFirst(AlertStatus? status, AlertType? type) async {
    final generation = ++_generation;
    try {
      final page = await _api.list(
        status: status,
        type: type,
        pageSize: pageSize,
      );
      if (!ref.mounted || generation != _generation) return;
      state = AlertsState(
        items: page.items,
        status: status,
        type: type,
        page: 1,
        total: page.total,
      );
    } on ApiFailure catch (failure) {
      if (!ref.mounted || generation != _generation) return;
      state = state.copyWith(failure: failure);
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.loadingMore) return;
    final generation = _generation;
    state = state.copyWith(loadingMore: true);
    try {
      final page = await _api.list(
        status: state.status,
        type: state.type,
        page: state.page + 1,
        pageSize: pageSize,
      );
      if (!ref.mounted || generation != _generation) return;
      final known = {for (final alert in state.items!) alert.id};
      state = state.copyWith(
        items: [
          ...state.items!,
          for (final alert in page.items)
            if (!known.contains(alert.id)) alert,
        ],
        page: page.page,
        total: page.total,
        loadingMore: false,
        clearFailure: true,
      );
    } on ApiFailure catch (failure) {
      if (!ref.mounted || generation != _generation) return;
      state = state.copyWith(failure: failure, loadingMore: false);
    }
  }

  /// Throws [ApiFailure] for the sheet: field errors, MSG29, MSG27, MSG41.
  Future<Alert> create(String pairId, AlertRule rule) async {
    final alert = await _api.create(pairId, rule);
    await _changed();
    return alert;
  }

  Future<Alert> update(Alert alert, AlertRule rule) async {
    final saved = await _api.update(alert.id, rule);
    await _changed();
    return saved;
  }

  /// Throws [ApiFailure]: MSG43 when the status no longer allows it.
  Future<void> pause(Alert alert) async {
    try {
      await _api.pause(alert.id);
    } finally {
      // The watchlist counts active alerts only.
      await _changed();
    }
  }

  /// Throws [ApiFailure]: MSG27 at the limit, MSG29, an `expiresAt` MSG15
  /// when the expiry passed (edit it instead), MSG43.
  Future<void> resume(Alert alert) async {
    try {
      await _api.resume(alert.id);
    } finally {
      await _changed();
    }
  }

  Future<void> delete(Alert alert) async {
    await _api.delete(alert.id);
    await _changed();
  }

  Future<void> _changed() async {
    // Only reload what someone already looked at.
    final reloads = [
      if (state.items != null) load(),
      ref.read(watchlistControllerProvider.notifier).load(),
    ];
    await Future.wait(reloads);
  }
}
