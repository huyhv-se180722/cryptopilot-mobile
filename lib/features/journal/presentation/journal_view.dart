import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/message_text.dart';
import '../../../core/format/decimal_format.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/cp_colors.dart';
import '../../../core/web/web_links.dart';
import '../../market/data/market_repository.dart';
import '../../market/domain/market.dart';
import '../../market/presentation/market_widgets.dart';
import '../../plans/domain/plan.dart';
import '../application/journal_controllers.dart';
import '../domain/journal.dart';

/// `/journal/{id}` (SCR-21), pushed over the tabs.
String journalEntryLocation(String id) => '/journal/${Uri.encodeComponent(id)}';

String tradeResultName(AppLocalizations l, TradeResult result) =>
    switch (result) {
      TradeResult.win => l.journalWin,
      TradeResult.loss => l.journalLoss,
      TradeResult.breakeven => l.journalBreakeven,
    };

String tradeSourceName(AppLocalizations l, TradeSource source) =>
    source == TradeSource.simulated ? l.journalSimulated : l.journalManual;

String journalTime(DateTime at) =>
    DateFormat('d MMM HH:mm', 'en').format(at.toLocal());

/// SCR-20 Trading Journal (SRS 3.6.1): simulated and manual trades with
/// filters and results, inside the Plans tab (D-154). Recording a manual
/// trade (SCR-22) is on the web.
class JournalView extends ConsumerWidget {
  const JournalView({super.key});

  Future<void> _filter(BuildContext context, WidgetRef ref) async {
    final current = ref.read(journalControllerProvider).filter;
    final next = await showModalBottomSheet<JournalFilter>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => JournalFilterSheet(initial: current),
    );
    if (next != null) {
      unawaited(ref.read(journalControllerProvider.notifier).setFilter(next));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final cp = context.cp;
    final state = ref.watch(journalControllerProvider);
    final controller = ref.read(journalControllerProvider.notifier);
    final items = state.items;
    final filter = state.filter;

    Widget body;
    if (items == null && state.failure != null) {
      body = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 96),
          Center(child: Text(failureText(l, state.failure!))),
          Center(
            child: TextButton(
              onPressed: controller.load,
              child: Text(l.commonRetry),
            ),
          ),
        ],
      );
    } else if (items == null) {
      body = const ListSkeleton();
    } else if (items.isEmpty) {
      body = ListView(
        key: const Key('journal-empty'),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 96),
          Icon(Icons.menu_book_outlined, size: 48, color: cp.muted),
          const SizedBox(height: 12),
          Center(child: Text(l.journalEmpty)),
        ],
      );
    } else {
      body = NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.extentAfter < 400) {
            unawaited(controller.loadMore());
          }
          return false;
        },
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: items.length + (state.hasMore ? 1 : 0),
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            if (index == items.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return JournalRow(entry: items[index]);
          },
        ),
      );
    }

    final period = filter.days == null
        ? l.journalAllTime
        : l.journalLastDays(filter.days!);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              ActionChip(
                key: const Key('journal-filter'),
                avatar: const Icon(Icons.filter_list, size: 18),
                label: Text(period),
                onPressed: () => _filter(context, ref),
              ),
              const SizedBox(width: 8),
              // At 360 dp the label is cut; the tooltip keeps it whole.
              Flexible(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Tooltip(
                    message: l.journalRecordOnWeb,
                    child: TextButton.icon(
                      key: const Key('journal-record-web'),
                      onPressed: () => unawaited(
                        ref.read(webLinksProvider).open('/journal/new'),
                      ),
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: Text(
                        l.journalRecordOnWeb,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(onRefresh: controller.load, child: body),
        ),
      ],
    );
  }
}

/// A trade of SCR-20; opens SCR-21.
class JournalRow extends ConsumerWidget {
  const JournalRow({required this.entry, super.key});

