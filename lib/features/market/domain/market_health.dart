import 'package:flutter/foundation.dart';

import '../../../core/json/json_read.dart';
import 'market.dart';

/// How current one market's exchange data is (D-159, backend
/// `MarketHealthState`). A state this build does not know reads as
/// [unknown]; [MarketHealth.tradingOpen] still says what may be done.
enum MarketHealthState {
  live('LIVE'),
  reconnecting('RECONNECTING'),
  paused('PAUSED'),
  recovering('RECOVERING'),
  maintenance('MAINTENANCE'),
  unknown('');

  const MarketHealthState(this.wire);

  final String wire;

  static MarketHealthState decode(String value) => values.firstWhere(
    (state) => state.wire == value && state != unknown,
    orElse: () => unknown,
  );
}

/// What closed a market (backend `IncidentReason`); null when unknown.
enum IncidentReason {
  streamLost('STREAM_LOST'),
  restUnavailable('REST_UNAVAILABLE'),
  rateLimited('RATE_LIMITED'),
  ipBanned('IP_BANNED'),
  maintenance('MAINTENANCE');

  const IncidentReason(this.wire);

  final String wire;

  static IncidentReason? decode(String? value) {
    for (final reason in values) {
      if (reason.wire == value) return reason;
    }
    return null;
  }
}

/// Where the prices shown for a market come from now (backend
/// `DisplaySource`): the exchange, OKX for display only, or none.
enum DisplaySource {
  binance('BINANCE'),
  okx('OKX'),
  none('NONE');

  const DisplaySource(this.wire);

  final String wire;

  static DisplaySource decode(String? value) => values.firstWhere(
    (source) => source.wire == value,
    orElse: () => binance,
  );
}

/// One market of `GET /market/status` and `/topic/market.status`
/// (`MarketHealthResponse`, backend develop e02a7c3b).
@immutable
class MarketHealth {
  const MarketHealth({
    required this.market,
    this.state = MarketHealthState.live,
    this.tradingOpen = true,
    this.since,
    this.pausedAt,
    this.reason,
    this.message,
    this.incidentId,
    this.resumedAt,
    this.pausedPairs = const [],
    this.expectedEndAt,
    this.retryAt,
    this.pairsDone,
    this.pairsTotal,
    this.displaySource = DisplaySource.binance,
    this.dataLost = false,
  });

  /// Until the first answer, and when none can be read, a market counts as
  /// live: the backend is what refuses trading (MSG57).
  const MarketHealth.live(Market market) : this(market: market);

  final Market market;
  final MarketHealthState state;

  /// Orders, positions and wallets of the market may be changed now.
  final bool tradingOpen;

  /// When its data was last live, while trading is closed.
  final DateTime? since;

  /// When trading closed, while it is closed.
  final DateTime? pausedAt;
  final IncidentReason? reason;

  /// The administrator's message of a maintenance, if any.
  final String? message;

  /// The open incident, or the one that just ended.
  final String? incidentId;

  /// When trading reopened, for an incident that ended in the last ten
  /// minutes.
  final DateTime? resumedAt;

  /// Upper-case symbols whose own data is lost while the market is open
  /// (E5): their order forms are locked.
  final List<String> pausedPairs;

  /// When an administrator expects a maintenance to end, if said.
  final DateTime? expectedEndAt;

  /// When the exchange may be called again (a ban or an open circuit).
  final DateTime? retryAt;

  /// How far the market has caught up, while it recovers.
  final int? pairsDone;
  final int? pairsTotal;
  final DisplaySource displaySource;

  /// The exchange data is missing or being refilled: the book and trades are
  /// not current and reference prices are shown instead.
  final bool dataLost;

  /// Shown in the banner: closed, or reopened in the last ten minutes.
  bool get noteworthy =>
      !tradingOpen || (resumedAt != null && incidentId != null);

  /// Whether [symbol] of this market may be traded now.
  bool canTrade(String? symbol) =>
      tradingOpen &&
      (symbol == null || !pausedPairs.contains(symbol.toUpperCase()));
}

