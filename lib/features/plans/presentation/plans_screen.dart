import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/errors/message_text.dart';
import '../../../core/format/age_format.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/cp_colors.dart';
import '../../../core/web/web_links.dart';
import '../../market/presentation/market_widgets.dart';
import '../application/plan_lists.dart';
import '../domain/plan.dart';
import 'plan_widgets.dart';

/// The Plans tab (D-154; A-61: read only): Positions, Active with the
/// drafts, History and the journal ([journal], composed by the router so
/// the two features do not depend on each other). Plans are created and
/// edited on the web (SCR-17).
class PlansScreen extends StatelessWidget {
  const PlansScreen({
    required this.journal,
    this.actions = const [],
    this.initialTab,
    super.key,
  });

  final Widget journal;

  /// `journal` opens the journal (`/plans?tab=journal`, an Academy link).
  final String? initialTab;

  /// Header actions other features add (the bell), composed by the router.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return DefaultTabController(
      length: 4,
      initialIndex: initialTab == 'journal' ? 3 : 0,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.navPlans),
          actions: [
            Consumer(
              builder: (context, ref, _) => IconButton(
                key: const Key('plan-create-web'),
                tooltip: l.planCreateOnWeb,
                icon: const Icon(Icons.add_box_outlined),
                onPressed: () =>
                    unawaited(ref.read(webLinksProvider).open('/plans/new')),
              ),
            ),
            ...actions,
            IconButton(
              key: const Key('open-account'),
              tooltip: l.navAccount,
              icon: const Icon(Icons.account_circle_outlined),
              onPressed: () => context.push('/account'),
            ),
          ],
          bottom: TabBar(
            key: const Key('plans-tabs'),
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(
                key: const Key('plans-tab-positions'),
                text: l.planTabPositions,
              ),
              Tab(key: const Key('plans-tab-active'), text: l.planTabActive),
              Tab(key: const Key('plans-tab-history'), text: l.planTabHistory),
              Tab(key: const Key('plans-tab-journal'), text: l.planTabJournal),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            const _PlanListView(
              lists: [PlanList.openPositions],
              emptyIcon: Icons.show_chart,
            ),
            const _PlanListView(
              lists: [PlanList.active, PlanList.drafts],
              emptyIcon: Icons.assignment_outlined,
            ),
            const _HistoryView(),
            journal,
          ],
        ),
      ),
    );
  }
}

class _HistoryView extends StatefulWidget {
  const _HistoryView();

  @override
  State<_HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<_HistoryView> {
  PlanList _list = PlanList.executed;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              ChoiceChip(
                key: const Key('plans-history-executed'),
                label: Text(l.planHistoryExecuted),
                selected: _list == PlanList.executed,
                onSelected: (_) => setState(() => _list = PlanList.executed),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                key: const Key('plans-history-cancelled'),
                label: Text(l.planHistoryCancelled),
                selected: _list == PlanList.cancelledExpired,
                onSelected: (_) =>
                    setState(() => _list = PlanList.cancelledExpired),
              ),
            ],
          ),
        ),
        Expanded(
          child: _PlanListView(
            key: ValueKey(_list),
            lists: [_list],
            emptyIcon: Icons.history,
          ),
        ),
      ],
    );
  }
}

/// One or two lists one under the other (Active, then the drafts under
/// their heading), with load more on the last one.
class _PlanListView extends ConsumerWidget {
  const _PlanListView({
    required this.lists,
    required this.emptyIcon,
    super.key,
  });

  final List<PlanList> lists;
  final IconData emptyIcon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final cp = context.cp;
    final states = [
      for (final list in lists) ref.watch(planListProvider(list)),
    ];
    final first = states.first;
    Future<void> reload() => Future.wait([
      for (final list in lists)
        ref.read(planListProvider(list).notifier).load(),
    ]);

    Widget body;
    if (first.items == null && first.failure != null) {
      body = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 96),
          Icon(Icons.cloud_off, size: 40, color: cp.muted),
          const SizedBox(height: 12),
          Center(child: Text(failureText(l, first.failure!))),
          Center(
            child: TextButton(onPressed: reload, child: Text(l.commonRetry)),
          ),
        ],
      );
    } else if (first.items == null) {
      body = const ListSkeleton();
    } else if (states.every((s) => (s.items ?? const []).isEmpty)) {
      body = ListView(
        key: Key('plans-empty-${lists.first.name}'),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 96),
          Icon(emptyIcon, size: 48, color: cp.muted),
          const SizedBox(height: 12),
          Center(child: Text(l.planEmpty)),
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 4, 32, 0),
            child: Text(
              l.planEmptyHint,
              textAlign: TextAlign.center,
              style: TextStyle(color: cp.muted),
            ),
          ),
        ],
      );
    } else {
      final rows = <Widget>[];
      for (var i = 0; i < lists.length; i++) {
        final items = states[i].items ?? const <PlanSummary>[];
        if (i > 0 && items.isNotEmpty) {
          rows.add(
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                l.planDrafts,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: cp.muted),
              ),
            ),
          );
        }
        for (final plan in items) {
          rows.add(PlanRow(plan: plan));
        }
      }
      final last = states.last;
      if (last.hasMore) {
        rows.add(
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
        );
      }
      rows.add(const PlanDisclaimer(key: Key('plans-disclaimer')));
      body = NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.extentAfter < 400) {
            unawaited(
              ref.read(planListProvider(lists.last).notifier).loadMore(),
            );
          }
          return false;
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 16),
          children: rows,
        ),
      );
    }
    return RefreshIndicator(onRefresh: reload, child: body);
  }
}

/// A plan of the lists; opens SCR-18.
class PlanRow extends ConsumerWidget {
  const PlanRow({required this.plan, super.key});

  final PlanSummary plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final cp = context.cp;
    final text = Theme.of(context).textTheme;
    final pair = pairOf(ref, plan.market, plan.pairId);
    final now = ref.read(clockProvider)();
    final position = plan.positionState;
    final (label, tone) = position == null
        ? (statusName(l, plan.status), cp.muted)
        : position == PositionState.open
        ? (l.planPositionOpen, cp.primary)
        : (l.planPositionClosed, cp.muted);
    return InkWell(
      key: Key('plan-row-${plan.id}'),
      onTap: () => context.push(planLocation(plan.id)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: PlanHeadline(
                    pairId: plan.pairId,
                    market: plan.market,
                    direction: plan.direction,
                    leverage: plan.leverage,
                  ),
                ),
                const SizedBox(width: 8),
                StatusChip(label, tone: tone),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              [
                '${l.planEntry} ${priceText(pair, plan.entryPrice)}',
                '${l.planStopLoss} ${priceText(pair, plan.stopLoss)}',
                '${l.planTakeProfit} ${priceText(pair, plan.takeProfit)}',
              ].join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall?.copyWith(color: cp.muted),
            ),
            const SizedBox(height: 2),
            Text(
              '${plan.entryType} · ${formatAge(l, plan.createdAt, now)}',
              style: text.bodySmall?.copyWith(color: cp.muted),
            ),
          ],
        ),
      ),
    );
  }
}
