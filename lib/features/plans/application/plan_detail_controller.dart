import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/realtime/realtime_hub.dart';
import '../../../core/state/load_after_build.dart';
import '../data/plan_detail_api.dart';
import '../domain/plan_detail.dart';
import 'plan_lists.dart';

@immutable
class PlanDetailState {
  const PlanDetailState({this.plan, this.failure, this.busy = false});

  /// Null until first read.
  final PlanDetail? plan;

  /// Reading the plan failed.
  final ApiFailure? failure;

  /// An action is on its way.
  final bool busy;

  /// No such plan of the caller (404 MSG41).
  bool get missing =>
      failure is ProblemFailure &&
      (failure! as ProblemFailure).problem.messageCode == 'MSG41';
}

/// What Activate did (SRS 3.5.3, BR-69).
sealed class ActivateOutcome {
  const ActivateOutcome();
}

/// The plan is ACTIVE, or EXECUTED for a MARKET entry (MSG19).
class Activated extends ActivateOutcome {
  const Activated();
}

/// 400 MSG51: the MARKET entry moved; ask, then activate with the
/// confirmation.
class NeedsConfirmation extends ActivateOutcome {
  const NeedsConfirmation(this.failure);

  final ProblemFailure failure;
}

/// Refused: MSG18, MSG27, MSG29, MSG52, MSG43 …
class ActivateRefused extends ActivateOutcome {
  const ActivateRefused(this.failure);

  final ApiFailure failure;
}

final planDetailControllerProvider = NotifierProvider.autoDispose
    .family<PlanDetailController, PlanDetailState, String>(
      PlanDetailController.new,
    );

/// SCR-18 (UC-18, UC-19, UC-21). Every figure is the server one, as on the
/// web: the plan is read again when its position changes
/// (`/user/queue/positions`), after a reconnection, when the app comes back,
/// and every [pollEvery] while an OPEN position is on screen (its current
/// price and unrealized P/L).
class PlanDetailController extends Notifier<PlanDetailState> {
  PlanDetailController(this.id);

  static const pollEvery = Duration(seconds: 10);

  final String id;
  Timer? _poll;
  int _generation = 0;

  @override
  PlanDetailState build() {
    final pushes = ref
        .read(realtimeHubProvider.notifier)
        .watch(positionsQueue)
        .listen(_onPush);
    final lifecycle = AppLifecycleListener(onResume: () => unawaited(load()));
    ref
      ..onDispose(() {
        _poll?.cancel();
        _poll = null;
        // Not awaited: a broadcast cancel only detaches the listener.
        unawaited(pushes.cancel());
        lifecycle.dispose();
      })
      ..listen(realtimeHubProvider, (previous, next) {
        if (previous?.generation != next.generation) unawaited(load());
      });
    listenSelf(
      (_, next) => _pollWhile(open: next.plan?.hasOpenPosition ?? false),
    );
    ref.loadAfterBuild(load);
    return const PlanDetailState();
  }

  PlanDetailApi get _api => ref.read(planDetailApiProvider);

  Future<void> load() async {
    final generation = ++_generation;
    try {
      final plan = await _api.plan(id);
      if (!ref.mounted || generation != _generation) return;
      state = PlanDetailState(plan: plan, busy: state.busy);
    } on ApiFailure catch (failure) {
      if (!ref.mounted || generation != _generation) return;
      state = PlanDetailState(
        plan: state.plan,
        failure: failure,
        busy: state.busy,
      );
    }
  }

  void _onPush(Object? body) {
    final String planId;
    try {
      planId = decodePositionUpdate(body).planId;
    } on Exception {
      unawaited(load());
      return;
    }
    if (planId == id) unawaited(load());
  }

  void _pollWhile({required bool open}) {
    if (!open) {
      _poll?.cancel();
      _poll = null;
    } else {
      _poll ??= Timer.periodic(pollEvery, (_) => unawaited(load()));
    }
  }

  Future<T> _act<T>(Future<T> Function() action) async {
    state = PlanDetailState(plan: state.plan, busy: true);
    try {
      return await action();
    } finally {
      if (ref.mounted) {
        state = PlanDetailState(plan: state.plan);
      }
    }
  }

  void _shown(PlanDetail plan) {
    if (!ref.mounted) return;
    ++_generation;
    state = PlanDetailState(plan: plan, busy: state.busy);
    refreshPlanLists(ref);
  }

  /// [confirmDeviation] after the Trader accepted MSG51.
  Future<ActivateOutcome> activate({bool confirmDeviation = false}) =>
      _act(() async {
        try {
          _shown(await _api.activate(id, confirmDeviation: confirmDeviation));
          return const Activated();
        } on ProblemFailure catch (failure) {
          if (failure.code == 'ENTRY_DEVIATION_CONFIRMATION_REQUIRED' &&
              !confirmDeviation) {
            return NeedsConfirmation(failure);
          }
          return ActivateRefused(failure);
        } on ApiFailure catch (failure) {
          return ActivateRefused(failure);
        }
      });

  /// After MSG20. Throws [ApiFailure] (MSG43, MSG41).
  Future<void> cancel() => _act(() async => _shown(await _api.cancel(id)));

  /// After SCR-19. Throws [ApiFailure]; on MSG43 (closed first by the
  /// engine) the plan is read again.
  Future<void> closePosition() => _act(() async {
    try {
      _shown(await _api.closePosition(id));
    } on ApiFailure {
      unawaited(load());
      rethrow;
    }
  });

  /// Throws [ApiFailure]: field errors MSG15, MSG16 on `stopLoss` or
  /// `takeProfit`, MSG43. The answer carries the non-blocking level warnings.
  Future<PlanDetail> changeLevels({String? stopLoss, String? takeProfit}) =>
      _act(() async {
        final plan = await _api.changeLevels(
          id,
          stopLoss: stopLoss,
          takeProfit: takeProfit,
        );
        _shown(plan);
        return plan;
      });
}

@immutable
class CloseEstimateState {
  const CloseEstimateState({this.estimate, this.failure});

  final CloseEstimate? estimate;
  final ApiFailure? failure;
}

final closeEstimateProvider = NotifierProvider.autoDispose
    .family<CloseEstimateController, CloseEstimateState, String>(
      CloseEstimateController.new,
    );

/// SCR-19: the estimate of closing now, read again every [refreshEvery]
/// while the sheet is open, as the web does.
class CloseEstimateController extends Notifier<CloseEstimateState> {
  CloseEstimateController(this.id);

  static const refreshEvery = Duration(seconds: 5);

  final String id;

  @override
  CloseEstimateState build() {
    final timer = Timer.periodic(refreshEvery, (_) => unawaited(load()));
    ref.onDispose(timer.cancel);
    ref.loadAfterBuild(load);
    return const CloseEstimateState();
  }

  Future<void> load() async {
    try {
      final estimate = await ref.read(planDetailApiProvider).closeEstimate(id);
      if (ref.mounted) state = CloseEstimateState(estimate: estimate);
    } on ApiFailure catch (failure) {
      if (ref.mounted) {
        state = CloseEstimateState(estimate: state.estimate, failure: failure);
      }
    }
  }
}
