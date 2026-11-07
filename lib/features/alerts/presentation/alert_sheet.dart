import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/errors/message_text.dart';
import '../../../core/format/decimal_format.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/cp_colors.dart';
import '../../../core/web/web_links.dart';
import '../../market/application/market_board.dart';
import '../../market/domain/market.dart';
import '../../watchlist/application/watchlist_controller.dart';
import '../application/alerts_controller.dart';
import '../domain/alert.dart';
import 'alert_format.dart';

/// The pair an alert is set on: its id, symbol and tick, and the markets it
/// is listed on.
class AlertPair {
  const AlertPair({
    required this.pairId,
    required this.symbol,
    required this.markets,
    this.tickSize,
  });

  final String pairId;
  final String symbol;
  final Set<Market> markets;
  final String? tickSize;
}

/// Every enabled pair of the two market boards once, watched pairs first.
List<AlertPair> alertPairChoices(WidgetRef ref) {
  final spot =
      ref.watch(marketBoardProvider(Market.spot).select((s) => s.pairs)) ??
      const <MarketPair>[];
  final futures =
      ref.watch(marketBoardProvider(Market.futures).select((s) => s.pairs)) ??
      const <MarketPair>[];
  final watched = ref.watch(watchlistControllerProvider).items;
  final byId = <String, MarketPair>{};
  final markets = <String, Set<Market>>{};
  for (final pair in [...spot, ...futures]) {
    byId.putIfAbsent(pair.pairId, () => pair);
    markets.putIfAbsent(pair.pairId, () => {}).add(pair.market);
  }
  final order = {for (final (i, item) in watched.indexed) item.pairId: i};
  final pairs = byId.values.toList()
    ..sort((a, b) {
      final wa = order[a.pairId];
      final wb = order[b.pairId];
      if (wa != null || wb != null) {
        return (wa ?? 1 << 30).compareTo(wb ?? 1 << 30);
      }
      return a.displayOrder.compareTo(b.displayOrder);
    });
  return [
    for (final pair in pairs)
      AlertPair(
        pairId: pair.pairId,
        symbol: pair.symbol,
        markets: markets[pair.pairId]!,
        tickSize: pair.tickSize,
      ),
  ];
}

/// The [AlertPair] of a market pair; the sheet adds the other market from
/// the boards.
AlertPair alertPairOf(MarketPair pair) => AlertPair(
  pairId: pair.pairId,
  symbol: pair.symbol,
  markets: {pair.market},
  tickSize: pair.tickSize,
);

/// SCR-14 as a bottom sheet: a new alert on [pair] (market [market] first),
/// a new alert on a pair picked here, or an edit of [alert]. True when saved.
Future<bool> showAlertSheet(
  BuildContext context, {
  AlertPair? pair,
  Market? market,
  Alert? alert,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.9,
      child: AlertSheet(pair: pair, market: market, alert: alert),
    ),
  );
  return saved ?? false;
}

class AlertSheet extends ConsumerStatefulWidget {
  const AlertSheet({this.pair, this.market, this.alert, super.key});

  final AlertPair? pair;
  final Market? market;
  final Alert? alert;

  @override
  ConsumerState<AlertSheet> createState() => _AlertSheetState();
}

class _AlertSheetState extends ConsumerState<AlertSheet> {
  AlertPair? _pair;
  late AlertDraft _draft;
  late final TextEditingController _threshold;
  late final TextEditingController _cooldown;
  Map<RuleField, RuleError> _errors = const {};
  String? _error;
  bool _saving = false;
  String _query = '';

  /// Days ahead for a new expiry; null keeps the stored one (edit) or none.
  int? _expiryDays;

  bool get _editing => widget.alert != null;

  @override
  void initState() {
    super.initState();
    final alert = widget.alert;
    _pair = widget.pair;
    _draft = alert != null
        ? AlertDraft.of(alert.rule)
        : AlertDraft(
            market: widget.market ?? widget.pair?.markets.first ?? Market.spot,
          );
    _threshold = TextEditingController(text: _draft.threshold);
    _cooldown = TextEditingController(text: _draft.cooldown);
  }

