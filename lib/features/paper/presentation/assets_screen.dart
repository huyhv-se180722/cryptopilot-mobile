import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/message_text.dart';
import '../../../core/format/decimal_format.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/cp_colors.dart';
import '../application/assets_controller.dart';
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
                  onPressed: () => context.push('/assets/history'),
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
                subtitle: Text(
                  '${l.assetsFree(money(coin.free, places: 8))} · '
                  '${l.assetsLocked(money(coin.locked, places: 8))}',
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
