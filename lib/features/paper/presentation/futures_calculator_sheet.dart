import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/decimal_format.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/cp_colors.dart';
import '../../market/domain/market.dart';
import '../application/futures_calculator_controller.dart';
import '../data/futures_repository.dart';
import '../domain/futures.dart';
import '../domain/futures_calculator.dart';
import 'paper_text.dart';

/// The Futures calculator of [pair] (TR-25, plan 9.4, T-123) in a tall
/// sheet over the Trade tab: PnL, target price, liquidation price, max
/// open and open price, each worked out by the server.
Future<void> showFuturesCalculator(BuildContext context, MarketPair pair) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.92,
      child: FuturesCalculator(pair: pair),
    ),
  );
}

class FuturesCalculator extends ConsumerWidget {
  const FuturesCalculator({required this.pair, super.key});

  final MarketPair pair;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final provider = futuresCalculatorProvider(pair.symbol);
    final state = ref.watch(provider);
    final c = ref.read(provider.notifier);
    final maxLeverage =
        ref.watch(
          futuresSettingsProvider(pair.symbol).select((s) => s.maxLeverage),
        ) ??
        125;
    final small = Theme.of(context).textTheme.bodySmall;

    String tabName(CalcTab tab) => switch (tab) {
      CalcTab.pnl => l.calcPnl,
      CalcTab.target => l.calcTarget,
      CalcTab.liquidation => l.calcLiquidation,
      CalcTab.maxOpen => l.calcMaxOpen,
      CalcTab.openPrice => l.calcOpenPrice,
    };
    String fieldName(CalcField field) => switch (field) {
      CalcField.entry => l.calcEntry,
      CalcField.exit => l.calcExit,
      CalcField.quantity => '${l.futSize} (${pair.baseAsset})',
      CalcField.roe => l.calcRoe,
      CalcField.wallet =>
        state.tab == CalcTab.liquidation &&
                state.marginType == MarginType.isolated
            ? l.calcWalletIsolated
            : l.calcWallet,
    };

    final result = state.result;
    final rows = <(String, String?)>[
      if (result != null)
        ...switch (state.tab) {
          CalcTab.pnl => [
            (l.calcInitialMargin, result.initialMargin),
            (l.calcPnlResult, result.pnl),
            (l.calcRoeResult, result.roe),
          ],
          CalcTab.target => [(l.calcTargetResult, result.targetPrice)],
          CalcTab.liquidation => [
            (l.calcLiquidationResult, result.liquidationPrice),
          ],
          CalcTab.maxOpen => [
            (l.calcMaxQuantity, result.maxQuantity),
            (l.calcMaxNotional, result.maxNotional),
          ],
          CalcTab.openPrice => [
            (l.calcOpenPriceResult, result.openPrice),
            (l.calcTotalQuantity, result.quantity),
          ],
        },
    ];

