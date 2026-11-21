import 'package:decimal/decimal.dart';

import '../../../core/json/json_read.dart';

/// Timeframes the backend stores and streams (BR-08); 1h is the default of
/// the analysis screens (SRS 3.3.2).
enum Timeframe {
  m15('15m', Duration(minutes: 15)),
  h1('1h', Duration(hours: 1)),
  h4('4h', Duration(hours: 4)),
  d1('1d', Duration(days: 1));

  const Timeframe(this.wire, this.step);
  final String wire;

  /// From one candle's open time to the next one's (UTC, no month frame).
  final Duration step;

  static Timeframe? fromWire(String? wire) =>
      values.where((tf) => tf.wire == wire).firstOrNull;
}

/// One candle of `GET /market/{m}/{s}/candles` (closed) or of
/// `/topic/kline.{M}.{S}.{tf}` ([closed] false while it is forming). Prices
/// and volume stay decimal strings (D-141).
class Candle {
  const Candle({
    required this.openTime,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.quoteVolume,
    this.closed = true,
  });

  final DateTime openTime;
  final String open;
  final String high;
  final String low;
  final String close;
  final String quoteVolume;
  final bool closed;

  /// The shape the chart page and the device cache read.
  Map<String, Object?> toJson() => {
    'openTime': openTime.toIso8601String(),
    'open': open,
    'high': high,
    'low': low,
    'close': close,
    'quoteVolume': quoteVolume,
    'closed': closed,
  };
}

String _decimal(Map<String, Object?> json, String key) {
  final text = readString(json, key);
  if (Decimal.tryParse(text) == null) {
    throw DecodeException('$key is not a decimal');
  }
  return text;
}

/// A candle of the REST list, a kline push or the device cache.
Candle decodeCandle(Object? body) {
  final json = asJsonObject(body, 'candle');
  final closed = json['closed'];
  if (closed != null && closed is! bool) {
    throw const DecodeException('closed is not a boolean');
  }
  return Candle(
    openTime: readInstant(json, 'openTime'),
    open: _decimal(json, 'open'),
    high: _decimal(json, 'high'),
    low: _decimal(json, 'low'),
    close: _decimal(json, 'close'),
    quoteVolume: _decimal(json, 'quoteVolume'),
    closed: closed as bool? ?? true,
  );
}

/// `CandlesResponse`: `{symbol, market, timeframe, candles}`, oldest first.
List<Candle> decodeCandles(Object? body) {
  final json = asJsonObject(body, 'candles page');
  final items = json['candles'];
  if (items is! List) throw const DecodeException('candles is not a list');
  return [for (final item in items) decodeCandle(item)];
}
