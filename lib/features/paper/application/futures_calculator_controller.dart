import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../data/futures_api.dart';
import '../data/futures_repository.dart';
import '../domain/futures.dart';
import '../domain/futures_calculator.dart';

/// The inputs of the calculator; each tab takes some of them.
enum CalcField { entry, exit, quantity, roe, wallet }

/// The fields [tab] asks for, in the order shown; the wallet is optional
/// for an isolated liquidation (its initial margin then).
List<CalcField> calcFields(CalcTab tab) => switch (tab) {
  CalcTab.pnl => const [CalcField.entry, CalcField.exit, CalcField.quantity],
  CalcTab.target => const [CalcField.entry, CalcField.roe],
  CalcTab.liquidation => const [
    CalcField.entry,
    CalcField.quantity,
    CalcField.wallet,
  ],
  CalcTab.maxOpen => const [CalcField.entry, CalcField.wallet],
  CalcTab.openPrice => const [],
};

@immutable
class CalculatorState {
  const CalculatorState({
    this.tab = CalcTab.pnl,
    this.long = true,
    this.leverage,
    this.marginType = MarginType.crossed,
    this.values = const {},
    this.lots = const [('', ''), ('', '')],
    this.missing = const {},
    this.missingLots = false,
    this.result,
    this.failure,
    this.busy = false,
  });

  final CalcTab tab;
  final bool long;

  /// Null until chosen: the pair's own leverage then.
  final int? leverage;
  final MarginType marginType;
  final Map<CalcField, String> values;

  /// Open price: up to 20 parts of a price and a quantity.
  final List<(String, String)> lots;
  final Set<CalcField> missing;
  final bool missingLots;
  final CalcResult? result;
  final ApiFailure? failure;
  final bool busy;

  String of(CalcField field) => values[field] ?? '';

  CalculatorState copyWith({
    CalcTab? tab,
    bool? long,
    int? leverage,
    MarginType? marginType,
    Map<CalcField, String>? values,
    List<(String, String)>? lots,
    bool clearOutcome = false,
  }) => CalculatorState(
    tab: tab ?? this.tab,
    long: long ?? this.long,
    leverage: leverage ?? this.leverage,
    marginType: marginType ?? this.marginType,
    values: values ?? this.values,
    lots: lots ?? this.lots,
    missing: clearOutcome ? const {} : missing,
    missingLots: !clearOutcome && missingLots,
    result: clearOutcome ? null : result,
    failure: clearOutcome ? null : failure,
    busy: busy,
  );
}

final futuresCalculatorProvider = NotifierProvider.autoDispose
    .family<FuturesCalculatorController, CalculatorState, String>(
      FuturesCalculatorController.new,
    );

/// The Futures calculator of one pair (TR-25, plan 9.4, T-123): each tab
/// asks the server, which rounds to the pair's tick and step and bounds
/// the leverage by its brackets; nothing is stored.
class FuturesCalculatorController extends Notifier<CalculatorState> {
  FuturesCalculatorController(this.symbol);

  final String symbol;
  static const maxLots = 20;

  @override
  CalculatorState build() => const CalculatorState();

  void selectTab(CalcTab tab) =>
      state = state.copyWith(tab: tab, clearOutcome: true);
  void setLong(bool long) =>
      state = state.copyWith(long: long, clearOutcome: true);
  void setLeverage(int leverage) =>
      state = state.copyWith(leverage: leverage, clearOutcome: true);
  void setMarginType(MarginType type) =>
      state = state.copyWith(marginType: type, clearOutcome: true);

  void edit(CalcField field, String value) => state = state.copyWith(
    values: {...state.values, field: value.trim()},
    clearOutcome: true,
  );

  void editLot(int index, {String? price, String? quantity}) {
    final lots = [...state.lots];
    final (p, q) = lots[index];
    lots[index] = (price?.trim() ?? p, quantity?.trim() ?? q);
    state = state.copyWith(lots: lots, clearOutcome: true);
  }

  void addLot() {
    if (state.lots.length >= maxLots) return;
    state = state.copyWith(lots: [...state.lots, ('', '')], clearOutcome: true);
  }

  void removeLot(int index) {
    if (state.lots.length <= 1) return;
    state = state.copyWith(
      lots: [...state.lots]..removeAt(index),
      clearOutcome: true,
    );
  }

  int get leverage =>
      state.leverage ??
      ref.read(futuresSettingsProvider(symbol)).config?.leverage ??
      20;

  bool _positive(String text) {
    final value = Decimal.tryParse(text);
    return value != null && value > Decimal.zero;
  }

  /// Asks the server; false when a field is missing (marked) or it refused.
  Future<bool> calculate() async {
    if (state.busy) return false;
    final tab = state.tab;
    final missing = <CalcField>{
      for (final field in calcFields(tab))
        if (!(field == CalcField.wallet &&
                tab == CalcTab.liquidation &&
                state.marginType == MarginType.isolated &&
                state.of(field).isEmpty) &&
            !(field == CalcField.roe
                ? Decimal.tryParse(state.of(field)) != null
                : _positive(state.of(field))))
          field,
    };
    final lots = [
      for (final (price, quantity) in state.lots)
        if (_positive(price) && _positive(quantity))
          CalcLot(price: price, quantity: quantity),
    ];
    final missingLots = tab == CalcTab.openPrice && lots.isEmpty;
    if (missing.isNotEmpty || missingLots) {
      state = CalculatorState(
        tab: tab,
        long: state.long,
        leverage: state.leverage,
        marginType: state.marginType,
        values: state.values,
        lots: state.lots,
        missing: missing,
        missingLots: missingLots,
      );
      return false;
    }
    String? value(CalcField f) => state.of(f).isEmpty ? null : state.of(f);
    final request = CalcRequest(
      tab: tab,
      symbol: symbol,
      long: state.long,
      leverage: leverage,
      entryPrice: value(CalcField.entry),
      exitPrice: value(CalcField.exit),
      quantity: value(CalcField.quantity),
      roe: value(CalcField.roe),
      marginType: state.marginType,
      walletBalance: value(CalcField.wallet),
      lots: lots,
    );
    final before = state;
    state = CalculatorState(
      tab: tab,
      long: before.long,
      leverage: before.leverage,
      marginType: before.marginType,
      values: before.values,
      lots: before.lots,
      busy: true,
    );
    try {
      final result = await ref.read(futuresApiProvider).calculate(request);
      if (!ref.mounted) return true;
      state = CalculatorState(
        tab: tab,
        long: before.long,
        leverage: before.leverage,
        marginType: before.marginType,
        values: before.values,
        lots: before.lots,
        result: result,
      );
      return true;
    } on ApiFailure catch (failure) {
      if (ref.mounted) {
        state = CalculatorState(
          tab: tab,
          long: before.long,
          leverage: before.leverage,
          marginType: before.marginType,
          values: before.values,
          lots: before.lots,
          failure: failure,
        );
      }
      return false;
    }
  }
}