    return ListView(
      key: const Key('calc'),
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      children: [
        Text(
          l.calcTitle(pair.symbol),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        const DemoBanner(),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final tab in CalcTab.values)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    key: Key('calc-tab-${tab.path}'),
                    label: Text(tabName(tab)),
                    selected: state.tab == tab,
                    onSelected: (_) => c.selectTab(tab),
                  ),
                ),
            ],
          ),
        ),
        if (state.tab != CalcTab.openPrice) ...[
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            showSelectedIcon: false,
            key: const Key('calc-side'),
            segments: [
              ButtonSegment(value: true, label: Text(l.futLong)),
              ButtonSegment(value: false, label: Text(l.futShort)),
            ],
            selected: {state.long},
            onSelectionChanged: (s) => c.setLong(s.first),
          ),
          Row(
            children: [
              Expanded(child: Text(l.futLeverage(c.leverage))),
              IconButton(
                key: const Key('calc-leverage-down'),
                tooltip: l.futStepDown,
                onPressed: c.leverage > 1
                    ? () => c.setLeverage(c.leverage - 1)
                    : null,
                icon: const Icon(Icons.remove),
              ),
              IconButton(
                key: const Key('calc-leverage-up'),
                tooltip: l.futStepUp,
                onPressed: c.leverage < maxLeverage
                    ? () => c.setLeverage(c.leverage + 1)
                    : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ],
        if (state.tab == CalcTab.liquidation)
          Wrap(
            spacing: 6,
            children: [
              for (final type in MarginType.values)
                ChoiceChip(
                  key: Key('calc-margin-${type.wire}'),
                  label: Text(
                    type == MarginType.crossed ? l.futCross : l.futIsolated,
                  ),
                  selected: state.marginType == type,
                  onSelected: (_) => c.setMarginType(type),
                ),
            ],
          ),
        for (final field in calcFields(state.tab))
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: _CalcInput(
              key: Key('calc-${field.name}'),
              label: fieldName(field),
              value: state.of(field),
              signed: field == CalcField.roe,
              error: state.missing.contains(field) ? l.paperErrRequired : null,
              onChanged: (v) => c.edit(field, v),
            ),
          ),
        if (state.tab == CalcTab.openPrice) ...[
          for (final (i, (price, quantity)) in state.lots.indexed)
            Row(
              key: Key('calc-lot-$i'),
              children: [
                Expanded(
                  child: _CalcInput(
                    key: Key('calc-lot-$i-price'),
                    label: l.tradePrice,
                    value: price,
                    onChanged: (v) => c.editLot(i, price: v),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _CalcInput(
                    key: Key('calc-lot-$i-quantity'),
                    label: l.futSize,
                    value: quantity,
                    onChanged: (v) => c.editLot(i, quantity: v),
                  ),
                ),
                IconButton(
                  tooltip: l.calcRemoveLot,
                  onPressed: state.lots.length > 1
                      ? () => c.removeLot(i)
                      : null,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          if (state.missingLots)
            Text(
              l.calcLotsMissing,
              style: small?.copyWith(color: context.cp.negative),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('calc-add-lot'),
              onPressed: state.lots.length < FuturesCalculatorController.maxLots
                  ? c.addLot
                  : null,
              icon: const Icon(Icons.add),
              label: Text(l.calcAddLot),
            ),
          ),
        ],
        const SizedBox(height: 8),
        FilledButton(
          key: const Key('calc-go'),
          onPressed: state.busy ? null : c.calculate,
          child: Text(l.calcCalculate),
        ),
        if (state.failure case final failure?)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              // PAPER_LEVERAGE, PAPER_MAX_POSITION_AT_LEVERAGE (-2027).
              refusalOrFailureText(l, failure, pair.quoteAsset),
              key: const Key('calc-failure'),
              style: TextStyle(color: context.cp.negative),
            ),
          ),
        for (final (label, value) in rows)
          ListTile(
            key: Key('calc-result-$label'),
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(label),
            trailing: Text(
              switch (label) {
                _ when value == null => '--',
                _ when label == l.calcRoeResult => formatSignedPercent(value),
                _ when label == l.calcPnlResult => formatSignedDecimal(value),
                _ => groupThousands(value),
              },
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: label == l.calcRoeResult || label == l.calcPnlResult
                    ? switch (directionOf(value)) {
                        Direction.up => context.cp.positive,
                        Direction.down => context.cp.negative,
                        Direction.flat => null,
                      }
                    : null,
              ),
            ),
          ),
      ],
    );
  }
}

class _CalcInput extends StatefulWidget {
  const _CalcInput({
    required this.label,
    required this.value,
    required this.onChanged,
    this.error,
    this.signed = false,
    super.key,
  });

  final String label;
  final String value;
  final String? error;
  final bool signed;
  final ValueChanged<String> onChanged;

  @override
  State<_CalcInput> createState() => _CalcInputState();
}

class _CalcInputState extends State<_CalcInput> {
  late final _text = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(_CalcInput old) {
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
    keyboardType: TextInputType.numberWithOptions(
      decimal: true,
      signed: widget.signed,
    ),
    inputFormatters: [
      FilteringTextInputFormatter.allow(
        RegExp(widget.signed ? r'[0-9.\-]' : r'[0-9.]'),
      ),
    ],
    onChanged: widget.onChanged,
    decoration: InputDecoration(
      isDense: true,
      labelText: widget.label,
      errorText: widget.error,
    ),
  );
}
