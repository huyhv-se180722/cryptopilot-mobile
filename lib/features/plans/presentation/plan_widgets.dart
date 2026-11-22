import 'dart:math';

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

/// The plan's prices on one line (D-163, as the web `PriceLadder`): the
/// stop-to-entry part red, the entry-to-target part green, a tick at the
/// entry and a "Now" mark at the last price when it is known. The figures
/// only place marks; the prices shown are the decimal strings.
class PriceLadder extends StatelessWidget {
  const PriceLadder({
    required this.stop,
    required this.entry,
    required this.target,
    required this.now,
    required this.nowLabel,
    required this.semantics,
    super.key,
  });

  final String? stop;
  final String? entry;
  final String? target;
  final String? now;
  final String nowLabel;
  final String semantics;

  @override
  Widget build(BuildContext context) {
    final s = double.tryParse(stop ?? '');
    final e = double.tryParse(entry ?? '');
    final t = double.tryParse(target ?? '');
    if (s == null || e == null || t == null) return const SizedBox.shrink();
    final n = double.tryParse(now ?? '');
    final values = [s, e, t, ?n];
    final low = values.reduce(min);
    final high = values.reduce(max);
    final span = high - low;
    if (span <= 0) return const SizedBox.shrink();
    double at(double v) => (v - low) / span;
    final cp = context.cp;
    final label = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: cp.primary,
      fontWeight: FontWeight.w700,
    );
    return Semantics(
      key: const Key('plan-ladder'),
      label: semantics,
      excludeSemantics: true,
      child: SizedBox(
        height: 40,
        child: LayoutBuilder(
          builder: (context, box) {
            final w = box.maxWidth;
            double x(double v) => at(v) * w;
            final lossFrom = min(x(s), x(e));
            final lossTo = max(x(s), x(e));
            final winFrom = min(x(e), x(t));
            final winTo = max(x(e), x(t));
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 24,
                  height: 6,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: cp.raised,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                Positioned(
                  left: lossFrom,
                  width: lossTo - lossFrom,
                  top: 24,
                  height: 6,
                  child: ColoredBox(color: cp.negative.withValues(alpha: 0.4)),
                ),
                Positioned(
                  left: winFrom,
                  width: winTo - winFrom,
                  top: 24,
                  height: 6,
                  child: ColoredBox(color: cp.positive.withValues(alpha: 0.4)),
                ),
                Positioned(
                  left: x(e) - 1,
                  top: 18,
                  width: 2,
                  height: 18,
                  child: ColoredBox(color: cp.text),
                ),
                if (n != null) ...[
                  Positioned(
                    left: (x(n) - 20).clamp(0, w - 40),
                    width: 40,
                    top: 0,
                    child: Text(
                      nowLabel,
                      key: const Key('plan-ladder-now'),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: label,
                    ),
                  ),
                  Positioned(
                    left: x(n) - 5,
                    top: 30,
                    child: Icon(
                      Icons.arrow_drop_up,
                      size: 10,
                      color: cp.primary,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
