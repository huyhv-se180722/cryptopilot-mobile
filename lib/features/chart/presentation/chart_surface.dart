import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/theme/cp_colors.dart';
import '../../market/domain/candle.dart';
import '../domain/drawing.dart';
import '../domain/drawing_tools.dart';

/// A horizontal line on the price axis: BR-14 support and resistance now;
/// plan entry, stop loss and take profit later (cp-paper-trading-boundary:
/// the chart knows prices and labels, never plans or orders).
@immutable
class ChartPriceLine {
  const ChartPriceLine({
    required this.price,
    required this.label,
    required this.color,
  });

  /// A decimal string; only the page turns it into a number, to draw.
  final String price;
  final String label;
  final Color color;

  @override
  bool operator ==(Object other) =>
      other is ChartPriceLine &&
      other.price == price &&
      other.label == label &&
      other.color == color;

  @override
  int get hashCode => Object.hash(price, label, color);
}

/// The theme tokens the page draws with.
@immutable
class ChartTheme {
  const ChartTheme({
    required this.bg,
    required this.text,
    required this.grid,
    required this.up,
    required this.down,
    this.accent = '#2962FF',
  });

  factory ChartTheme.of(CpColors cp) => ChartTheme(
    bg: _rgba(cp.surface),
    text: _rgba(cp.muted),
    grid: _rgba(cp.border),
    up: _hex(cp.positive),
    down: _hex(cp.negative),
    accent: _hex(cp.primary),
  );

  final String bg;
  final String text;
  final String grid;

  /// `#RRGGBB`: the page adds an alpha for faded candles and volume.
  final String up;
  final String down;

  /// The handles of the selected drawing.
  final String accent;

  Map<String, Object?> toJson() => {
    'bg': bg,
    'text': text,
    'grid': grid,
    'up': up,
    'down': down,
    'accent': accent,
  };

  @override
  bool operator ==(Object other) =>
      other is ChartTheme &&
      other.bg == bg &&
      other.text == text &&
      other.grid == grid &&
      other.up == up &&
      other.down == down &&
      other.accent == accent;

  @override
  int get hashCode => Object.hash(bg, text, grid, up, down, accent);
}

/// What the drawing layer of the page holds (D-149, T-153). The page passes
/// on only what changed, so sending it again keeps a drawing being placed.
@immutable
class DrawingLayerState {
  const DrawingLayerState({
    this.drawings = const [],
    this.magnet = false,
    this.stayInDrawing = false,
    this.lockAll = false,
    this.hideAll = false,
    this.tool,
    this.editable = false,
    this.selectedId,
  });

  static const none = DrawingLayerState();

  final List<ChartDrawing> drawings;
  final bool magnet;
  final bool stayInDrawing;
  final bool lockAll;
  final bool hideAll;
  final DrawingTool? tool;

  /// Off, the layer only paints (the analysis card); on, touch draws.
  final bool editable;
  final String? selectedId;

  Map<String, Object?> toJson() => {
    'drawings': [for (final drawing in drawings) drawing.toJson()],
    'options': {
      'magnet': magnet,
      'stayInDrawing': stayInDrawing,
      'lockAll': lockAll,
      'hideAll': hideAll,
    },
    'tool': tool?.name,
    'editable': editable,
    'selected': selectedId,
  };

  @override
  bool operator ==(Object other) =>
      other is DrawingLayerState &&
      listEquals(other.drawings, drawings) &&
      other.magnet == magnet &&
      other.stayInDrawing == stayInDrawing &&
      other.lockAll == lockAll &&
      other.hideAll == hideAll &&
      other.tool == tool &&
      other.editable == editable &&
      other.selectedId == selectedId;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(drawings),
    magnet,
    stayInDrawing,
    lockAll,
    hideAll,
    tool,
    editable,
    selectedId,
  );
}

/// What the Trader did on the drawing layer; the app saves it.
sealed class DrawingEvent {
  const DrawingEvent();

