import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/errors/api_failure.dart';
import '../../../core/errors/message_text.dart';
import '../../../core/format/decimal_format.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/cp_colors.dart';
import '../../market/data/market_repository.dart';
import '../../market/domain/market.dart';
import '../../market/presentation/market_status_banner.dart';
import '../../market/presentation/market_widgets.dart';
import '../application/futures_form_controller.dart';
import '../application/futures_preview_controller.dart';
import '../application/trade_controller.dart';
import '../data/futures_repository.dart';
import '../data/paper_repository.dart';
import '../domain/futures.dart';
import '../domain/paper.dart';
import 'futures_calculator_sheet.dart';
import 'order_book_panel.dart';
import 'trade_widgets.dart';
import 'paper_text.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/cp_tag.dart';
import '../../../core/widgets/pair_label.dart';

/// Futures on the Trade tab (D-154, T-129): the pair, margin mode and
/// leverage, the form with Buy/Long and Sell/Short, then the positions and
/// the open orders. A margin call shows as a banner.
class FuturesTrade extends ConsumerWidget {
  const FuturesTrade({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final board = marketRepositoryProvider(Market.futures);
    final pairs = ref.watch(board.select((s) => s.pairs));
    final account = ref.watch(paperAccountProvider);
    final futures = ref.watch(futuresProvider);
    final pair = tradePairOf(ref.watch(futuresPairProvider), pairs);

    // A margin call is told as it comes: a side effect per push.
    ref.listen(futuresProvider.select((s) => s.marginCalls), (_, _) {
      final call = ref.read(futuresProvider).marginCall;
      if (call == null) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger
        ..clearMaterialBanners()
        ..showMaterialBanner(
          MaterialBanner(
            key: const Key('margin-call'),
            backgroundColor: context.cp.negative.withValues(alpha: 0.15),
            content: Text(
              l.futMarginCall(
                call.symbol,
                formatRatioAsPercent(call.marginRatio, places: 2),
              ),
            ),
            actions: [
              TextButton(
                onPressed: messenger.hideCurrentMaterialBanner,
                child: Text(l.commonClose),
              ),
            ],
          ),
        );
    });

    if (account.spot == null && account.failure != null) {
      return _Retry(
        failure: account.failure!,
        onRetry: ref.read(paperAccountProvider.notifier).retry,
      );
    }
    if (pair == null || futures.positions == null) {
      if (futures.failure case final failure?) {
        return _Retry(
          failure: failure,
          onRetry: ref.read(futuresProvider.notifier).load,
        );
      }
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      key: const Key('trade-futures'),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      children: [
        _Header(pair: pair, pairs: pairs ?? const []),
        ReferencePriceNote(market: Market.futures, symbol: pair.symbol),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 6, child: _Form(pair: pair)),
            const SizedBox(width: 8),
            Expanded(
              flex: 5,
              child: OrderBookPanel(
                pair: pair,
                market: Market.futures,
                onPrice: ref
                    .read(futuresFormProvider(pair.symbol).notifier)
                    .usePrice,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _Positions(pair: pair),
        const SizedBox(height: 8),
        _Orders(),
      ],
    );
  }
}

class _Retry extends StatelessWidget {
  const _Retry({required this.failure, required this.onRetry});

  final ApiFailure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(failureText(l, failure), textAlign: TextAlign.center),
          TextButton(onPressed: onRetry, child: Text(l.commonRetry)),
        ],
      ),
    );
  }
}

String _refusalOrFailure(AppLocalizations l, ApiFailure failure) =>
    refusalOrFailureText(l, failure, 'USDT');

/// A sheet over the Futures screen; a snack bar still showing would cover
/// its confirm button, so it goes first.
Future<T?> _sheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool showDragHandle = true,
  bool isScrollControlled = false,
}) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  return showModalBottomSheet<T>(
    context: context,
    showDragHandle: showDragHandle,
    isScrollControlled: isScrollControlled,
    builder: builder,
  );
}

/// A yes / no before an action that cannot be taken back (plan 9.2).
Future<bool> _confirm(BuildContext context, String question) async {
  final l = AppLocalizations.of(context);
  final yes = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      content: Text(question),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l.commonCancel),
        ),
        FilledButton(
          key: const Key('futures-ask-yes'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l.tradeConfirm),
        ),
      ],
    ),
  );
  return yes ?? false;
}

