import 'dart:async';

import 'package:cryptopilot_mobile/features/chart/presentation/chart_surface.dart';
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
  Widget view() => const SizedBox.expand(key: Key('chart-surface'));
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
