import 'dart:async';

import 'package:cryptopilot_mobile/core/errors/api_failure.dart';
import 'package:cryptopilot_mobile/core/errors/api_problem.dart';
import 'package:cryptopilot_mobile/features/chart/data/chart_drawing_api.dart';
import 'package:cryptopilot_mobile/features/chart/domain/drawing.dart';
import 'package:cryptopilot_mobile/features/chart/presentation/chart_surface.dart';
import 'package:cryptopilot_mobile/features/chart/presentation/metric_surface.dart';
import 'package:cryptopilot_mobile/features/market/domain/candle.dart';
import 'package:flutter/material.dart';

/// The chart page as the widgets see it, without a WebView (ADR-012: widget
/// tests cannot draw one). Records every call.
class FakeChartSurface implements ChartSurface {
  final List<String> calls = [];
  final _requests = StreamController<String>.broadcast();
  int warms = 0;
  List<Candle>? candles;
  Map<String, Object?>? indicators;
  List<ChartPriceLine> lines = const [];
  ChartTheme? theme;
  DrawingLayerState layer = DrawingLayerState.none;
  final _drawingEvents = StreamController<DrawingEvent>.broadcast();
  bool? fullScreen;

  /// The Trader did something on the drawing layer.
  void draw(DrawingEvent event) => _drawingEvents.add(event);

  /// How long the page takes to paint a list of candles (the WebView
  /// answers after two frames).
  Duration paintTime = Duration.zero;

  /// The page asks for older candles (the Trader reached the left edge).
  void askMore() => _requests.add('more');

  @override
  Future<void> warm() async => warms++;

  @override
  Stream<String> get requests => _requests.stream;

  @override
  Future<void> setTheme(ChartTheme theme) async {
    this.theme = theme;
    calls.add('theme');
  }

  @override
  Future<void> setPrecision(int digits) async => calls.add('precision $digits');

  @override
  Future<void> setTimeOffset(int seconds) async => calls.add('offset $seconds');

  @override
  Future<void> setCandles(List<Candle> candles, {int shift = 0}) async {
    this.candles = candles;
    calls.add('candles ${candles.length} shift $shift');
    if (paintTime > Duration.zero) await Future<void>.delayed(paintTime);
  }

  @override
  Future<void> update(Candle candle) async =>
      calls.add('update ${candle.close}${candle.closed ? '' : ' forming'}');

  @override
  Future<void> setIndicators(Map<String, Object?> payload) async {
    indicators = payload;
    calls.add('indicators');
  }

  @override
  Future<void> setLines(List<ChartPriceLine> lines) async {
    this.lines = lines;
    calls.add('lines ${lines.length}');
  }

  @override
  Future<void> setBarSeconds(int seconds) async =>
      calls.add('barSeconds $seconds');

  @override
  Future<void> setDrawingLayer(DrawingLayerState layer) async {
    this.layer = layer;
    calls.add('drawings ${layer.drawings.length}');
  }

  @override
  Future<void> cancelDrawing() async => calls.add('cancelDrawing');

  @override
  Stream<DrawingEvent> get drawingEvents => _drawingEvents.stream;

  @override
  Widget view({bool fullScreen = false}) {
    this.fullScreen = fullScreen;
    return const SizedBox.expand(key: Key('chart-surface'));
  }
}

/// The metric chart page (SCR-11) without a WebView. Keeps every payload.
class FakeMetricSurface implements MetricSurface {
  final List<String> calls = [];
  final List<Map<String, Object?>> payloads = [];
  int warms = 0;
  ChartTheme? theme;

  /// The lines of the last payload.
  List<Map<String, Object?>> get lines =>
      (payloads.last['lines']! as List).cast<Map<String, Object?>>();

  @override
  Future<void> warm() async => warms++;

  @override
  Future<void> setTheme(ChartTheme theme) async {
    this.theme = theme;
    calls.add('theme');
  }

  @override
  Future<void> setLines(Map<String, Object?> payload) async {
    payloads.add(payload);
    calls.add('lines ${(payload['lines']! as List).length}');
  }

  @override
  Widget view() => const SizedBox.expand(key: Key('metric-surface'));
}

/// [count] closed candles one [step] apart, ending before [end]; closes rise
/// by 1 from [first].
List<Candle> candleRun(
  int count, {
  DateTime? end,
  Duration step = const Duration(hours: 1),
  double first = 100,
}) {
  final last = end ?? DateTime.utc(2026, 11, 6, 12);
  return [
    for (var i = 0; i < count; i++)
      () {
        final close = first + i;
        return Candle(
          openTime: last.subtract(step * (count - i)),
          open: (close - 0.5).toStringAsFixed(2),
          high: (close + 1).toStringAsFixed(2),
          low: (close - 1).toStringAsFixed(2),
          close: close.toStringAsFixed(2),
          quoteVolume: (1000 + i).toStringAsFixed(2),
        );
      }(),
  ];
}

