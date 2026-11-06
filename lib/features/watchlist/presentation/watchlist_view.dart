import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/errors/message_text.dart';
import '../../../core/format/decimal_format.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/cp_colors.dart';
import '../../market/application/market_board.dart';
import '../../market/domain/market.dart';
import '../../market/presentation/market_widgets.dart';
import '../../market/presentation/pair_sheet.dart';
import '../application/watchlist_controller.dart';
import '../domain/watchlist.dart';
import 'add_pair_sheet.dart';

/// The pair behind a watched row: Spot when listed there, else Futures.
MarketPair? pairFor(WidgetRef ref, WatchItem item) {
  MarketPair? find(Market market) {
    final pairs = ref.watch(marketBoardProvider(market).select((s) => s.pairs));
    return pairs?.where((pair) => pair.pairId == item.pairId).firstOrNull;
  }

  return (item.spotListed ? find(Market.spot) : null) ??
      (item.futuresListed ? find(Market.futures) : null);
}

/// SCR-12 on the Markets tab: groups by label, live price and change from the
/// market boards, the setup score of the Trader's preset and the number of
/// active alerts. Swipe left removes (MSG26 when alerts go with it).
class WatchlistView extends ConsumerWidget {
  const WatchlistView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(watchlistControllerProvider);
    final controller = ref.read(watchlistControllerProvider.notifier);
    final watchlist = state.watchlist;