Future<void> _run(BuildContext context, Future<void> Function() action) async {
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
    messenger.showSnackBar(SnackBar(content: Text(l.futDone)));
  } on ApiFailure catch (failure) {
    messenger.showSnackBar(
      SnackBar(content: Text(_refusalOrFailure(l, failure))),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.pair, required this.pairs});

  final MarketPair pair;
  final List<MarketPair> pairs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final mark = ref.watch(
      marketRepositoryProvider(Market.futures).select(
        (s) =>
            s.tickers[pair.symbol]?.markPrice ??
            s.tickers[pair.symbol]?.displayPrice,
      ),
    );
    // The pair's own ticker carries the next funding time (as on SCR-11);
    // the board's ticker gives the rate until it answers.
    final ticker = ref
        .watch(
          pairTickerProvider((market: Market.futures, symbol: pair.symbol)),
        )
        .ticker;
    final funding =
        ticker?.fundingRate ??
        ref.watch(
          marketRepositoryProvider(
            Market.futures,
          ).select((s) => s.tickers[pair.symbol]?.fundingRate),
        );
    final next = ticker?.nextFundingTime;
    final text = Theme.of(context).textTheme;
    final header = Row(
      children: [
        TextButton.icon(
          key: const Key('futures-pair'),
          onPressed: () async {
            final chosen = await _sheet<String>(
              context: context,
              showDragHandle: true,
              builder: (context) => SafeArea(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final p in pairs)
                      ListTile(
                        key: Key('futures-pick-${p.symbol}'),
                        leading: CoinLogo(
                          symbol: p.baseAsset,
                          url: p.logoUrl,
                          size: 24,
                        ),
                        title: PairLabel(
                          base: p.baseAsset,
                          quote: p.quoteAsset,
                          tag: l.marketPerpetual,
                        ),
                        selected: p.symbol == pair.symbol,
                        onTap: () => Navigator.of(context).pop(p.symbol),
                      ),
                  ],
                ),
              ),
            );
            if (chosen != null) {
              ref.read(futuresPairProvider.notifier).select(chosen);
            }
          },
          icon: const Icon(Icons.arrow_drop_down),
          label: PairLabel(
            base: pair.baseAsset,
            quote: pair.quoteAsset,
            tag: l.marketPerpetual,
            style: text.titleMedium,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${l.futMark} ${formatPrice(mark, pair.tickSize)}',
            key: const Key('futures-mark'),
            style: text.bodyMedium,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          key: const Key('futures-calculator'),
          tooltip: l.calcOpen,
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.calculate_outlined),
          onPressed: () => showFuturesCalculator(context, pair),
        ),
      ],
    );
    if (funding == null) return header;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        header,
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l.marketFundingShort(formatFractionAsPercent(funding)),
              key: const Key('futures-funding'),
              style: text.bodySmall,
            ),
            if (next != null) ...[
              Text(' · ', style: text.bodySmall),
              Countdown(
                key: const Key('futures-funding-countdown'),
                until: next,
                now: ref.read(clockProvider),
                style: text.bodySmall,
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Margin mode and leverage of the pair, each changed in a sheet.
class _Settings extends ConsumerWidget {
  const _Settings({required this.symbol});

  final String symbol;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final settings = ref.watch(futuresSettingsProvider(symbol));
    final config = settings.config;
    if (config == null) return const SizedBox(height: 36);
    final repository = ref.read(futuresSettingsProvider(symbol).notifier);
    // Three small filled boxes over the form (D-163, the exchange layout).
    return OutlinedButtonTheme(
      data: OutlinedButtonThemeData(style: settingBoxStyle(context)),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              key: const Key('futures-margin-mode'),
              onPressed: () async {
                final chosen = await _sheet<MarginType>(
                  context: context,
                  showDragHandle: true,
                  builder: (context) => SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(l.futMarginTitle),
                        for (final type in MarginType.values)
                          ListTile(
                            key: Key('margin-${type.wire}'),
                            title: Text(
                              type == MarginType.crossed
                                  ? l.futCross
                                  : l.futIsolated,
                            ),
                            selected: type == config.marginType,
                            onTap: () => Navigator.of(context).pop(type),
                          ),
                      ],
                    ),
                  ),
                );
                if (chosen != null &&
                    chosen != config.marginType &&
                    context.mounted) {
                  await _run(context, () => repository.setMarginType(chosen));
                }
              },
              child: SettingText(
                config.marginType == MarginType.crossed
                    ? l.futCross
                    : l.futIsolated,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: OutlinedButton(
              key: const Key('futures-leverage'),
              onPressed: () async {
                final chosen = await _sheet<int>(
                  context: context,
                  showDragHandle: true,
                  builder: (_) => _LeverageSheet(
                    current: config.leverage,
                    max: settings.maxLeverage ?? config.leverage,
                  ),
                );
                if (chosen != null &&
                    chosen != config.leverage &&
                    context.mounted) {
                  await _run(context, () => repository.setLeverage(chosen));
                }
              },
              child: SettingText(l.futLeverage(config.leverage)),
            ),
          ),
          const _PositionModeButton(),
        ],
      ),
    );
  }
}

/// One-way or hedge mode (TR-14b, T-123), switched in a sheet; the server
/// refuses while a position or an order is open.
class _PositionModeButton extends ConsumerWidget {
  const _PositionModeButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final hedge = ref.watch(futuresModeProvider.select((s) => s.hedge));
    if (hedge == null) return const SizedBox.shrink();
    return Expanded(
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 6),
        child: OutlinedButton(
          key: const Key('futures-position-mode'),
          onPressed: () async {
            final chosen = await _sheet<bool>(
              context: context,
              builder: (context) => SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l.futModeTitle),
                    for (final (value, title, hint) in [
                      (false, l.futModeOneWay, l.futModeOneWayHint),
                      (true, l.futModeHedge, l.futModeHedgeHint),
                    ])
                      ListTile(
                        key: Key('mode-${value ? 'hedge' : 'one-way'}'),
                        title: Text(title),
                        subtitle: Text(hint),
                        selected: value == hedge,
                        onTap: () => Navigator.of(context).pop(value),
                      ),
                  ],
                ),
              ),
            );
            if (chosen != null && chosen != hedge && context.mounted) {
              await _run(
                context,
                () => ref.read(futuresModeProvider.notifier).set(hedge: chosen),
              );
            }
          },
          child: SettingText(hedge ? l.futModeHedge : l.futModeOneWay),
        ),
      ),
    );
  }
}

