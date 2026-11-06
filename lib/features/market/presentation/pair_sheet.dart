import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/format/decimal_format.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/cp_colors.dart';
import '../application/market_board.dart';
import '../domain/market.dart';
import 'market_widgets.dart';

/// A pair's 24 h figures, live from the board, until the analysis screens of
/// T-090 replace it (SRS 3.3.1 statistics; mobile plan 8b).
Future<void> showPairSheet(BuildContext context, MarketPair pair) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => PairSheet(pair: pair),
    );

class PairSheet extends ConsumerWidget {
  const PairSheet({required this.pair, super.key});

  final MarketPair pair;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final board = ref.watch(marketBoardProvider(pair.market));
    final ticker = board.tickers[pair.symbol];
    final futures = pair.market == Market.futures;
    String price(String? value) => formatPrice(value, pair.tickSize);
    final rows = <(String, Widget)>[
      (l.marketHigh24h, Text(price(ticker?.high24h))),
      (l.marketLow24h, Text(price(ticker?.low24h))),
      (
        l.marketVolume24h(pair.baseAsset),
        Text(formatCompact(ticker?.baseVolume24h)),
      ),
      (
        l.marketTurnover24h(pair.quoteAsset),
        Text(formatCompact(ticker?.quoteVolume24h)),
      ),
      if (!futures) ...[
        (l.marketBestBid, Text(price(ticker?.bestBid))),
        (l.marketBestAsk, Text(price(ticker?.bestAsk))),
      ],
      if (futures) ...[
        (l.marketMarkPrice, Text(price(ticker?.markPrice))),
        (l.marketIndexPrice, Text(price(ticker?.indexPrice))),
        (
          l.marketFundingRate,
          Text(formatFractionAsPercent(ticker?.fundingRate)),
        ),
        (
          l.marketNextFunding,
          ticker?.nextFundingTime == null
              ? const Text('--')
              : Countdown(
                  until: ticker!.nextFundingTime!,
                  now: ref.read(clockProvider),
                ),
        ),
      ],
    ];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${pair.baseAsset}/${pair.quoteAsset}',
                  style: text.titleLarge,
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(futures ? l.marketFutures : l.marketSpot),
                  visualDensity: VisualDensity.compact,
                ),
                const Spacer(),
                LiveBadge(delayed: board.delayed),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              price(ticker?.displayPrice),
              style: text.headlineMedium?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (!futures || ticker?.changePercent24h != null)
              SignedPercentText(
                ticker?.changePercent24h,
                style: text.titleSmall,
              ),
            const SizedBox(height: 16),
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
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
                      style: const TextStyle(
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                      child: value,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Text(
              l.marketAnalysisNext,
              style: text.bodySmall?.copyWith(color: context.cp.muted),
            ),
          ],
        ),
      ),
    );
  }
}
