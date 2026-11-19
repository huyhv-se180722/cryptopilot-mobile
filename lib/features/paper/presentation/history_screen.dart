import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/message_text.dart';
import '../../../core/format/decimal_format.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/cp_colors.dart';
import '../application/history_controller.dart';
import '../domain/paper.dart';
import 'paper_text.dart';

/// The paper histories (plan 9.3): orders, fills, the ledger and transfers,
/// each with the filters its endpoint has, page after page.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return DefaultTabController(
      length: HistoryKind.values.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.assetsHistory),
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: l.historyOrders),
              Tab(text: l.historyFills),
              Tab(text: l.historyLedger),
              Tab(text: l.historyTransfers),
            ],
          ),
        ),
        body: Column(
          children: [
            const DemoBanner(),
            Expanded(
              child: TabBarView(
                children: [
                  for (final kind in HistoryKind.values) _History(kind: kind),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _when(DateTime at) {
  final t = at.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
}

class _History extends ConsumerWidget {
  const _History({required this.kind});

  final HistoryKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final provider = historyControllerProvider(kind);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final items = state.items;

    final filters = <Widget>[
      if (kind != HistoryKind.transfers)
        Wrap(
          spacing: 6,
          children: [
            for (final period in <HistoryPeriod?>[
              null,
              ...HistoryPeriod.values,
            ])
              ChoiceChip(
                key: Key('period-${kind.name}-${period?.name ?? 'all'}'),
                label: Text(switch (period) {
                  null => l.historyAll,
                  HistoryPeriod.day => l.historyDay,
                  HistoryPeriod.week => l.historyWeek,
                  HistoryPeriod.month => l.historyMonth,
                  HistoryPeriod.quarter => l.historyQuarter,
                }),
                selected: state.period == period,
                onSelected: (_) => controller.selectPeriod(period),
              ),
          ],
        ),
      if (kind == HistoryKind.orders)
        DropdownButton<OrderStatus?>(
          key: const Key('history-status'),
          value: state.status,
          hint: Text(l.historyAllStatuses),
          onChanged: controller.selectStatus,
          items: [
            DropdownMenuItem(child: Text(l.historyAllStatuses)),
            for (final status in OrderStatus.values)
              DropdownMenuItem(value: status, child: Text(status.wire)),
          ],
        ),
      if (kind == HistoryKind.ledger)
        DropdownButton<LedgerType?>(
          key: const Key('history-type'),
          value: state.ledgerType,
          hint: Text(l.historyAllTypes),
          onChanged: controller.selectLedgerType,
          items: [
            DropdownMenuItem(child: Text(l.historyAllTypes)),
            for (final type in LedgerType.values)
              DropdownMenuItem(value: type, child: Text(type.wire)),
          ],
        ),
    ];

    final Widget list;
    if (items == null && state.failure != null) {
      list = Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(failureText(l, state.failure!), textAlign: TextAlign.center),
            TextButton(onPressed: controller.load, child: Text(l.commonRetry)),
          ],
        ),
      );
    } else if (items == null) {
      list = const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (items.isEmpty) {
      list = Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          l.historyEmpty,
          key: Key('history-empty-${kind.name}'),
          textAlign: TextAlign.center,
        ),
      );
    } else {
      list = Column(children: [for (final item in items) _Row(item: item)]);
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (note) {
        if (note.metrics.extentAfter < 300) controller.loadMore();
        return false;
      },
      child: ListView(
        key: Key('history-${kind.name}'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          ...filters,
          list,
          if (state.loadingMore)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.item});

  final Object item;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    Color sideColor(OrderSide side) =>
        side == OrderSide.buy ? context.cp.positive : context.cp.negative;
    String sideText(OrderSide side) =>
        side == OrderSide.buy ? l.tradeBuy : l.tradeSell;
    return switch (item) {
      final PaperOrder o => ListTile(
        key: Key('history-order-${o.orderId}'),
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: Text(
          '${o.symbol} · ${sideText(o.side)} · ${o.type.wire}',
          style: TextStyle(color: sideColor(o.side)),
        ),
        subtitle: Text(
          '${groupThousands(o.price ?? o.avgPrice ?? '--')} · '
          '${o.executedQuantity}/${o.quantity ?? '--'} · ${_when(o.placedAt)}',
        ),
        trailing: Text(o.status.wire),
      ),
      final PaperFill f => ListTile(
        key: Key('history-fill-${f.fillId}'),
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: Text(
          '${f.symbol} · ${sideText(f.side)}',
          style: TextStyle(color: sideColor(f.side)),
        ),
        subtitle: Text(
          '${groupThousands(f.price)} × ${f.quantity} · '
          '${f.fee} ${f.feeAsset} · ${_when(f.tradedAt)}',
        ),
      ),
      final LedgerEntry e => ListTile(
        key: Key('history-ledger-${e.entryId}'),
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: Text('${e.type.wire} · ${e.wallet.wire}'),
        subtitle: Text(_when(e.createdAt)),
        trailing: Text(
          '${e.amount.startsWith('-') ? '' : '+'}${groupThousands(e.amount)} '
          '${e.asset}',
          style: TextStyle(
            color: e.amount.startsWith('-')
                ? context.cp.negative
                : context.cp.positive,
          ),
        ),
      ),
      final Transfer t => ListTile(
        key: Key('history-transfer-${t.transferId}'),
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: Text('${t.from.wire} → ${t.to.wire}'),
        subtitle: Text(_when(t.transferredAt)),
        trailing: Text('${groupThousands(t.amount)} ${t.asset}'),
      ),
      _ => const SizedBox.shrink(),
    };
  }
}