class _LeverageSheet extends StatefulWidget {
  const _LeverageSheet({required this.current, required this.max});

  final int current;
  final int max;

  @override
  State<_LeverageSheet> createState() => _LeverageSheetState();
}

class _LeverageSheetState extends State<_LeverageSheet> {
  late double _value = widget.current.clamp(1, widget.max).toDouble();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.futLeverageTitle(widget.max)),
            Text(
              l.futLeverage(_value.round()),
              key: const Key('leverage-value'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Slider(
              key: const Key('leverage-slider'),
              min: 1,
              max: widget.max.toDouble(),
              divisions: widget.max > 1 ? widget.max - 1 : null,
              value: _value,
              onChanged: (v) => setState(() => _value = v),
            ),
            FilledButton(
              key: const Key('leverage-save'),
              onPressed: () => Navigator.of(context).pop(_value.round()),
              child: Text(l.futSave),
            ),
          ],
        ),
      ),
    );
  }
}

class _Form extends ConsumerWidget {
  const _Form({required this.pair});

  final MarketPair pair;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final provider = futuresFormProvider(pair.symbol);
    final state = ref.watch(provider);
    final c = ref.read(provider.notifier);
    final available = ref.watch(
      futuresProvider.select((s) => s.account?.availableBalance),
    );
    final preview = ref.watch(futuresPreviewProvider(pair.symbol));
    final hedge =
        ref.watch(futuresModeProvider.select((s) => s.hedge)) ?? false;
    final closing = hedge && state.closing;
    // D-159: closed market or a pair whose data is lost (E5).
    final blocked = watchTradingBlock(ref, l, Market.futures, pair.symbol);

    String label(FuturesField field) => switch (field) {
      FuturesField.price => l.tradePrice,
      FuturesField.size =>
        '${l.futSize} (${state.sizeInUsdt ? l.futSizeUsdt : pair.baseAsset})',
      FuturesField.trigger => l.futTrigger,
      FuturesField.takeProfit => l.futTakeProfit,
      FuturesField.stopLoss => l.futStopLoss,
      FuturesField.callback => l.futCallback,
      FuturesField.activation => l.futActivation,
    };
    String? issueText(FuturesIssue? issue) => switch (issue) {
      FuturesIssue.required => l.paperErrRequired,
      FuturesIssue.notPositive => l.paperErrPositive,
      FuturesIssue.offStep => l.paperErrStep(
        groupThousands(pair.tickSize.replaceFirst(RegExp(r'0+$'), '')),
      ),
      FuturesIssue.tpSlWithReduceOnly => l.futErrTpSlReduceOnly,
      FuturesIssue.outOfRange => l.futErrCallback,
      null => null,
    };

