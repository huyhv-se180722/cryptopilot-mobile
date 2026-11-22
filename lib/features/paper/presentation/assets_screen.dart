import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/errors/message_text.dart';
import '../../../core/format/decimal_format.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/cp_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../../chart/presentation/metric_chart.dart';
import '../../chart/presentation/metric_surface.dart';
import '../../market/data/market_repository.dart';
import '../../market/domain/market.dart';
import '../../market/presentation/market_widgets.dart';
import '../application/assets_controller.dart';
import '../application/assets_pnl_controller.dart';
import '../application/futures_history_controller.dart';
import '../application/trade_controller.dart';
import '../data/futures_repository.dart';
import '../data/paper_repository.dart';
import '../domain/paper.dart';
import 'paper_text.dart';
import 'trade_widgets.dart';

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
      final futuresWorth = ref.watch(
        futuresProvider.select((s) => s.account?.marginBalance),
      );
      final total = addDecimal(spot.estimatedUsdt, futuresWorth);
      final week = sevenDayChange(
        ref.watch(assetsPnlProvider.select((s) => s.equity)),
        ref.read(clockProvider)(),
      );
      body = RefreshIndicator(
        onRefresh: controller.refresh,
        child: ListView(
          key: const Key('assets-list'),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Row(
              children: [
                Text(
                  l.assetsTotal,
                  style: text.bodyMedium?.copyWith(color: context.cp.muted),
                ),
                IconButton(
                  key: const Key('assets-eye'),
                  tooltip: assets.hideBalances
                      ? l.assetsShowBalances
                      : l.assetsHideBalances,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    assets.hideBalances
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                  ),
                  onPressed: controller.toggleHideBalances,
                ),
              ],
            ),
            // The worth of both wallets, large; its unit small (D-163, M7).
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: money(total ?? spot.estimatedUsdt),
                    style: text.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  TextSpan(
                    text: ' USDT',
                    style: text.titleSmall?.copyWith(color: context.cp.muted),
                  ),
                ],
              ),
              key: const Key('assets-total'),
            ),
            if (week != null)
              _WeekChange(change: week, hidden: assets.hideBalances),
            if (!spot.complete)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  l.assetsIncomplete,
                  key: const Key('assets-incomplete'),
                  style: text.bodySmall?.copyWith(color: context.cp.muted),
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                _RoundAction(
                  key: const Key('assets-transfer'),
                  icon: Icons.swap_vert,
                  label: l.assetsTransfer,
                  onTap: (_) => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    showDragHandle: true,
                    builder: (_) => const _TransferSheet(),
                  ),
                ),
                _RoundAction(
                  key: const Key('assets-history'),
                  icon: Icons.history,
                  label: l.assetsHistory,
                  onTap: (_) {
                    ref
                        .read(historyFuturesProvider.notifier)
                        .show(futures: false);
                    context.push('/assets/history');
                  },
                ),
                _RoundAction(
                  key: const Key('assets-trade'),
                  icon: Icons.swap_horiz,
                  label: l.assetsActionTrade,
                  onTap: (_) {
                    ref
                        .read(tradeFuturesProvider.notifier)
                        .show(futures: false);
                    context.go('/trade');
                  },
                ),
                _RoundAction(
                  key: const Key('assets-pnl'),
                  icon: Icons.show_chart,
                  label: l.assetsActionPnl,
                  onTap: (from) => _reveal(from, _equityKey),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SplitCard(
              spot: spot.estimatedUsdt,
              futures: futuresWorth,
              hidden: assets.hideBalances,
              money: money,
              onSpot: (from) => _reveal(from, _spotKey),
              onFutures: (from) => _reveal(from, _futuresKey),
            ),
            const SizedBox(height: 16),
            TradeSectionHeader(
              key: _spotKey,
              title: l.assetsSpot,
              trailing: TradeCheck(
                key: const Key('assets-hide-small'),
                label: l.assetsHideSmall,
                value: assets.hideSmall,
                onChanged: (_) => controller.toggleHideSmall(),
              ),
            ),
            if (coins.isEmpty)
              EmptyState(
                message: l.assetsNoCoins,
                icon: Icons.account_balance_wallet_outlined,
                inline: true,
              ),
            for (final coin in coins)
              _CoinRow(
                key: Key('coin-${coin.asset}'),
                coin: coin,
                hidden: assets.hideBalances,
                money: money,
                pnl: coin.asset == 'USDT'
                    ? null
                    : _CoinPnlLine(
                        pnl: pnl?.of(coin.asset),
                        hidden: assets.hideBalances,
                      ),
                onTrade: coin.asset == 'USDT'
                    ? null
                    : () {
                        ref
                            .read(tradePairProvider.notifier)
                            .select('${coin.asset}USDT');
                        ref
                            .read(tradeFuturesProvider.notifier)
                            .show(futures: false);
                        context.go('/trade');
                      },
              ),
            const SizedBox(height: 16),
            TradeSectionHeader(
              key: _futuresKey,
              title: l.assetsFutures,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    key: const Key('assets-futures-history'),
                    tooltip: l.assetsHistory,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.history),
                    onPressed: () {
                      ref
                          .read(historyFuturesProvider.notifier)
                          .show(futures: true);
                      context.push('/assets/history');
                    },
                  ),
                  Flexible(
                    child: TextButton(
                      key: const Key('assets-trade-futures'),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () {
                        ref
                            .read(tradeFuturesProvider.notifier)
                            .show(futures: true);
                        context.go('/trade');
                      },
                      child: Text(
                        l.assetsTradeDemo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
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
            KeyedSubtree(
              key: _equityKey,
              child: _EquityCard(hidden: assets.hideBalances),
            ),
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
    final text = hidden
        ? l.assetsCoinPnl(l.assetsHidden, l.assetsHidden)
        : l.assetsCoinPnl(
            formatCost(pnl.averageCost),
            upnl == null
                ? '--'
                : percent == null
                ? formatSignedDecimal(upnl)
                : '${formatSignedDecimal(upnl)} '
                      '(${formatSignedPercent(percent)})',
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

/// Scrolls the Assets list to [key]'s section. The list builds lazily, so a
/// section not built yet (the equity, last) is reached by going to the end
/// first, from [from], a context inside the list.
Future<void> _reveal(BuildContext from, GlobalKey key) async {
  const duration = Duration(milliseconds: 250);
  var target = key.currentContext;
  if (target == null) {
    final position = Scrollable.maybeOf(from)?.position;
    if (position == null) return;
    await position.animateTo(
      position.maxScrollExtent,
      duration: duration,
      curve: Curves.easeOut,
    );
    target = key.currentContext;
  }
  if (target == null || !target.mounted) return;
  await Scrollable.ensureVisible(target, duration: duration);
}

// Scroll targets of the round actions and the split card (one Assets tab).
final _spotKey = GlobalKey(debugLabel: 'assets-spot');
final _futuresKey = GlobalKey(debugLabel: 'assets-futures');
final _equityKey = GlobalKey(debugLabel: 'assets-equity');

/// The 7-day change under the total, coloured with its sign.
class _WeekChange extends StatelessWidget {
  const _WeekChange({required this.change, required this.hidden});

  final ({String change, String? percent}) change;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final color = hidden
        ? context.cp.muted
        : switch (directionOf(change.change)) {
            Direction.up => context.cp.positive,
            Direction.down => context.cp.negative,
            Direction.flat => context.cp.muted,
          };
    final percent = change.percent;
    final value = hidden
        ? l.assetsHidden
        : percent == null
        ? formatSignedDecimal(change.change)
        : '${formatSignedDecimal(change.change)} '
              '(${formatSignedPercent(percent)})';
    final small = Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '${l.assetsSevenDay}  ',
              style: small?.copyWith(color: context.cp.muted),
            ),
            TextSpan(
              text: value,
              style: small?.copyWith(color: color),
            ),
          ],
        ),
        key: const Key('assets-week'),
      ),
    );
  }
}

