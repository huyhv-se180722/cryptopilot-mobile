import '../../../core/json/json_read.dart';

enum Market {
  spot('SPOT', 'spot'),
  futures('FUTURES', 'futures');

  const Market(this.wire, this.path);

  /// Upper case, as in bodies and topic names (`/topic/overview.SPOT`).
  final String wire;

  /// Lower case, as in REST paths (`/market/spot/...`).
  final String path;

  static Market decode(String value) => switch (value.toUpperCase()) {
    'SPOT' => Market.spot,
    'FUTURES' => Market.futures,
    _ => throw DecodeException('market $value is unknown'),
  };
}

/// An enabled pair of one market (`GET /market/pairs`, BR-07).
class MarketPair {
  const MarketPair({
    required this.pairId,
    required this.symbol,
    required this.market,
    required this.baseAsset,
    required this.quoteAsset,
    required this.baseAssetName,
    required this.tickSize,
    required this.stepSize,
    required this.displayOrder,
  });

  final String pairId;
  final String symbol;
  final Market market;
  final String baseAsset;
  final String quoteAsset;
  final String baseAssetName;
  final String tickSize;
  final String stepSize;
  final int displayOrder;

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return symbol.toLowerCase().contains(q) ||
        baseAsset.toLowerCase().contains(q) ||
        baseAssetName.toLowerCase().contains(q);
  }
}

MarketPair decodePair(Object? body) {
  final json = asJsonObject(body, 'pair');
  final order = json['displayOrder'];
  return MarketPair(
    pairId: readString(json, 'pairId'),
    symbol: readString(json, 'symbol'),
    market: Market.decode(readString(json, 'market')),
    baseAsset: readString(json, 'baseAsset'),
    quoteAsset: readString(json, 'quoteAsset'),
    baseAssetName:
        readOptionalString(json, 'baseAssetName') ??
        readString(json, 'baseAsset'),
    tickSize: readString(json, 'tickSize'),
    stepSize: readString(json, 'stepSize'),
    displayOrder: order is int ? order : 0,
  );
}

/// The latest values of a pair. Every value may be missing: the overview
/// carries what the streams have seen, and the Futures REST stats carry no
/// last price or 24 h change.
class Ticker {
  const Ticker({
    required this.symbol,
    this.lastPrice,
    this.bestBid,
    this.bestAsk,
    this.high24h,
    this.low24h,
    this.changePercent24h,
    this.baseVolume24h,
    this.quoteVolume24h,
    this.markPrice,
    this.indexPrice,
    this.fundingRate,
    this.nextFundingTime,
  });

  final String symbol;
  final String? lastPrice;
  final String? bestBid;
  final String? bestAsk;
  final String? high24h;
  final String? low24h;

  /// Already in percent units ("-5.658").
  final String? changePercent24h;
  final String? baseVolume24h;
  final String? quoteVolume24h;
  final String? markPrice;
  final String? indexPrice;

  /// A fraction ("0.0001" = 0.01 %).
  final String? fundingRate;
  final DateTime? nextFundingTime;

  /// The price a list shows: last, else mark (Futures without a last).
  String? get displayPrice => lastPrice ?? markPrice;

  /// Newer values win, missing ones keep what was known.
  Ticker merge(Ticker newer) => Ticker(
    symbol: symbol,
    lastPrice: newer.lastPrice ?? lastPrice,
    bestBid: newer.bestBid ?? bestBid,
    bestAsk: newer.bestAsk ?? bestAsk,
    high24h: newer.high24h ?? high24h,
    low24h: newer.low24h ?? low24h,
    changePercent24h: newer.changePercent24h ?? changePercent24h,
    baseVolume24h: newer.baseVolume24h ?? baseVolume24h,
    quoteVolume24h: newer.quoteVolume24h ?? quoteVolume24h,
    markPrice: newer.markPrice ?? markPrice,
    indexPrice: newer.indexPrice ?? indexPrice,
    fundingRate: newer.fundingRate ?? fundingRate,
    nextFundingTime: newer.nextFundingTime ?? nextFundingTime,
  );
}

DateTime? _optionalInstant(Map<String, Object?> json, String key) {
  final text = readOptionalString(json, key);
  return text == null ? null : DateTime.tryParse(text)?.toUtc();
}

/// One entry of `/topic/overview.{MARKET}` or `/topic/ticker.{MARKET}.{SYMBOL}`.
Ticker decodeTickerUpdate(Object? body) {
  final json = asJsonObject(body, 'ticker');
  return Ticker(
    symbol: readString(json, 'symbol'),
    lastPrice: readOptionalString(json, 'lastPrice'),
    bestBid: readOptionalString(json, 'bestBid'),
    bestAsk: readOptionalString(json, 'bestAsk'),
    high24h: readOptionalString(json, 'high24h'),
    low24h: readOptionalString(json, 'low24h'),
    changePercent24h: readOptionalString(json, 'changePercent24h'),
    baseVolume24h: readOptionalString(json, 'baseVolume24h'),
    quoteVolume24h: readOptionalString(json, 'quoteVolume24h'),
    markPrice: readOptionalString(json, 'markPrice'),
    indexPrice: readOptionalString(json, 'indexPrice'),
    fundingRate: readOptionalString(json, 'fundingRate'),
    nextFundingTime: _optionalInstant(json, 'nextFundingTime'),
  );
}

/// `/topic/overview.{MARKET}`: every pair streamed on the market.
List<Ticker> decodeOverview(Object? body) {
  final json = asJsonObject(body, 'overview');
  final tickers = json['tickers'];
  if (tickers is! List) throw const DecodeException('tickers is not a list');
  return [for (final item in tickers) decodeTickerUpdate(item)];
}

/// `GET /market/spot/{symbol}/stats`.
Ticker decodeSpotStats(Object? body) {
  final json = asJsonObject(body, 'spot stats');
  final ticker = json['ticker'];
  return ticker == null
      ? Ticker(symbol: readString(json, 'symbol'))
      : decodeTickerUpdate({
          ...asJsonObject(ticker, 'ticker'),
          'symbol': readString(json, 'symbol'),
        });
}

/// `GET /market/futures/{symbol}/stats`: mark, index and funding only.
Ticker decodeFuturesStats(Object? body) {
  final json = asJsonObject(body, 'futures stats');
  final price = json['price'];
  return price == null
      ? Ticker(symbol: readString(json, 'symbol'))
      : decodeTickerUpdate({
          ...asJsonObject(price, 'price'),
          'symbol': readString(json, 'symbol'),
        });
}