  /// null for a message that is not the layer's or does not decode.
  static DrawingEvent? fromJson(Map<String, Object?> json) {
    try {
      return switch (json['type']) {
        'drawing.create' ||
        'drawing.text' => DrawingPlaced(DrawingDraft.fromJson(json['draft'])),
        'drawing.change' => DrawingMoved(json['id']! as String, [
          for (final point in json['points']! as List)
            DrawingPoint.fromJson(point),
        ]),
        'drawing.remove' => DrawingRemoved(json['id']! as String),
        'drawing.select' => DrawingSelected(json['id'] as String?),
        'drawing.toolDone' => const DrawingToolDone(),
        _ => null,
      };
    } on Object catch (error) {
      debugPrint('chart page: drawing event not read: $error');
      return null;
    }
  }
}

/// A drawing was placed (a text one still needs its text).
class DrawingPlaced extends DrawingEvent {
  const DrawingPlaced(this.draft);

  final DrawingDraft draft;
}

/// A drawing was dragged, whole or by one anchor.
class DrawingMoved extends DrawingEvent {
  const DrawingMoved(this.id, this.points);

  final String id;
  final List<DrawingPoint> points;
}

class DrawingRemoved extends DrawingEvent {
  const DrawingRemoved(this.id);

  final String id;
}

class DrawingSelected extends DrawingEvent {
  const DrawingSelected(this.id);

  final String? id;
}

/// The tool was put down after a drawing was finished.
class DrawingToolDone extends DrawingEvent {
  const DrawingToolDone();
}

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

String _rgba(Color c) {
  final argb = c.toARGB32();
  return 'rgba(${(argb >> 16) & 0xFF},${(argb >> 8) & 0xFF},${argb & 0xFF},'
      '${((argb >> 24) & 0xFF) / 255})';
}

/// Where the chart draws (ADR-012 / D-144). Widget tests use a fake: a
/// WebView cannot be drawn there.
abstract interface class ChartSurface {
  /// Starts the page once; the shell calls it early (ADR-012 item 2).
  Future<void> warm();

  /// `more`: the Trader reached the left edge.
  Stream<String> get requests;

  Future<void> setTheme(ChartTheme theme);

  /// Decimals of the pair's tick size.
  Future<void> setPrecision(int digits);

  /// Seconds added to every time the page draws (BR-08: the library draws
  /// UTC only); set before the candles it applies to.
  Future<void> setTimeOffset(int seconds);

  /// Completes once the page painted them; [shift] keeps the visible range
  /// after older candles went in front.
  Future<void> setCandles(List<Candle> candles, {int shift = 0});

  /// The forming candle or the one that just closed.
  Future<void> update(Candle candle);

  /// `indicatorPayload` of the candles on the page.
  Future<void> setIndicators(Map<String, Object?> payload);

  Future<void> setLines(List<ChartPriceLine> lines);

  /// Seconds of one candle of the timeframe shown, so drawings can sit right
  /// of the last candle; set before its candles.
  Future<void> setBarSeconds(int seconds);

  Future<void> setDrawingLayer(DrawingLayerState layer);

  /// Drops the anchors placed so far, then the tool, then the selection.
  Future<void> cancelDrawing();

  Stream<DrawingEvent> get drawingEvents;

  /// [fullScreen]: the chart takes every gesture (no screen scrolls around
  /// it), so a finger can draw in any direction.
  Widget view({bool fullScreen = false});
}

/// TradingView Lightweight Charts in one WebView kept for the whole app,
/// loaded from asset files (ADR-012 item 1).
class WebViewChartSurface implements ChartSurface {
  WebViewController? _web;
  Future<void>? _ready;
  final _events = StreamController<Map<String, Object?>>.broadcast();
  int _tag = 0;

  @override
  Stream<String> get requests => _events.stream
      .where((e) => e['type'] == 'more')
      .map((e) => e['type']! as String);

  @override
  Stream<DrawingEvent> get drawingEvents => _events.stream
      .map(DrawingEvent.fromJson)
      .where((e) => e != null)
      .cast<DrawingEvent>();

  @override
  Future<void> warm() => _ready ??= _start();