/// `/chart-layouts` and `/chart-drawings` in memory, as the backend keeps
/// them (T-119): copies numbered with the smallest free number, a version
/// per drawing checked on every update.
class FakeChartDrawingApi implements ChartDrawingApi {
  final List<ChartLayout> layoutRows = [];
  final Map<String, List<ChartDrawing>> drawingRows = {};
  final List<String> calls = [];
  int _ids = 0;

  /// Thrown by the next write (create, update, remove, removeAll), once.
  ApiFailure? failNextWrite;

  /// Thrown by every read while set.
  ApiFailure? failReads;

  /// Holds each create until completed, to test two quick drawings.
  Completer<void>? holdCreates;

  static ApiFailure problem(String code, {int status = 409}) => ProblemFailure(
    ApiProblem(status: status, code: code, messageCode: 'MSG43'),
  );

  ChartLayout addLayout(String pairId, {String? name}) {
    final used = {for (final l in layoutRows) l.number};
    var number = 1;
    while (used.contains(number)) {
      number++;
    }
    final layout = ChartLayout(
      id: 'layout-${++_ids}',
      pairId: pairId,
      number: number,
      name: name,
      drawings: 0,
    );
    layoutRows.add(layout);
    drawingRows[layout.id] = [];
    return layout;
  }

  ChartDrawing addDrawing(String layoutId, DrawingDraft draft) {
    final drawing = ChartDrawing(
      id: 'drawing-${++_ids}',
      layoutId: layoutId,
      type: draft.type,
      change: draft.change,
      version: 0,
    );
    drawingRows[layoutId]!.add(drawing);
    return drawing;
  }

  void _write(String call) {
    calls.add(call);
    final failure = failNextWrite;
    failNextWrite = null;
    if (failure != null) throw failure;
  }

  ChartLayout _counted(ChartLayout layout) =>
      layout.copyWith(drawings: drawingRows[layout.id]?.length ?? 0);

  @override
  Future<List<ChartLayout>> layouts(String pairId) async {
    calls.add('layouts $pairId');
    if (failReads != null) throw failReads!;
    return [
      for (final layout in layoutRows)
        if (layout.pairId == pairId) _counted(layout),
    ]..sort((a, b) => a.number.compareTo(b.number));
  }

  @override
  Future<ChartLayout> createLayout(String pairId, {String? copyFrom}) async {
    _write('createLayout${copyFrom == null ? '' : ' from $copyFrom'}');
    if (layoutRows.where((l) => l.pairId == pairId).length >=
        ChartLayout.maxPerPair) {
      throw problem('CHART_LAYOUT_LIMIT_REACHED');
    }
    final layout = addLayout(pairId);
    if (copyFrom != null) {
      for (final drawing in [...?drawingRows[copyFrom]]) {
        addDrawing(
          layout.id,
          DrawingDraft(type: drawing.type, change: drawing.change),
        );
      }
    }
    return _counted(layout);
  }

  @override
  Future<ChartLayout> renameLayout(String id, String? name) async {
    _write('rename $id $name');
    final i = layoutRows.indexWhere((l) => l.id == id);
    layoutRows[i] = name == null
        ? layoutRows[i].copyWith(clearName: true)
        : layoutRows[i].copyWith(name: name);
    return _counted(layoutRows[i]);
  }

  @override
  Future<void> removeLayout(String id) async {
    _write('removeLayout $id');
    layoutRows.removeWhere((l) => l.id == id);
    drawingRows.remove(id);
  }

  @override
  Future<List<ChartDrawing>> drawings(String layoutId) async {
    calls.add('drawings $layoutId');
    if (failReads != null) throw failReads!;
    return [...?drawingRows[layoutId]];
  }

  @override
  Future<ChartDrawing> create(String layoutId, DrawingDraft draft) async {
    _write('create ${draft.type}');
    await holdCreates?.future;
    if (drawingRows[layoutId]!.length >= ChartLayout.maxDrawings) {
      throw problem('CHART_DRAWING_LIMIT_REACHED');
    }
    return addDrawing(layoutId, draft);
  }

  @override
  Future<ChartDrawing> update(
    String id,
    int version,
    DrawingChange change,
  ) async {
    _write('update $id v$version');
    for (final list in drawingRows.values) {
      final i = list.indexWhere((d) => d.id == id);
      if (i < 0) continue;
      if (list[i].version != version) throw problem('CONFLICT');
      list[i] = ChartDrawing(
        id: id,
        layoutId: list[i].layoutId,
        type: list[i].type,
        change: change,
        version: version + 1,
      );
      return list[i];
    }
    throw problem('NOT_FOUND', status: 404);
  }

  @override
  Future<void> remove(String id) async {
    _write('remove $id');
    for (final list in drawingRows.values) {
      list.removeWhere((d) => d.id == id);
    }
  }

  @override
  Future<void> removeAll(String layoutId) async {
    _write('removeAll $layoutId');
    drawingRows[layoutId]?.clear();
  }
}
