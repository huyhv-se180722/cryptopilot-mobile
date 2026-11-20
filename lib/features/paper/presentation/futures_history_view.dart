import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/message_text.dart';
import '../../../core/format/decimal_format.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/cp_colors.dart';
import '../../market/data/market_repository.dart';
import '../../market/domain/market.dart';
import '../application/futures_history_controller.dart';
import '../application/history_controller.dart';
import '../domain/futures.dart';
import '../domain/futures_history.dart';
import '../domain/paper.dart';

/// The Futures tabs of the history screen (plan 9.3, T-123).
List<Tab> futuresHistoryTabs(AppLocalizations l) => [
  for (final kind in FuturesHistoryKind.values)
    Tab(
      text: switch (kind) {
        FuturesHistoryKind.positions => l.futHistPositions,
        FuturesHistoryKind.income => l.futHistIncome,
        FuturesHistoryKind.orders => l.historyOrders,
        FuturesHistoryKind.trades => l.historyFills,
        FuturesHistoryKind.conditional => l.futHistConditional,
        FuturesHistoryKind.liquidations => l.futHistLiquidations,
        FuturesHistoryKind.margin => l.futHistMargin,
      },
    ),
];

String _when(DateTime at) {
  final t = at.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
}

String _signed(String value) =>
    '${value.startsWith('-') ? '' : '+'}${formatTrimmed(value, keep: 2)}';

/// One Futures history with the filters its endpoint has.
class FuturesHistoryView extends ConsumerWidget {
  const FuturesHistoryView({required this.kind, super.key});

  final FuturesHistoryKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final provider = futuresHistoryProvider(kind);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final pairs =
        ref.watch(
          marketRepositoryProvider(Market.futures).select((s) => s.pairs),
        ) ??
        const <MarketPair>[];
    final items = state.items;

