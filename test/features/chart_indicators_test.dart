import 'dart:io';

import 'package:cryptopilot_mobile/features/chart/domain/indicators.dart';
import 'package:flutter_test/flutter_test.dart';

/// The backend's golden data (Binance BTCUSDT 1h, TA-Lib 0.8.1; MACD built
/// from TA-Lib EMAs as D-52 says), the same 400 candles the web tests. A value
/// at candle i depends only on candles 0…i, so the cut is exact.
void main() {
  final rows = File('test/fixtures/btcusdt-1h-talib.csv')
      .readAsLinesSync()
      .where((line) => line.trim().isNotEmpty)
      .skip(1)
      .map(
        (line) => [
          for (final cell in line.split(','))
            cell.isEmpty ? null : double.parse(cell),
        ],
      )
      .toList();
  Series column(int index) => [for (final row in rows) row[index]];
  final closes = [for (final row in rows) row[1]!];
  final volumes = [for (final row in rows) row[2]!];

  /// D-52 tolerance: max(1e-8·|expected|, 1e-8).
  void expectSeries(Series actual, Series expected) {
    expect(actual, hasLength(expected.length));
    for (var i = 0; i < expected.length; i++) {
      final want = expected[i];
      if (want == null) {
        expect(actual[i], isNull, reason: 'index $i');
        continue;
      }
      expect(actual[i], isNotNull, reason: 'index $i');
      expect(
        (actual[i]! - want).abs(),
        lessThanOrEqualTo(
          (1e-8 * want.abs()) > 1e-8 ? 1e-8 * want.abs() : 1e-8,
        ),
        reason: 'index $i',
      );
    }
  }

  group('indicators against the golden data (BR-12)', () {
    test('SMA20 and the volume SMA20', () {
      expect(rows, hasLength(400));
      expectSeries(sma(closes, 20), column(3));
      expectSeries(sma(volumes, 20), column(14));
    });
    test('EMA20, EMA50 and EMA200 seeded with the SMA', () {
      expectSeries(ema(closes, 20), column(4));
      expectSeries(ema(closes, 50), column(5));
      expectSeries(ema(closes, 200), column(6));
    });
    test('RSI14 with Wilder smoothing', () {
      expectSeries(rsi(closes), column(7));
    });
    test('MACD(12, 26, 9) as D-52', () {
      final result = macd(closes);
      expectSeries(result.line, column(8));
      expectSeries(result.signal, column(9));
      expectSeries(result.histogram, column(10));
    });
    test('Bollinger(20, 2) with the population deviation', () {
      final bands = bollinger(closes);
      expectSeries(bands.upper, column(11));
      expectSeries(bands.middle, column(12));
      expectSeries(bands.lower, column(13));
    });
  });

  group('indicator edge cases', () {
    test('RSI is 50 on a flat seed (D-55), 100 without losses, 0 without '
        'gains', () {
      expect(rsi(List.filled(20, 5))[14], 50);
      expect(rsi([for (var i = 0; i < 16; i++) i.toDouble()])[15], 100);
      expect(rsi([for (var i = 0; i < 16; i++) (20 - i).toDouble()])[15], 0);
    });
    test('equal closes give bands equal to the middle', () {
      final bands = bollinger(List.filled(25, 1.1));
      expect(bands.upper[24], bands.middle[24]);
      expect(bands.lower[24], bands.middle[24]);
    });
    test('stays null while the seed is incomplete', () {
      expect(ema([1, 2], 3), [null, null]);
      expect(macd([1, 2, 3]).signal, [null, null, null]);
    });
  });
}
