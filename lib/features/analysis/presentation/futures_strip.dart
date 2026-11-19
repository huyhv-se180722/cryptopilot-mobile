import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/format/decimal_format.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/cp_colors.dart';
import '../../market/domain/market.dart';
import '../../market/presentation/market_widgets.dart';

/// The Futures figures of SCR-11 (SRS 3.3.3): mark price, index price, the
/// current funding rate — the predicted rate of the coming settlement — and
/// a countdown to the next funding time as the source reports it, never a
/// computed one (BR-11). A value not received yet is a dash.
class FuturesStrip extends ConsumerWidget {
  const FuturesStrip({required this.pair, required this.ticker, super.key});

  final MarketPair pair;

  /// Null until the first read.
  final Ticker? ticker;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final next = ticker?.nextFundingTime;
    return Container(
      key: const Key('futures-strip'),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: context.cp.raised,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _Cell(
                  id: 'mark',
                  label: l.marketMarkPrice,
                  value: Text(formatPrice(ticker?.markPrice, pair.tickSize)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Cell(
                  id: 'index',
                  label: l.marketIndexPrice,
                  value: Text(formatPrice(ticker?.indexPrice, pair.tickSize)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _Cell(
                  id: 'funding',
                  label: l.marketFundingRate,
                  // With its sign: who pays is the sign, not a colour.
                  value: Text(formatFractionAsPercent(ticker?.fundingRate)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Cell(
                  id: 'next-funding',
                  label: l.marketNextFunding,
                  value: next == null
                      ? const Text('--')
                      : Countdown(until: next, now: ref.read(clockProvider)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.id, required this.label, required this.value});

  final String id;
  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.bodySmall?.copyWith(color: context.cp.muted),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: DefaultTextStyle.merge(
              key: Key('futures-$id'),
              style: (text.bodyMedium ?? const TextStyle()).copyWith(
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              child: value,
            ),
          ),
        ],
      ),
    );
  }
}
