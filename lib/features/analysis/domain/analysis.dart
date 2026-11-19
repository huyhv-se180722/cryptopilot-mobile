import 'package:decimal/decimal.dart';

import '../../../core/json/json_read.dart';
import '../../market/domain/market.dart';

/// Decimal strings stay strings (D-141); null when not computable yet.
String? _decimalOrNull(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is String && Decimal.tryParse(value) != null) return value;
  throw DecodeException('$key is not a decimal');
}

DateTime? _instantOrNull(Map<String, Object?> json, String key) =>
    json[key] == null ? null : readInstant(json, key);

/// The latest values of BR-12 for the candle the analysis is about; the
/// chart draws its own series, the card shows these.
class Indicators {
  const Indicators(this.values);

  /// sma20, ema20, ema50, ema200, rsi14, macdLine, macdSignal,
  /// macdHistogram, bbUpper, bbMiddle, bbLower, volumeSma20.
  final Map<String, String?> values;

  static const keys = [
    'sma20',
    'ema20',
    'ema50',
    'ema200',
    'rsi14',
    'macdLine',
    'macdSignal',
    'macdHistogram',
    'bbUpper',
    'bbMiddle',
    'bbLower',
    'volumeSma20',
  ];

  String? operator [](String key) => values[key];
}

Indicators decodeIndicators(Object? body) {
  final json = asJsonObject(body, 'indicators');
  return Indicators({
    for (final k in Indicators.keys) k: _decimalOrNull(json, k),
  });
}

/// BR-13 component scores with their formula version; Futures adds
/// derivatives.
class Components {
  const Components({
    required this.formulaVersion,
    required this.trend,
    required this.momentum,
    required this.volume,
    required this.level,
    this.derivatives,
  });

  /// Null when no candle of the timeframe is analysed yet (the backend
  /// then sends every component as null too).
  final String? formulaVersion;
  final String? trend;
  final String? momentum;
  final String? volume;
  final String? level;
  final String? derivatives;
}

Components decodeComponents(Object? body, Market market) {
  final json = asJsonObject(body, 'components');
  return Components(
    formulaVersion: readOptionalString(json, 'formulaVersion'),
    trend: _decimalOrNull(json, 'trend'),
    momentum: _decimalOrNull(json, 'momentum'),
    volume: _decimalOrNull(json, 'volume'),
    level: _decimalOrNull(json, 'level'),
    derivatives: market == Market.futures
        ? _decimalOrNull(json, 'derivatives')
        : null,
  );
}

/// LONG, SHORT or NEUTRAL next to a Futures score, never part of it (BR-13).
enum DominantSide {
  long('LONG'),
  short('SHORT'),
  neutral('NEUTRAL');

  const DominantSide(this.wire);
  final String wire;
}

/// Why a score sits below its weighted sum (BR-13, setup score v2).
enum CapReason {
  /// Too little room to the next level on the scored side.
  lowRoom('LOW_ROOM');

  const CapReason(this.wire);
  final String wire;
}

/// The side every component was scored for (BR-13, setup score v2): LONG on
/// Spot, the trend's side on Futures. Information about the score, never a
/// trade recommendation (BR-51).
enum ScoredSide {
  long('LONG'),
  short('SHORT');

  const ScoredSide(this.wire);
  final String wire;
}

/// The score of the Trader's preset (BR-13, BR-60): null with fewer than
/// 200 closed candles ("Insufficient data").
class AnalysisScore {
  const AnalysisScore({
    required this.score,
    required this.preset,
    required this.presetVersion,
    required this.timeframe,
    this.components,
    this.dominantSide,
    this.capReason,
    this.scoredSide,
  });

  final int? score;

  /// SCALPING, DAY_TRADING or SWING.
  final String preset;
  final String presetVersion;
  final String timeframe;

  /// Null on a plan without SCORE_COMPONENTS (CR-08).
  final Components? components;
  final DominantSide? dominantSide;

  /// Null when the score is its weighted sum.
  final CapReason? capReason;

  /// Null on scores stored before the side was (v1) and without a candle.
  final ScoredSide? scoredSide;
}

/// An optional enum by its wire name; a value the app does not know is a
/// bad answer, not a silent null.
T? _wireOrNull<T>(
  Map<String, Object?> json,
  String key,
  Map<String, T> byWire,
) {
  final wire = readOptionalString(json, key);
  if (wire == null) return null;
  return byWire[wire] ?? (throw DecodeException('$key $wire is unknown'));
}

AnalysisScore decodeAnalysisScore(Object? body, Market market) {
  final json = asJsonObject(body, 'setupScore');
  final score = json['score'];
  if (score != null && score is! int) {
    throw const DecodeException('score is not a whole number');
  }
  return AnalysisScore(
    score: score as int?,
    preset: readString(json, 'preset'),
    presetVersion: readString(json, 'presetVersion'),
    timeframe: readString(json, 'timeframe'),
    components: json['components'] == null
        ? null
        : decodeComponents(json['components'], market),
    dominantSide: _wireOrNull(json, 'dominantSide', {
      for (final side in DominantSide.values) side.wire: side,
    }),
    capReason: _wireOrNull(json, 'capReason', {
      for (final reason in CapReason.values) reason.wire: reason,
    }),
    scoredSide: _wireOrNull(json, 'scoredSide', {
      for (final side in ScoredSide.values) side.wire: side,
    }),
  );
}