  final JournalEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final cp = context.cp;
    final text = Theme.of(context).textTheme;
    final pair = ref.watch(
      marketRepositoryProvider(entry.market).select(
        (s) => s.pairs?.where((p) => p.pairId == entry.pairId).firstOrNull,
      ),
    );
    String price(String? value) => formatPrice(value, pair?.tickSize);
    final result = entry.result;
    final long = entry.direction == PlanDirection.long;
    return InkWell(
      key: Key('journal-row-${entry.id}'),
      onTap: () => context.push(journalEntryLocation(entry.id)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: pair?.symbol ?? '…',
                          style: text.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
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
                ),
                if (result != null) ...[
                  Text(
                    tradeResultName(l, result),
                    style: text.labelSmall?.copyWith(
                      color: switch (result) {
                        TradeResult.win => cp.positive,
                        TradeResult.loss => cp.negative,
                        TradeResult.breakeven => cp.muted,
                      },
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                _Signed(
                  entry.status == PositionState.closed ? entry.netPnl : null,
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              [
                '${price(entry.entryPrice)} → ${entry.exitPrice == null ? l.journalOpen : price(entry.exitPrice)}',
                tradeSourceName(l, entry.source),
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall?.copyWith(color: cp.muted),
            ),
            Text(
              [?entry.strategyName, journalTime(entry.entryTime)].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall?.copyWith(color: cp.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _Signed extends StatelessWidget {
  const _Signed(this.value);

  final String? value;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final color = switch (directionOf(value)) {
      Direction.up => cp.positive,
      Direction.down => cp.negative,
      Direction.flat => cp.text,
    };
    return Text(
      formatSignedDecimal(value),
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

/// The filters of SCR-20 (period, market, source, result, status,
/// strategy), as a History page of an exchange app.
class JournalFilterSheet extends ConsumerStatefulWidget {
  const JournalFilterSheet({required this.initial, super.key});

  final JournalFilter initial;

  @override
  ConsumerState<JournalFilterSheet> createState() => _JournalFilterSheetState();
}

class _JournalFilterSheetState extends ConsumerState<JournalFilterSheet> {
  late int? _days = widget.initial.days;
  late Market? _market = widget.initial.market;
  late TradeSource? _source = widget.initial.source;
  late TradeResult? _result = widget.initial.result;
  late PositionState? _status = widget.initial.status;
  late String? _strategy = widget.initial.strategyId;
  late String? _pair = widget.initial.pairId;

  Widget _chips<T>(
    String title,
    List<(T?, String)> options,
    T? selected,
    ValueChanged<T?> onSelect,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final (value, label) in options)
                ChoiceChip(
                  label: Text(label),
                  selected: selected == value,
                  onSelected: (_) => setState(() => onSelect(value)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pairPicker(AppLocalizations l, Market market) {
    final pairs =
        ref.watch(marketRepositoryProvider(market).select((s) => s.pairs)) ??
        const [];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DropdownButtonFormField<String?>(
        key: const Key('journal-filter-pair'),
        initialValue: pairs.any((p) => p.pairId == _pair) ? _pair : null,
        decoration: InputDecoration(labelText: l.journalPair),
        items: [
          DropdownMenuItem(value: null, child: Text(l.journalAll)),
          for (final pair in pairs)
            DropdownMenuItem(value: pair.pairId, child: Text(pair.symbol)),
        ],
        onChanged: (v) => setState(() => _pair = v),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final strategies = ref.watch(strategiesProvider).value ?? const [];
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          key: const Key('journal-filter-sheet'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _chips<int>(
              l.journalPeriod,
              [
                (7, l.journalLastDays(7)),
                (30, l.journalLastDays(30)),
                (90, l.journalLastDays(90)),
                (null, l.journalAllTime),
              ],
              _days,
              (v) => _days = v,
            ),
            _chips<Market>(
              l.journalMarket,
              [
                (null, l.journalAll),
                (Market.spot, l.marketSpot),
                (Market.futures, l.marketFutures),
              ],
              _market,
              (v) {
                _market = v;
                _pair = null;
              },
            ),
            if (_market case final market?) _pairPicker(l, market),
            _chips<TradeSource>(
              l.journalSource,
              [
                (null, l.journalAll),
                (TradeSource.simulated, l.journalSimulated),
                (TradeSource.manual, l.journalManual),
              ],
              _source,
              (v) => _source = v,
            ),
            _chips<TradeResult>(
              l.journalResult,
              [
                (null, l.journalAll),
                for (final r in TradeResult.values) (r, tradeResultName(l, r)),
              ],
              _result,
              (v) => _result = v,
            ),
            _chips<PositionState>(
              l.journalStatus,
              [
                (null, l.journalAll),
                (PositionState.open, l.journalOpen),
                (PositionState.closed, l.journalClosed),
              ],
              _status,
              (v) => _status = v,
            ),
            if (strategies.isNotEmpty)
              _chips<String>(
                l.journalStrategy,
                [
                  (null, l.journalAll),
                  for (final s in strategies) (s.id, s.name),
                ],
                _strategy,
                (v) => _strategy = v,
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('journal-filter-reset'),
                    onPressed: () =>
                        Navigator.pop(context, const JournalFilter()),
                    child: Text(l.journalReset),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    key: const Key('journal-filter-apply'),
                    onPressed: () => Navigator.pop(
                      context,
                      JournalFilter(
                        days: _days,
                        market: _market,
                        source: _source,
                        result: _result,
                        status: _status,
                        strategyId: _strategy,
                        pairId: _market == null ? null : _pair,
                      ),
                    ),
                    child: Text(l.journalApply),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