    return tradeInputs(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Settings(symbol: pair.symbol),
          const SizedBox(height: 6),
          // Hedge mode: Open or Close, as the exchange's two tabs (TR-14b).
          if (hedge)
            SegmentedButton<bool>(
              showSelectedIcon: false,
              key: const Key('futures-open-close'),
              segments: [
                ButtonSegment(value: false, label: Text(l.futOpen)),
                ButtonSegment(value: true, label: Text(l.futCloseTab)),
              ],
              selected: {state.closing},
              onSelectionChanged: (s) => c.setClosing(s.first),
            ),
          if (hedge) const SizedBox(height: 6),
          // A Limit's time in force shares the kind's row (T-123).
          TradeSelectBox(
            child: Row(
              children: [
                Expanded(
                  child: DropdownButton<FuturesKind>(
                    key: const Key('futures-kind'),
                    isDense: true,
                    isExpanded: true,
                    value: state.kind,
                    onChanged: (kind) => c.selectKind(kind!),
                    items: [
                      for (final kind in FuturesKind.values)
                        DropdownMenuItem(
                          value: kind,
                          child: Text(switch (kind) {
                            FuturesKind.limit => l.futKindLimit,
                            FuturesKind.market => l.futKindMarket,
                            FuturesKind.stopLimit => l.futKindStopLimit,
                            FuturesKind.stopMarket => l.futKindStopMarket,
                            FuturesKind.takeProfitLimit =>
                              l.futKindTakeProfitLimit,
                            FuturesKind.takeProfitMarket =>
                              l.futKindTakeProfitMarket,
                            FuturesKind.trailingStop => l.futKindTrailingStop,
                          }),
                        ),
                    ],
                  ),
                ),
                if (state.kind == FuturesKind.limit) ...[
                  const SizedBox(width: 6),
                  DropdownButton<FuturesTimeInForce>(
                    key: const Key('futures-tif'),
                    isDense: true,
                    value: state.timeInForce,
                    onChanged: (tif) => c.setTimeInForce(tif!),
                    selectedItemBuilder: (_) => [
                      for (final tif in FuturesTimeInForce.values)
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(tif.wire),
                        ),
                    ],
                    items: [
                      for (final tif in FuturesTimeInForce.values)
                        DropdownMenuItem(
                          value: tif,
                          child: Text(switch (tif) {
                            FuturesTimeInForce.gtc => l.tradeTifGtc,
                            FuturesTimeInForce.ioc => l.tradeTifIoc,
                            FuturesTimeInForce.fok => l.tradeTifFok,
                            FuturesTimeInForce.gtx => l.futTifGtx,
                            FuturesTimeInForce.gtd => l.futTifGtd,
                          }),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (state.kind == FuturesKind.limit &&
              state.timeInForce == FuturesTimeInForce.gtd)
            Wrap(
              spacing: 6,
              children: [
                for (final hours in gtdHours)
                  ChoiceChip(
                    key: Key('futures-gtd-$hours'),
                    label: Text(switch (hours) {
                      1 => l.futGtdHour,
                      24 => l.futGtdDay,
                      _ => l.futGtdWeek,
                    }),
                    selected: state.gtdHours == hours,
                    onSelected: (_) => c.setGtdHours(hours),
                  ),
              ],
            ),
          for (final field in state.fields)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: _Input(
                key: Key('futures-field-${field.name}'),
                label: label(field),
                value: state.of(field),
                error: issueText(state.issues[field]),
                onChanged: (v) => c.edit(field, v),
                stepKey: field.name,
                onStep: (up) => c.step(field, up: up),
              ),
            ),
          _ShareSlider(
            key: ValueKey('share-${state.placed}-${state.sizeInUsdt}'),
            max: preview.sharedMax,
            onShare: (percent, max) => c.useShare(percent, max),
          ),
          const PercentMarks(),
          Wrap(
            spacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ChoiceChip(
                key: const Key('futures-size-coin'),
                label: Text(l.futSizeCoin(pair.baseAsset)),
                selected: !state.sizeInUsdt,
                onSelected: (_) => c.setSizeInUsdt(false),
              ),
              ChoiceChip(
                key: const Key('futures-size-usdt'),
                label: Text(l.futSizeUsdt),
                selected: state.sizeInUsdt,
                onSelected: (_) => c.setSizeInUsdt(true),
              ),
              if (state.kind.conditional || state.tpSl)
                for (final w in WorkingType.values)
                  ChoiceChip(
                    key: Key('futures-working-${w.name}'),
                    label: Text(w == WorkingType.mark ? l.futMark : l.futLast),
                    selected: state.working == w,
                    onSelected: (_) => c.setWorking(w),
                  ),
            ],
          ),
          // TP/SL and Reduce-only on one line (D-163). Hedge mode has no
          // reduce-only, and a close takes no TP/SL.
          Wrap(
            spacing: 8,
            children: [
              if (!state.kind.conditional && !closing)
                TradeCheck(
                  key: const Key('futures-tpsl'),
                  label: l.futTpSl,
                  value: state.tpSl,
                  onChanged: c.setTpSl,
                ),
              if (!hedge)
                TradeCheck(
                  key: const Key('futures-reduce-only'),
                  label: l.futReduceOnly,
                  value: state.reduceOnly,
                  onChanged: c.setReduceOnly,
                ),
            ],
          ),
          Text(
            l.futAvailable(formatDecimal(available, 2)),
            key: const Key('futures-available'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (state.refusal case final refusal?)
            _Red(refusalText(l, refusal, 'USDT')),
          if (state.failure case final failure?) _Red(failureText(l, failure)),
          if (blocked != null) TradingBlockNotice(blocked),
          const SizedBox(height: 6),
          for (final side in OrderSide.values)
            _SideAction(
              side: side,
              closing: closing,
              pair: pair,
              preview: preview.of(side),
              stale: preview.loading,
              sizeInUsdt: state.sizeInUsdt,
              // A BLOCKING warning disables its side (TR-26, plan 9.2; FE
              // owner 2026-11-19); the sheet still blocks when the preview
              // could not be read.
              onPressed:
                  state.busy || preview.of(side).blocked || blocked != null
                  ? null
                  : () => _go(context, ref, side),
            ),
        ],
      ),
    );
  }

  Future<void> _go(BuildContext context, WidgetRef ref, OrderSide side) async {
    final l = AppLocalizations.of(context);
    final c = ref.read(futuresFormProvider(pair.symbol).notifier);
    final ok = await c.review(side);
    final review = ref.read(futuresFormProvider(pair.symbol)).review;
    if (!context.mounted) return;
    if (!ok && review == null) return;
    final ask = await ref.read(confirmOrdersProvider.notifier).current();
    if (!context.mounted) return;
    if (ask || review != null && review.warnings.isNotEmpty || !ok) {
      final go = await _sheet<bool>(
        context: context,
        showDragHandle: true,
        builder: (_) => _ReviewSheet(review: review, blocked: !ok),
      );
      if (go != true) return;
    }
    final placed = await c.place(side);
    if (placed && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.tradePlaced)));
    }
  }
}

/// A share of the Max the balance opens (plan 9.2): 0, 25, 50, 75, 100 %.
class _ShareSlider extends StatefulWidget {
  const _ShareSlider({required this.max, required this.onShare, super.key});

  final MaxOpen? max;
  final void Function(int percent, MaxOpen max) onShare;

  @override
  State<_ShareSlider> createState() => _ShareSliderState();
}

class _ShareSliderState extends State<_ShareSlider> {
  double _value = 0;