/// `GET /analysis/{market}/{symbol}?tf=` (UC-10, UC-11; T-107 gates).
class Analysis {
  const Analysis({
    required this.symbol,
    required this.market,
    required this.timeframe,
    required this.indicators,
    required this.componentsLocked,
    this.openTime,
    this.calculatedAt,
    this.nearestSupport,
    this.nearestResistance,
    this.components,
    this.setupScore,
  });

  final String symbol;
  final Market market;
  final String timeframe;
  final DateTime? openTime;
  final DateTime? calculatedAt;
  final Indicators indicators;

  /// BR-14: drawn as horizontal lines.
  final String? nearestSupport;
  final String? nearestResistance;

  /// True without SCORE_COMPONENTS: the components are null (CR-08, D-60).
  final bool componentsLocked;
  final Components? components;
  final AnalysisScore? setupScore;
}

Market _market(Map<String, Object?> json) {
  final wire = readString(json, 'market');
  return Market.values.where((m) => m.wire == wire).firstOrNull ??
      (throw DecodeException('market $wire is unknown'));
}

Analysis decodeAnalysis(Object? body) {
  final json = asJsonObject(body, 'analysis');
  final market = _market(json);
  return Analysis(
    symbol: readString(json, 'symbol'),
    market: market,
    timeframe: readString(json, 'timeframe'),
    openTime: _instantOrNull(json, 'openTime'),
    calculatedAt: _instantOrNull(json, 'calculatedAt'),
    indicators: json['indicators'] == null
        ? const Indicators({})
        : decodeIndicators(json['indicators']),
    nearestSupport: _decimalOrNull(json, 'nearestSupport'),
    nearestResistance: _decimalOrNull(json, 'nearestResistance'),
    componentsLocked: readBool(json, 'componentsLocked'),
    components: json['components'] == null
        ? null
        : decodeComponents(json['components'], market),
    setupScore: json['setupScore'] == null
        ? null
        : decodeAnalysisScore(json['setupScore'], market),
  );
}

/// One point of a Futures metric series (BR-10).
class MetricPoint {
  const MetricPoint(
    this.time,
    this.value, {
    this.second,
    this.longShare,
    this.shortShare,
  });

  final DateTime time;

  /// Open interest, or the long/short account ratio.
  final String value;

  /// Open interest value (quote asset), or none.
  final String? second;

  /// The shares of accounts that are long and short, fractions of 1 (a
  /// long/short point only).
  final String? longShare;
  final String? shortShare;
}

/// `GET /market/futures/{symbol}/metrics?from=&to=` (SRS 3.3.3, BR-10).
class FuturesMetrics {
  const FuturesMetrics({
    required this.from,
    required this.openInterest,
    required this.longShortRatio,
    this.openInterestSince,
    this.longShortSince,
  });

  final DateTime from;
  final List<MetricPoint> openInterest;
  final List<MetricPoint> longShortRatio;

  /// The first stored point: later than [from] → "data since …".
  final DateTime? openInterestSince;
  final DateTime? longShortSince;
}

FuturesMetrics decodeFuturesMetrics(Object? body) {
  final json = asJsonObject(body, 'metrics');
  List<Object?> list(String key) {
    final value = json[key];
    if (value is! List) throw DecodeException('$key is not a list');
    return value;
  }

  final available = json['availableFrom'] == null
      ? const <String, Object?>{}
      : asJsonObject(json['availableFrom'], 'availableFrom');
  return FuturesMetrics(
    from: readInstant(json, 'from'),
    openInterest: [
      for (final item in list('openInterest'))
        () {
          final p = asJsonObject(item, 'open interest');
          return MetricPoint(
            readInstant(p, 'time'),
            _decimalOrNull(p, 'openInterest') ??
                (throw const DecodeException('openInterest is missing')),
            second: _decimalOrNull(p, 'openInterestValue'),
          );
        }(),
    ],
    longShortRatio: [
      for (final item in list('longShortRatio'))
        () {
          final p = asJsonObject(item, 'long/short ratio');
          return MetricPoint(
            readInstant(p, 'time'),
            _decimalOrNull(p, 'longShortRatio') ??
                (throw const DecodeException('longShortRatio is missing')),
            longShare: _decimalOrNull(p, 'longAccountRatio'),
            shortShare: _decimalOrNull(p, 'shortAccountRatio'),
          );
        }(),
    ],
    openInterestSince: _instantOrNull(available, 'openInterest'),
    longShortSince: _instantOrNull(available, 'longShortRatio'),
  );
}
