import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/message_text.dart';
import '../../../core/format/decimal_format.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/cp_colors.dart';
import '../../chart/presentation/metric_chart.dart';
import '../../chart/presentation/metric_surface.dart';
import '../application/assets_controller.dart';
import '../application/assets_pnl_controller.dart';
import '../application/futures_history_controller.dart';
import '../application/trade_controller.dart';
import '../data/futures_repository.dart';
import '../data/paper_repository.dart';
import '../domain/paper.dart';
import 'paper_text.dart';

/// The Assets tab (D-154, plan 9.3): the estimated total with a switch to
/// hide amounts, the Spot coins (small ones can be hidden), the Futures
/// USDT, a transfer between them and the history. Virtual funds only: no
/// deposit, no withdrawal.
class AssetsScreen extends ConsumerWidget {
  const AssetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final account = ref.watch(paperAccountProvider);
    final assets = ref.watch(assetsControllerProvider);
    final controller = ref.read(assetsControllerProvider.notifier);
    final spot = account.spot;
    final text = Theme.of(context).textTheme;
    String money(String? value, {int places = 2}) =>
        assets.hideBalances ? l.assetsHidden : formatDecimal(value, places);

    final Widget body;
    if (spot == null && account.failure != null) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(failureText(l, account.failure!)),
            TextButton(
              onPressed: ref.read(paperAccountProvider.notifier).retry,
              child: Text(l.commonRetry),
            ),
          ],
        ),
      );
    } else if (spot == null) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      final coins = shownCoins(spot, hideSmall: assets.hideSmall);
      final pnl = ref.watch(assetsPnlProvider.select((s) => s.pnl));
      body = RefreshIndicator(
        onRefresh: controller.refresh,
        child: ListView(
          key: const Key('assets-list'),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Row(
              children: [
                Text(l.assetsTotal, style: text.bodyMedium),
                IconButton(
                  key: const Key('assets-eye'),
                  tooltip: assets.hideBalances
                      ? l.assetsShowBalances
                      : l.assetsHideBalances,
                  icon: Icon(
                    assets.hideBalances
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  onPressed: controller.toggleHideBalances,
                ),
              ],
            ),
            Text(
              l.assetsUsdt(money(spot.estimatedUsdt)),
              key: const Key('assets-total'),
              style: text.headlineSmall,
            ),
            if (!spot.complete)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  l.assetsIncomplete,
                  key: const Key('assets-incomplete'),
                  style: text.bodySmall?.copyWith(color: context.cp.muted),
                ),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.tonalIcon(
                  key: const Key('assets-transfer'),
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    showDragHandle: true,
                    builder: (_) => const _TransferSheet(),
                  ),
                  icon: const Icon(Icons.swap_vert),
                  label: Text(l.assetsTransfer),
                ),
                OutlinedButton.icon(
                  key: const Key('assets-history'),
                  onPressed: () {
                    ref
                        .read(historyFuturesProvider.notifier)
                        .show(futures: false);
                    context.push('/assets/history');
                  },
                  icon: const Icon(Icons.history),
                  label: Text(l.assetsHistory),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: Text(l.assetsSpot, style: text.titleMedium)),
                Flexible(
                  child: Text(
                    l.assetsUsdt(money(spot.estimatedUsdt)),
                    style: text.bodySmall,
                  ),
                ),
              ],
            ),
            SwitchListTile(
              key: const Key('assets-hide-small'),
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(l.assetsHideSmall),
              value: assets.hideSmall,
              onChanged: (_) => controller.toggleHideSmall(),
            ),
            if (coins.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(l.assetsNoCoins, textAlign: TextAlign.center),
              ),
            for (final coin in coins)
              ListTile(
                key: Key('coin-${coin.asset}'),
                contentPadding: EdgeInsets.zero,
                title: Text(coin.asset),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${l.assetsFree(money(coin.free, places: 8))} · '
                      '${l.assetsLocked(money(coin.locked, places: 8))}',
                    ),
                    if (coin.asset != 'USDT')
                      _CoinPnlLine(
                        pnl: pnl?.of(coin.asset),
                        hidden: assets.hideBalances,
                      ),
                  ],
                ),
                trailing: coin.asset == 'USDT'
                    ? Text(money(coin.total))
                    : TextButton(
                        key: Key('trade-${coin.asset}'),
                        onPressed: () {
                          ref
                              .read(tradePairProvider.notifier)
                              .select('${coin.asset}USDT');
                          ref
                              .read(tradeFuturesProvider.notifier)
                              .show(futures: false);
                          context.go('/trade');
                        },
                        child: Text(l.assetsTradeDemo),
                      ),
              ),
            const Divider(height: 32),
            Row(
              children: [
                Expanded(child: Text(l.assetsFutures, style: text.titleMedium)),
                IconButton(
                  key: const Key('assets-futures-history'),
                  tooltip: l.assetsHistory,
                  icon: const Icon(Icons.history),
                  onPressed: () {
                    ref
                        .read(historyFuturesProvider.notifier)
                        .show(futures: true);
                    context.push('/assets/history');
                  },
                ),
                TextButton(
                  key: const Key('assets-trade-futures'),
                  onPressed: () {
                    ref.read(tradeFuturesProvider.notifier).show(futures: true);
                    context.go('/trade');
                  },
                  child: Text(l.assetsTradeDemo),
                ),
              ],
            ),
            ListTile(
              key: const Key('futures-usdt'),
              contentPadding: EdgeInsets.zero,
              title: const Text('USDT'),
              trailing: Text(
                assets.futures == null
                    ? '--'
                    : money(assets.futures!.of('USDT')?.total ?? '0'),
              ),
            ),
            _FuturesAccountRows(money: money),
            const Divider(height: 32),
            _EquityCard(hidden: assets.hideBalances),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l.navAssets),
        actions: [
          IconButton(
            key: const Key('open-account'),
            tooltip: l.navAccount,
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => context.push('/account'),
          ),
        ],
      ),
      body: Column(
        children: [
          const DemoBanner(),
          Expanded(child: body),
        ],
      ),
    );
  }
}

