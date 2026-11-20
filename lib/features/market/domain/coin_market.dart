import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';

import '../../../core/json/json_read.dart';
import 'market.dart';

/// The whole market's figures of `GET /market/coins` (A-65, T-134; read
/// on backend develop 03352518). A figure the backend does not know is
/// absent, never zero. The coin rows feed the Coins list (A-67, T-137).
@immutable
class MarketOverview {
  const MarketOverview({
    required this.asOf,
    this.global,
    this.fearGreed,
    this.altcoinSeason,
    this.openInterest,
    this.coins = const [],
  });

  final DateTime asOf;
  final GlobalMarket? global;
  final FearGreed? fearGreed;
  final AltcoinSeason? altcoinSeason;
  final OpenInterest? openInterest;

  /// By CoinPaprika rank, then symbol.
  final List<CoinRow> coins;
}

/// One listed coin: what the live tickers do not carry (A-67).
@immutable
class CoinRow {
  const CoinRow({
    required this.symbol,
    required this.name,
    this.logoUrl,
    this.rank,
    this.spotSymbol,
    this.futuresSymbol,
    this.circulatingSupply,
    this.price1hAgo,
    this.price7dAgo,
    this.sparkline7d = const [],
  });

  final String symbol;
  final String name;
  final String? logoUrl;
  final int? rank;
  final String? spotSymbol;
  final String? futuresSymbol;
  final String? circulatingSupply;
  final String? price1hAgo;
  final String? price7dAgo;

  /// The closes of the last 7 days, oldest first.
  final List<double> sparkline7d;
}

/// A coin's live figures from its Spot ticker: the market cap and the
/// 1 h and 7 d changes move with the live price, as on the web.
@immutable
class CoinFigures {
  const CoinFigures({
    this.price,
    this.change1h,
    this.change24h,
    this.change7d,
    this.marketCap,
    this.volume24h,
  });

  final String? price;

  /// Percents, e.g. "-1.23".
  final String? change1h;
  final String? change24h;
  final String? change7d;
  final String? marketCap;
  final String? volume24h;
}

String? _changeSince(Decimal price, String? before) {
  final then = before == null ? null : Decimal.tryParse(before);
  if (then == null || then == Decimal.zero) return null;
  final change = ((price - then) * Decimal.fromInt(100) / then).toDecimal(
    scaleOnInfinitePrecision: 6,
  );
  return change.toStringAsFixed(2);
}

CoinFigures coinFigures(CoinRow coin, Ticker? ticker) {
  final price = Decimal.tryParse(ticker?.displayPrice ?? '');
  if (price == null) {
    return CoinFigures(
      change24h: ticker?.changePercent24h,
      volume24h: ticker?.quoteVolume24h,
    );
  }
  final supply = Decimal.tryParse(coin.circulatingSupply ?? '');
  return CoinFigures(
    price: ticker!.displayPrice,
    change1h: _changeSince(price, coin.price1hAgo),
    change24h: ticker.changePercent24h,
    change7d: _changeSince(price, coin.price7dAgo),
    marketCap: supply == null ? null : (price * supply).toString(),
    volume24h: ticker.quoteVolume24h,
  );
}

/// The whole crypto market, from CoinPaprika (US dollars, percents).
@immutable
class GlobalMarket {
  const GlobalMarket({
    required this.marketCapUsd,
    this.marketCapChange24hPercent,
    this.volume24hUsd,
    this.bitcoinDominancePercent,
  });

  final String marketCapUsd;
  final String? marketCapChange24hPercent;
  final String? volume24hUsd;
  final String? bitcoinDominancePercent;
}

/// The Crypto Fear & Greed Index (alternative.me), 0 to 100.
@immutable
class FearGreed {
  const FearGreed({required this.value, required this.classification});

  final int value;
  final String classification;
}

/// The share of listed altcoins beating Bitcoin over [days] (0 to 100):
/// 75 or more an altcoin season, 25 or less a Bitcoin season.
@immutable
class AltcoinSeason {
  const AltcoinSeason({
    required this.index,
    required this.altcoins,
    required this.days,
  });

