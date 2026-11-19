import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/errors/message_text.dart';
import '../../../core/format/decimal_format.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/cp_colors.dart';
import '../../market/data/market_repository.dart';
import '../../market/data/order_book_repository.dart';
import '../../market/domain/market.dart';
import '../../market/domain/order_book.dart';
import '../application/spot_form_controller.dart';
import '../application/trade_controller.dart';
import '../data/paper_repository.dart';
import '../domain/paper.dart';
import '../domain/paper_refusal.dart';
import 'paper_text.dart';

/// The Trade tab (D-154, plan 9.2): the demo banner, Spot or Futures, and
/// for Spot the pair, the order form beside the order book, then the open
/// orders and the market trades. Futures arrives with T-129.
class TradeScreen extends StatefulWidget {
  const TradeScreen({super.key});

  @override
  State<TradeScreen> createState() => _TradeScreenState();
}

class _TradeScreenState extends State<TradeScreen> {
  bool _futures = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.navTrade),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SegmentedButton<bool>(
              key: const Key('trade-segment'),
              segments: [
                ButtonSegment(value: false, label: Text(l.tradeSpot)),
                ButtonSegment(value: true, label: Text(l.tradeFutures)),
              ],
              selected: {_futures},
              onSelectionChanged: (s) => setState(() => _futures = s.first),
            ),
          ),
          Expanded(
            child: _futures
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        l.tradeFuturesSoon,
                        key: const Key('trade-futures-soon'),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : const _SpotTrade(),
          ),
        ],
      ),
    );
  }
}

class _SpotTrade extends ConsumerWidget {
  const _SpotTrade();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final board = marketRepositoryProvider(Market.spot);
    final pairs = ref.watch(board.select((s) => s.pairs));
    final pairsFailure = ref.watch(board.select((s) => s.failure));
    final account = ref.watch(paperAccountProvider);
    final pair = tradePairOf(ref.watch(tradePairProvider), pairs);
    // Each fill pushed is told once: a side effect per push, so listen.
    ref.listen(openOrdersProvider.select((s) => s.fills), (_, _) {
      final fill = ref.read(openOrdersProvider).fill;
      if (fill == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l.tradeFilled(
              fill.side == OrderSide.buy ? l.tradeBuy : l.tradeSell,
              fill.quantity,
              fill.symbol,
              groupThousands(fill.price),
            ),
          ),
        ),
      );
    });

    if (account.spot == null && account.failure != null) {
      return _Failed(
        failure: account.failure!,
        onRetry: ref.read(paperAccountProvider.notifier).retry,
      );
    }
    if (pair == null) {
      if (pairsFailure != null) {
        return _Failed(
          failure: pairsFailure,
          onRetry: ref.read(board.notifier).load,
        );
      }
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      key: const Key('trade-spot'),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      children: [
        _PairHeader(pair: pair),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 6, child: _SpotForm(pair: pair)),
            const SizedBox(width: 8),
            Expanded(flex: 5, child: _Book(pair: pair)),
          ],
        ),
        const SizedBox(height: 16),
        _OrdersAndTrades(pair: pair),
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text(
            l.paperDemoBanner,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: context.cp.muted),
          ),
        ),
      ],
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.failure, required this.onRetry});

  final ApiFailure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(failureText(l, failure), textAlign: TextAlign.center),
            TextButton(onPressed: onRetry, child: Text(l.commonRetry)),
          ],
        ),
      ),
    );
  }
}

/// The pair (a sheet to change it), its last price and 24 h change.
class _PairHeader extends ConsumerWidget {
  const _PairHeader({required this.pair});

  final MarketPair pair;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticker = ref.watch(
      marketRepositoryProvider(
        Market.spot,
      ).select((s) => s.tickers[pair.symbol]),
    );
    final change = ticker?.changePercent24h;
    final direction = directionOf(change);
    final color = switch (direction) {
      Direction.up => context.cp.positive,
      Direction.down => context.cp.negative,
      Direction.flat => context.cp.muted,
    };
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        TextButton.icon(
          key: const Key('trade-pair'),
          onPressed: () => _choosePair(context, ref),
          icon: const Icon(Icons.arrow_drop_down),
          label: Text(
            '${pair.baseAsset}/${pair.quoteAsset}',
            style: text.titleMedium,
          ),
        ),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatPrice(ticker?.lastPrice, pair.tickSize),
              key: const Key('trade-last'),
              style: text.titleMedium?.copyWith(color: color),
            ),
            Text(
              formatSignedPercent(change),
              style: text.bodySmall?.copyWith(color: color),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _choosePair(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final pairs =
        ref.read(marketRepositoryProvider(Market.spot)).pairs ??
        const <MarketPair>[];
    final chosen = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l.tradeChoosePair,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final p in pairs)
                      ListTile(
                        key: Key('trade-pick-${p.symbol}'),
                        title: Text('${p.baseAsset}/${p.quoteAsset}'),
                        subtitle: Text(p.baseAssetName),
                        selected: p.symbol == pair.symbol,
                        onTap: () => Navigator.of(context).pop(p.symbol),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (chosen != null) ref.read(tradePairProvider.notifier).select(chosen);
  }
}