  @override
  void dispose() {
    _threshold.dispose();
    _cooldown.dispose();
    super.dispose();
  }

  void _update(AlertDraft draft, {RuleField? field}) => setState(() {
    _draft = draft;
    if (field != null) _errors = {..._errors}..remove(field);
    _error = null;
  });

  void _setMarket(Market market) {
    var draft = _draft.copyWith(market: market);
    if (market == Market.spot && draft.indicator.futuresOnly) {
      draft = draft.copyWith(indicator: AlertIndicator.rsi14);
    }
    _update(draft, field: RuleField.market);
  }

  void _setIndicator(AlertIndicator indicator) {
    var draft = _draft.copyWith(indicator: indicator);
    if (indicator.signCross && !draft.condition.isCross) {
      draft = draft.copyWith(condition: AlertCondition.crossAbove);
    }
    _update(draft, field: RuleField.condition);
  }

  void _setType(AlertType type) {
    var draft = _draft.copyWith(type: type);
    if (type == AlertType.indicator &&
        draft.shape.crossesOnly &&
        !draft.condition.isCross) {
      draft = draft.copyWith(condition: AlertCondition.crossAbove);
    }
    _update(draft, field: RuleField.threshold);
  }

  DateTime? _expiryFor(DateTime now) {
    if (_expiryDays == null) {
      return _editing ? widget.alert!.rule.expiresAt : null;
    }
    if (_expiryDays == 0) return null;
    return now.add(Duration(days: _expiryDays!));
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final pair = _pair;
    final alert = widget.alert;
    if (pair == null && alert == null) return;
    final now = DateTime.now();
    var draft = _draft.copyWith(
      threshold: _threshold.text,
      cooldown: _cooldown.text,
      expiresAt: _expiryFor(now),
      clearExpiry: _expiryFor(now) == null,
    );
    // An unchanged expiry that has passed is the reason to edit: ask for one.
    final checked = checkDraft(draft, now);
    if (checked.rule == null) {
      setState(() => _errors = checked.errors);
      return;
    }
    setState(() {
      _saving = true;
      _errors = const {};
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final controller = ref.read(alertsControllerProvider.notifier);
    try {
      if (alert != null) {
        await controller.update(alert, checked.rule!);
      } else {
        await controller.create(pair!.pairId, checked.rule!);
      }
      messenger.showSnackBar(SnackBar(content: Text(l.msg14)));
      navigator.pop(true);
    } on ProblemFailure catch (failure) {
      if (!mounted) return;
      draft = _draft;
      final fields = failure.problem.fieldErrors;
      final known = <RuleField, RuleError>{};
      for (final field in RuleField.values) {
        final code = fields[field.name];
        if (code == null) continue;
        final error = serverRuleError(draft.shape, field, code);
        if (error != null) known[field] = error;
      }
      setState(() {
        _saving = false;
        _errors = known;
        _error = known.isNotEmpty && known.length == fields.length
            ? null
            : failureText(l, failure);
      });
      if (failure.problem.messageCode == 'MSG29') {
        await showUpgradeDialog(context, ref, failure);
      }
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = failureText(l, failure);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    // Both boards tell the markets the pair is listed on and its tick; an
    // edit knows only the pair id.
    final pairId = _pair?.pairId ?? widget.alert?.pairId;
    final listed = pairId == null
        ? null
        : alertPairChoices(
            ref,
          ).where((choice) => choice.pairId == pairId).firstOrNull;
    final pair = listed ?? _pair;
    final symbol = widget.alert?.symbol ?? pair?.symbol;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              [_editing ? l.alertEdit : l.alertCreate, ?symbol].join(' · '),
              style: text.titleLarge,
            ),
          ),
          Expanded(
            child: pair == null && !_editing
                ? _picker(context)
                : _form(context, pair),
          ),
        ],
      ),
    );
  }

  Widget _picker(BuildContext context) {
    final l = AppLocalizations.of(context);
    final rows = [
      for (final pair in alertPairChoices(ref))
        if (_query.isEmpty ||
            pair.symbol.toLowerCase().contains(_query.trim().toLowerCase()))
          pair,
    ];
    final watched = ref.watch(watchlistControllerProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            key: const Key('alert-pair-search'),
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search, size: 20),
              hintText: l.alertPairSearch,
            ),
          ),
        ),
        Expanded(
          child: rows.isEmpty
              ? Center(child: Text(l.msg41))
              : ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (_, index) {
                    final pair = rows[index];
                    return ListTile(
                      key: Key('alert-pick-${pair.symbol}'),
                      title: Text(pair.symbol),
                      subtitle: Text(
                        [
                          if (pair.markets.contains(Market.spot)) l.marketSpot,
                          if (pair.markets.contains(Market.futures))
                            l.marketFutures,
                        ].join(' · '),
                      ),
                      trailing: watched.watches(pair.pairId)
                          ? const Icon(Icons.star, size: 18)
                          : null,
                      onTap: () => setState(() {
                        _pair = pair;
                        _draft = _draft.copyWith(market: pair.markets.first);
                      }),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _form(BuildContext context, AlertPair? pair) {
    final l = AppLocalizations.of(context);
    final draft = _draft;
    final shape = draft.shape;
    final markets = pair?.markets ?? {draft.market};
    final watched = pair == null
        ? true
        : ref.watch(watchlistControllerProvider).watches(pair.pairId);
    String? errorOf(RuleField field, String label) {
      final error = _errors[field];
      return error == null ? null : ruleErrorText(l, error, label);
    }

    final thresholdLabel = switch (shape.indicator) {
      null => l.alertPriceField,
      AlertIndicator.rsi14 => l.alertRsiField,
      AlertIndicator.fundingRate => l.alertFundingField,
      _ => l.alertPercentField,
    };

    final fields = ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      children: [
        if (!watched)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              l.alertAddsToWatchlist,
              style: TextStyle(color: context.cp.muted),
            ),
          ),
        _label(context, l.alertMarketField),
        SegmentedButton<Market>(
          key: const Key('alert-market'),
          segments: [
            for (final market in Market.values)
              ButtonSegment(
                value: market,
                enabled: markets.contains(market),
                label: Text(
                  market == Market.spot ? l.marketSpot : l.marketFutures,
                ),
              ),
          ],
          selected: {draft.market},
          showSelectedIcon: false,
          onSelectionChanged: (value) => _setMarket(value.single),
        ),
        if (errorOf(RuleField.market, l.alertMarketField) != null)
          _errorLine(context, l.alertFuturesOnly),
        const SizedBox(height: 12),
        _label(context, l.alertTypeField),
        SegmentedButton<AlertType>(
          key: const Key('alert-type'),
          segments: [
            for (final type in AlertType.values)
              ButtonSegment(value: type, label: Text(typeLabel(l, type))),
          ],
          selected: {draft.type},
          showSelectedIcon: false,
          onSelectionChanged: (value) => _setType(value.single),
        ),
        if (draft.type == AlertType.indicator) ...[
          const SizedBox(height: 12),
          _dropdown<AlertIndicator>(
            key: const Key('alert-indicator'),
            label: l.alertIndicatorField,
            value: draft.indicator,
            items: [
              for (final indicator in AlertIndicator.values)
                if (!indicator.futuresOnly || draft.market == Market.futures)
                  (indicator, indicatorLabel(l, indicator)),
            ],
            onChanged: _setIndicator,
          ),
        ],
        if (shape.takesTimeframe) ...[
          const SizedBox(height: 12),
          _label(context, l.alertTimeframeField),
          Wrap(
            spacing: 8,
            children: [
              for (final frame in alertTimeframes)
                ChoiceChip(
                  key: Key('alert-timeframe-$frame'),
                  label: Text(frame),
                  selected: draft.timeframe == frame,
                  onSelected: (_) => _update(draft.copyWith(timeframe: frame)),
                ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        _dropdown<AlertCondition>(
          key: const Key('alert-condition'),
          label: l.alertConditionField,
          value: draft.condition,
          error: errorOf(RuleField.condition, l.alertConditionField),
          items: [
            for (final condition in AlertCondition.values)
              if (!shape.crossesOnly || condition.isCross)
                (condition, conditionLabel(l, condition)),
          ],
          onChanged: (condition) => _update(
            draft.copyWith(condition: condition),
            field: RuleField.condition,
          ),
        ),
        if (shape.takesThreshold) ...[
          const SizedBox(height: 12),
          TextField(
            key: const Key('alert-threshold'),
            controller: _threshold,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[-0-9.]')),
            ],
            onChanged: (_) => setState(() {
              _errors = {..._errors}..remove(RuleField.threshold);
              _error = null;
            }),
            decoration: InputDecoration(
              labelText: thresholdLabel,
              helperText: shape.indicator == null ? l.alertPriceHint : null,
              errorText: errorOf(RuleField.threshold, thresholdLabel),
            ),
          ),
          if (shape.indicator == null && pair != null)
            _PriceHelper(
              pair: pair,
              market: draft.market,
              onPick: (value) => setState(() {
                _threshold.text = value;
                _errors = {..._errors}..remove(RuleField.threshold);
              }),
            ),
        ],
        const SizedBox(height: 12),
        _dropdown<TriggerMode>(
          key: const Key('alert-mode'),
          label: l.alertTriggerField,
          value: draft.triggerMode,
          helper: l.alertModeHint,
          items: [
            for (final mode in TriggerMode.values) (mode, modeLabel(l, mode)),
          ],
          onChanged: (mode) => _update(
            draft.copyWith(triggerMode: mode),
            field: RuleField.cooldownMinutes,
          ),
        ),
        if (draft.triggerMode == TriggerMode.everyTime) ...[
          const SizedBox(height: 12),
          TextField(
            key: const Key('alert-cooldown'),
            controller: _cooldown,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(
              () => _errors = {..._errors}..remove(RuleField.cooldownMinutes),
            ),
            decoration: InputDecoration(
              labelText: l.alertCooldownField,
              errorText: errorOf(
                RuleField.cooldownMinutes,
                l.alertCooldownField,
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        _label(context, l.alertChannelsField),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: true,
          onChanged: null,
          title: Text(l.alertInApp),
        ),
        SwitchListTile(
          key: const Key('alert-email'),
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: draft.notifyEmail,
          onChanged: (value) => _update(draft.copyWith(notifyEmail: value)),
          title: Text(l.alertEmail),
        ),
        SwitchListTile(
          key: const Key('alert-push'),
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: draft.notifyPush,
          onChanged: (value) => _update(draft.copyWith(notifyPush: value)),
          title: Text(l.alertPush),
        ),
        const SizedBox(height: 4),
        _dropdown<int?>(
          key: const Key('alert-expiry'),
          label: l.alertExpiryField,
          value: _expiryDays,
          error: errorOf(RuleField.expiresAt, l.alertExpiryField),
          items: [
            if (_editing && widget.alert!.rule.expiresAt != null)
              (
                null,
                '${l.alertExpiryKeep} · '
                    '${shortDate(widget.alert!.rule.expiresAt!)}',
              )
            else
              (null, l.alertNoExpiry),
            if (_editing && widget.alert!.rule.expiresAt != null)
              (0, l.alertNoExpiry),
            for (final days in const [1, 7, 30, 90])
              (days, l.alertExpiryDays(days)),
          ],
          onChanged: (days) => setState(() {
            _expiryDays = days;
            _errors = {..._errors}..remove(RuleField.expiresAt);
          }),
        ),
      ],
    );

    // The refusal and Save stay below the fields, always in view.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: fields),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _error!,
                    key: const Key('alert-error'),
                    style: TextStyle(color: context.cp.negative),
                  ),
                ),
              FilledButton(
                key: const Key('alert-save'),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l.alertSave),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _label(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: Theme.of(context).textTheme.labelLarge),
  );

  Widget _errorLine(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: context.cp.negative),
    ),
  );

  Widget _dropdown<T>({
    required Key key,
    required String label,
    required T value,
    required List<(T, String)> items,
    required ValueChanged<T> onChanged,
    String? error,
    String? helper,
  }) => InputDecorator(
    decoration: InputDecoration(
      labelText: label,
      errorText: error,
      helperText: helper,
      helperMaxLines: 3,
      isDense: true,
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        key: key,
        value: value,
        isDense: true,
        isExpanded: true,
        items: [
          for (final (item, text) in items)
            DropdownMenuItem(value: item, child: Text(text)),
        ],
        onChanged: (value) {
          // A nullable T (the expiry) takes null as a choice too.
          if (value is T) onChanged(value);
        },
      ),
    ),
  );
}