  @override
  Widget build(BuildContext context) {
    final max = widget.max;
    return Slider(
      key: const Key('futures-share'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      value: _value,
      max: 100,
      divisions: 4,
      label: '${_value.round()}%',
      onChanged: max == null
          ? null
          : (v) {
              setState(() => _value = v);
              widget.onShare(v.round(), max);
            },
    );
  }
}

/// A side's button with, under it, what the server would make of the
/// order (TR-26, plan 9.2): the cost and the Max, then each warning by its
/// short name. A BLOCKING one is told here and its side is disabled.
class _SideAction extends StatelessWidget {
  const _SideAction({
    required this.side,
    required this.closing,
    required this.pair,
    required this.preview,
    required this.stale,
    required this.sizeInUsdt,
    required this.onPressed,
  });

  final OrderSide side;

  /// Hedge mode's Close tab: Buy closes the Short, Sell the Long.
  final bool closing;
  final MarketPair pair;
  final SidePreview preview;
  final bool stale;
  final bool sizeInUsdt;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final small = Theme.of(context).textTheme.bodySmall;
    final buy = side == OrderSide.buy;
    final cost = preview.warnings?.cost;
    final max = preview.max;
    final String? maxText;
    if (max == null) {
      maxText = null;
    } else if (sizeInUsdt) {
      maxText = '${formatDecimal(max.maxNotional, 2)} ${l.futSizeUsdt}';
    } else {
      maxText = '${groupThousands(max.maxQuantity)} ${pair.baseAsset}';
    }
    final String? info;
    if (cost != null && maxText != null) {
      info = l.futCostMax(formatDecimal(cost, 2), maxText);
    } else if (cost != null) {
      info = l.futCostOnly(formatDecimal(cost, 2));
    } else if (maxText != null) {
      info = l.futMaxOnly(maxText);
    } else {
      info = null;
    }
    final warnings = preview.warnings?.warnings ?? const <OrderWarning>[];
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton(
            key: Key('futures-${side.wire}'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(40),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              backgroundColor: buy ? context.cp.positive : context.cp.negative,
              foregroundColor: buy
                  ? context.cp.onPositive
                  : context.cp.onNegative,
            ),
            onPressed: onPressed,
            child: Text(
              closing
                  ? (buy ? l.futCloseShort : l.futCloseLong)
                  : (buy ? l.futBuyLong : l.futSellShort),
            ),
          ),
          if (info != null)
            Opacity(
              opacity: stale ? 0.5 : 1,
              child: Text(
                info,
                key: Key('futures-info-${side.wire}'),
                style: small,
              ),
            ),
          if (warnings.isNotEmpty)
            Wrap(
              spacing: 8,
              children: [
                for (final w in warnings)
                  Row(
                    key: Key('inline-warning-${side.wire}-${w.type}'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _warningIcon(w.severity),
                        size: 14,
                        color: w.severity == WarningSeverity.blocking
                            ? context.cp.negative
                            : context.cp.warning,
                      ),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(warningName(l, w.type), style: small),
                      ),
                    ],
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

IconData _warningIcon(WarningSeverity severity) => switch (severity) {
  WarningSeverity.blocking => Icons.block,
  WarningSeverity.warning => Icons.warning_amber,
  _ => Icons.info_outline,
};

/// The short name of a TR-26 warning; the server's message is shown in the
/// confirmation sheet. An unknown type shows as sent.
String warningName(AppLocalizations l, String type) => switch (type) {
  'INSUFFICIENT_MARGIN' => l.futWarnInsufficientMargin,
  'SL_BEYOND_LIQUIDATION' => l.futWarnSlBeyondLiquidation,
  'HIGH_LEVERAGE' => l.futWarnHighLeverage,
  'OVERSIZED_POSITION' => l.futWarnOversizedPosition,
  'LOW_RR' => l.futWarnLowRr,
  'HIGH_FUNDING_RATE' => l.futWarnHighFundingRate,
  'WIDE_STOP_LOSS' => l.futWarnWideStopLoss,
  _ => type,
};

class _ReviewSheet extends StatelessWidget {
  const _ReviewSheet({required this.review, required this.blocked});

  final OrderWarnings? review;
  final bool blocked;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final review = this.review;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          key: const Key('futures-review'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.futConfirmTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const DemoBanner(),
            if (review?.cost case final cost?)
              Text(l.futCost(formatDecimal(cost, 2))),
            if (review?.liquidationPrice case final liq?)
              Text(l.futLiq(groupThousands(liq))),
            for (final w in review?.warnings ?? const <OrderWarning>[])
              ListTile(
                key: Key('warning-${w.type}'),
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(
                  w.severity == WarningSeverity.blocking
                      ? Icons.block
                      : w.severity == WarningSeverity.warning
                      ? Icons.warning_amber
                      : Icons.info_outline,
                  color: w.severity == WarningSeverity.blocking
                      ? context.cp.negative
                      : context.cp.warning,
                ),
                title: Text(w.message),
              ),
            if (blocked) _Red(l.futBlocked),
            const SizedBox(height: 8),
            FilledButton(
              key: const Key('futures-confirm'),
              onPressed: blocked ? null : () => Navigator.of(context).pop(true),
              child: Text(l.tradeConfirm),
            ),
          ],
        ),
      ),
    );
  }
}

class _Red extends StatelessWidget {
  const _Red(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text(
      text,
      key: const Key('futures-notice'),
      style: TextStyle(color: context.cp.negative, fontSize: 12),
    ),
  );
}