class _SpotForm extends ConsumerWidget {
  const _SpotForm({required this.pair});

  final MarketPair pair;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final provider = spotFormProvider(pair.symbol);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final buy = state.side == OrderSide.buy;
    final spendAsset = buy ? pair.quoteAsset : pair.baseAsset;
    final available = ref.watch(
      paperAccountProvider.select((s) => s.spotBalance(spendAsset)?.free),
    );
    final quote = pair.quoteAsset;

    String label(SpotField field) => switch (field) {
      SpotField.price => l.tradePrice,
      SpotField.amount => '${l.tradeAmount} (${pair.baseAsset})',
      SpotField.total => '${l.tradeTotal} ($quote)',
      SpotField.stop =>
        state.kind == SpotKind.oco || state.kind == SpotKind.limitTpSl
            ? l.tradeStopLoss
            : l.tradeStop,
      SpotField.takeProfit => l.tradeTakeProfit,
      SpotField.stopLimit => l.tradeStopLimit,
    };

    final side = buy ? context.cp.positive : context.cp.negative;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (final s in OrderSide.values)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: _SideButton(
                    key: Key('trade-side-${s.wire}'),
                    label: s == OrderSide.buy ? l.tradeBuy : l.tradeSell,
                    selected: state.side == s,
                    color: s == OrderSide.buy
                        ? context.cp.positive
                        : context.cp.negative,
                    onTap: () => controller.selectSide(s),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        DropdownButton<SpotKind>(
          key: const Key('trade-kind'),
          isExpanded: true,
          value: state.kind,
          onChanged: (kind) => controller.selectKind(kind!),
          items: [
            for (final kind in SpotKind.values)
              DropdownMenuItem(
                value: kind,
                child: Text(switch (kind) {
                  SpotKind.limit => l.tradeKindLimit,
                  SpotKind.market => l.tradeKindMarket,
                  SpotKind.stopLimit => l.tradeKindStopLimit,
                  SpotKind.stopMarket => l.tradeKindStopMarket,
                  SpotKind.oco => l.tradeKindOco,
                  SpotKind.limitTpSl => l.tradeKindLimitTpSl,
                }),
              ),
          ],
        ),
        if (state.kind == SpotKind.market)
          Wrap(
            spacing: 4,
            children: [
              ChoiceChip(
                key: const Key('trade-by-amount'),
                label: Text(l.tradeByAmount),
                selected: !state.inputs.byTotal,
                onSelected: (_) => controller.setByTotal(false),
              ),
              ChoiceChip(
                key: const Key('trade-by-total'),
                label: Text(l.tradeByTotal),
                selected: state.inputs.byTotal,
                onSelected: (_) => controller.setByTotal(true),
              ),
            ],
          ),
        for (final field in state.fields)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: _NumberField(
              key: Key('trade-field-${field.name}'),
              label: label(field),
              value: state.inputs.of(field),
              error: switch (state.errors[field]) {
                final error? => fieldErrorText(l, error, quote),
                null => null,
              },
              onChanged: (value) => controller.edit(field, value),
            ),
          ),
        if (available != null)
          _ShareSlider(
            key: ValueKey('trade-share-${state.side.wire}-${state.kind.name}'),
            onChanged: (share) =>
                controller.useShare(share, available: available),
          ),
        Text(
          l.tradeAvailable(
            formatDecimal(available, buy ? 2 : decimalPlaces(pair.stepSize)),
            spendAsset,
          ),
          key: const Key('trade-available'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (state.notice case final notice?)
          _Notice(refusalText(l, notice, quote)),
        if (state.failure case final failure?) _Notice(failureText(l, failure)),
        const SizedBox(height: 6),
        FilledButton(
          key: const Key('trade-submit'),
          style: FilledButton.styleFrom(backgroundColor: side),
          onPressed: state.submitting ? null : () => _submit(context, ref),
          child: Text(
            buy
                ? l.tradeBuyAsset(pair.baseAsset)
                : l.tradeSellAsset(pair.baseAsset),
          ),
        ),
      ],
    );
  }

  Future<void> _submit(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final controller = ref.read(spotFormProvider(pair.symbol).notifier);
    if (controller.validate().isNotEmpty) {
      await controller.submit();
      return;
    }
    if (await ref.read(confirmOrdersProvider.notifier).current()) {
      if (!context.mounted) return;
      final state = ref.read(spotFormProvider(pair.symbol));
      final go = await showModalBottomSheet<bool>(
        context: context,
        showDragHandle: true,
        builder: (context) => _ConfirmSheet(pair: pair, state: state),
      );
      if (go != true) return;
    }
    final placed = await controller.submit();
    if (placed && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.tradePlaced)));
    }
  }
}

