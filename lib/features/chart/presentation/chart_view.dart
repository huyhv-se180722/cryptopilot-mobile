import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/message_text.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/cp_colors.dart';
import '../../market/domain/candle.dart';
import '../application/candles_controller.dart';
import '../domain/chart_indicators.dart';
import 'chart_surface.dart';

/// The candle chart of one pair and timeframe, shared by analysis and, later,
/// plans and paper trading (ADR-012 / D-144). It pushes what the candles
/// controller holds to the chart page: the whole list on a reset or when
/// older candles go in front, one candle per kline otherwise.
class ChartView extends ConsumerStatefulWidget {
  const ChartView({
    required this.candleKey,
    required this.precision,
    this.indicators = ChartIndicator.defaults,
    this.lines = const [],
    super.key,
  });

  final CandleKey candleKey;
  final int precision;
  final Set<ChartIndicator> indicators;
  final List<ChartPriceLine> lines;

  /// The price pane plus one band per panel (Volume, RSI, MACD).
  static double heightFor(Set<ChartIndicator> indicators) =>
      300 +
      80.0 *
          indicators.where((i) => !ChartIndicator.overlays.contains(i)).length;

  @override
  ConsumerState<ChartView> createState() => _ChartViewState();
}

class _ChartViewState extends ConsumerState<ChartView> {
  ChartSurface get _surface => ref.read(chartSurfaceProvider);
  StreamSubscription<String>? _requests;
  ChartTheme? _theme;
  int _closedCount = -1;

  @override
  void initState() {
    super.initState();
    unawaited(
      _surface.warm().then((_) {
        if (mounted) setState(() {});
      }),
    );
    _requests = _surface.requests.listen((_) {
      unawaited(
        ref
            .read(candlesControllerProvider(widget.candleKey).notifier)
            .loadOlder(),
      );
    });
    unawaited(_surface.setPrecision(widget.precision));
    unawaited(_surface.setLines(widget.lines));
    // Candles already held (the provider outlived an earlier chart).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = ref.read(candlesControllerProvider(widget.candleKey));
      if (state.candles != null) unawaited(_push(state));
    });
  }

  @override
  void dispose() {
    unawaited(_requests?.cancel());
    super.dispose();
  }

  @override
  void didUpdateWidget(ChartView old) {
    super.didUpdateWidget(old);
    if (old.precision != widget.precision) {
      unawaited(_surface.setPrecision(widget.precision));
    }
    if (!_sameLines(old.lines, widget.lines)) {
      unawaited(_surface.setLines(widget.lines));
    }
    final candles = ref
        .read(candlesControllerProvider(widget.candleKey))
        .candles;
    if (old.candleKey != widget.candleKey) {
      _closedCount = -1;
    } else if (!_sameSet(old.indicators, widget.indicators) &&
        candles != null) {
      unawaited(
        _surface.setIndicators(indicatorPayload(candles, widget.indicators)),
      );
    }
  }

  static bool _sameLines(List<ChartPriceLine> a, List<ChartPriceLine> b) =>
      a.length == b.length &&
      [for (var i = 0; i < a.length; i++) a[i] == b[i]].every((same) => same);

  static bool _sameSet(Set<ChartIndicator> a, Set<ChartIndicator> b) =>
      a.length == b.length && a.containsAll(b);

  Future<void> _push(CandlesState state) async {
    final candles = state.candles;
    if (candles == null || candles.isEmpty) return;
    final closed = candles.where((c) => c.closed).length;
    switch (state.change) {
      case CandleChange.reset:
        await _surface.setCandles(candles);
      case CandleChange.prepend:
        await _surface.setCandles(candles, shift: state.prepended);
      case CandleChange.update:
        await _surface.update(candles.last);
        // Indicators move only when a candle closes, not on every tick.
        if (closed == _closedCount) return;
    }
    _closedCount = closed;
    await _surface.setIndicators(indicatorPayload(candles, widget.indicators));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = ChartTheme.of(context.cp);
    if (theme != _theme) {
      _theme = theme;
      unawaited(_surface.setTheme(theme));
    }
    ref.listen(candlesControllerProvider(widget.candleKey), (previous, next) {
      if (!identical(previous?.candles, next.candles)) unawaited(_push(next));
    });
    final state = ref.watch(candlesControllerProvider(widget.candleKey));
    final first = state.candles == null || state.candles!.isEmpty;

    return SizedBox(
      key: const Key('chart-view'),
      height: ChartView.heightFor(widget.indicators),
      child: Stack(
        children: [
          Positioned.fill(child: _surface.view()),
          if (first && state.failure != null)
            Positioned.fill(
              child: ColoredBox(
                color: context.cp.surface,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        failureText(l, state.failure!),
                        textAlign: TextAlign.center,
                      ),
                      TextButton(
                        onPressed: () => ref
                            .read(
                              candlesControllerProvider(
                                widget.candleKey,
                              ).notifier,
                            )
                            .load(),
                        child: Text(l.commonRetry),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (first)
            // Skeleton with the chart's size while the candles come.
            Positioned.fill(
              key: const Key('chart-skeleton'),
              child: ColoredBox(color: context.cp.raised),
            ),
        ],
      ),
    );
  }
}

/// Decimals of a tick size such as `0.01000000` → 2.
int decimalsOf(String? tickSize) {
  if (tickSize == null) return 2;
  final text = tickSize.contains('.')
      ? tickSize.replaceFirst(RegExp(r'0+$'), '')
      : tickSize;
  final dot = text.indexOf('.');
  return dot < 0 ? 0 : text.length - dot - 1;
}

/// The timeframe chips of SRS 3.3.2 (BR-08).
const chartTimeframes = Timeframe.values;