    final filters = <Widget>[
      Wrap(
        spacing: 6,
        children: [
          for (final period in <HistoryPeriod?>[null, ...HistoryPeriod.values])
            ChoiceChip(
              key: Key('fperiod-${kind.name}-${period?.name ?? 'all'}'),
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
      DropdownButton<String?>(
        key: Key('fh-symbol-${kind.name}'),
        value: state.symbol,
        hint: Text(l.futHistAllPairs),
        onChanged: controller.selectSymbol,
        items: [
          if (!kind.needsSymbol)
            DropdownMenuItem(child: Text(l.futHistAllPairs)),
          for (final pair in pairs)
            DropdownMenuItem(
              value: pair.symbol,
              child: Text('${pair.symbol} Perp'),
            ),
        ],
      ),
      if (kind == FuturesHistoryKind.income)
        DropdownButton<IncomeType?>(
          key: const Key('fh-income-type'),
          value: state.incomeType,
          hint: Text(l.historyAllTypes),
          onChanged: controller.selectIncomeType,
          items: [
            DropdownMenuItem(child: Text(l.historyAllTypes)),
            for (final type in IncomeType.values)
              DropdownMenuItem(value: type, child: Text(type.wire)),
          ],
        ),
      if (kind == FuturesHistoryKind.margin)
        Wrap(
          spacing: 6,
          children: [
            for (final (id, added, label) in [
              ('all', null, l.historyAll),
              ('added', true, l.futHistAdded),
              ('reduced', false, l.futHistReduced),
            ])
              ChoiceChip(
                key: Key('fh-margin-$id'),
                label: Text(label),
                selected: state.marginAdded == added,
                onSelected: (_) => controller.selectMarginAdded(added),
              ),
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
          key: Key('fh-empty-${kind.name}'),
          textAlign: TextAlign.center,
        ),
      );
    } else {
      list = Column(
        children: [
          for (final (i, item) in items.indexed)
            _FuturesRow(kind: kind, item: item, index: i),
        ],
      );
    }

    return ListView(
      key: Key('fh-${kind.name}'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [...filters, list],
    );
  }
}

class _FuturesRow extends StatelessWidget {
  const _FuturesRow({
    required this.kind,
    required this.item,
    required this.index,
  });

  final FuturesHistoryKind kind;
  final Object item;
  final int index;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    Color sideColor(OrderSide side) =>
        side == OrderSide.buy ? context.cp.positive : context.cp.negative;
    Color signColor(String value) => switch (directionOf(value)) {
      Direction.up => context.cp.positive,
      Direction.down => context.cp.negative,
      Direction.flat => context.cp.muted,
    };
    String sideText(OrderSide side) =>
        side == OrderSide.buy ? l.tradeBuy : l.tradeSell;
    return switch (item) {
      final ClosedPosition p => ListTile(
        key: Key('fh-position-${p.positionId}'),
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: Text(
          '${p.symbol} · ${p.long ? l.futLong : l.futShort} · '
          '${l.futLeverage(p.leverage)}',
          style: TextStyle(
            color: p.long ? context.cp.positive : context.cp.negative,
          ),
        ),
        subtitle: Text(
          '${formatTrimmed(p.entryPrice)} → ${formatTrimmed(p.avgClosePrice)}'
          ' · ${l.futHistClosed(p.closedQuantity)} · ${p.closeReason}'
          ' · ${_when(p.closeTime)}',
        ),
        trailing: Text(
          _signed(p.netProfit),
          style: TextStyle(color: signColor(p.netProfit)),
        ),
      ),
      final FuturesIncome i => ListTile(
        key: Key('fh-income-${i.tranId}'),
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: Text([i.typeWire, ?i.symbol].join(' · ')),
        subtitle: Text(_when(i.time)),
        trailing: Text(
          '${_signed(i.income)} USDT',
          style: TextStyle(color: signColor(i.income)),
        ),
      ),
      final FuturesOrder o => ListTile(
        key: Key(
          '${kind == FuturesHistoryKind.liquidations ? 'fh-force' : 'fh-order'}'
          '-${o.orderId}',
        ),
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: Text(
          '${o.symbol} · ${sideText(o.side)} · ${o.type}',
          style: TextStyle(color: sideColor(o.side)),
        ),
        subtitle: Text(
          '${formatTrimmed(o.price)} · ${formatTrimmed(o.executedQty)}/'
          '${formatTrimmed(o.origQty)}'
          ' · ${_when(o.time)}',
        ),
        trailing: Text(o.status.wire),
      ),
      final FuturesTrade t => ListTile(
        key: Key('fh-trade-${t.id}'),
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: Text(
          '${t.symbol} · ${sideText(t.side)}',
          style: TextStyle(color: sideColor(t.side)),
        ),
        subtitle: Text(
          '${formatTrimmed(t.price)} × ${formatTrimmed(t.qty)} · '
          '${_when(t.time)}',
        ),
        trailing: Text(
          _signed(t.realizedPnl),
          style: TextStyle(color: signColor(t.realizedPnl)),
        ),
      ),
      final AlgoOrder a => ListTile(
        key: Key('fh-algo-${a.algoId}'),
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: Text(
          '${a.symbol} · ${sideText(a.side)} · ${a.type}',
          style: TextStyle(color: sideColor(a.side)),
        ),
        subtitle: Text(formatTrimmed(a.triggerPrice)),
        trailing: Text(a.status),
      ),
      final MarginChange m => ListTile(
        key: Key('fh-margin-row-$index'),
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: Text(
          '${m.added ? l.futHistAdded : l.futHistReduced} · ${m.symbol}',
        ),
        subtitle: Text(_when(m.time)),
        trailing: Text(
          '${m.added ? '+' : '−'}${formatTrimmed(m.amount, keep: 2)} USDT',
          style: TextStyle(
            color: m.added ? context.cp.positive : context.cp.negative,
          ),
        ),
      ),
      _ => const SizedBox.shrink(),
    };
  }
}
