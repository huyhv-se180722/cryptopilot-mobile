import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/errors/message_text.dart';
import '../../../core/format/decimal_format.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/cp_colors.dart';
import '../../../core/web/web_links.dart';
import '../../market/data/market_repository.dart';
import '../../market/domain/market.dart';
import '../../plans/domain/plan.dart';
import '../../plans/domain/plan_detail.dart';
import '../application/journal_controllers.dart';
import '../domain/journal.dart';
import 'journal_view.dart';

String _closeReason(AppLocalizations l, CloseReason reason) => switch (reason) {
  CloseReason.takeProfit => l.planCloseTakeProfit,
  CloseReason.stopLoss => l.planCloseStopLoss,
  CloseReason.manual => l.planCloseManual,
  CloseReason.liquidation => l.planCloseLiquidation,
};

String? _paid(String? fee) {
  final parsed = fee == null ? null : Decimal.tryParse(fee);
  return parsed == null ? null : (-parsed.abs()).toString();
}

/// SCR-21 Journal Entry Detail (SRS 3.6.1): the facts of the trade, read
/// only for a SIMULATED one (BR-40), a link to its plan (SCR-18), and the
/// review: strategy, setup description, lessons learned and mistakes, up to
/// 4,000 characters each; saving shows MSG14. A MANUAL trade is edited on the
/// web (SCR-22) and can be deleted here.
class JournalEntryScreen extends ConsumerStatefulWidget {
  const JournalEntryScreen({required this.id, super.key});

  final String id;

  @override
  ConsumerState<JournalEntryScreen> createState() => _JournalEntryScreenState();
}

class _JournalEntryScreenState extends ConsumerState<JournalEntryScreen> {
  final _setup = TextEditingController();
  final _lessons = TextEditingController();
  final _mistakes = TextEditingController();
  String? _strategy;
  bool _filled = false;
  Map<String, String> _errors = const {};

  @override
  void dispose() {
    _setup.dispose();
    _lessons.dispose();
    _mistakes.dispose();
    super.dispose();
  }

  void _fill(JournalDetail detail) {
    if (_filled) return;
    _filled = true;
    _setup.text = detail.setupDescription ?? '';
    _lessons.text = detail.lessonsLearned ?? '';
    _mistakes.text = detail.mistakes ?? '';
    _strategy = detail.entry.strategyId;
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    setState(() => _errors = const {});
    try {
      await ref
          .read(journalEntryControllerProvider(widget.id).notifier)
          .saveReview(
            strategyId: _strategy,
            setupDescription: _setup.text,
            lessonsLearned: _lessons.text,
            mistakes: _mistakes.text,
          );
      messenger.showSnackBar(SnackBar(content: Text(l.msg14)));
    } on ProblemFailure catch (failure) {
      if (!mounted) return;
      setState(() => _errors = failure.problem.fieldErrors);
      if (_errors.isEmpty) {
        messenger.showSnackBar(
          SnackBar(content: Text(failureText(l, failure))),
        );
      }
    } on ApiFailure catch (failure) {
      messenger.showSnackBar(SnackBar(content: Text(failureText(l, failure))));
    }
  }