  Future<void> _start() async {
    final loaded = Completer<void>();
    final web = WebViewController();
    await web.setJavaScriptMode(JavaScriptMode.unrestricted);
    await web.setBackgroundColor(const Color(0x00000000));
    await web.addJavaScriptChannel('Host', onMessageReceived: _onMessage);
    await web.setNavigationDelegate(
      NavigationDelegate(
        onPageFinished: (_) {
          if (!loaded.isCompleted) loaded.complete();
        },
      ),
    );
    _web = web;
    await web.loadFlutterAsset('assets/chart/chart.html');
    await loaded.future;
    final ready = _events.stream.firstWhere((e) => e['type'] == 'ready');
    final dark =
        PlatformDispatcher.instance.platformBrightness == Brightness.dark;
    final theme = ChartTheme.of(dark ? CpColors.dark : CpColors.light);
    await web.runJavaScript('init(${jsonEncode(theme.toJson())})');
    await ready;
  }

  void _onMessage(JavaScriptMessage message) {
    final Object? decoded;
    try {
      decoded = jsonDecode(message.message);
    } on FormatException {
      return;
    }
    if (decoded is! Map<String, Object?>) return;
    if (decoded['type'] == 'log') debugPrint('chart page: ${decoded['msg']}');
    _events.add(decoded);
  }

  Future<void> _run(String script) async {
    await warm();
    await _web!.runJavaScript(script);
  }

  @override
  Future<void> setTheme(ChartTheme theme) =>
      _run('setTheme(${jsonEncode(theme.toJson())})');

  @override
  Future<void> setPrecision(int digits) => _run('setPrecision($digits)');

  @override
  Future<void> setTimeOffset(int seconds) => _run('setTimeOffset($seconds)');

  @override
  Future<void> setCandles(List<Candle> candles, {int shift = 0}) async {
    await warm();
    final tag = ++_tag;
    final painted = _events.stream
        .firstWhere((e) => e['type'] == 'rendered' && e['tag'] == tag)
        // A page not on screen does not paint; never wait for ever.
        .timeout(const Duration(seconds: 5), onTimeout: () => const {});
    await _web!.runJavaScript(
      'setCandles(${jsonEncode([for (final c in candles) c.toJson()])}, '
      '$tag, $shift)',
    );
    await painted;
  }

  @override
  Future<void> update(Candle candle) =>
      _run('update(${jsonEncode(candle.toJson())})');

  @override
  Future<void> setIndicators(Map<String, Object?> payload) =>
      _run('setIndicators(${jsonEncode(payload)})');

  @override
  Future<void> setLines(List<ChartPriceLine> lines) => _run(
    'setLines(${jsonEncode([
      for (final l in lines) {'price': l.price, 'label': l.label, 'color': _hex(l.color)},
    ])})',
  );

  @override
  Future<void> setBarSeconds(int seconds) => _run('setBarSeconds($seconds)');

  @override
  Future<void> setDrawingLayer(DrawingLayerState layer) =>
      _run('setDrawingLayer(${jsonEncode(layer.toJson())})');

  @override
  Future<void> cancelDrawing() => _run('cancelDrawing()');

  @override
  Widget view({bool fullScreen = false}) {
    final web = _web;
    if (web == null) return const SizedBox.expand();
    return WebViewWidget(
      controller: web,
      gestureRecognizers: fullScreen
          ? const {Factory<EagerGestureRecognizer>(EagerGestureRecognizer.new)}
          // Horizontal drags and pinches go to the chart; a vertical drag
          // scrolls the screen around it.
          : const {
              Factory<HorizontalDragGestureRecognizer>(
                HorizontalDragGestureRecognizer.new,
              ),
              Factory<ScaleGestureRecognizer>(ScaleGestureRecognizer.new),
            },
    );
  }
}

/// One page for the whole app (ADR-012 item 2).
final chartSurfaceProvider = Provider<ChartSurface>(
  (ref) => WebViewChartSurface(),
);

/// The page of the Chart screen (T-153): a second one, so the analysis card
/// under it keeps its own; started when the screen opens.
final fullChartSurfaceProvider = Provider.autoDispose<ChartSurface>(
  (ref) => WebViewChartSurface(),
);
