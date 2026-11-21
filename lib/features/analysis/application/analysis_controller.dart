import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/errors/api_failure.dart';
import '../../../core/realtime/realtime_hub.dart';
import '../../../core/state/load_after_build.dart';
import '../../../core/state/poll_gate.dart';
import '../../market/data/market_repository.dart';
import '../../market/domain/candle.dart';
import '../../market/domain/market.dart';
import '../data/analysis_api.dart';
import '../domain/analysis.dart';

typedef AnalysisKey = ({Market market, String symbol, Timeframe tf});

@immutable
class AnalysisState {
  const AnalysisState({this.analysis, this.failure, this.ticker});

  final Analysis? analysis;

  /// MSG29 (Futures on a plan without FUTURES_ANALYSIS), MSG41 (pair no
  /// longer enabled), MSG43 and the network ones.
  final ApiFailure? failure;

  /// Live statistics of [PairTickerRepository]: REST first, then
  /// `/topic/ticker.{M}.{S}`.
  final Ticker? ticker;

  /// SRS 3.3.2: an Admin disabled the pair while it was open.
  bool get pairGone =>
      failure is ProblemFailure &&
      (failure! as ProblemFailure).problem.messageCode == 'MSG41';

  /// SRS 3.3.3: Futures analysis on a plan without it.
  bool get notInPlan =>
      failure is ProblemFailure &&
      (failure! as ProblemFailure).problem.messageCode == 'MSG29';

  AnalysisState copyWith({
    Analysis? analysis,
    ApiFailure? failure,
    bool clearFailure = false,
    Ticker? ticker,
  }) => AnalysisState(
    analysis: analysis ?? this.analysis,
    failure: clearFailure ? null : failure ?? this.failure,
    ticker: ticker ?? this.ticker,
  );
}

final analysisControllerProvider = NotifierProvider.autoDispose
    .family<AnalysisController, AnalysisState, AnalysisKey>(
      AnalysisController.new,
    );

/// SCR-10 / SCR-11 data besides the candles. D-126: the analysis topics are
/// subscribed only once the REST read succeeded — `.components` only when
/// it is not locked — because a SUBSCRIBE the plan does not allow is
/// answered with an ERROR frame that closes the whole STOMP connection. A
/// push carries no score, so the analysis is read again by REST.
class AnalysisController extends Notifier<AnalysisState> {
  AnalysisController(this.key);

  final AnalysisKey key;
  final List<StreamSubscription<Object?>> _subs = [];
  bool _analysisTopics = false;
  bool _componentsTopic = false;
  bool _reading = false;

  String get _base =>
      '/topic/analysis.${key.market.wire}.${key.symbol}.${key.tf.wire}';

  @override
  AnalysisState build() {
    final pair = pairTickerProvider((market: key.market, symbol: key.symbol));
    ref.listen(pair, (previous, next) {
      if (next.ticker != null && !identical(next.ticker, previous?.ticker)) {
        state = state.copyWith(ticker: next.ticker);
      }
      final failure = next.failure;
      if (failure != null && !identical(failure, previous?.failure)) {
        _fail(failure);
      }
    });
    ref.onDispose(() {
      for (final s in _subs) {
        unawaited(s.cancel());
      }
    });
    ref.loadAfterBuild(load);
    final known = ref.read(pair);
    return AnalysisState(ticker: known.ticker, failure: known.failure);
  }

  void _fail(ApiFailure failure) {
    // Keep what is shown unless the pair is gone or not in the plan.
    if (state.analysis != null &&
        !(failure is ProblemFailure &&
            const {'MSG41', 'MSG29'}.contains(failure.problem.messageCode))) {
      return;
    }
    state = state.copyWith(failure: failure);
  }

  Future<void> load() async {
    if (_reading) return;
    _reading = true;
    try {
      final analysis = await ref
          .read(analysisApiProvider)
          .analysis(key.market, key.symbol, key.tf);
      if (!ref.mounted) return;
      state = state.copyWith(analysis: analysis, clearFailure: true);
      _subscribe(analysis);
    } on ApiFailure catch (failure) {
      if (ref.mounted) _fail(failure);
    } finally {
      _reading = false;
    }
  }

  void _subscribe(Analysis analysis) {
    final hub = ref.read(realtimeHubProvider.notifier);
    if (!_analysisTopics) {
      _analysisTopics = true;
      _subs.add(hub.watch(_base).listen((_) => unawaited(load())));
    }
    if (!_componentsTopic && !analysis.componentsLocked) {
      _componentsTopic = true;
      _subs.add(
        hub.watch('$_base.components').listen((_) => unawaited(load())),
      );
    }
  }
}

/// The ranges of the SCR-11 metric charts, in days (the API allows 7).
const metricRanges = [1, 3, 7];

typedef MetricsKey = ({String symbol, int days});

@immutable
class MetricsState {
  const MetricsState({this.metrics, this.failure});
  final FuturesMetrics? metrics;
  final ApiFailure? failure;
}

final futuresMetricsProvider = NotifierProvider.autoDispose
    .family<FuturesMetricsController, MetricsState, MetricsKey>(
      FuturesMetricsController.new,
    );

/// Open interest and long/short ratio of the last [MetricsKey.days] (SRS
/// 3.3.3, BR-10), read again every 5 minutes: new points are stored that
/// often (NSF-04).
class FuturesMetricsController extends Notifier<MetricsState> {
  FuturesMetricsController(this.key);

  static const refresh = Duration(minutes: 5);

  /// Starting a minute late keeps 7 days inside the limit when the device
  /// clock runs behind the server's.
  static const clockMargin = Duration(minutes: 1);

  final MetricsKey key;

  @override
  MetricsState build() {
    final timer = ref.pollEvery(refresh, () => unawaited(load()));
    ref.onDispose(timer.cancel);
    ref.loadAfterBuild(load);
    return const MetricsState();
  }

  Future<void> load() async {
    final from = ref
        .read(clockProvider)()
        .toUtc()
        .subtract(Duration(days: key.days) - clockMargin);
    try {
      final metrics = await ref
          .read(analysisApiProvider)
          .metrics(key.symbol, from);
      if (ref.mounted) state = MetricsState(metrics: metrics);
    } on ApiFailure catch (failure) {
      if (ref.mounted && state.metrics == null) {
        state = MetricsState(failure: failure);
      }
    }
  }
}