  final int index;
  final int altcoins;
  final int days;
}

/// The open interest of the listed Futures pairs together.
@immutable
class OpenInterest {
  const OpenInterest({required this.valueUsd, this.change24hPercent});

  final String valueUsd;
  final String? change24hPercent;
}

String _decimal(Map<String, Object?> json, String key) => switch (json[key]) {
  final String value when num.tryParse(value) != null => value,
  _ => throw DecodeException('$key is not a decimal'),
};

String? _optionalDecimal(Map<String, Object?> json, String key) =>
    json[key] == null ? null : _decimal(json, key);

int _int(Map<String, Object?> json, String key) => switch (json[key]) {
  final int value => value,
  _ => throw DecodeException('$key is not a whole number'),
};

T? _optional<T>(Object? body, T Function(Object?) decode) =>
    body == null ? null : decode(body);

MarketOverview decodeMarketOverview(Object? body) {
  final json = asJsonObject(body, 'coin market');
  return MarketOverview(
    asOf: readInstant(json, 'asOf'),
    global: _optional(json['global'], (b) {
      final g = asJsonObject(b, 'global');
      return GlobalMarket(
        marketCapUsd: _decimal(g, 'marketCapUsd'),
        marketCapChange24hPercent: _optionalDecimal(
          g,
          'marketCapChange24hPercent',
        ),
        volume24hUsd: _optionalDecimal(g, 'volume24hUsd'),
        bitcoinDominancePercent: _optionalDecimal(g, 'bitcoinDominancePercent'),
      );
    }),
    fearGreed: _optional(json['fearGreed'], (b) {
      final f = asJsonObject(b, 'fear and greed');
      return FearGreed(
        value: _int(f, 'value'),
        classification: readString(f, 'classification'),
      );
    }),
    altcoinSeason: _optional(json['altcoinSeason'], (b) {
      final a = asJsonObject(b, 'altcoin season');
      return AltcoinSeason(
        index: _int(a, 'index'),
        altcoins: _int(a, 'altcoins'),
        days: _int(a, 'days'),
      );
    }),
    coins: switch (json['coins']) {
      null => const [],
      final List<Object?> list => [for (final c in list) decodeCoinRow(c)],
      _ => throw const DecodeException('coins is not a list'),
    },
    openInterest: _optional(json['openInterest'], (b) {
      final o = asJsonObject(b, 'open interest');
      return OpenInterest(
        valueUsd: _decimal(o, 'valueUsd'),
        change24hPercent: _optionalDecimal(o, 'change24hPercent'),
      );
    }),
  );
}

int? _optionalInt(Map<String, Object?> json, String key) => switch (json[key]) {
  null => null,
  final int value => value,
  _ => throw DecodeException('$key is not a whole number'),
};

/// A figure not known is absent; one of the wrong kind is refused.
CoinRow decodeCoinRow(Object? body) {
  final json = asJsonObject(body, 'coin');
  return CoinRow(
    symbol: readString(json, 'symbol'),
    name: readString(json, 'name'),
    logoUrl: switch (readOptionalString(json, 'logoUrl')) {
      final url? when url.startsWith('https://') => url,
      _ => null,
    },
    rank: _optionalInt(json, 'rank'),
    spotSymbol: readOptionalString(json, 'spotSymbol'),
    futuresSymbol: readOptionalString(json, 'futuresSymbol'),
    circulatingSupply: _optionalDecimal(json, 'circulatingSupply'),
    price1hAgo: _optionalDecimal(json, 'price1hAgo'),
    price7dAgo: _optionalDecimal(json, 'price7dAgo'),
    sparkline7d: switch (json['sparkline7d']) {
      null => const [],
      final List<Object?> list => [
        for (final v in list)
          switch (v) {
            final String s when double.tryParse(s) != null => double.parse(s),
            final num n => n.toDouble(),
            _ => throw const DecodeException('sparkline7d holds a non-number'),
          },
      ],
      _ => throw const DecodeException('sparkline7d is not a list'),
    },
  );
}