/// 0, 25, 50, 75 or 100 % of what is available.
class _ShareSlider extends StatefulWidget {
  const _ShareSlider({required this.onChanged, super.key});

  final ValueChanged<double> onChanged;

  @override
  State<_ShareSlider> createState() => _ShareSliderState();
}

class _ShareSliderState extends State<_ShareSlider> {
  double _share = 0;

  @override
  Widget build(BuildContext context) => Slider(
    key: const Key('trade-share'),
    value: _share,
    divisions: 4,
    label: '${(_share * 100).round()}%',
    onChanged: (share) {
      setState(() => _share = share);
      widget.onChanged(share);
    },
  );
}

class _ConfirmSheet extends StatelessWidget {
  const _ConfirmSheet({required this.pair, required this.state});

  final MarketPair pair;
  final SpotFormState state;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final inputs = state.inputs;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          key: const Key('trade-confirm-sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.tradeConfirmTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const DemoBanner(),
            const SizedBox(height: 8),
            Text(
              '${state.side == OrderSide.buy ? l.tradeBuy : l.tradeSell} '
              '${pair.baseAsset}/${pair.quoteAsset}',
            ),
            for (final field in state.fields)
              if (inputs.of(field).isNotEmpty)
                Text('${field.name}: ${groupThousands(inputs.of(field))}'),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('trade-confirm'),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l.tradeConfirm),
            ),
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text(
      text,
      key: const Key('trade-notice'),
      style: TextStyle(color: context.cp.negative, fontSize: 12),
    ),
  );
}

class _SideButton extends StatelessWidget {
  const _SideButton({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => selected
      ? FilledButton(
          style: FilledButton.styleFrom(backgroundColor: color),
          onPressed: onTap,
          child: Text(label),
        )
      : OutlinedButton(onPressed: onTap, child: Text(label));
}

/// A decimal input whose text follows the view model (a book tap or the
/// slider fills it) without moving the cursor while typing.
class _NumberField extends StatefulWidget {
  const _NumberField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.error,
    super.key,
  });

  final String label;
  final String value;
  final String? error;
  final ValueChanged<String> onChanged;

  @override
  State<_NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<_NumberField> {
  late final TextEditingController _text = TextEditingController(
    text: widget.value,
  );

  @override
  void didUpdateWidget(_NumberField old) {
    super.didUpdateWidget(old);
    if (widget.value != _text.text) _text.text = widget.value;
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _text,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
    onChanged: widget.onChanged,
    decoration: InputDecoration(
      isDense: true,
      labelText: widget.label,
      errorText: widget.error,
      errorMaxLines: 3,
    ),
  );
}

/// The order book: 7 asks above the last price, 7 bids below, on a chosen
/// tick; a level tapped fills the price. Read only while the tab shows
/// (an inactive tab has its tickers muted), so a hidden book costs nothing.
class _Book extends ConsumerStatefulWidget {
  const _Book({required this.pair});

  final MarketPair pair;

  @override
  ConsumerState<_Book> createState() => _BookState();
}

class _BookState extends ConsumerState<_Book> {
  int _scale = 0;

  String get _step => _stepAt(_scale);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (!TickerMode.valuesOf(context).enabled) return const SizedBox.shrink();
    final pair = widget.pair;
    final book = ref.watch(
      orderBookProvider((market: Market.spot, symbol: pair.symbol)),
    );
    final last = ref.watch(
      marketRepositoryProvider(
        Market.spot,
      ).select((s) => s.tickers[pair.symbol]?.lastPrice),
    );
    final depth = book.depth;
    final small = Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11);
    final places = decimalPlaces(_step);

