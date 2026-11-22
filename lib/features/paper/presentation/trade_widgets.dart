import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/cp_colors.dart';

/// Spot and Futures as text tabs in the app bar (D-163, the exchange
/// layout): the chosen one bold, the other muted.
class TradeMarketTabs extends StatelessWidget {
  const TradeMarketTabs({
    required this.futures,
    required this.onSelect,
    super.key,
  });

  final bool futures;
  final ValueChanged<bool> onSelect;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cp = context.cp;
    final style = Theme.of(context).textTheme.titleLarge;
    Widget tab(String label, bool value) {
      final on = value == futures;
      return Semantics(
        selected: on,
        button: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: on ? null : () => onSelect(value),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Text(
              label,
              style: style?.copyWith(
                fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                color: on ? cp.text : cp.muted,
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        tab(l.tradeSpot, false),
        const SizedBox(width: 14),
        tab(l.tradeFutures, true),
      ],
    );
  }
}

/// Buy and Sell as one block: the chosen side filled with its colour.
class SideToggle extends StatelessWidget {
  const SideToggle({
    required this.buy,
    required this.buyLabel,
    required this.sellLabel,
    required this.onSelect,
    this.buyKey,
    this.sellKey,
    super.key,
  });

  final bool buy;
  final String buyLabel;
  final String sellLabel;
  final ValueChanged<bool> onSelect;
  final Key? buyKey;
  final Key? sellKey;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    Widget half(String label, bool value, Key? key) {
      final on = value == buy;
      final shape = RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
      );
      const text = TextStyle(fontWeight: FontWeight.w700);
      const size = Size.fromHeight(36);
      return Expanded(
        // The key on a wrapper: the chosen side is a FilledButton in its
        // colour with the on-colour text (M1), the other a muted text button.
        child: Semantics(
          key: key,
          selected: on,
          child: on
              ? FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: value ? cp.positive : cp.negative,
                    foregroundColor: value ? cp.onPositive : cp.onNegative,
                    minimumSize: size,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: shape,
                    textStyle: text,
                  ),
                  onPressed: () => onSelect(value),
                  child: Text(label),
                )
              : TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: cp.muted,
                    minimumSize: size,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: shape,
                    textStyle: text,
                  ),
                  onPressed: () => onSelect(value),
                  child: Text(label),
                ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: cp.raised,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          half(buyLabel, true, buyKey),
          half(sellLabel, false, sellKey),
        ],
      ),
    );
  }
}

/// The order form's inputs: filled, borderless, dense (the exchange
/// look); errors keep their red outline.
Widget tradeInputs(BuildContext context, {required Widget child}) {
  final theme = Theme.of(context);
  final cp = context.cp;
  final none = OutlineInputBorder(
    borderRadius: BorderRadius.circular(6),
    borderSide: BorderSide.none,
  );
  return Theme(
    data: theme.copyWith(
      inputDecorationTheme: theme.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: cp.raised,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        border: none,
        enabledBorder: none,
        focusedBorder: none.copyWith(
          borderSide: BorderSide(color: cp.primary, width: 1.2),
        ),
      ),
    ),
    child: child,
  );
}

/// A filled 40 dp box around the order kind and time in force menus.
class TradeSelectBox extends StatelessWidget {
  const TradeSelectBox({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    height: 40,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: context.cp.raised,
      borderRadius: BorderRadius.circular(6),
    ),
    child: DropdownButtonHideUnderline(child: child),
  );
}

/// 0 %, 25 %, 50 %, 75 % and 100 % under the share slider.
class PercentMarks extends StatelessWidget {
  const PercentMarks({super.key});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(color: context.cp.muted);
    const marks = [0, 25, 50, 75, 100];
    // Five equal cells, so a narrow form column never overflows.
    return Row(
      children: [
        for (var i = 0; i < marks.length; i++)
          Expanded(
            child: Text(
              '${marks[i]}%',
              style: style,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.fade,
              textAlign: i == 0
                  ? TextAlign.start
                  : i == marks.length - 1
                  ? TextAlign.end
                  : TextAlign.center,
            ),
          ),
      ],
    );
  }
}

/// Lists under the form as text tabs with an underline.
class TradeListTabs extends StatelessWidget {
  const TradeListTabs({
    required this.labels,
    required this.selected,
    required this.onSelect,
    this.trailing,
    super.key,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final style = Theme.of(context).textTheme.titleSmall;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: cp.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                for (var i = 0; i < labels.length; i++)
                  Flexible(child: _tab(i, cp, style)),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  Widget _tab(int i, CpColors cp, TextStyle? style) => Semantics(
    selected: i == selected,
    button: true,
    child: InkWell(
      onTap: () => onSelect(i),
      child: Container(
        padding: const EdgeInsets.fromLTRB(2, 10, 2, 8),
        margin: const EdgeInsets.only(right: 18),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              width: 2,
              color: i == selected ? cp.primary : Colors.transparent,
            ),
          ),
        ),
        child: Text(
          labels[i],
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style?.copyWith(
            fontWeight: i == selected ? FontWeight.w700 : FontWeight.w500,
            color: i == selected ? cp.text : cp.muted,
          ),
        ),
      ),
    ),
  );
}

/// A small filled box for Futures settings (margin mode, leverage, mode).
ButtonStyle settingBoxStyle(BuildContext context) {
  final cp = context.cp;
  return OutlinedButton.styleFrom(
    backgroundColor: cp.raised,
    foregroundColor: cp.text,
    side: BorderSide.none,
    minimumSize: const Size(0, 36),
    padding: const EdgeInsets.symmetric(horizontal: 4),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
  );
}

/// A setting's value, bold, scaled down to fit its box.
class SettingText extends StatelessWidget {
  const SettingText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Text(
      text,
      maxLines: 1,
      style: const TextStyle(fontWeight: FontWeight.w700),
    ),
  );
}

/// A compact check box with its label, tapped as one.
class TradeCheck extends StatelessWidget {
  const TradeCheck({
    required this.label,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
    checked: value,
    child: InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 24,
              child: Checkbox(
                value: value,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: (v) => onChanged(v ?? false),
              ),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    ),
  );
}

/// A list's title over a hairline, with an action at the end (the lists
/// under the Futures form; not tabs, both lists stay shown).
class TradeSectionHeader extends StatelessWidget {
  const TradeSectionHeader({required this.title, this.trailing, super.key});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 40),
    margin: const EdgeInsets.only(bottom: 6),
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: context.cp.border)),
    ),
    child: Row(
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 8),
        // The action takes what is left and shrinks before it overflows.
        Expanded(
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: trailing,
          ),
        ),
      ],
    ),
  );
}