/// Both markets' data health, Spot then Futures.
@immutable
class MarketStatus {
  const MarketStatus(this.markets);

  static const allLive = MarketStatus([
    MarketHealth.live(Market.spot),
    MarketHealth.live(Market.futures),
  ]);

  final List<MarketHealth> markets;

  MarketHealth of(Market market) => markets.firstWhere(
    (health) => health.market == market,
    orElse: () => MarketHealth.live(market),
  );
}

DateTime? _instant(Map<String, Object?> json, String key) =>
    json[key] == null ? null : readInstant(json, key);

int? _optionalInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is int) return value;
  throw DecodeException('$key is not a whole number');
}

MarketHealth decodeMarketHealth(Object? body) {
  final json = asJsonObject(body, 'market health');
  final paused = json['pausedPairs'];
  final recovery = json['recovery'] == null
      ? null
      : asJsonObject(json['recovery'], 'recovery');
  return MarketHealth(
    market: Market.decode(readString(json, 'market')),
    state: MarketHealthState.decode(readString(json, 'state')),
    tradingOpen: readBool(json, 'tradingOpen'),
    since: _instant(json, 'since'),
    pausedAt: _instant(json, 'pausedAt'),
    reason: IncidentReason.decode(readOptionalString(json, 'reason')),
    message: readOptionalString(json, 'message'),
    incidentId: readOptionalString(json, 'incidentId'),
    resumedAt: _instant(json, 'resumedAt'),
    pausedPairs: paused is List
        ? [for (final symbol in paused) '$symbol'.toUpperCase()]
        : const [],
    expectedEndAt: _instant(json, 'expectedEndAt'),
    retryAt: _instant(json, 'retryAt'),
    pairsDone: recovery == null ? null : _optionalInt(recovery, 'pairsDone'),
    pairsTotal: recovery == null ? null : _optionalInt(recovery, 'pairsTotal'),
    displaySource: DisplaySource.decode(
      readOptionalString(json, 'displaySource'),
    ),
    dataLost: json['dataLost'] == true,
  );
}

MarketStatus decodeMarketStatus(Object? body) {
  final json = asJsonObject(body, 'market status');
  final markets = json['markets'];
  if (markets is! List) throw const DecodeException('markets is not a list');
  return MarketStatus([for (final item in markets) decodeMarketHealth(item)]);
}

/// One pair's display-only reference price while its market's exchange data
/// is lost (`FallbackPriceResponse`).
@immutable
class ReferencePrice {
  const ReferencePrice({
    required this.symbol,
    required this.lastPrice,
    this.asOf,
    this.diverged = false,
  });

  final String symbol;
  final String lastPrice;
  final DateTime? asOf;

  /// May differ markedly from the exchange.
  final bool diverged;
}

/// `GET /market/fallback` and `/topic/market.fallback.<MARKET>`
/// (`FallbackPricesResponse`).
@immutable
class FallbackPrices {
  const FallbackPrices({
    required this.market,
    required this.source,
    this.asOf,
    this.prices = const {},
  });

  final Market market;
  final DisplaySource source;
  final DateTime? asOf;

  /// By upper-case symbol.
  final Map<String, ReferencePrice> prices;
}

FallbackPrices decodeFallbackPrices(Object? body) {
  final json = asJsonObject(body, 'fallback prices');
  final items = json['prices'];
  final prices = <String, ReferencePrice>{};
  if (items is List) {
    for (final item in items) {
      final price = asJsonObject(item, 'fallback price');
      final symbol = readString(price, 'symbol').toUpperCase();
      final last = price['lastPrice'];
      if (last == null) continue;
      prices[symbol] = ReferencePrice(
        symbol: symbol,
        lastPrice: '$last',
        asOf: _instant(price, 'asOf'),
        diverged: price['diverged'] == true,
      );
    }
  }
  return FallbackPrices(
    market: Market.decode(readString(json, 'market')),
    source: DisplaySource.decode(readOptionalString(json, 'source')),
    asOf: _instant(json, 'asOf'),
    prices: prices,
  );
}
