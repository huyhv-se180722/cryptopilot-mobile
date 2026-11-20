import 'package:flutter/foundation.dart';

import '../../../core/json/json_read.dart';

/// The whole market's figures of `GET /market/coins` (A-65, T-134; read
/// on backend develop 03352518). A figure the backend does not know is
/// absent, never zero; the coin rows stay with the web.
@immutable
class MarketOverview {
  const MarketOverview({
    required this.asOf,
    this.global,
    this.fearGreed,
    this.altcoinSeason,
    this.openInterest,
  });

  final DateTime asOf;
  final GlobalMarket? global;
  final FearGreed? fearGreed;
  final AltcoinSeason? altcoinSeason;
  final OpenInterest? openInterest;
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
    openInterest: _optional(json['openInterest'], (b) {
      final o = asJsonObject(b, 'open interest');
      return OpenInterest(
        valueUsd: _decimal(o, 'valueUsd'),
        change24hPercent: _optionalDecimal(o, 'change24hPercent'),
      );
    }),
  );
}