class _Input extends StatefulWidget {
  const _Input({
    required this.label,
    required this.value,
    required this.onChanged,
    this.error,
    this.stepKey,
    this.onStep,
    super.key,
  });

  final String label;
  final String value;
  final String? error;
  final ValueChanged<String> onChanged;

  /// Names the −/+ buttons (`futures-minus-…`, `futures-plus-…`).
  final String? stepKey;

  /// One step down (false) or up (true); no buttons when null.
  final void Function(bool up)? onStep;

  @override
  State<_Input> createState() => _InputState();
}

class _InputState extends State<_Input> {
  late final _text = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(_Input old) {
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
      prefixIcon: _stepButton(up: false),
      suffixIcon: _stepButton(up: true),
      prefixIconConstraints: _stepBox,
      suffixIconConstraints: _stepBox,
    ),
  );

  static const _stepBox = BoxConstraints(minWidth: 32, minHeight: 32);

  Widget? _stepButton({required bool up}) {
    final onStep = widget.onStep;
    if (onStep == null) return null;
    final l = AppLocalizations.of(context);
    final name = up ? 'plus' : 'minus';
    return IconButton(
      key: Key('futures-$name-${widget.stepKey}'),
      tooltip: up ? l.futStepUp : l.futStepDown,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: _stepBox,
      iconSize: 18,
      onPressed: () => onStep(up),
      icon: Icon(up ? Icons.add : Icons.remove),
    );
  }
}

class _Positions extends ConsumerWidget {
  const _Positions({required this.pair});

  final MarketPair pair;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final positions =
        ref.watch(futuresProvider.select((s) => s.positions)) ??
        const <FuturesPosition>[];
    final repository = ref.read(futuresProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TradeSectionHeader(
          title: l.futPositions(positions.length),
          trailing: positions.isEmpty
              ? null
              : TextButton(
                  key: const Key('futures-close-all'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () async {
                    if (await _confirm(context, l.futCloseAllAsk) &&
                        context.mounted) {
                      await _run(context, repository.closeAll);
                    }
                  },
                  child: Text(l.futCloseAll),
                ),
        ),
        if (positions.isEmpty)
          EmptyState(
            key: const Key('futures-no-positions'),
            message: l.futNoPositions,
            icon: Icons.inbox_outlined,
            inline: true,
          ),
        for (final position in positions) _PositionCard(position: position),
      ],
    );
  }
}

class _PositionCard extends ConsumerWidget {
  const _PositionCard({required this.position});

