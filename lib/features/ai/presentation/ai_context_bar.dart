import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/errors/message_text.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/cp_colors.dart';
import '../../market/data/market_repository.dart';
import '../../market/domain/candle.dart';
import '../../market/domain/market.dart';
import '../../plans/domain/plan.dart';
import '../application/ai_context.dart';
import '../application/ai_plans.dart';
import '../domain/ai.dart';

String marketLabel(AppLocalizations l, Market market) =>
    market == Market.spot ? l.marketSpot : l.marketFutures;

/// The pair's symbol: the context's, or read from the pair list.
String? contextSymbol(WidgetRef ref, AiContext context) {
  final pairId = context.pairId;
  if (pairId == null) return null;
  if (context.symbol != null) return context.symbol;
  return ref.watch(
    marketRepositoryProvider(context.market).select(
      (s) => s.pairs?.where((p) => p.pairId == pairId).firstOrNull?.symbol,
    ),
  );
}

/// The context selector above the input (SRS 3.9.1): chips of what the
/// next question reads, by topic.
class AiContextBar extends ConsumerWidget {
  const AiContextBar({
    required this.value,
    required this.onChanged,
    required this.quota,
    super.key,
  });

  final AiContext value;
  final ValueChanged<AiContext> onChanged;
  final AiQuota? quota;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final cp = context.cp;
    final small = Theme.of(context).textTheme.bodySmall;
    switch (value.topic) {
      case ConversationTopic.general:
        return Text(
          l.aiTopicGeneralHint,
          key: const Key('ai-context-general'),
          style: small?.copyWith(color: cp.muted),
        );
      case ConversationTopic.market:
        final symbol = contextSymbol(ref, value);
        return Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            ActionChip(
              key: const Key('ai-context-pair'),
              avatar: const Icon(Icons.currency_bitcoin, size: 18),
              label: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: Text(
                  value.pairId == null
                      ? l.aiPickPair
                      : '${symbol ?? '…'} · ${marketLabel(l, value.market)}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              onPressed: () async {
                final pair = await showModalBottomSheet<MarketPair>(
                  context: context,
                  isScrollControlled: true,
                  showDragHandle: true,
                  builder: (_) => AiPairSheet(market: value.market),
                );
                if (pair != null) {
                  onChanged(
                    value.withPair(pair.pairId, pair.symbol, pair.market),
                  );
                }
              },
            ),
            PopupMenuButton<Timeframe>(
              key: const Key('ai-context-timeframe'),
              tooltip: l.aiTimeframe,
              initialValue: value.timeframe,
              onSelected: (tf) => onChanged(value.withTimeframe(tf)),
              itemBuilder: (_) => [
                for (final tf in Timeframe.values)
                  PopupMenuItem(
                    key: Key('ai-timeframe-${tf.wire}'),
                    value: tf,
                    child: Text(tf.wire),
                  ),
              ],
              child: Chip(
                avatar: const Icon(Icons.schedule, size: 18),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(value.timeframe.wire),
                    const Icon(Icons.arrow_drop_down, size: 18),
                  ],
                ),
              ),
            ),
          ],
        );
      case ConversationTopic.myTrading:
        final plan = value.plan;
        final planSymbol = plan == null
            ? null
            : ref.watch(
                marketRepositoryProvider(plan.market).select(
                  (s) => s.pairs
                      ?.where((p) => p.pairId == plan.pairId)
                      .firstOrNull
                      ?.symbol,
                ),
              );
        final performance = quota?.performanceContext ?? false;
        return Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            ActionChip(
              key: const Key('ai-context-plan'),
              avatar: const Icon(Icons.assignment_outlined, size: 18),
              label: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: Text(
                  plan == null
                      ? l.aiPlan
                      : l.aiPlanChip(
                          planSymbol ?? '…',
                          plan.direction == PlanDirection.long
                              ? l.aiLong
                              : l.aiShort,
                        ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              onPressed: () async {
                final picked = await showModalBottomSheet<_PlanChoice>(
                  context: context,
                  isScrollControlled: true,
                  showDragHandle: true,
                  builder: (_) => AiPlanSheet(selected: plan?.id),
                );
                if (picked != null) onChanged(value.withPlan(picked.plan));
              },
            ),
            FilterChip(
              key: const Key('ai-context-performance'),
              label: Text(
                performance ? l.aiPerformance : l.aiPerformanceLocked,
              ),
              selected: value.includePerformance,
              onSelected: performance
                  ? (on) => onChanged(value.withPerformance(include: on))
                  : null,
            ),
          ],
        );
    }
  }
}

