import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/realtime/realtime_hub.dart';
import '../data/plan_api.dart';
import '../data/plan_detail_api.dart';
import '../domain/plan.dart';

/// The lists of the Plans tab (A-61, read only): ACTIVE, DRAFT, EXECUTED and
/// CANCELLED_EXPIRED, each 20 a page; Open positions are the OPEN rows of
/// the newest 100 EXECUTED plans, as the web reads them.
enum PlanList {
  active(PlanTab.active),
  drafts(PlanTab.draft),
  executed(PlanTab.executed),
  cancelledExpired(PlanTab.cancelledExpired),
  openPositions(PlanTab.executed);

  const PlanList(this.tab);

  final PlanTab tab;
}

@immutable
class PlanListState {
  const PlanListState({
    this.items,
    this.total = 0,
    this.failure,
    this.loadingMore = false,
  });

  /// Null until the first page arrives; newest first.
  final List<PlanSummary>? items;
  final int total;
  final ApiFailure? failure;
  final bool loadingMore;

  bool get hasMore => items != null && items!.length < total;

  PlanListState copyWith({
    List<PlanSummary>? items,
    int? total,
    ApiFailure? failure,
    bool clearFailure = false,
    bool? loadingMore,
  }) => PlanListState(
    items: items ?? this.items,
    total: total ?? this.total,
    failure: clearFailure ? null : failure ?? this.failure,
    loadingMore: loadingMore ?? this.loadingMore,
  );
}

final planListProvider = NotifierProvider.autoDispose
    .family<PlanListController, PlanListState, PlanList>(
      PlanListController.new,
    );

/// One list of the Plans tab, read again when a plan's position changes
/// (`/user/queue/positions`), after a reconnection and when the app comes
/// back.
class PlanListController extends Notifier<PlanListState> {
  PlanListController(this.list);

  static const pageSize = 20;
  static const openPositionsWindow = 100;

  final PlanList list;
  int _generation = 0;
  int _page = 0;

  @override
  PlanListState build() {
    final pushes = ref
        .read(realtimeHubProvider.notifier)
        .watch(positionsQueue)
        .listen((_) => unawaited(load()));
    final lifecycle = AppLifecycleListener(onResume: () => unawaited(load()));
    ref
      ..onDispose(() {
        // Not awaited: a broadcast cancel only detaches the listener.
        unawaited(pushes.cancel());
        lifecycle.dispose();
      })
      ..listen(realtimeHubProvider, (previous, next) {
        if (previous?.generation != next.generation) unawaited(load());
      });
    unawaited(Future.microtask(load));
    return const PlanListState();
  }

  PlanApi get _api => ref.read(planApiProvider);

  Future<void> load() async {
    final generation = ++_generation;
    final open = list == PlanList.openPositions;
    try {
      final page = await _api.list(
        tab: list.tab,
        pageSize: open ? openPositionsWindow : pageSize,
      );
      if (!ref.mounted || generation != _generation) return;
      _page = 1;
      final items = open
          ? [
              for (final plan in page.items)
                if (plan.positionState == PositionState.open) plan,
            ]
          : page.items;
      state = PlanListState(
        items: items,
        total: open ? items.length : page.total,
      );
    } on ApiFailure catch (failure) {
      if (!ref.mounted || generation != _generation) return;
      state = state.copyWith(failure: failure);
    }
  }

  Future<void> loadMore() async {
    if (list == PlanList.openPositions || !state.hasMore || state.loadingMore) {
      return;
    }
    final generation = _generation;
    state = state.copyWith(loadingMore: true);
    try {
      final page = await _api.list(
        tab: list.tab,
        page: _page + 1,
        pageSize: pageSize,
      );
      if (!ref.mounted || generation != _generation) return;
      _page += 1;
      final known = {for (final p in state.items!) p.id};
      state = state.copyWith(
        items: [
          ...state.items!,
          for (final p in page.items)
            if (!known.contains(p.id)) p,
        ],
        total: page.total,
        loadingMore: false,
        clearFailure: true,
      );
    } on ApiFailure catch (failure) {
      if (!ref.mounted || generation != _generation) return;
      state = state.copyWith(failure: failure, loadingMore: false);
    }
  }
}

/// After an action on a plan, every list on screen reads again.
void refreshPlanLists(Ref ref) {
  for (final list in PlanList.values) {
    if (ref.exists(planListProvider(list))) {
      unawaited(ref.read(planListProvider(list).notifier).load());
    }
  }
}
