import 'package:decimal/decimal.dart';

import '../../../core/json/json_read.dart';

/// `GET /journal/performance/summary` (T-051), simulated trades by default:
/// the figures every plan gets; the full dashboard (SCR-23) is on the web.
class PerformanceSummary {
  const PerformanceSummary({
    required this.trades,
    required this.wins,
    required this.losses,
    required this.totalNetPnl,
    this.winRate,
  });

  final int trades;
  final int wins;
  final int losses;

  /// 0 to 1; null without a win or a loss.
  final String? winRate;
  final String totalNetPnl;
}

int _count(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw DecodeException('$key is not a whole number');
}

String _decimal(Object? value, String key) {
  final text = value is String ? value : (value is num ? '$value' : null);
  if (text == null || Decimal.tryParse(text) == null) {
    throw DecodeException('$key is not a decimal');
  }
  return text;
}

PerformanceSummary decodePerformanceSummary(Object? body) {
  final json = asJsonObject(body, 'performance summary');
  final winRate = json['winRate'];
  return PerformanceSummary(
    trades: _count(json, 'trades'),
    wins: _count(json, 'wins'),
    losses: _count(json, 'losses'),
    winRate: winRate == null ? null : _decimal(winRate, 'winRate'),
    totalNetPnl: _decimal(json['totalNetPnl'], 'totalNetPnl'),
  );
}
