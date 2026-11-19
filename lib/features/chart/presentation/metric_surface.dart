import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/theme/cp_colors.dart';
import 'chart_surface.dart';

/// The axis a line is read on: two units can share one chart.
enum MetricScale { left, right }

/// How the axis writes a line's values: amounts in K / M / B, ratios at
/// four decimals.
enum MetricFormat { amount, ratio }

/// One line of a metric chart (SCR-11: open interest, its value, the
/// long/short ratio). Values stay decimal strings; only the page turns them
/// into numbers, to draw.
@immutable
class MetricLine {
  const MetricLine({
    required this.color,
    required this.scale,
    required this.format,
    required this.points,
  });

  final Color color;
  final MetricScale scale;
  final MetricFormat format;

  /// Oldest first; sparse, never filled in (D-45).
  final List<(DateTime, String)> points;
}

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// What the page draws: every time in seconds, moved by [offset] on the
/// page (BR-08: the library draws UTC only). The library needs times that
/// rise, so a point that does not come after the one before it is left out.
Map<String, Object?> metricPayload(List<MetricLine> lines, Duration offset) => {
  'offset': offset.inSeconds,
  'lines': [
    for (final line in lines)
      {
        'color': _hex(line.color),
        'scale': line.scale.name,
        'format': line.format.name,
        'points': () {
          final points = <List<Object>>[];
          int? last;
          for (final (time, value) in line.points) {
            final seconds = time.millisecondsSinceEpoch ~/ 1000;
            if (last != null && seconds <= last) continue;
            last = seconds;
            points.add([seconds, value]);
          }
          return points;
        }(),
      },
  ],
};

/// Where a metric chart draws. Widget tests use a fake: a WebView cannot be
/// drawn there.
abstract interface class MetricSurface {
  /// Starts the page once.
  Future<void> warm();

  Future<void> setTheme(ChartTheme theme);

  /// Replaces every line on the page with `metricPayload`.
  Future<void> setLines(Map<String, Object?> payload);

  Widget view();
}

/// TradingView Lightweight Charts in a WebView of its own, loaded from
/// asset files like the candle chart (ADR-012 item 1).
class WebViewMetricSurface implements MetricSurface {
  WebViewController? _web;
  Future<void>? _ready;
  final _events = StreamController<Map<String, Object?>>.broadcast();

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
    await web.loadFlutterAsset('assets/chart/metrics.html');
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
    if (decoded['type'] == 'log') debugPrint('metric page: ${decoded['msg']}');
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
  Future<void> setLines(Map<String, Object?> payload) =>
      _run('setLines(${jsonEncode(payload)})');

  @override
  Widget view() {
    final web = _web;
    if (web == null) return const SizedBox.expand();
    return WebViewWidget(
      controller: web,
      // Horizontal drags and pinches go to the chart; a vertical drag
      // scrolls the screen around it.
      gestureRecognizers: const {
        Factory<HorizontalDragGestureRecognizer>(
          HorizontalDragGestureRecognizer.new,
        ),
        Factory<ScaleGestureRecognizer>(ScaleGestureRecognizer.new),
      },
    );
  }
}

/// A page that lives as long as a metric chart is on screen: only a Futures
/// analysis shows one, so it is not kept for the whole app.
final metricSurfaceProvider = Provider.autoDispose<MetricSurface>(
  (ref) => WebViewMetricSurface(),
);