    Widget row(BookLevel level, Color color) => InkWell(
      key: Key('book-${level.price}'),
      onTap: () => ref
          .read(spotFormProvider(pair.symbol).notifier)
          .usePrice(level.price),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(
              child: Text(
                formatDecimal(level.price, places),
                style: small?.copyWith(color: color),
              ),
            ),
            Text(
              formatDecimal(level.quantity, decimalPlaces(pair.stepSize)),
              style: small,
            ),
          ],
        ),
      ),
    );

    if (depth == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    final asks = groupLevels(depth.asks, _step, bids: false);
    final bids = groupLevels(depth.bids, _step, bids: true);
    final share = bidShare(bids, asks);
    return Column(
      key: const Key('trade-book'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(l.tradeBookPrice, style: small)),
            Text(l.tradeBookAmount, style: small),
          ],
        ),
        for (final level in asks.reversed) row(level, context.cp.negative),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            formatPrice(last, pair.tickSize),
            key: const Key('book-last'),
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        for (final level in bids) row(level, context.cp.positive),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: share,
            minHeight: 4,
            color: context.cp.positive,
            backgroundColor: context.cp.negative,
          ),
        ),
        DropdownButton<int>(
          key: const Key('book-tick'),
          isExpanded: true,
          isDense: true,
          value: _scale,
          onChanged: (scale) => setState(() => _scale = scale!),
          items: [
            for (var i = 0; i < 3; i++)
              DropdownMenuItem(
                value: i,
                child: Text(l.tradeTick(_stepAt(i)), style: small),
              ),
          ],
        ),
      ],
    );
  }

  String _stepAt(int scale) {
    var step = Decimal.parse(widget.pair.tickSize);
    for (var i = 0; i < scale; i++) {
      step = step * Decimal.ten;
    }
    return step.toString();
  }
}

class _OrdersAndTrades extends ConsumerStatefulWidget {
  const _OrdersAndTrades({required this.pair});

  final MarketPair pair;

  @override
  ConsumerState<_OrdersAndTrades> createState() => _OrdersAndTradesState();
}

class _OrdersAndTradesState extends ConsumerState<_OrdersAndTrades> {
  bool _trades = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final pair = widget.pair;
    final orders = ref.watch(
      openOrdersProvider.select((s) => s.of(pair.pairId)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: SegmentedButton<bool>(
                key: const Key('trade-lists'),
                segments: [
                  ButtonSegment(
                    value: false,
                    label: Text(l.tradeOpenOrders(orders.length)),
                  ),
                  ButtonSegment(value: true, label: Text(l.tradeMarketTrades)),
                ],
                selected: {_trades},
                onSelectionChanged: (s) => setState(() => _trades = s.first),
              ),
            ),
          ],
        ),
        if (_trades)
          _Trades(pair: pair)
        else ...[
          if (orders.isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: const Key('trade-cancel-all'),
                onPressed: () => _run(
                  context,
                  () => ref
                      .read(openOrdersProvider.notifier)
                      .cancelAll(pair.pairId),
                ),
                child: Text(l.tradeCancelAll),
              ),
            ),
          if (orders.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l.tradeNoOpenOrders,
                key: const Key('trade-no-orders'),
                textAlign: TextAlign.center,
              ),
            ),
          for (final order in orders)
            ListTile(
              key: Key('open-order-${order.orderId}'),
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(
                '${order.side == OrderSide.buy ? l.tradeBuy : l.tradeSell} · '
                '${order.type.wire}',
                style: TextStyle(
                  color: order.side == OrderSide.buy
                      ? context.cp.positive
                      : context.cp.negative,
                ),
              ),
              subtitle: Text(
                '${formatPrice(order.price ?? order.stopPrice, pair.tickSize)}'
                ' · ${formatDecimal(order.executedQuantity, decimalPlaces(pair.stepSize))}'
                '/${formatDecimal(order.quantity, decimalPlaces(pair.stepSize))}',
              ),
              trailing: TextButton(
                key: Key('cancel-${order.orderId}'),
                onPressed: () => _run(
                  context,
                  () => ref.read(openOrdersProvider.notifier).cancel(order),
                ),
                child: Text(l.tradeCancel),
              ),
            ),
        ],
      ],
    );
  }

  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(l.tradeCanceled)));
    } on ApiFailure catch (failure) {
      final refusal = paperRefusal(failure);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            refusal == null
                ? failureText(l, failure)
                : refusalText(l, refusal, widget.pair.quoteAsset),
          ),
        ),
      );
    }
  }
}

class _Trades extends ConsumerWidget {
  const _Trades({required this.pair});

  final MarketPair pair;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    if (!TickerMode.valuesOf(context).enabled) return const SizedBox.shrink();
    final trades = ref.watch(
      orderBookProvider((
        market: Market.spot,
        symbol: pair.symbol,
      )).select((b) => b.trades),
    );
    if (trades.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(l.tradeNoTrades, textAlign: TextAlign.center),
      );
    }
    final small = Theme.of(context).textTheme.bodySmall;
    return Column(
      key: const Key('trade-trades'),
      children: [
        for (final trade in trades.take(20))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    formatPrice(trade.price, pair.tickSize),
                    style: small?.copyWith(
                      color: trade.buyerMaker
                          ? context.cp.negative
                          : context.cp.positive,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    formatDecimal(trade.quantity, decimalPlaces(pair.stepSize)),
                    style: small,
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