  final FuturesPosition position;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final repository = ref.read(futuresProvider.notifier);
    final color = position.short ? context.cp.negative : context.cp.positive;
    final pnl = position.unrealizedProfit;
    final pnlColor = switch (directionOf(pnl)) {
      Direction.up => context.cp.positive,
      Direction.down => context.cp.negative,
      Direction.flat => context.cp.muted,
    };
    final small = Theme.of(context).textTheme.bodySmall;
    final key = '${position.symbol}-${position.side.wire}';
    String signed(String value) =>
        '${value.startsWith('-') ? '' : '+'}${formatDecimal(value, 2)}';
    final roe = position.roePercent;
    // The TP and SL waiting on this position (plan 9.2).
    final guards = ref
        .watch(futuresProvider.select((s) => s.algoOrders))
        .where((order) => order.guards(position));
    String? priceOf(bool takeProfit) => guards
        .where((o) => takeProfit ? o.takeProfit : o.stopLoss)
        .map((o) => groupThousands(o.triggerPrice))
        .firstOrNull;
    final tp = priceOf(true);
    final sl = priceOf(false);
    final text = Theme.of(context).textTheme;
    final big = text.titleLarge?.copyWith(
      color: pnlColor,
      fontWeight: FontWeight.w700,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final (base, quote) = splitSymbol(position.symbol);
    final leverage = position.leverage;
    final mode = position.marginType == MarginType.crossed
        ? l.futCross
        : l.futIsolated;
    final liq = position.liquidationPrice;
    final ratio = position.marginRatio;
    // The exchange's position card (D-163): side, pair and mode as tags;
    // uPnL and ROI large; then a grid of figures and the actions.
    return Card(
      key: Key('position-$key'),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                CpTag(position.short ? l.futShort : l.futLong, color: color),
                PairLabel(
                  base: base,
                  quote: quote,
                  tag: l.marketPerpetual,
                  style: text.titleSmall,
                ),
                CpTag(
                  [
                    mode,
                    if (leverage != null) l.futLeverage(leverage),
                  ].join(' '),
                  textKey: Key('position-title-$key'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: Text(l.futCardPnl, style: small)),
                if (roe != null) Text(l.futCardRoi, style: small),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    signed(pnl),
                    key: Key('position-pnl-$key'),
                    style: big,
                  ),
                ),
                if (roe != null)
                  Text(
                    '${roe.startsWith('-') ? '' : '+'}$roe%',
                    key: Key('position-roi-$key'),
                    style: big,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _Figures(
              cells: [
                (l.futCardSize(base), position.size, null),
                (
                  l.futCardMargin,
                  formatDecimal(
                    position.isolatedMargin ?? position.positionInitialMargin,
                    2,
                  ),
                  null,
                ),
                (
                  l.futCardMarginRatio,
                  ratio == null ? '--' : formatRatioAsPercent(ratio, places: 2),
                  Key('margin-line-$key'),
                ),
                (l.futCardEntry, groupThousands(position.entryPrice), null),
                (l.futCardMark, groupThousands(position.markPrice), null),
                (l.futCardLiq, liq == null ? '--' : groupThousands(liq), null),
              ],
              liquidation: context.cp.warning,
            ),
            if (tp != null || sl != null) ...[
              const SizedBox(height: 6),
              Text(
                l.futTpSlLine(tp ?? '--', sl ?? '--'),
                key: Key('tpsl-line-$key'),
                style: small,
              ),
            ],
            const SizedBox(height: 10),
            OutlinedButtonTheme(
              data: OutlinedButtonThemeData(style: settingBoxStyle(context)),
              child: Row(
                children: [
                  for (final (i, button) in [
                    OutlinedButton(
                      key: Key('tpsl-$key'),
                      onPressed: () => _tpSlSheet(context, ref),
                      child: SettingText(l.futTpSl),
                    ),
                    OutlinedButton(
                      key: Key('close-$key'),
                      onPressed: () => _closeSheet(context, ref),
                      child: SettingText(l.futClose),
                    ),
                    OutlinedButton(
                      key: Key('market-close-$key'),
                      onPressed: () async {
                        if (await _confirm(
                              context,
                              l.futMarketCloseAsk(position.symbol),
                            ) &&
                            context.mounted) {
                          await _run(
                            context,
                            () => repository.close(position, percent: 100),
                          );
                        }
                      },
                      child: SettingText(l.futMarketClose),
                    ),
                    if (position.marginType == MarginType.isolated)
                      OutlinedButton(
                        key: Key('margin-$key'),
                        onPressed: () => _marginSheet(context, ref),
                        child: SettingText(l.futMargin),
                      ),
                  ].indexed) ...[
                    if (i > 0) const SizedBox(width: 6),
                    Expanded(child: button),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _closeSheet(BuildContext context, WidgetRef ref) async {
    final result = await _sheet<(int, String?)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _CloseSheet(),
    );
    if (result == null || !context.mounted) return;
    await _run(
      context,
      () => ref
          .read(futuresProvider.notifier)
          .close(position, percent: result.$1, price: result.$2),
    );
  }

  Future<void> _tpSlSheet(BuildContext context, WidgetRef ref) async {
    final result = await _sheet<(String?, String?, WorkingType)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _TpSlSheet(),
    );
    if (result == null || !context.mounted) return;
    await _run(
      context,
      () => ref
          .read(futuresProvider.notifier)
          .setTpSl(
            position,
            takeProfit: result.$1,
            stopLoss: result.$2,
            working: result.$3,
            key: newClientId,
          ),
    );
  }

  Future<void> _marginSheet(BuildContext context, WidgetRef ref) async {
    final result = await _sheet<(String, bool)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _MarginSheet(),
    );
    if (result == null || !context.mounted) return;
    await _run(
      context,
      () => ref
          .read(futuresProvider.notifier)
          .changeMargin(position, amount: result.$1, add: result.$2),
    );
  }
}

class _CloseSheet extends StatefulWidget {
  const _CloseSheet();

  @override
  State<_CloseSheet> createState() => _CloseSheetState();
}

class _CloseSheetState extends State<_CloseSheet> {
  int _percent = 100;
  final _price = TextEditingController();

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return _SheetFrame(
      title: l.futCloseTitle,
      children: [
        Wrap(
          spacing: 6,
          children: [
            for (final p in const [25, 50, 75, 100])
              ChoiceChip(
                key: Key('close-percent-$p'),
                label: Text('$p%'),
                selected: _percent == p,
                onSelected: (_) => setState(() => _percent = p),
              ),
          ],
        ),
        TextField(
          key: const Key('close-price'),
          controller: _price,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: l.futCloseLimit),
        ),
        const SizedBox(height: 8),
        FilledButton(
          key: const Key('close-confirm'),
          onPressed: () => Navigator.of(context).pop((
            _percent,
            _price.text.trim().isEmpty ? null : _price.text.trim(),
          )),
          child: Text(l.futClose),
        ),
      ],
    );
  }
}

class _TpSlSheet extends StatefulWidget {
  const _TpSlSheet();

  @override
  State<_TpSlSheet> createState() => _TpSlSheetState();
}

class _TpSlSheetState extends State<_TpSlSheet> {
  final _tp = TextEditingController();
  final _sl = TextEditingController();
  WorkingType _working = WorkingType.mark;

  @override
  void dispose() {
    _tp.dispose();
    _sl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    String? value(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    return _SheetFrame(
      title: l.futTpSl,
      children: [
        TextField(
          key: const Key('tpsl-tp'),
          controller: _tp,
          onChanged: (_) => setState(() {}),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: l.futTakeProfit),
        ),
        TextField(
          key: const Key('tpsl-sl'),
          controller: _sl,
          onChanged: (_) => setState(() {}),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: l.futStopLoss),
        ),
        Wrap(
          spacing: 6,
          children: [
            for (final w in WorkingType.values)
              ChoiceChip(
                label: Text(w == WorkingType.mark ? l.futMark : l.futLast),
                selected: _working == w,
                onSelected: (_) => setState(() => _working = w),
              ),
          ],
        ),
        FilledButton(
          key: const Key('tpsl-confirm'),
          onPressed: value(_tp) == null && value(_sl) == null
              ? null
              : () => Navigator.of(
                  context,
                ).pop((value(_tp), value(_sl), _working)),
          child: Text(l.futSave),
        ),
      ],
    );
  }
}

