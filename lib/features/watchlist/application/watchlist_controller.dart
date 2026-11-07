import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/errors/api_failure.dart';
import '../data/watchlist_api.dart';
import '../domain/watchlist.dart';

@immutable
class WatchlistState {
  const WatchlistState({
    this.watchlist,
    this.failure,
    this.scores = const {},
    this.saving = false,
  });

  final Watchlist? watchlist;
  final ApiFailure? failure;

  /// A new order is being written ([WatchlistController.reorder]).
  final bool saving;

  /// By symbol; read once per load (≤ 4 at a time, as the web).
  final Map<String, SetupScore?> scores;

  List<WatchItem> get items => watchlist?.items ?? const [];

  bool watches(String pairId) => items.any((item) => item.pairId == pairId);

  /// Label groups in first-seen order; rows without a label last.
  List<(String?, List<WatchItem>)> get groups {
    final labelled = <String, List<WatchItem>>{};
    final rest = <WatchItem>[];
    for (final item in items) {
      final label = item.label?.trim();
      if (label == null || label.isEmpty) {
        rest.add(item);
      } else {
        labelled.putIfAbsent(label, () => []).add(item);
      }
    }
    return [
      for (final entry in labelled.entries) (entry.key, entry.value),
      if (rest.isNotEmpty) (null, rest),
    ];
  }

  WatchlistState copyWith({
    Watchlist? watchlist,
    ApiFailure? failure,
    bool clearFailure = false,
    Map<String, SetupScore?>? scores,
    bool? saving,
  }) => WatchlistState(
    watchlist: watchlist ?? this.watchlist,
    failure: clearFailure ? null : failure ?? this.failure,
    scores: scores ?? this.scores,
    saving: saving ?? this.saving,
  );
}

/// The outcome of a removal the screen has to act on.
sealed class RemoveOutcome {
  const RemoveOutcome();
}

class Removed extends RemoveOutcome {
  const Removed();
}

/// MSG26: the row holds [alerts] alerts that go with it.
class NeedsConfirmation extends RemoveOutcome {
  const NeedsConfirmation(this.alerts);

  final int alerts;
}

final watchlistControllerProvider =
    NotifierProvider<WatchlistController, WatchlistState>(
      WatchlistController.new,
    );

/// SCR-12 (UC-12): the Trader's watched pairs, shared by the Markets tab and
/// Home. Every write reads the list again, so counts and order come from the
/// server.
class WatchlistController extends Notifier<WatchlistState> {
  static const parallelScores = 4;

  @override
  WatchlistState build() {
    // Another account, or none: start over.
    final signedIn = ref.watch(
      sessionControllerProvider.select((session) => session is SignedIn),
    );
    if (signedIn) unawaited(Future.microtask(load));
    return const WatchlistState();
  }

  WatchlistApi get _api => ref.read(watchlistApiProvider);

  Future<void> load() async {
    try {
      final watchlist = await _api.list();
      if (!ref.mounted) return;
      state = state.copyWith(watchlist: watchlist, clearFailure: true);
      unawaited(_readScores(watchlist.items));
    } on ApiFailure catch (failure) {
      if (ref.mounted) state = state.copyWith(failure: failure);
    }
  }

  Future<void> _readScores(List<WatchItem> items) async {
    final queue = [
      for (final item in items)
        if (item.spotListed) item.symbol,
    ];
    Future<void> worker() async {
      while (queue.isNotEmpty) {
        final symbol = queue.removeAt(0);
        SetupScore? score;
        try {
          score = await _api.score(symbol);
        } on ApiFailure {
          score = null;
        }
        if (!ref.mounted) return;
        state = state.copyWith(scores: {...state.scores, symbol: score});
      }
    }

    await Future.wait([for (var i = 0; i < parallelScores; i++) worker()]);
  }

  /// Throws [ApiFailure] (MSG45, MSG27, MSG41) for the sheet to show.
  Future<WatchItem> add(String pairId) async {
    final item = await _api.add(pairId);
    await load();
    return item;
  }

  Future<void> edit(
    WatchItem item, {
    required String label,
    required String note,
  }) async {
    await _api.update(item.id, label: label.trim(), note: note.trim());
    await load();
  }

  /// SRS 3.4.1 "drag to reorder": moves the row at [from] of label group
  /// [group] to [to] (both counted in the group, [to] after the removal).
  ///
  /// The new order shows at once. The server moves one row per request and
  /// leaves the others where they are, so the whole list, in the order shown,
  /// is numbered 0…n-1 and only the rows whose number changes are sent, one
  /// after the other; the list is then read again. On a failure the server's
  /// order comes back and the [ApiFailure] is rethrown for the screen to show.
  Future<void> reorder(int group, int from, int to) async {
    final watchlist = state.watchlist;
    final groups = state.groups;
    if (watchlist == null || state.saving || group >= groups.length) return;
    final moved = [...groups[group].$2];
    if (from == to || from >= moved.length || to >= moved.length) return;
    moved.insert(to, moved.removeAt(from));
    final ordered = [
      for (var g = 0; g < groups.length; g++)
        ...(g == group ? moved : groups[g].$2),
    ];
    state = state.copyWith(
      watchlist: Watchlist(items: ordered, limit: watchlist.limit),
      saving: true,
    );
    try {
      for (var i = 0; i < ordered.length; i++) {
        if (ordered[i].sortOrder != i) {
          await _api.update(ordered[i].id, sortOrder: i);
          if (!ref.mounted) return;
        }
      }
    } on ApiFailure {
      await load();
      rethrow;
    } finally {
      if (ref.mounted) state = state.copyWith(saving: false);
    }
    await load();
  }

  /// First call without confirmation; MSG26 comes back as [NeedsConfirmation].
  Future<RemoveOutcome> remove(WatchItem item, {int? confirmedAlerts}) async {
    try {
      await _api.remove(
        item.id,
        confirm: confirmedAlerts != null,
        expectedAlertCount: confirmedAlerts,
      );
    } on ProblemFailure catch (failure) {
      if (failure.code == 'WATCHLIST_REMOVAL_CONFIRMATION_REQUIRED') {
        final args = failure.problem.messageArgs;
        final n = args.length > 1 ? int.tryParse(args[1]) : null;
        return NeedsConfirmation(n ?? item.activeAlerts);
      }
      rethrow;
    }
    await load();
    return const Removed();
  }
}
