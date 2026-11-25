import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/message_text.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/cp_colors.dart';
import '../../market/domain/candle.dart';
import '../application/candles_controller.dart';
import '../application/chart_prefs.dart';
import '../application/drawing_board_controller.dart';
import '../domain/chart_indicators.dart';
import '../domain/chart_time.dart';
import 'chart_surface.dart';

/// The candle chart of one pair and timeframe, shared by analysis and, later,
/// plans and paper trading (ADR-012 / D-144). It pushes what the candles
/// controller holds to the chart page: the whole list on a reset or when
/// older candles go in front, one candle per kline otherwise.
///
/// With [drawingPairId] it also shows the Trader's drawings of that pair
/// (D-149, T-153): read-only, or drawn by touch when [editable] (the Chart
/// screen, which fills its space with [expand] on a page of its own).
class ChartView extends ConsumerStatefulWidget {
  const ChartView({
    required this.candleKey,
    required this.precision,
    this.indicators = ChartIndicator.defaults,
    this.lines = const [],
    this.drawingPairId,
    this.editable = false,
    this.expand = false,
    this.surface,
    super.key,
  });

  final CandleKey candleKey;
  final int precision;
  final Set<ChartIndicator> indicators;
  final List<ChartPriceLine> lines;
  final String? drawingPairId;
  final bool editable;
  final bool expand;

  /// The page to draw on; the app's shared one when null.
  final ChartSurface? surface;

  /// The price pane plus one band per panel (Volume, RSI, MACD).
  static double heightFor(Set<ChartIndicator> indicators) =>
      300 +
      80.0 *
          indicators.where((i) => !ChartIndicator.overlays.contains(i)).length;

  @override
  ConsumerState<ChartView> createState() => _ChartViewState();
}

class _ChartViewState extends ConsumerState<ChartView> {
  late final ChartSurface _surface =
      widget.surface ?? ref.read(chartSurfaceProvider);
  StreamSubscription<String>? _requests;
  StreamSubscription<DrawingEvent>? _drawingEvents;
  DrawingLayerState? _layer;
  ChartTheme? _theme;
  int _closedCount = -1;

  /// Counts the candle lists sent to the page. A list waits until the
  /// page painted it; when a newer one went meanwhile (the fresh candles
  /// after the cached ones, or another timeframe), the older one must not
  /// send its indicators any more: their times would join the time scale
  /// of the newer candles and move what the Trader sees away from the
  /// latest candle.
  int _lists = 0;

  /// What the axis adds to UTC for this timeframe (BR-08).
  Duration get _offset =>
      chartOffset(widget.candleKey.tf, ref.read(chartZoneProvider));

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
    _drawingEvents = _surface.drawingEvents.listen(_onDrawing);
    unawaited(_surface.setTimeOffset(_offset.inSeconds));
    unawaited(_surface.setBarSeconds(widget.candleKey.tf.step.inSeconds));
    unawaited(_surface.setPrecision(widget.precision));
    unawaited(_surface.setLines(widget.lines));
    // A chart without drawings does not show those of an earlier pair.
    if (widget.drawingPairId == null) _pushLayer(DrawingLayerState.none);
    // Candles already held (the provider outlived an earlier chart).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = ref.read(candlesControllerProvider(widget.candleKey));
      if (state.candles != null) unawaited(_push(state));
      final pairId = widget.drawingPairId;
      if (pairId != null) _pushBoard(ref.read(drawingBoardProvider(pairId)));
    });
  }

  @override
  void dispose() {
    unawaited(_requests?.cancel());
    unawaited(_drawingEvents?.cancel());
    super.dispose();
  }

  void _pushLayer(DrawingLayerState layer) {
    if (layer == _layer) return;
    _layer = layer;
    unawaited(_surface.setDrawingLayer(layer));
  }

  void _pushBoard(DrawingBoardState board) {
    final editable = widget.editable;
    final options = board.options;
    _pushLayer(
      DrawingLayerState(
        drawings: board.shown,
        magnet: options.magnet,
        stayInDrawing: options.stayInDrawing,
        lockAll: options.lockAll,
        hideAll: options.hideAll,
        tool: editable ? board.tool : null,
        editable: editable,
        selectedId: editable ? board.selectedId : null,
      ),
    );
  }

  /// What the Trader did on the page goes to the board, which saves it.
  void _onDrawing(DrawingEvent event) {
    final pairId = widget.drawingPairId;
    if (pairId == null || !widget.editable || !mounted) return;
    final board = ref.read(drawingBoardProvider(pairId).notifier);
    switch (event) {
      case DrawingPlaced(:final draft):
        board.placed(draft);
      case DrawingMoved(:final id, :final points):
        board.moved(id, points);
      case DrawingRemoved(:final id):
        board.removed(id);
      case DrawingSelected(:final id):
        board.selected(id);
      case DrawingToolDone():
        board.toolDone();
    }
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
      // What the old timeframe still has under way is out of date.
      _lists++;
      // Before the candles of the new timeframe go to the page.
      unawaited(_surface.setTimeOffset(_offset.inSeconds));
      unawaited(_surface.setBarSeconds(widget.candleKey.tf.step.inSeconds));
    }
    final pairId = widget.drawingPairId;
    if (pairId == null) {
      if (old.drawingPairId != null) _pushLayer(DrawingLayerState.none);
    } else if (old.drawingPairId != pairId || old.editable != widget.editable) {
      _pushBoard(ref.read(drawingBoardProvider(pairId)));
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
        final list = ++_lists;
        await _surface.setCandles(candles);
        if (list != _lists) return;
      case CandleChange.prepend:
        final list = ++_lists;
        await _surface.setCandles(candles, shift: state.prepended);
        if (list != _lists) return;
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
    final pairId = widget.drawingPairId;
    if (pairId != null) {
      ref.listen(drawingBoardProvider(pairId), (_, next) => _pushBoard(next));
    }
    final state = ref.watch(candlesControllerProvider(widget.candleKey));
    final first = state.candles == null || state.candles!.isEmpty;

    final chart = SizedBox(
      key: const Key('chart-view'),
      height: widget.expand ? null : ChartView.heightFor(widget.indicators),
      child: Stack(
        children: [
          Positioned.fill(child: _surface.view(fullScreen: widget.expand)),
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
    return Column(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.expand) Expanded(child: chart) else chart,
        // The axis has no zone of its own: say which one it shows.
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            l.chartTimeZone(zoneLabel(_offset)),
            key: const Key('chart-zone'),
            textAlign: TextAlign.end,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: context.cp.muted),
          ),
        ),
      ],
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
