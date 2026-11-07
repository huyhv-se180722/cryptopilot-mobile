import '../../../core/json/json_read.dart';

/// A watched pair (`GET /watchlist`, T-053). A pair an Admin later disabled
/// stays listed with its `*Listed` flags off (Q-29).
class WatchItem {
  const WatchItem({
    required this.id,
    required this.pairId,
    required this.symbol,
    required this.spotListed,
    required this.futuresListed,
    required this.sortOrder,
    required this.activeAlerts,
    this.label,
    this.note,
  });

  final String id;
  final String pairId;
  final String symbol;
  final bool spotListed;
  final bool futuresListed;
  final String? label;
  final String? note;
  final int sortOrder;
  final int activeAlerts;
}

class Watchlist {
  const Watchlist({required this.items, this.limit});

  final List<WatchItem> items;

  /// The plan's ceiling (D-58); null when the plan has none.
  final int? limit;
}

int _int(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw DecodeException('$key is not a whole number');
}

WatchItem decodeWatchItem(Object? body) {
  final json = asJsonObject(body, 'watchlist item');
  return WatchItem(
    id: readString(json, 'id'),
    pairId: readString(json, 'pairId'),
    symbol: readString(json, 'symbol'),
    spotListed: readBool(json, 'spotListed'),
    futuresListed: readBool(json, 'futuresListed'),
    label: readOptionalString(json, 'label'),
    note: readOptionalString(json, 'note'),
    sortOrder: _int(json, 'sortOrder'),
    activeAlerts: _int(json, 'activeAlerts'),
  );
}

/// Keeps the server's order (`sortOrder`, then `addedAt`): rows can share a
/// position, and only the server knows when each was added.
Watchlist decodeWatchlist(Object? body) {
  final json = asJsonObject(body, 'watchlist');
  final items = json['items'];
  if (items is! List) throw const DecodeException('items is not a list');
  final limit = json['limit'];
  return Watchlist(
    items: [for (final item in items) decodeWatchItem(item)],
    limit: limit is int ? limit : null,
  );
}

/// The setup score of the Trader's preset (BR-13, D-53), read from
/// `GET /analysis/spot/{symbol}`; `score` is null with fewer than 200 candles.
class SetupScore {
  const SetupScore({
    required this.preset,
    required this.presetVersion,
    required this.timeframe,
    this.score,
  });

  final int? score;
  final String preset;
  final String presetVersion;
  final String timeframe;
}

SetupScore? decodeSetupScore(Object? analysis) {
  final json = asJsonObject(analysis, 'analysis');
  final setup = json['setupScore'];
  if (setup == null) return null;
  final score = asJsonObject(setup, 'setup score');
  final value = score['score'];
  return SetupScore(
    score: value is int ? value : null,
    preset: readString(score, 'preset'),
    presetVersion: readString(score, 'presetVersion'),
    timeframe: readString(score, 'timeframe'),
  );
}