/// A coin's average cost and unrealised PnL with its percent (plan 9.3);
/// a dash where the backend does not know a figure.
class _CoinPnlLine extends StatelessWidget {
  const _CoinPnlLine({required this.pnl, required this.hidden});

  final CoinPnl? pnl;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final pnl = this.pnl;
    if (pnl == null) return const SizedBox.shrink();
    final upnl = pnl.unrealizedPnl;
    final percent = pnl.unrealizedPnlPercent;
    String signed(String value) =>
        '${value.startsWith('-') ? '' : '+'}${formatDecimal(value, 2)}';
    final text = hidden
        ? l.assetsCoinPnl(l.assetsHidden, l.assetsHidden)
        : l.assetsCoinPnl(
            pnl.averageCost == null ? '--' : groupThousands(pnl.averageCost!),
            upnl == null
                ? '--'
                : percent == null
                ? signed(upnl)
                : '${signed(upnl)} (${signed(percent)}%)',
          );
    final color = hidden || upnl == null
        ? context.cp.muted
        : switch (directionOf(upnl)) {
            Direction.up => context.cp.positive,
            Direction.down => context.cp.negative,
            Direction.flat => context.cp.muted,
          };
    return Text(
      text,
      key: Key('coin-pnl-${pnl.asset}'),
      style: TextStyle(color: color),
    );
  }
}

/// The account's worth over the last 7, 30 or 90 days (plan 9.3), drawn
/// with the SCR-11 metric chart; the amounts follow the eye switch.
class _EquityCard extends ConsumerWidget {
  const _EquityCard({required this.hidden});

  final bool hidden;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(assetsPnlProvider);
    final controller = ref.read(assetsPnlProvider.notifier);
    final equity = state.equity;
    final history = equity?.history ?? const <EquityPoint>[];
    final small = Theme.of(context).textTheme.bodySmall;
    final Widget? cover;
    if (hidden) {
      cover = Text(l.assetsHidden);
    } else if (equity == null && state.equityFailure != null) {
      cover = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            failureText(l, state.equityFailure!),
            textAlign: TextAlign.center,
          ),
          TextButton(
            onPressed: controller.loadEquity,
            child: Text(l.commonRetry),
          ),
        ],
      );
    } else if (equity == null) {
      cover = const CircularProgressIndicator();
    } else if (history.length < 2) {
      cover = Text(l.assetsEquityEmpty, textAlign: TextAlign.center);
    } else {
      cover = null;
    }
    return Column(
      key: const Key('assets-equity'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l.assetsEquity,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            for (final days in equityPeriods)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: ChoiceChip(
                  key: Key('equity-$days'),
                  label: Text(l.assetsEquityDays(days)),
                  selected: state.days == days,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => controller.selectDays(days),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        MetricChart(
          lines: [
            if (!hidden && history.length >= 2)
              MetricLine(
                color: Theme.of(context).colorScheme.primary,
                scale: MetricScale.right,
                format: MetricFormat.amount,
                points: [for (final p in history) (p.date, p.totalEquity)],
              ),
          ],
          label: l.assetsEquityChart(state.days),
          cover: cover == null ? null : Center(child: cover),
        ),
        if (!hidden && state.pnl?.totalUnrealizedPnl != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              l.assetsSpotUpnl(
                '${state.pnl!.totalUnrealizedPnl!.startsWith('-') ? '' : '+'}'
                '${formatDecimal(state.pnl!.totalUnrealizedPnl, 2)}',
              ),
              key: const Key('assets-spot-upnl'),
              style: small,
            ),
          ),
        if (!hidden && state.pnl != null && !state.pnl!.complete)
          Text(l.assetsPnlIncomplete, style: small),
      ],
    );
  }
}

