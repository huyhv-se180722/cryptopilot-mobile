import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/errors/message_text.dart';
import '../../../core/format/decimal_format.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/cp_colors.dart';
import '../../../core/web/web_links.dart';
import '../../market/data/market_repository.dart';
import '../../market/domain/market.dart';
import '../application/plan_detail_controller.dart';
import '../domain/plan.dart';
import '../domain/plan_detail.dart';
import 'plan_widgets.dart';

/// "+2.7%": how far [level] is from [from], with its sign; "--" without
/// either.
String distanceText(String? level, String? from) {
  final l = level == null ? null : Decimal.tryParse(level);
  final f = from == null ? null : Decimal.tryParse(from);
  if (l == null || f == null || f == Decimal.zero) return '--';
  final percent = ((l - f) / f).toDecimal(scaleOnInfinitePrecision: 8);
  return formatSignedPercent(percent.shift(2).toString());
}

String _time(DateTime at) =>
    DateFormat('d MMM yyyy HH:mm', 'en').format(at.toLocal());

/// SCR-18 Trading Plan Detail (SRS 3.5.3): the plan inputs, the snapshot,
/// the warnings and the status history; once executed the simulated
/// position, live while OPEN. Actions by status: Activate and Cancel on a
/// draft, Cancel on an active plan, Set SL/TP and Close position (SCR-19) on
/// an open position. Every figure is the server one.
class PlanDetailScreen extends ConsumerWidget {
  const PlanDetailScreen({
    required this.id,
    this.extraActions,
    this.journalLink,
    super.key,
  });

  final String id;

  /// Header actions other features add (Ask AI), composed by the router.
  final List<Widget> Function(PlanDetail plan)? extraActions;

  /// The link to the plan's journal entry (SCR-21), composed by the router.
  final Widget Function(PlanDetail plan)? journalLink;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final provider = planDetailControllerProvider(id);
    final state = ref.watch(provider);
    final plan = state.plan;

    if (plan == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l.planDetailTitle)),
        body: Center(
          child: state.failure == null
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      state.missing ? l.msg41 : failureText(l, state.failure!),
                      key: const Key('plan-detail-failure'),
                      textAlign: TextAlign.center,
                    ),
                    if (!state.missing)
                      TextButton(
                        onPressed: ref.read(provider.notifier).load,
                        child: Text(l.commonRetry),
                      ),
                  ],
                ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: PlanHeadline(
          pairId: plan.pairId,
          market: plan.market,
          direction: plan.direction,
          leverage: plan.leverage,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        actions: [
          ...?extraActions?.call(plan),
          if (plan.editable)
            IconButton(
              key: const Key('plan-edit-web'),
              tooltip: l.planEditOnWeb,
              icon: const Icon(Icons.open_in_new),
              onPressed: () => unawaited(
                ref.read(webLinksProvider).open('/plans/${plan.id}/edit'),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: ref.read(provider.notifier).load,
        child: ListView(
          key: const Key('plan-detail'),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _StatusLine(plan: plan),
            // A live position comes first; the plan's summary follows it.
            if (plan.position case final position?) ...[
              const SizedBox(height: 12),
              _PositionCard(plan: plan, position: position),
            ],
            if (plan.position != null) ?journalLink?.call(plan),
            if (plan.snapshot case final snapshot?) ...[
              const SizedBox(height: 12),
              _SummaryCard(plan: plan, snapshot: snapshot),
            ],
            const SizedBox(height: 8),
            _PlanSections(plan: plan),
            const PlanDisclaimer(key: Key('plan-detail-disclaimer')),
          ],
        ),
      ),
      bottomNavigationBar: _ActionBar(plan: plan, busy: state.busy),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.plan});

  final PlanDetail plan;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cp = context.cp;
    final reason = plan.invalidationReason;
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        StatusChip(statusName(l, plan.status), tone: cp.primary),
        if (plan.position != null)
          Text(
            l.planSimulatedPosition,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: cp.muted),
          ),
        if (reason != null)
          Text(
            switch (reason) {
              InvalidationReason.takeProfitReached => l.planInvalidTakeProfit,
              InvalidationReason.stopLossReached => l.planInvalidStopLoss,
              InvalidationReason.invalidationPrice => l.planInvalidPrice,
            },
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: cp.muted),
          ),
      ],
    );
  }
}

/// The simulated position (BR-34…BR-38): live while OPEN, how it ended once
/// CLOSED, net P/L as the headline then (D-97).
class _PositionCard extends ConsumerWidget {
  const _PositionCard({required this.plan, required this.position});