class _MarginSheet extends StatefulWidget {
  const _MarginSheet();

  @override
  State<_MarginSheet> createState() => _MarginSheetState();
}

class _MarginSheetState extends State<_MarginSheet> {
  final _amount = TextEditingController();
  bool _add = true;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return _SheetFrame(
      title: l.futMargin,
      children: [
        SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: true, label: Text(l.futMarginAdd)),
            ButtonSegment(value: false, label: Text(l.futMarginRemove)),
          ],
          selected: {_add},
          onSelectionChanged: (s) => setState(() => _add = s.first),
        ),
        TextField(
          key: const Key('margin-amount'),
          controller: _amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: l.futAmountUsdt),
        ),
        FilledButton(
          key: const Key('margin-confirm'),
          onPressed: () {
            final amount = _amount.text.trim();
            if (amount.isEmpty) return;
            Navigator.of(context).pop((amount, _add));
          },
          child: Text(l.futSave),
        ),
      ],
    );
  }
}

/// A new price and quantity for an open Limit (`PUT /futures/order`);
/// both start from the order's own.
class _AmendSheet extends StatefulWidget {
  const _AmendSheet({required this.order});

  final FuturesOrder order;

  @override
  State<_AmendSheet> createState() => _AmendSheetState();
}

class _AmendSheetState extends State<_AmendSheet> {
  late final _price = TextEditingController(text: widget.order.price ?? '');
  late final _quantity = TextEditingController(text: widget.order.origQty);

  @override
  void dispose() {
    _price.dispose();
    _quantity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final price = _price.text.trim();
    final quantity = _quantity.text.trim();
    return _SheetFrame(
      title: l.futAmendTitle,
      children: [
        TextField(
          key: const Key('amend-price'),
          controller: _price,
          onChanged: (_) => setState(() {}),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: l.tradePrice),
        ),
        TextField(
          key: const Key('amend-quantity'),
          controller: _quantity,
          onChanged: (_) => setState(() {}),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: l.futSize),
        ),
        const SizedBox(height: 8),
        FilledButton(
          key: const Key('amend-confirm'),
          onPressed: price.isEmpty || quantity.isEmpty
              ? null
              : () => Navigator.of(context).pop((price, quantity)),
          child: Text(l.futSave),
        ),
      ],
    );
  }
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    ),
  );
}

class _Orders extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(futuresProvider);
    final repository = ref.read(futuresProvider.notifier);
    final count = state.orders.length + state.algoOrders.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TradeSectionHeader(title: l.futOrders(count)),
        if (count == 0)
          EmptyState(
            message: l.futNoOrders,
            icon: Icons.receipt_long_outlined,
            inline: true,
          ),
        for (final order in state.orders)
          ListTile(
            key: Key('futures-order-${order.orderId}'),
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text('${order.symbol} · ${order.side.wire} · ${order.type}'),
            subtitle: Text(
              '${groupThousands(order.price ?? '--')} · ${order.executedQty}/${order.origQty}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // A Limit can take a new price and quantity (T-123).
                if (order.type == 'LIMIT')
                  TextButton(
                    key: Key('futures-amend-${order.orderId}'),
                    onPressed: () async {
                      final result = await _sheet<(String, String)>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => _AmendSheet(order: order),
                      );
                      if (result == null || !context.mounted) return;
                      await _run(
                        context,
                        () => repository.amendOrder(
                          order,
                          price: result.$1,
                          quantity: result.$2,
                        ),
                      );
                    },
                    child: Text(l.futAmend),
                  ),
                TextButton(
                  key: Key('futures-cancel-${order.orderId}'),
                  onPressed: () =>
                      _run(context, () => repository.cancelOrder(order)),
                  child: Text(l.tradeCancel),
                ),
              ],
            ),
          ),
        for (final order in state.algoOrders)
          ListTile(
            key: Key('futures-algo-${order.algoId}'),
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text('${order.symbol} · ${order.side.wire} · ${order.type}'),
            subtitle: Text(groupThousands(order.triggerPrice)),
            trailing: TextButton(
              key: Key('futures-cancel-algo-${order.algoId}'),
              onPressed: () =>
                  _run(context, () => repository.cancelAlgoOrder(order)),
              child: Text(l.tradeCancel),
            ),
          ),
      ],
    );
  }
}

/// Figures of a position, three to a row: label above, value below; the
/// last of each row aligned to the end, the liquidation price in amber.
class _Figures extends StatelessWidget {
  const _Figures({required this.cells, required this.liquidation});

  final List<(String, String, Key?)> cells;
  final Color liquidation;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final label = text.bodySmall?.copyWith(color: context.cp.muted);
    final value = text.bodyMedium?.copyWith(
      fontWeight: FontWeight.w600,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var r = 0; r < cells.length; r += 3)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var c = r; c < r + 3 && c < cells.length; c++)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: c % 3 == 2
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        Text(cells[c].$1, style: label, maxLines: 1),
                        Text(
                          cells[c].$2,
                          key: cells[c].$3,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: c == cells.length - 1
                              ? value?.copyWith(color: liquidation)
                              : value,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
