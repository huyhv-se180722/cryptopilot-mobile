import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/market_api.dart';
import '../domain/coin_market.dart';

/// The whole market's figures (A-65), read while Spot or Futures shows
/// and again on pull-to-refresh; they change slowly (CoinPaprika, the
/// daily Fear & Greed), so nothing streams.
final marketOverviewProvider = FutureProvider.autoDispose<MarketOverview>(
  (ref) => ref.read(marketApiProvider).overview(),
);

/// The web's five Fear & Greed bands.
enum FearGreedBand { extremeFear, fear, neutral, greed, extremeGreed }

FearGreedBand fearGreedBand(int value) => value < 25
    ? FearGreedBand.extremeFear
    : value < 45
    ? FearGreedBand.fear
    : value <= 55
    ? FearGreedBand.neutral
    : value < 75
    ? FearGreedBand.greed
    : FearGreedBand.extremeGreed;