  final PlanDetail plan;
  final PlanPosition position;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final cp = context.cp;
    final text = Theme.of(context).textTheme;
    final pair = pairOf(ref, plan.market, plan.pairId);
    String price(String? value) => priceText(pair, value);
    final current = position.currentPrice;
    final futures = plan.market == Market.futures;
    // The live mark price of the pair (`/topic/overview.FUTURES`); null on
    // Spot or before the first push.
    final symbol = pair?.symbol;
    final mark = futures && symbol != null
        ? ref.watch(
            marketRepositoryProvider(
              Market.futures,
            ).select((s) => s.tickers[symbol]?.markPrice),
          )
        : null;
    return Container(
      key: const Key('plan-position'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cp.surface,
        border: Border.all(color: cp.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  position.open ? l.planUnrealized : l.planNetPnl,
                  style: text.labelMedium?.copyWith(color: cp.muted),
                ),
              ),
              if (position.provisional)
                StatusChip(l.planProvisional, tone: cp.warning),
            ],
          ),
          SignedAmount(
            position.open ? position.unrealizedPnl : position.netPnl,
            suffix: ' USDT',
            style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (position.open)
            Text(
              l.planUnrealizedHint,
              style: text.bodySmall?.copyWith(color: cp.muted),
            ),
          const Divider(height: 20),
          FactRow(l.planEntryFill, Text(price(position.fillPrice))),
          FactRow(
            l.planQuantity,
            Text(
              formatDecimal(position.quantity, decimalPlaces(pair?.stepSize)),
            ),
          ),
          if (position.open) ...[
            FactRow(l.planCurrentPrice, Text(price(current))),
            FactRow(
              l.planStopLoss,
              Text(
                '${price(position.stopLoss)}  ${distanceText(position.stopLoss, current)}',
              ),
            ),
            FactRow(
              l.planTakeProfit,
              Text(
                '${price(position.takeProfit)}  ${distanceText(position.takeProfit, current)}',
              ),
            ),
            // Liquidation goes by the mark price (BR-35, SRS 3.5.3).
            if (futures && position.liquidationPrice != null) ...[
              if (mark != null) FactRow(l.planMarkPrice, Text(price(mark))),
              FactRow(
                l.planLiquidation,
                Text(
                  '${price(position.liquidationPrice)}  ${distanceText(position.liquidationPrice, mark)}',
                ),
              ),
            ],
            if (position.breakevenPrice != null)
              FactRow(l.planBreakeven, Text(price(position.breakevenPrice))),
          ] else ...[
            FactRow(
              l.planExit,
              Text(
                [
                  price(position.exitPrice),
                  if (position.closeReason case final reason?)
                    closeReasonName(l, reason),
                ].join(' · '),
              ),
            ),
            if (position.exitTime case final at?)
              FactRow(l.planExitTime, Text(_time(at))),
            FactRow(l.planRealized, SignedAmount(position.realizedPnl)),
          ],
          FactRow(
            l.planFees,
            SignedAmount(
              _negative(position.open ? position.entryFee : position.feeAmount),
            ),
          ),
          if (futures)
            FactRow(l.planFunding, SignedAmount(position.fundingFeeAmount)),
          FactRow(l.planEntryTime, Text(_time(position.entryTime))),
          if (position.levelWarnings.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final warning in position.levelWarnings)
              _WarningLine(warning: warning),
          ],
          if (position.levelChanges.isNotEmpty)
            ExpansionTile(
              key: const Key('plan-level-history'),
              tilePadding: EdgeInsets.zero,
              title: Text(
                l.planLevelHistory(position.levelChanges.length),
                style: text.bodyMedium,
              ),
              children: [
                for (final change in position.levelChanges)
                  FactRow(
                    _time(change.changedAt),
                    Text(
                      [
                        if (change.newStopLoss != null)
                          '${l.planStopLoss} ${price(change.oldStopLoss)} → ${price(change.newStopLoss)}',
                        if (change.newTakeProfit != null)
                          '${l.planTakeProfit} ${price(change.oldTakeProfit)} → ${price(change.newTakeProfit)}',
                      ].join('\n'),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// A fee is money paid: shown with a minus sign.
String? _negative(String? fee) {
  final parsed = fee == null ? null : Decimal.tryParse(fee);
  if (parsed == null) return null;
  return (-parsed.abs()).toString();
}

class _WarningLine extends StatelessWidget {
  const _WarningLine({required this.warning});

  final PlanWarning warning;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cp = context.cp;
    final (icon, tone, label) = switch (warning.severity) {
      WarningSeverity.blocking => (
        Icons.block,
        cp.negative,
        l.planSeverityBlocking,
      ),
      WarningSeverity.warning => (
        Icons.warning_amber,
        cp.warning,
        l.planSeverityWarning,
      ),
      WarningSeverity.info => (
        Icons.info_outline,
        cp.muted,
        l.planSeverityInfo,
      ),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: tone),
          const SizedBox(width: 6),
          // MSG17: "{severity}: {message}".
          Expanded(
            child: Text(
              '$label: ${warning.message}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// SCR-18 summary (D-163, mockup b4): the risk-reward large with the loss
/// at the stop, the price ladder stop → entry → target with the last price,
/// then the levels and the sizes. A plan is not an order: no order words.
class _SummaryCard extends ConsumerWidget {
  const _SummaryCard({required this.plan, required this.snapshot});

  final PlanDetail plan;
  final PlanSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final cp = context.cp;
    final text = Theme.of(context).textTheme;
    final pair = pairOf(ref, plan.market, plan.pairId);
    String price(String? value) => priceText(pair, value);
    // The last price, read one way from Market (as the alert sheet does).
    final now = pair == null
        ? null
        : ref.watch(
            marketRepositoryProvider(
              plan.market,
            ).select((s) => s.tickers[pair.symbol]?.displayPrice),
          );
    final loss = snapshot.lossAtStopLoss ?? snapshot.riskAmount;
    final muted = text.bodySmall?.copyWith(color: cp.muted);
    final rr = snapshot.riskRewardRatio;
    return Container(
      key: const Key('plan-summary'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: cp.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.planSummaryRr, style: muted),
                    Text(
                      rr == null ? '--' : '1 : ${formatDecimal(rr, 2)}',
                      key: const Key('plan-summary-rr'),
                      style: text.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (loss != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(l.planLossAtSl, style: muted),
                    Text(
                      '${formatSignedDecimal(loss.trim().startsWith('-') ? loss : '-$loss')} USDT',
                      key: const Key('plan-summary-loss'),
                      style: text.titleMedium?.copyWith(
                        color: cp.negative,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          PriceLadder(
            stop: plan.stopLoss,
            entry: plan.entryPrice,
            target: plan.takeProfit,
            now: now,
            nowLabel: l.planNow,
            semantics: l.planLadderLabel(
              price(plan.stopLoss),
              price(plan.entryPrice),
              price(plan.takeProfit),
              price(now),
            ),
          ),
          const SizedBox(height: 4),
          _Grid(
            cells: [
              (l.planGridStop, price(plan.stopLoss), cp.negative),
              (l.planEntry, price(plan.entryPrice), null),
              (l.planGridTake, price(plan.takeProfit), cp.positive),
              (
                l.planQuantity,
                snapshot.positionQuantity == null
                    ? '--'
                    : '${formatDecimal(snapshot.positionQuantity, decimalPlaces(pair?.stepSize))}'
                          '${pair == null ? '' : ' ${pair.baseAsset}'}',
                null,
              ),
              if (snapshot.initialMargin != null)
                (
                  l.planGridMargin,
                  formatDecimal(snapshot.initialMargin, 2),
                  null,
                ),
              if (snapshot.estimatedLiquidationPrice != null)
                (
                  l.planLiquidation,
                  price(snapshot.estimatedLiquidationPrice),
                  null,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Figures three to a row: label above, value below; the third of each row
/// aligned to the end.
class _Grid extends StatelessWidget {
  const _Grid({required this.cells});

  final List<(String, String, Color?)> cells;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final label = text.bodySmall?.copyWith(color: context.cp.muted);
    final value = text.bodyMedium?.copyWith(
      fontWeight: FontWeight.w600,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Column(
      children: [
        for (var r = 0; r < cells.length; r += 3)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var c = r; c < r + 3; c++)
                  Expanded(
                    child: c >= cells.length
                        ? const SizedBox.shrink()
                        : Column(
                            crossAxisAlignment: c % 3 == 2
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              Text(
                                cells[c].$1,
                                style: label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                cells[c].$2,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: value?.copyWith(color: cells[c].$3),
                              ),
                            ],
                          ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PlanSections extends ConsumerWidget {
  const _PlanSections({required this.plan});

  final PlanDetail plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final pair = pairOf(ref, plan.market, plan.pairId);
    String price(String? value) => priceText(pair, value);
    final snapshot = plan.snapshot;
    return Column(
      children: [
        if (plan.warnings.isNotEmpty)
          ExpansionTile(
            key: const Key('plan-warnings'),
            tilePadding: EdgeInsets.zero,
            initiallyExpanded: plan.blocksActivation,
            title: Text(l.planWarnings(plan.warnings.length)),
            children: [
              for (final warning in plan.warnings)
                _WarningLine(warning: warning),
            ],
          ),
        ExpansionTile(
          key: const Key('plan-inputs'),
          tilePadding: EdgeInsets.zero,
          initiallyExpanded: true,
          title: Text(l.planInputs),
          children: [
            FactRow(l.planEntryType, Text(plan.entryType)),
            FactRow(l.planEntry, Text(price(plan.entryPrice))),
            FactRow(l.planStopLoss, Text(price(plan.stopLoss))),
            FactRow(l.planTakeProfit, Text(price(plan.takeProfit))),
            FactRow(l.planCapital, Text(formatDecimal(plan.capital, 2))),
            FactRow(
              l.planRiskPercent,
              Text('${formatDecimal(plan.riskPercent, 2)}%'),
            ),
            if (plan.leverage != null)
              FactRow(l.planLeverage, Text('${plan.leverage}x')),
            if (plan.analysisTimeframe != null)
              FactRow(l.planTimeframe, Text(plan.analysisTimeframe!)),
            if (plan.expiresAt case final at?)
              FactRow(l.planExpires, Text(_time(at))),
            if (plan.note case final note? when note.isNotEmpty)
              FactRow(l.planNote, Text(note)),
          ],
        ),
        if (snapshot != null)
          ExpansionTile(
            key: const Key('plan-snapshot'),
            tilePadding: EdgeInsets.zero,
            title: Text(l.planSnapshot),
            children: [
              FactRow(
                l.planQuantity,
                Text(
                  formatDecimal(
                    snapshot.positionQuantity,
                    decimalPlaces(pair?.stepSize),
                  ),
                ),
              ),
              FactRow(
                l.planRiskAmount,
                Text(formatDecimal(snapshot.riskAmount, 2)),
              ),
              FactRow(
                l.planRewardAmount,
                Text(formatDecimal(snapshot.rewardAmount, 2)),
              ),
              FactRow(
                l.planRiskReward,
                Text(formatDecimal(snapshot.riskRewardRatio, 2)),
              ),
              if (snapshot.netRiskReward != null)
                FactRow(
                  l.planNetRiskReward,
                  Text(formatDecimal(snapshot.netRiskReward, 2)),
                ),
              if (snapshot.estimatedLiquidationPrice != null)
                FactRow(
                  l.planLiquidation,
                  Text(price(snapshot.estimatedLiquidationPrice)),
                ),
            ],
          ),
        ExpansionTile(
          key: const Key('plan-status-history'),
          tilePadding: EdgeInsets.zero,
          title: Text(l.planStatusHistory),
          children: [
            for (final change in plan.statusHistory)
              FactRow(statusName(l, change.status), Text(_time(change.at))),
          ],
        ),
      ],
    );
  }
}

/// The actions the status allows (SRS 3.5.3).
class _ActionBar extends ConsumerWidget {
  const _ActionBar({required this.plan, required this.busy});

  final PlanDetail plan;
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final controller = ref.read(planDetailControllerProvider(plan.id).notifier);
    final buttons = <Widget>[
      if (plan.status == PlanStatus.draft)
        FilledButton(
          key: const Key('plan-activate'),
          onPressed: busy ? null : () => _activate(context, controller),
          child: Text(l.planActivate),
        ),
      if (plan.status == PlanStatus.draft || plan.status == PlanStatus.active)
        OutlinedButton(
          key: const Key('plan-cancel'),
          onPressed: busy ? null : () => _cancel(context, controller),
          child: Text(l.planCancel),
        ),
      if (plan.hasOpenPosition) ...[
        OutlinedButton(
          key: const Key('plan-set-levels'),
          onPressed: busy ? null : () => _setLevels(context, plan),
          child: Text(l.planSetLevels),
        ),
        FilledButton(
          key: const Key('plan-close'),
          onPressed: busy ? null : () => _close(context, plan),
          child: Text(l.planClosePosition),
        ),
      ],
    ];
    if (buttons.isEmpty) return const SizedBox.shrink();
    return Material(
      color: context.cp.surface,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: context.cp.border)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              for (var i = 0; i < buttons.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: buttons[i]),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _activate(
    BuildContext context,
    PlanDetailController controller,
  ) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    var outcome = await controller.activate();
    if (outcome case NeedsConfirmation(:final failure)) {
      if (!context.mounted) return;
      final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          key: const Key('plan-msg51'),
          content: Text(failureText(l, failure)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l.commonCancel),
            ),
            FilledButton(
              key: const Key('plan-msg51-confirm'),
              onPressed: () => Navigator.pop(context, true),
              child: Text(l.planActivate),
            ),
          ],
        ),
      );
      if (yes != true) return;
      outcome = await controller.activate(confirmDeviation: true);
    }
    switch (outcome) {
      case Activated():
        messenger.showSnackBar(SnackBar(content: Text(l.msg19)));
      case ActivateRefused(:final failure):
        if (!context.mounted) return;
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            key: const Key('plan-refused'),
            content: Text(failureText(l, failure)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l.commonClose),
              ),
            ],
          ),
        );
      case NeedsConfirmation():
        break;
    }
  }

  Future<void> _cancel(
    BuildContext context,
    PlanDetailController controller,
  ) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l.msg20),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.planKeep),
          ),
          FilledButton(
            key: const Key('plan-cancel-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.planCancel),
          ),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await controller.cancel();
    } on ApiFailure catch (failure) {
      messenger.showSnackBar(SnackBar(content: Text(failureText(l, failure))));
    }
  }

  Future<void> _setLevels(BuildContext context, PlanDetail plan) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => SetLevelsSheet(plan: plan),
      );

  Future<void> _close(BuildContext context, PlanDetail plan) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => ClosePositionSheet(plan: plan),
      );
}

/// SCR-19 Close Position (SRS 3.5.3, BR-39): the estimate of a taker exit at
/// the current last price, read again every 5 s, and MSG21 to confirm.
class ClosePositionSheet extends ConsumerStatefulWidget {
  const ClosePositionSheet({required this.plan, super.key});

  final PlanDetail plan;

  @override
  ConsumerState<ClosePositionSheet> createState() => _ClosePositionSheetState();
}

class _ClosePositionSheetState extends ConsumerState<ClosePositionSheet> {
  bool _closing = false;

  Future<void> _confirm() async {
    final l = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _closing = true);
    try {
      await ref
          .read(planDetailControllerProvider(widget.plan.id).notifier)
          .closePosition();
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text(l.planClosed)));
    } on ApiFailure catch (failure) {
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text(failureText(l, failure))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cp = context.cp;
    final text = Theme.of(context).textTheme;
    final state = ref.watch(closeEstimateProvider(widget.plan.id));
    final pair = pairOf(ref, widget.plan.market, widget.plan.pairId);
    String price(String? value) => priceText(pair, value);
    final estimate = state.estimate;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          key: const Key('plan-close-sheet'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.planClosePosition, style: text.titleMedium),
            const SizedBox(height: 4),
            PlanHeadline(
              pairId: widget.plan.pairId,
              market: widget.plan.market,
              direction: widget.plan.direction,
              leverage: widget.plan.leverage,
            ),
            const SizedBox(height: 12),
            if (estimate == null)
              Center(
                child: state.failure == null
                    ? const CircularProgressIndicator()
                    : Text(failureText(l, state.failure!)),
              )
            else ...[
              FactRow(l.planCurrentPrice, Text(price(estimate.currentPrice))),
              FactRow(
                l.planExitEstimate,
                Text(price(estimate.estimatedExitPrice)),
              ),
              FactRow(l.planPriceResult, SignedAmount(estimate.priceResult)),
              FactRow(
                l.planEntryFeeLine,
                SignedAmount(_negative(estimate.entryFee)),
              ),
              FactRow(
                l.planExitFee,
                SignedAmount(_negative(estimate.estimatedExitFee)),
              ),
              if (estimate.fundingSoFar != null)
                FactRow(
                  estimate.fundingProvisional
                      ? '${l.planFunding} (${l.planProvisional})'
                      : l.planFunding,
                  SignedAmount(estimate.fundingSoFar),
                ),
              const Divider(height: 20),
              FactRow(
                l.planNetEstimate,
                SignedAmount(
                  estimate.estimatedNetPnl,
                  suffix: ' USDT',
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (state.failure != null)
                Text(
                  failureText(l, state.failure!),
                  style: text.bodySmall?.copyWith(color: cp.negative),
                ),
              const SizedBox(height: 8),
              // MSG21.
              Text(
                l.msg21(
                  price(estimate.estimatedExitPrice),
                  formatSignedDecimal(estimate.estimatedNetPnl),
                ),
                key: const Key('plan-msg21'),
                style: text.bodyMedium,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _closing ? null : () => Navigator.pop(context),
                      child: Text(l.commonCancel),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      key: const Key('plan-close-confirm'),
                      onPressed: _closing ? null : _confirm,
                      child: Text(l.planConfirmClose),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Set SL/TP of an open position: the levels the exits use now; a level on
/// the wrong side of, or already reached by, the last price is refused under
/// its field (MSG16, MSG15).
class SetLevelsSheet extends ConsumerStatefulWidget {
  const SetLevelsSheet({required this.plan, super.key});

  final PlanDetail plan;

  @override
  ConsumerState<SetLevelsSheet> createState() => _SetLevelsSheetState();
}

class _SetLevelsSheetState extends ConsumerState<SetLevelsSheet> {
  late final _stop = TextEditingController(
    text: _plain(widget.plan.position?.stopLoss),
  );
  late final _take = TextEditingController(
    text: _plain(widget.plan.position?.takeProfit),
  );
  Map<String, String> _errors = const {};
  String? _failure;
  bool _saving = false;

  static String _plain(String? value) {
    final parsed = value == null ? null : Decimal.tryParse(value);
    return parsed?.toString() ?? '';
  }

  @override
  void dispose() {
    _stop.dispose();
    _take.dispose();
    super.dispose();
  }

  String _fieldText(AppLocalizations l, String field, String code) {
    final label = field == 'stopLoss' ? l.planStopLoss : l.planTakeProfit;
    if (code == 'MSG16') {
      final long = widget.plan.direction == PlanDirection.long;
      return l.msg16(
        directionName(l, widget.plan.direction),
        long ? l.planRuleLong : l.planRuleShort,
      );
    }
    return messageText(l, code, field: label);
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final stop = _stop.text.trim();
    final take = _take.text.trim();
    final oldStop = _plain(widget.plan.position?.stopLoss);
    final oldTake = _plain(widget.plan.position?.takeProfit);
    final changedStop = stop.isNotEmpty && stop != oldStop ? stop : null;
    final changedTake = take.isNotEmpty && take != oldTake ? take : null;
    if (changedStop == null && changedTake == null) {
      navigator.pop();
      return;
    }
    setState(() {
      _saving = true;
      _errors = const {};
      _failure = null;
    });
    try {
      final plan = await ref
          .read(planDetailControllerProvider(widget.plan.id).notifier)
          .changeLevels(stopLoss: changedStop, takeProfit: changedTake);
      navigator.pop();
      final warnings = plan.position?.levelWarnings ?? const [];
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            warnings.isEmpty
                ? l.msg14
                : warnings.map((w) => w.message).join('\n'),
          ),
        ),
      );
    } on ProblemFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errors = failure.problem.fieldErrors;
        _failure = _errors.isEmpty ? failureText(l, failure) : null;
      });
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _failure = failureText(l, failure);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final position = widget.plan.position;
    final pair = pairOf(ref, widget.plan.market, widget.plan.pairId);
    final long = widget.plan.direction == PlanDirection.long;
    InputDecoration field(String label, String key) => InputDecoration(
      labelText: label,
      errorText: _errors[key] == null
          ? null
          : _fieldText(l, key, _errors[key]!),
      errorMaxLines: 3,
      suffixText: 'USDT',
    );
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            key: const Key('plan-levels-sheet'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.planSetLevels, style: text.titleMedium),
              const SizedBox(height: 4),
              Text(
                '${l.planCurrentPrice} ${priceText(pair, position?.currentPrice)} · '
                '${long ? l.planRuleLong : l.planRuleShort}',
                style: text.bodySmall,
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('plan-stop-field'),
                controller: _stop,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: field(l.planStopLoss, 'stopLoss'),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('plan-take-field'),
                controller: _take,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: field(l.planTakeProfit, 'takeProfit'),
              ),
              if (_failure != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _failure!,
                    style: text.bodySmall?.copyWith(color: context.cp.negative),
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('plan-levels-save'),
                  onPressed: _saving ? null : _save,
                  child: Text(l.planSave),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