/// The Futures account (plan 9.3): unrealized PnL with its sign, margin
/// balance and what is available, kept live by [FuturesRepository].
class _FuturesAccountRows extends ConsumerWidget {
  const _FuturesAccountRows({required this.money});

  final String Function(String? value) money;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final account = ref.watch(futuresProvider.select((s) => s.account));
    final pnl = account?.unrealizedProfit;
    final pnlColor = switch (pnl == null ? Direction.flat : directionOf(pnl)) {
      Direction.up => context.cp.positive,
      Direction.down => context.cp.negative,
      Direction.flat => null,
    };
    final hidden = ref.watch(
      assetsControllerProvider.select((s) => s.hideBalances),
    );
    String signed(String value) => hidden
        ? money(value)
        : '${value.startsWith('-') ? '' : '+'}${money(value)}';
    Widget row(String key, String title, String value, {Color? color}) =>
        ListTile(
          key: Key(key),
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(title),
          trailing: Text(value, style: TextStyle(color: color)),
        );
    return Column(
      children: [
        row(
          'futures-pnl',
          l.assetsFuturesPnl,
          pnl == null ? '--' : signed(pnl),
          color: hidden ? null : pnlColor,
        ),
        row(
          'futures-margin-balance',
          l.assetsFuturesMargin,
          account == null ? '--' : money(account.marginBalance),
        ),
        row(
          'futures-available',
          l.assetsFuturesAvailable,
          account == null ? '--' : money(account.availableBalance),
        ),
      ],
    );
  }
}

class _TransferSheet extends ConsumerStatefulWidget {
  const _TransferSheet();

  @override
  ConsumerState<_TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends ConsumerState<_TransferSheet> {
  final _amount = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(transferControllerProvider);
    final controller = ref.read(transferControllerProvider.notifier);
    final spot = ref.watch(paperAccountProvider.select((s) => s.spot));
    final futures = ref.watch(
      assetsControllerProvider.select((s) => s.futures),
    );
    final account = ref.watch(futuresProvider.select((s) => s.account));
    final available = controller.available(spot, futures, account);
    String name(PaperWallet w) =>
        w == PaperWallet.spot ? l.assetsSpot : l.assetsFutures;
    final error = switch (state.issue) {
      TransferIssue.required => l.paperErrRequired,
      TransferIssue.notPositive => l.paperErrPositive,
      TransferIssue.tooPrecise => l.transferTooPrecise,
      TransferIssue.overAvailable =>
        state.from == PaperWallet.futures && account != null
            ? l.transferOverFutures
            : l.transferOver,
      null => switch (state.failure) {
        final failure? => failureText(l, failure),
        null => null,
      },
    };
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          key: const Key('transfer-sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.transferTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${l.transferFrom(name(state.from))}\n'
                    '${l.transferTo(name(state.to))}',
                    key: const Key('transfer-direction'),
                  ),
                ),
                IconButton(
                  key: const Key('transfer-swap'),
                  tooltip: l.transferSwap,
                  icon: const Icon(Icons.swap_vert),
                  onPressed: controller.swap,
                ),
              ],
            ),
            TextField(
              key: const Key('transfer-amount'),
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              onChanged: controller.edit,
              decoration: InputDecoration(
                labelText: l.transferAmount,
                errorText: error,
                helperText: l.tradeAvailable(
                  formatDecimal(available, 2),
                  'USDT',
                ),
                suffixIcon: TextButton(
                  key: const Key('transfer-max'),
                  onPressed: available == null
                      ? null
                      : () {
                          _amount.text = available;
                          controller.edit(available);
                        },
                  child: Text(l.transferMax),
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('transfer-send'),
              onPressed: state.sending
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final navigator = Navigator.of(context);
                      final sent = await controller.send(available: available);
                      if (!sent) return;
                      await ref
                          .read(assetsControllerProvider.notifier)
                          .refresh();
                      navigator.pop();
                      messenger.showSnackBar(
                        SnackBar(content: Text(l.transferDone)),
                      );
                    },
              child: Text(l.transferSend),
            ),
          ],
        ),
      ),
    );
  }
}