/// Picks a pair of either market for a MARKET question.
class AiPairSheet extends ConsumerStatefulWidget {
  const AiPairSheet({required this.market, super.key});

  final Market market;

  @override
  ConsumerState<AiPairSheet> createState() => _AiPairSheetState();
}

class _AiPairSheetState extends ConsumerState<AiPairSheet> {
  late Market _market = widget.market;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final data = ref.watch(marketRepositoryProvider(_market));
    final pairs = data.pairs;
    final shown = pairs?.where((p) => p.matches(_query)).toList();
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SegmentedButton<Market>(
              key: const Key('ai-pair-market'),
              segments: [
                for (final market in Market.values)
                  ButtonSegment(
                    value: market,
                    label: Text(marketLabel(l, market)),
                  ),
              ],
              selected: {_market},
              showSelectedIcon: false,
              onSelectionChanged: (value) =>
                  setState(() => _market = value.single),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              key: const Key('ai-pair-search'),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l.aiSearchPairs,
              ),
              onChanged: (text) => setState(() => _query = text),
            ),
          ),
          Expanded(
            child: shown == null
                ? (data.failure == null
                      ? const Center(child: CircularProgressIndicator())
                      : Center(child: Text(failureText(l, data.failure!))))
                : shown.isEmpty
                ? Center(child: Text(l.msg41))
                : ListView.builder(
                    itemCount: shown.length,
                    itemBuilder: (context, index) {
                      final pair = shown[index];
                      return ListTile(
                        key: Key('ai-pair-${pair.symbol}-${pair.market.wire}'),
                        title: Text(pair.symbol),
                        subtitle: Text(pair.baseAssetName),
                        onTap: () => Navigator.pop(context, pair),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// The plan picked, or none (clears it).
class _PlanChoice {
  const _PlanChoice(this.plan);

  final PlanSummary? plan;
}

/// Picks one of the Trader's plans for a MY_TRADING question.
class AiPlanSheet extends ConsumerWidget {
  const AiPlanSheet({required this.selected, super.key});

  final String? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final cp = context.cp;
    final plans = ref.watch(aiPlansProvider);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.6,
      child: plans.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                error is ApiFailure
                    ? failureText(l, error)
                    : l.msg43(l.errorUnknownReference),
              ),
              TextButton(
                onPressed: () => ref.invalidate(aiPlansProvider),
                child: Text(l.commonRetry),
              ),
            ],
          ),
        ),
        data: (items) => items.isEmpty
            ? Center(
                key: const Key('ai-no-plans'),
                child: Text(l.aiNoPlans, style: TextStyle(color: cp.muted)),
              )
            : ListView(
                children: [
                  ListTile(
                    key: const Key('ai-plan-none'),
                    title: Text(l.aiNoPlan),
                    selected: selected == null,
                    onTap: () =>
                        Navigator.pop(context, const _PlanChoice(null)),
                  ),
                  for (final plan in items)
                    _PlanTile(plan: plan, selected: plan.id == selected),
                ],
              ),
      ),
    );
  }
}

class _PlanTile extends ConsumerWidget {
  const _PlanTile({required this.plan, required this.selected});

  final PlanSummary plan;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final symbol = ref.watch(
      marketRepositoryProvider(plan.market).select(
        (s) =>
            s.pairs?.where((p) => p.pairId == plan.pairId).firstOrNull?.symbol,
      ),
    );
    return ListTile(
      key: Key('ai-plan-${plan.id}'),
      selected: selected,
      title: Text(
        l.aiPlanChip(
          symbol ?? '…',
          plan.direction == PlanDirection.long ? l.aiLong : l.aiShort,
        ),
      ),
      subtitle: Text(
        '${marketLabel(l, plan.market)} · ${switch (plan.status) {
          PlanStatus.draft => l.planStatusDraft,
          PlanStatus.active => l.planStatusActive,
          PlanStatus.executed => l.planStatusExecuted,
          PlanStatus.cancelled => l.planStatusCancelled,
          PlanStatus.expired => l.planStatusExpired,
          PlanStatus.invalidated => l.planStatusInvalidated,
        }}',
      ),
      onTap: () => Navigator.pop(context, _PlanChoice(plan)),
    );
  }
}