/// The live price next to the target (Binance price alert): tap it to use
/// it, or a ± percent step from it, rounded to the tick.
class _PriceHelper extends ConsumerWidget {
  const _PriceHelper({
    required this.pair,
    required this.market,
    required this.onPick,
  });

  final AlertPair pair;
  final Market market;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final ticker = ref.watch(
      marketBoardProvider(market).select((s) => s.tickers[pair.symbol]),
    );
    final last = ticker?.lastPrice;
    final price = last ?? ticker?.markPrice;
    final parsed = price == null ? null : Decimal.tryParse(price);
    if (parsed == null) return const SizedBox.shrink();
    final places = decimalPlaces(pair.tickSize);
    String at(int percent) => (parsed * Decimal.fromInt(100 + percent))
        .shift(-2)
        .round(scale: places)
        .toStringAsFixed(places);
    final shown = formatPrice(price, pair.tickSize);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ActionChip(
            key: const Key('alert-fill-last'),
            label: Text(
              last != null ? l.alertLastPrice(shown) : l.alertMarkPrice(shown),
            ),
            onPressed: () => onPick(parsed.toStringAsFixed(places)),
          ),
          for (final percent in const [-5, -1, 1, 5])
            ActionChip(
              key: Key('alert-step-$percent'),
              label: Text(percent > 0 ? '+$percent%' : '−${-percent}%'),
              onPressed: () => onPick(at(percent)),
            ),
        ],
      ),
    );
  }
}

