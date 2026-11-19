import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/errors/api_failure.dart';
import '../data/journal_api.dart';
import '../domain/journal.dart';

@immutable
class JournalState {
  const JournalState({
    this.filter = const JournalFilter(),
    this.items,
    this.page = 0,
    this.total = 0,
    this.failure,
    this.loadingMore = false,
  });

  final JournalFilter filter;

  /// Null until the first page arrives; newest first.
  final List<JournalEntry>? items;
  final int page;
  final int total;
  final ApiFailure? failure;
  final bool loadingMore;

  bool get hasMore => items != null && items!.length < total;

  JournalState copyWith({
    List<JournalEntry>? items,
    int? page,
    int? total,
    ApiFailure? failure,
    bool clearFailure = false,
    bool? loadingMore,
  }) => JournalState(
    filter: filter,
    items: items ?? this.items,
    page: page ?? this.page,
    total: total ?? this.total,
    failure: clearFailure ? null : failure ?? this.failure,
    loadingMore: loadingMore ?? this.loadingMore,
  );
}

final journalControllerProvider =
    NotifierProvider.autoDispose<JournalController, JournalState>(
      JournalController.new,
    );

/// SCR-20 (UC-22): the trades of the filter's period, 20 a page, newest
/// first; the last 30 days at first.
class JournalController extends Notifier<JournalState> {
  static const pageSize = 20;

  int _generation = 0;

  @override
  JournalState build() {
    unawaited(Future.microtask(load));
    return const JournalState();
  }

  JournalApi get _api => ref.read(journalApiProvider);

  (DateTime?, DateTime?) _period(JournalFilter filter) {
    final days = filter.days;
    if (days == null) return (null, null);
    final today = ref.read(clockProvider)().toUtc();
    return (today.subtract(Duration(days: days - 1)), today);
  }

  Future<void> load() => _loadFirst(state.filter);

  Future<void> setFilter(JournalFilter filter) {
    state = JournalState(filter: filter);
    return _loadFirst(filter);
  }

  Future<void> _loadFirst(JournalFilter filter) async {
    final generation = ++_generation;
    final (from, to) = _period(filter);
    try {
      final page = await _api.list(
        filter: filter,
        from: from,
        to: to,
        pageSize: pageSize,
      );
      if (!ref.mounted || generation != _generation) return;
      state = JournalState(
        filter: filter,
        items: page.items,
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
    final (from, to) = _period(state.filter);
    state = state.copyWith(loadingMore: true);
    try {
      final page = await _api.list(
        filter: state.filter,
        from: from,
        to: to,
        page: state.page + 1,
        pageSize: pageSize,
      );
      if (!ref.mounted || generation != _generation) return;
      final known = {for (final e in state.items!) e.id};
      state = state.copyWith(
        items: [
          ...state.items!,
          for (final e in page.items)
            if (!known.contains(e.id)) e,
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

  /// A trade left the list (deleted) or changed (reviewed).
  void changed(JournalDetail? detail, {String? removedId}) {
    final items = state.items;
    if (items == null) return;
    state = state.copyWith(
      items: [
        for (final e in items)
          if (e.id != removedId)
            detail != null && e.id == detail.entry.id ? detail.entry : e,
      ],
      total: removedId == null ? state.total : state.total - 1,
    );
  }
}

/// The strategies a review can name, read once per screen.
final strategiesProvider = FutureProvider.autoDispose<List<Strategy>>(
  (ref) => ref.read(journalApiProvider).strategies(),
);

@immutable
class JournalEntryState {
  const JournalEntryState({this.detail, this.failure, this.saving = false});

  final JournalDetail? detail;
  final ApiFailure? failure;
  final bool saving;

  bool get missing =>
      failure is ProblemFailure &&
      (failure! as ProblemFailure).problem.messageCode == 'MSG41';

  /// The review replaces the stored one and the detail has no key of the
  /// chart image, so saving would remove it (Q-95): a trade with an image
  /// keeps its review read only in the app.
  bool get reviewEditable => detail != null && detail!.chartImageUrl == null;
}

final journalEntryControllerProvider = NotifierProvider.autoDispose
    .family<JournalEntryController, JournalEntryState, String>(
      JournalEntryController.new,
    );

/// SCR-21 (UC-23): the facts of a trade, read only for a SIMULATED one
/// (BR-40), and its review (MSG14 when saved); a MANUAL trade can be deleted.
class JournalEntryController extends Notifier<JournalEntryState> {
  JournalEntryController(this.id);

  final String id;

  @override
  JournalEntryState build() {
    unawaited(Future.microtask(load));
    return const JournalEntryState();
  }

  JournalApi get _api => ref.read(journalApiProvider);

  Future<void> load() async {
    try {
      final detail = await _api.entry(id);
      if (ref.mounted) state = JournalEntryState(detail: detail);
    } on ApiFailure catch (failure) {
      if (ref.mounted) {
        state = JournalEntryState(detail: state.detail, failure: failure);
      }
    }
  }

  /// Throws [ApiFailure] (MSG15 on a field, MSG41). Not offered when
  /// [JournalEntryState.reviewEditable] is false.
  Future<void> saveReview({
    String? strategyId,
    String? setupDescription,
    String? lessonsLearned,
    String? mistakes,
  }) async {
    if (!state.reviewEditable || state.saving) return;
    String? text(String? value) =>
        value == null || value.trim().isEmpty ? null : value.trim();
    state = JournalEntryState(detail: state.detail, saving: true);
    try {
      final detail = await _api.review(
        id,
        strategyId: strategyId,
        setupDescription: text(setupDescription),
        lessonsLearned: text(lessonsLearned),
        mistakes: text(mistakes),
      );
      if (!ref.mounted) return;
      state = JournalEntryState(detail: detail);
      if (ref.exists(journalControllerProvider)) {
        ref.read(journalControllerProvider.notifier).changed(detail);
      }
    } on ApiFailure {
      if (ref.mounted) state = JournalEntryState(detail: state.detail);
      rethrow;
    }
  }

  /// A MANUAL trade (BR-41). Throws [ApiFailure] (MSG43 on a SIMULATED one).
  Future<void> delete() async {
    await _api.delete(id);
    if (ref.exists(journalControllerProvider)) {
      ref.read(journalControllerProvider.notifier).changed(null, removedId: id);
    }
  }
}
