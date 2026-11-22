import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/decimal_format.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/cp_colors.dart';
import '../../market/data/market_repository.dart';
import '../../market/domain/market.dart';
import '../domain/plan.dart';
import '../domain/plan_detail.dart';
import '../../../core/widgets/pair_label.dart';
import '../../../core/widgets/cp_tag.dart';

export '../../../core/widgets/price_ladder.dart';

/// MSG42 under every screen that shows trading plans (BR-60).
class PlanDisclaimer extends StatelessWidget {
  const PlanDisclaimer({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    child: Text(
      AppLocalizations.of(context).msg42,
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: context.cp.muted),
    ),
  );
}

/// `/plan/{id}` (SCR-18), pushed over the tabs.
String planLocation(String id) => '/plan/${Uri.encodeComponent(id)}';

/// The pair of [pairId] on [market], from the market's pair list (null
/// until it arrives).
MarketPair? pairOf(WidgetRef ref, Market market, String pairId) => ref.watch(
  marketRepositoryProvider(
    market,
  ).select((s) => s.pairs?.where((p) => p.pairId == pairId).firstOrNull),
);

String marketName(AppLocalizations l, Market market) =>
    market == Market.spot ? l.marketSpot : l.marketFutures;

String directionName(AppLocalizations l, PlanDirection direction) =>
    direction == PlanDirection.long ? l.planLong : l.planShort;

String statusName(AppLocalizations l, PlanStatus status) => switch (status) {
  PlanStatus.draft => l.planStatusDraft,
  PlanStatus.active => l.planStatusActive,
  PlanStatus.executed => l.planStatusExecuted,
  PlanStatus.cancelled => l.planStatusCancelled,
  PlanStatus.expired => l.planStatusExpired,
  PlanStatus.invalidated => l.planStatusInvalidated,
};

String closeReasonName(AppLocalizations l, CloseReason reason) =>
    switch (reason) {
      CloseReason.takeProfit => l.planCloseTakeProfit,
      CloseReason.stopLoss => l.planCloseStopLoss,
      CloseReason.manual => l.planCloseManual,
      CloseReason.liquidation => l.planCloseLiquidation,
    };

/// An amount in USDT with its sign and colour: green up, red down (CLAUDE.md
/// "up green / down red with a sign").
class SignedAmount extends StatelessWidget {
  const SignedAmount(this.value, {this.style, this.suffix = '', super.key});

  final String? value;
  final TextStyle? style;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final color = switch (directionOf(value)) {
      Direction.up => cp.positive,
      Direction.down => cp.negative,
      Direction.flat => cp.text,
    };
    final text = formatSignedDecimal(value);
    return Text(
      text == '--' ? text : '$text$suffix',
      style: (style ?? const TextStyle()).copyWith(
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

/// A small status label beside a plan's pair.
class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {this.tone, super.key});

  final String label;
  final Color? tone;

  @override
  Widget build(BuildContext context) => CpTag(label, color: tone);
}

/// "BTCUSDT Futures LONG 5x": the head of a plan row and of SCR-18.
class PlanHeadline extends ConsumerWidget {
  const PlanHeadline({
    required this.pairId,
    required this.market,
    required this.direction,
    this.leverage,
    this.style,
    super.key,
  });

  final String pairId;
  final Market market;
  final PlanDirection direction;
  final int? leverage;
  final TextStyle? style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final cp = context.cp;
    final text = Theme.of(context).textTheme;
    final pair = pairOf(ref, market, pairId);
    final long = direction == PlanDirection.long;
    return Text.rich(
      TextSpan(
        children: [
          if (pair == null)
            TextSpan(
              text: '…',
              style: (style ?? text.titleSmall)?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            )
          else
            ...pairSpans(
              context,
              base: pair.baseAsset,
              quote: pair.quoteAsset,
              style: style ?? text.titleSmall,
            ),
          TextSpan(
            text: '  ${marketName(l, market)} ',
            style: text.bodySmall?.copyWith(color: cp.muted),
          ),
          TextSpan(
            text: directionName(l, direction),
            style: text.bodySmall?.copyWith(
              color: long ? cp.positive : cp.negative,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (leverage != null)
            TextSpan(
              text: ' ${leverage}x',
              style: text.bodySmall?.copyWith(color: cp.muted),
            ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// A label and its value on one line, the value right-aligned.
class FactRow extends StatelessWidget {
  const FactRow(this.label, this.value, {super.key});

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: context.cp.muted);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: muted)),
          const SizedBox(width: 12),
          Flexible(
            child: DefaultTextStyle.merge(
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontFeatures: [FontFeature.tabularFigures()],
              ),
              child: value,
            ),
          ),
        ],
      ),
    );
  }
}

/// A price with the pair's tick, or "--".
String priceText(MarketPair? pair, String? value) =>
    formatPrice(value, pair?.tickSize);