  Future<void> _delete() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.journalDeleteTitle),
        content: Text(l.journalDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            key: const Key('journal-delete-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.journalDelete),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    try {
      await ref
          .read(journalEntryControllerProvider(widget.id).notifier)
          .delete();
      messenger.showSnackBar(SnackBar(content: Text(l.journalDeleted)));
      if (mounted) context.pop();
    } on ApiFailure catch (failure) {
      messenger.showSnackBar(SnackBar(content: Text(failureText(l, failure))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cp = context.cp;
    final text = Theme.of(context).textTheme;
    final state = ref.watch(journalEntryControllerProvider(widget.id));
    final detail = state.detail;
    if (detail == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l.journalEntryTitle)),
        body: Center(
          child: state.failure == null
              ? const CircularProgressIndicator()
              : Text(
                  state.missing ? l.msg41 : failureText(l, state.failure!),
                  key: const Key('journal-entry-failure'),
                ),
        ),
      );
    }
    _fill(detail);
    final entry = detail.entry;
    final manual = entry.source == TradeSource.manual;
    final pair = ref.watch(
      marketRepositoryProvider(entry.market).select(
        (s) => s.pairs?.where((p) => p.pairId == entry.pairId).firstOrNull,
      ),
    );
    String price(String? value) => formatPrice(value, pair?.tickSize);
    final result = entry.result;
    final editable = state.reviewEditable;
    final strategies = ref.watch(strategiesProvider).value ?? const [];
    final long = entry.direction == PlanDirection.long;

    Widget fact(String label, Widget value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: text.bodySmall?.copyWith(color: cp.muted),
            ),
          ),
          value,
        ],
      ),
    );
    Widget signed(String? value) => Text(
      formatSignedDecimal(value),
      style: TextStyle(
        color: switch (directionOf(value)) {
          Direction.up => cp.positive,
          Direction.down => cp.negative,
          Direction.flat => cp.text,
        },
      ),
    );
    Widget area(TextEditingController controller, String label, String key) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: TextField(
            key: Key('journal-$key'),
            controller: controller,
            enabled: editable,
            minLines: 2,
            maxLines: 6,
            maxLength: reviewMaxLength,
            decoration: InputDecoration(
              labelText: label,
              alignLabelWithHint: true,
              errorText: _errors[key] == null
                  ? null
                  : messageText(
                      l,
                      _errors[key]!,
                      field: label,
                      args: const ['0', '$reviewMaxLength'],
                    ),
            ),
          ),
        );

    return Scaffold(
      appBar: AppBar(
        title: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: pair?.symbol ?? '…'),
              TextSpan(
                text:
                    '  ${entry.market == Market.spot ? l.marketSpot : l.marketFutures} ',
                style: text.bodySmall?.copyWith(color: cp.muted),
              ),
              TextSpan(
                text: long ? l.planLong : l.planShort,
                style: text.bodySmall?.copyWith(
                  color: long ? cp.positive : cp.negative,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (manual)
            PopupMenuButton<String>(
              key: const Key('journal-menu'),
              onSelected: (action) => action == 'delete'
                  ? _delete()
                  : unawaited(
                      ref
                          .read(webLinksProvider)
                          .open('/journal/${entry.id}/edit'),
                    ),
              itemBuilder: (_) => [
                PopupMenuItem(
                  key: const Key('journal-edit-web'),
                  value: 'edit',
                  child: Text(l.journalEditOnWeb),
                ),
                PopupMenuItem(
                  key: const Key('journal-delete'),
                  value: 'delete',
                  child: Text(l.journalDelete),
                ),
              ],
            ),
        ],
      ),
      body: ListView(
        key: const Key('journal-entry'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                tradeSourceName(l, entry.source),
                style: text.labelMedium?.copyWith(color: cp.muted),
              ),
              if (result != null)
                Text(
                  tradeResultName(l, result),
                  style: text.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: switch (result) {
                      TradeResult.win => cp.positive,
                      TradeResult.loss => cp.negative,
                      TradeResult.breakeven => cp.muted,
                    },
                  ),
                ),
              if (entry.provisional)
                Text(l.planProvisional, style: text.labelSmall),
            ],
          ),
          const SizedBox(height: 8),
          if (entry.status == PositionState.closed) ...[
            Text(
              l.planNetPnl,
              style: text.labelMedium?.copyWith(color: cp.muted),
            ),
            DefaultTextStyle.merge(
              style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              child: signed(entry.netPnl),
            ),
            const Divider(height: 20),
          ],
          fact(l.planEntryFill, Text(price(entry.entryPrice))),
          fact(
            l.planExit,
            Text(
              entry.exitPrice == null
                  ? l.journalOpen
                  : [
                      price(entry.exitPrice),
                      if (entry.closeReason case final reason?)
                        _closeReason(l, reason),
                    ].join(' · '),
            ),
          ),
          fact(
            l.planQuantity,
            Text(formatDecimal(entry.quantity, decimalPlaces(pair?.stepSize))),
          ),
          if (entry.leverage != null)
            fact(l.planLeverage, Text('${entry.leverage}x')),
          fact(l.planStopLoss, Text(price(entry.stopLoss))),
          fact(l.planTakeProfit, Text(price(entry.takeProfit))),
          if (entry.realizedPnl != null)
            fact(l.planRealized, signed(entry.realizedPnl)),
          fact(l.planFees, signed(_paid(entry.feeAmount ?? entry.entryFee))),
          if (entry.market == Market.futures)
            fact(l.planFunding, signed(entry.fundingFeeAmount)),
          fact(l.planEntryTime, Text(journalTime(entry.entryTime))),
          if (entry.exitTime case final at?)
            fact(l.planExitTime, Text(journalTime(at))),
          if (entry.planId case final planId?)
            ListTile(
              key: const Key('journal-open-plan'),
              contentPadding: EdgeInsets.zero,
              title: Text(l.journalOpenPlan),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/plan/${Uri.encodeComponent(planId)}'),
            ),
          const Divider(height: 24),
          Text(l.journalReview, style: text.titleSmall),
          if (!editable)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                l.journalReviewImageNote,
                key: const Key('journal-review-locked'),
                style: text.bodySmall?.copyWith(color: cp.muted),
              ),
            ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String?>(
            key: const Key('journal-strategy'),
            initialValue: strategies.any((s) => s.id == _strategy)
                ? _strategy
                : null,
            decoration: InputDecoration(labelText: l.journalStrategy),
            items: [
              DropdownMenuItem(value: null, child: Text(l.journalNoStrategy)),
              for (final s in strategies)
                DropdownMenuItem(value: s.id, child: Text(s.name)),
            ],
            onChanged: editable ? (v) => setState(() => _strategy = v) : null,
          ),
          const SizedBox(height: 8),
          area(_setup, l.journalSetup, 'setupDescription'),
          area(_lessons, l.journalLessons, 'lessonsLearned'),
          area(_mistakes, l.journalMistakes, 'mistakes'),
          if (detail.chartImageUrl case final url?)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  url,
                  key: const Key('journal-chart-image'),
                  errorBuilder: (_, _, _) => Text(l.journalImageFailed),
                ),
              ),
            ),
          TextButton.icon(
            key: const Key('journal-upload-web'),
            onPressed: () => unawaited(
              ref.read(webLinksProvider).open('/journal/${entry.id}'),
            ),
            icon: const Icon(Icons.open_in_new, size: 16),
            label: Text(l.journalImageOnWeb),
          ),
          if (editable)
            FilledButton(
              key: const Key('journal-save'),
              onPressed: state.saving ? null : _save,
              child: Text(l.planSave),
            ),
        ],
      ),
    );
  }
}
