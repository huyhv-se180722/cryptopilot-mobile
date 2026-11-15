import 'package:flutter/material.dart';

import '../../../core/format/decimal_format.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/cp_colors.dart';
import '../../market/domain/market.dart';
import '../../market/presentation/market_widgets.dart';
import 'analysis_card.dart';

/// Market statistics of SRS 3.3.2: last price, best bid, best ask, spread
/// (ask − bid, exact), 24h high, low, change and volume. A value the
/// backend does not send is a dash, never a made-up number (Futures has no
/// 24h figures, Q-91).
class StatsCard extends StatelessWidget {
  const StatsCard({required this.pair, required this.ticker, super.key});

  final MarketPair pair;

  /// Null until the first read.
  final Ticker? ticker;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final ticker = this.ticker;
    if (ticker == null) {
      return AnalysisCard(
        key: const Key('stats-card'),
        title: l.analysisStatsTitle,
        child: const BlockSkeleton(key: Key('stats-loading'), lines: 4),
      );
    }
    String price(String? value) => formatPrice(value, pair.tickSize);
    final rows = <(String, String, Widget)>[
      ('last', l.statLastPrice, Text(price(ticker.lastPrice))),
      ('bid', l.marketBestBid, Text(price(ticker.bestBid))),
      ('ask', l.marketBestAsk, Text(price(ticker.bestAsk))),
      (
        'spread',
        l.statSpread,
        Text(price(subtractDecimal(ticker.bestAsk, ticker.bestBid))),
      ),
      ('high', l.marketHigh24h, Text(price(ticker.high24h))),
      ('low', l.marketLow24h, Text(price(ticker.low24h))),
      ('change', l.statChange24h, SignedPercentText(ticker.changePercent24h)),
      (
        'volume',
        l.marketVolume24h(pair.baseAsset),
        Text(formatCompact(ticker.baseVolume24h)),
      ),
      (
        'turnover',
        l.marketTurnover24h(pair.quoteAsset),
        Text(formatCompact(ticker.quoteVolume24h)),
      ),
    ];
    return AnalysisCard(
      key: const Key('stats-card'),
      title: l.analysisStatsTitle,
      child: Column(
        children: [
          for (final (id, label, value) in rows)
            MergeSemantics(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: text.bodyMedium?.copyWith(
                          color: context.cp.muted,
                        ),
                      ),
                    ),
                    DefaultTextStyle.merge(
                      key: Key('stat-$id'),
                      style: const TextStyle(
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                      child: value,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
