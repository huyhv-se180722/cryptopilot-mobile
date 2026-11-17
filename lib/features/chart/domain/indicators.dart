import 'dart:math' as math;

/// Indicator series for drawing only: the backend returns the latest values
/// (`GET /analysis`), so the chart computes the history itself with the
/// definitions and seeds of BR-12 (D-52, D-55), as the web does (D-103).
/// Indicators may be doubles; prices and money never are. The analysis card
/// keeps showing the backend's own values.
///
/// Every function returns one entry per input, null until its seed is
/// complete.
typedef Series = List<double?>;

/// SMA(n): rolling sum over the last n values; first value at n − 1.
Series sma(List<double> values, int n) {
  final out = Series.filled(values.length, null);
  var sum = 0.0;
  for (var i = 0; i < values.length; i++) {
    sum += values[i];
    if (i >= n) sum -= values[i - n];
    if (i >= n - 1) out[i] = sum / n;
  }
  return out;
}

/// EMA(n), α = 2/(n+1), seeded with the SMA of the first n values.
Series ema(List<double> values, int n) {
  final out = Series.filled(values.length, null);
  final alpha = 2 / (n + 1);
  double? current;
  var seed = 0.0;
  for (var i = 0; i < values.length; i++) {
    if (current == null) {
      seed += values[i];
      if (i == n - 1) current = seed / n;
    } else {
      current = alpha * values[i] + (1 - alpha) * current;
    }
    out[i] = current;
  }
  return out;
}

/// RSI(14), Wilder: averages seeded with the simple mean of the first 14
/// gains and losses, then smoothed with 13/14. No losses and some gains →
/// 100; neither → 50 (D-55).
Series rsi(List<double> closes, [int n = 14]) {
  final out = Series.filled(closes.length, null);
  var gain = 0.0;
  var loss = 0.0;
  for (var i = 1; i < closes.length; i++) {
    final change = closes[i] - closes[i - 1];
    final up = math.max(change, 0.0);
    final down = math.max(-change, 0.0);
    if (i <= n) {
      gain += up;
      loss += down;
      if (i < n) continue;
      gain /= n;
      loss /= n;
    } else {
      gain = (gain * (n - 1) + up) / n;
      loss = (loss * (n - 1) + down) / n;
    }
    out[i] = loss == 0 ? (gain == 0 ? 50 : 100) : 100 - 100 / (1 + gain / loss);
  }
  return out;
}

class MacdSeries {
  const MacdSeries(this.line, this.signal, this.histogram);
  final Series line;
  final Series signal;
  final Series histogram;
}

/// MACD(12, 26, 9) as D-52: each EMA seeded on its own (EMA12 at candle 12,
/// EMA26 at 26), the line from candle 26, the signal seeded with the mean of
/// the first 9 lines (candle 34).
MacdSeries macd(
  List<double> closes, [
  int fast = 12,
  int slow = 26,
  int signalPeriod = 9,
]) {
  final fastEma = ema(closes, fast);
  final slowEma = ema(closes, slow);
  final line = <double?>[
    for (var i = 0; i < closes.length; i++)
      fastEma[i] == null || slowEma[i] == null
          ? null
          : fastEma[i]! - slowEma[i]!,
  ];
  final signal = Series.filled(closes.length, null);
  final first = line.indexWhere((value) => value != null);
  if (first >= 0) {
    final tail = ema([for (final v in line.sublist(first)) v!], signalPeriod);
    for (var i = 0; i < tail.length; i++) {
      signal[first + i] = tail[i];
    }
  }
  final histogram = <double?>[
    for (var i = 0; i < closes.length; i++)
      line[i] == null || signal[i] == null ? null : line[i]! - signal[i]!,
  ];
  return MacdSeries(line, signal, histogram);
}

class BollingerSeries {
  const BollingerSeries(this.upper, this.middle, this.lower);
  final Series upper;
  final Series middle;
  final Series lower;
}

/// Bollinger(20, 2): middle = SMA20, σ = population deviation of the last 20
/// closes, computed shifted by the window's first close so equal closes give
/// σ = 0 exactly (D-52).
BollingerSeries bollinger(List<double> closes, [int n = 20, double width = 2]) {
  final middle = sma(closes, n);
  final upper = Series.filled(closes.length, null);
  final lower = Series.filled(closes.length, null);
  for (var i = n - 1; i < closes.length; i++) {
    final base = closes[i - n + 1];
    var sum = 0.0;
    var squares = 0.0;
    for (var j = i - n + 1; j <= i; j++) {
      final shifted = closes[j] - base;
      sum += shifted;
      squares += shifted * shifted;
    }
    final mean = sum / n;
    final sigma = math.sqrt(math.max(squares / n - mean * mean, 0));
    final mid = middle[i]!;
    upper[i] = mid + width * sigma;
    lower[i] = mid - width * sigma;
  }
  return BollingerSeries(upper, middle, lower);
}