/// MSG29: the plan does not include it; the plans live on the web.
Future<void> showUpgradeDialog(
  BuildContext context,
  WidgetRef ref,
  ProblemFailure failure,
) async {
  final l = AppLocalizations.of(context);
  final open = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      content: Text(failureText(l, failure)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l.commonCancel),
        ),
        FilledButton(
          key: const Key('upgrade-open-web'),
          onPressed: () => Navigator.pop(context, true),
          child: Text(l.upgradeOnWeb),
        ),
      ],
    ),
  );
  if (open ?? false) await ref.read(webLinksProvider).open('/subscription');
}

/// "Create alert" under a pair's figures (SRS 3.4.2: from SCR-10, SCR-11,
/// SCR-12 and SCR-13; on the phone also the pair sheet of SCR-09).
/// SCR-14 for a new alert on [pair], its market first.
Future<bool> openAlertSheetFor(BuildContext context, MarketPair pair) =>
    showAlertSheet(context, pair: alertPairOf(pair), market: pair.market);

class CreateAlertButton extends StatelessWidget {
  const CreateAlertButton({required this.pair, super.key});

  final MarketPair pair;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return OutlinedButton.icon(
      key: const Key('create-alert'),
      onPressed: () => openAlertSheetFor(context, pair),
      icon: const Icon(Icons.alarm_add),
      label: Text(l.alertCreate),
    );
  }
}