/// A round icon with its label under it (Transfer, History, Trade, PnL).
class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;

  /// Called with the button's context (inside the list).
  final void Function(BuildContext from) onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onTap(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: context.cp.raised,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 22),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Spot and Futures as shares of the total, each with a bar (D-163; the
/// split is a client figure the FE owner kept). Amounts and bars follow
/// the eye switch.
class _SplitCard extends StatelessWidget {
  const _SplitCard({
    required this.spot,
    required this.futures,
    required this.hidden,
    required this.money,
    required this.onSpot,
    required this.onFutures,
  });

  final String spot;
  final String? futures;
  final bool hidden;
  final String Function(String? value, {int places}) money;
  final void Function(BuildContext from) onSpot;
  final void Function(BuildContext from) onFutures;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final s = double.tryParse(spot) ?? 0;
    final f = double.tryParse(futures ?? '') ?? 0;
    final sum = s + f;
    Widget row(
      String key,
      String title,
      String? value,
      double share,
      void Function(BuildContext from) onTap,
    ) {
      final style = Theme.of(context).textTheme.bodyMedium;
      return InkWell(
        key: Key(key),
        onTap: () => onTap(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text(title, style: style)),
                  Text(
                    value == null ? '--' : l.assetsUsdt(money(value)),
                    style: style?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Icon(Icons.chevron_right, size: 18, color: context.cp.muted),
                ],
              ),
              if (!hidden && sum > 0) ...[
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: share,
                    minHeight: 4,
                    color: context.cp.primary,
                    backgroundColor: context.cp.raised,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Container(
      key: const Key('assets-split'),
      decoration: BoxDecoration(
        border: Border.all(color: context.cp.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          row(
            'assets-split-spot',
            l.assetsSpot,
            spot,
            sum > 0 ? s / sum : 0,
            onSpot,
          ),
          row(
            'assets-split-futures',
            l.assetsFutures,
            futures,
            sum > 0 ? f / sum : 0,
            onFutures,
          ),
        ],
      ),
    );
  }
}

/// A Spot coin: logo, name and what is in orders; the amount held and its
/// worth in USDT; tapped (not USDT), Trade opens on its pair.
class _CoinRow extends ConsumerWidget {
  const _CoinRow({
    required this.coin,
    required this.hidden,
    required this.money,
    required this.pnl,
    required this.onTrade,
    super.key,
  });

  final Balance coin;
  final bool hidden;
  final String Function(String? value, {int places}) money;
  final Widget? pnl;
  final VoidCallback? onTrade;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final muted = text.bodySmall?.copyWith(color: context.cp.muted);
    final usdt = coin.asset == 'USDT' ? coin.total : coin.usdtValue;
    // The coin's logo from the Spot pairs the app already reads (one way
    // from Market); letters until they arrive or for a coin with no pair.
    final logo = ref.watch(
      marketRepositoryProvider(Market.spot).select(
        (s) => s.pairs
            ?.where((p) => p.baseAsset == coin.asset && p.logoUrl != null)
            .firstOrNull
            ?.logoUrl,
      ),
    );
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CoinLogo(symbol: coin.asset, url: logo, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  coin.asset,
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  l.assetsLocked(
                    hidden ? l.assetsHidden : formatTrimmed(coin.locked),
                  ),
                  style: muted,
                ),
                ?pnl,
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                hidden ? l.assetsHidden : formatTrimmed(coin.total),
                style: text.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                usdt == null ? '--' : l.assetsApprox(money(usdt)),
                style: muted,
              ),
            ],
          ),
        ],
      ),
    );
    final onTrade = this.onTrade;
    if (onTrade == null) return row;
    return InkWell(
      key: Key('trade-${coin.asset}'),
      onTap: onTrade,
      child: Semantics(hint: l.assetsTradeDemo, child: row),
    );
  }
}