    Widget body;
    if (watchlist == null && state.failure != null) {
      body = _Centered(
        icon: Icons.cloud_off,
        title: failureText(l, state.failure!),
        action: TextButton(
          onPressed: controller.load,
          child: Text(l.commonRetry),
        ),
      );
    } else if (watchlist == null) {
      body = const ListSkeleton();
    } else if (watchlist.items.isEmpty) {
      body = _Centered(
        icon: Icons.star_border,
        title: l.watchEmptyTitle,
        body: l.watchEmptyBody,
        action: FilledButton.icon(
          onPressed: () => showAddPairSheet(context),
          icon: const Icon(Icons.add),
          label: Text(l.watchAddPair),
        ),
      );
    } else {
      body = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 88),
        children: [
          for (final (label, items) in state.groups) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                (label ?? l.watchUnlabelled).toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: context.cp.muted,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            for (final item in items) WatchRow(item: item),
          ],
        ],
      );
    }

    final count = watchlist?.items.length ?? 0;
    final limit = watchlist?.limit;
    return Scaffold(
      body: Column(
        children: [
          if (watchlist != null && watchlist.items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Text(
                    limit == null
                        ? l.watchCountNoLimit(count)
                        : l.watchCount(count, limit),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Spacer(),
                  LiveBadge(
                    delayed: ref.watch(
                      marketBoardProvider(Market.spot).select((s) => s.delayed),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: RefreshIndicator(onRefresh: controller.load, child: body),
          ),
        ],
      ),
      floatingActionButton: watchlist != null && watchlist.items.isNotEmpty
          ? FloatingActionButton.extended(
              key: const Key('add-pair'),
              onPressed: () => showAddPairSheet(context),
              icon: const Icon(Icons.add),
              label: Text(l.watchAddPair),
            )
          : null,
    );
  }
}

class WatchRow extends ConsumerWidget {
  const WatchRow({required this.item, super.key});

  final WatchItem item;

  Future<bool> _remove(BuildContext context, WidgetRef ref) =>
      removeWatchItem(context, ref, item);

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final label = TextEditingController(text: item.label ?? '');
    final note = TextEditingController(text: item.note ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.symbol),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('watch-label'),
              controller: label,
              maxLength: 100,
              decoration: InputDecoration(labelText: l.watchLabel),
            ),
            TextField(
              key: const Key('watch-note'),
              controller: note,
              maxLength: 1000,
              maxLines: 3,
              decoration: InputDecoration(labelText: l.watchNote),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            key: const Key('watch-save'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.watchSave),
          ),
        ],
      ),
    );
    if (!(saved ?? false) || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(watchlistControllerProvider.notifier)
          .edit(item, label: label.text, note: note.text);
      messenger.showSnackBar(SnackBar(content: Text(l.msg14)));
    } on ApiFailure catch (failure) {
      messenger.showSnackBar(SnackBar(content: Text(failureText(l, failure))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final pair = pairFor(ref, item);
    final market = pair?.market ?? Market.spot;
    final ticker = ref.watch(
      marketBoardProvider(market).select((s) => s.tickers[item.symbol]),
    );
    final score = ref.watch(
      watchlistControllerProvider.select((s) => s.scores[item.symbol]),
    );
    final listed = item.spotListed || item.futuresListed;
    final details = [
      if (!listed) l.watchUnlisted,
      if (score?.score != null) l.watchScore('${score!.score}'),
      l.watchAlerts(item.activeAlerts),
    ].join(' · ');

    return Dismissible(
      key: ValueKey('watch-${item.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _remove(context, ref),
      background: Container(
        color: context.cp.negative,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: InkWell(
        key: Key('watch-row-${item.symbol}'),
        onTap: pair == null ? null : () => showPairSheet(context, pair),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 4, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: pair?.baseAsset ?? item.symbol,
                            style: text.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (pair != null)
                            TextSpan(
                              text: '/${pair.quoteAsset}',
                              style: text.bodySmall?.copyWith(
                                color: context.cp.muted,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      details,
                      style: text.bodySmall?.copyWith(color: context.cp.muted),
                    ),
                  ],
                ),
              ),
              Text(
                formatPrice(ticker?.displayPrice, pair?.tickSize),
                style: text.titleSmall?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 12),
              ChangePill(percent: ticker?.changePercent24h, width: 76),
              PopupMenuButton<String>(
                key: Key('watch-menu-${item.symbol}'),
                onSelected: (action) => switch (action) {
                  'edit' => _edit(context, ref),
                  _ => _remove(context, ref),
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'edit', child: Text(l.watchEdit)),
                  PopupMenuItem(value: 'remove', child: Text(l.watchRemove)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({
    required this.icon,
    required this.title,
    this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(32, 64, 32, 32),
        child: Column(
          children: [
            Icon(icon, size: 36, color: context.cp.muted),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (body != null) ...[
              const SizedBox(height: 4),
              Text(body!, textAlign: TextAlign.center),
            ],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    ],
  );
}

/// Removes [item], asking MSG26 first when alerts go with it. Always false:
/// the reloaded list drops the row, a Dismissible never does.
Future<bool> removeWatchItem(
  BuildContext context,
  WidgetRef ref,
  WatchItem item,
) async {
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final controller = ref.read(watchlistControllerProvider.notifier);
  try {
    var outcome = await controller.remove(item);
    if (outcome is NeedsConfirmation && context.mounted) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          content: Text(
            l.msg26(
              item.symbol,
              '${outcome is NeedsConfirmation ? outcome.alerts : 0}',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l.commonCancel),
            ),
            FilledButton(
              key: const Key('confirm-remove'),
              onPressed: () => Navigator.pop(context, true),
              child: Text(l.watchRemove),
            ),
          ],
        ),
      );
      if (!(confirmed ?? false)) return false;
      outcome = await controller.remove(item, confirmedAlerts: outcome.alerts);
    }
  } on ApiFailure catch (failure) {
    messenger.showSnackBar(SnackBar(content: Text(failureText(l, failure))));
  }
  // The reloaded list drops the row; the Dismissible itself never does.
  return false;
}

/// "Add to watchlist" / "Watching" under a pair's figures (SRS 3.4.1: add from
/// SCR-09, SCR-10, SCR-11).
class WatchToggle extends ConsumerStatefulWidget {
  const WatchToggle({required this.pair, super.key});

  final MarketPair pair;

  @override
  ConsumerState<WatchToggle> createState() => _WatchToggleState();
}

class _WatchToggleState extends ConsumerState<WatchToggle> {
  bool _pending = false;

  Future<void> _add() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _pending = true);
    try {
      final item = await ref
          .read(watchlistControllerProvider.notifier)
          .add(widget.pair.pairId);
      messenger.showSnackBar(SnackBar(content: Text(l.msg25(item.symbol))));
    } on ApiFailure catch (failure) {
      messenger.showSnackBar(SnackBar(content: Text(failureText(l, failure))));
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(watchlistControllerProvider);
    final item = state.items
        .where((item) => item.pairId == widget.pair.pairId)
        .firstOrNull;
    if (item != null) {
      return OutlinedButton.icon(
        key: const Key('watch-toggle'),
        onPressed: _pending
            ? null
            : () async {
                setState(() => _pending = true);
                await removeWatchItem(context, ref, item);
                if (mounted) setState(() => _pending = false);
              },
        icon: const Icon(Icons.star),
        label: Text(l.watchWatching),
      );
    }
    return FilledButton.icon(
      key: const Key('watch-toggle'),
      onPressed: _pending || state.watchlist == null ? null : _add,
      icon: const Icon(Icons.star_border),
      label: Text(l.watchAddToWatchlist),
    );
  }
}
