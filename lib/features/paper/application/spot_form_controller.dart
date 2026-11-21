import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../market/data/market_repository.dart';
import '../../market/domain/market.dart';
import '../data/paper_api.dart';
import '../data/paper_repository.dart';
import '../domain/paper.dart';
import '../domain/paper_refusal.dart';

/// The Spot order kinds of the first version (D-154 (2)).
/// The second-version kinds (T-123, plan 9.4) come last: post-only
/// (`LIMIT_MAKER`) and OTO (a limit, then a limit the other way once it
/// filled).
enum SpotKind {
  limit,
  market,
  stopLimit,
  stopMarket,
  oco,
  limitTpSl,
  postOnly,
  oto;

  /// The kinds that take a time in force (GTC, IOC, FOK).
  bool get timed => this == limit || this == stopLimit;
}

/// The inputs of the form; a refusal is shown under its field.
enum SpotField {
  price,
  amount,
  total,
  stop,
  takeProfit,
  stopLimit,

  /// Optional on a stop: the trailing distance in percent (T-123).
  trailing,

  /// OTO: the price of the limit placed once the first one filled.
  pendingPrice,
}

/// Why a field cannot go yet, found on the phone before the server.
enum InputIssue { required, notPositive, offStep, stopSide, takeProfitSide }

@immutable
class FieldError {
  const FieldError.issue(this.issue, {this.limit}) : refusal = null;
  const FieldError.refusal(PaperRefusal this.refusal)
    : issue = null,
      limit = null;

  final InputIssue? issue;

  /// The step for [InputIssue.offStep].
  final String? limit;
  final PaperRefusal? refusal;
}

/// What the Trader typed on one side; Buy and Sell keep their own.
@immutable
class SpotInputs {
  const SpotInputs({
    this.price = '',
    this.amount = '',
    this.total = '',
    this.stop = '',
    this.takeProfit = '',
    this.stopLimit = '',
    this.trailing = '',
    this.pendingPrice = '',
    this.byTotal = false,
  });

  final String trailing;
  final String pendingPrice;
  final String price;
  final String amount;

  /// Market by total: what a Buy spends or a Sell receives.
  final String total;
  final String stop;
  final String takeProfit;

  /// Optional on an OCO and a Limit with TP/SL: the stop then rests as a
  /// limit; empty, it sells or buys at market when met.
  final String stopLimit;
  final bool byTotal;

  String of(SpotField field) => switch (field) {
    SpotField.price => price,
    SpotField.amount => amount,
    SpotField.total => total,
    SpotField.stop => stop,
    SpotField.takeProfit => takeProfit,
    SpotField.stopLimit => stopLimit,
    SpotField.trailing => trailing,
    SpotField.pendingPrice => pendingPrice,
  };

  SpotInputs set(SpotField field, String value) => SpotInputs(
    price: field == SpotField.price ? value : price,
    amount: field == SpotField.amount ? value : amount,
    total: field == SpotField.total ? value : total,
    stop: field == SpotField.stop ? value : stop,
    takeProfit: field == SpotField.takeProfit ? value : takeProfit,
    stopLimit: field == SpotField.stopLimit ? value : stopLimit,
    trailing: field == SpotField.trailing ? value : trailing,
    pendingPrice: field == SpotField.pendingPrice ? value : pendingPrice,
    byTotal: byTotal,
  );

  SpotInputs withByTotal(bool value) => SpotInputs(
    price: price,
    amount: amount,
    total: total,
    stop: stop,
    takeProfit: takeProfit,
    stopLimit: stopLimit,
    trailing: trailing,
    pendingPrice: pendingPrice,
    byTotal: value,
  );

  /// After an order went: the price stays, the amounts empty.
  SpotInputs placed() => SpotInputs(price: price, byTotal: byTotal);
}

@immutable
class SpotFormState {
  const SpotFormState({
    this.side = OrderSide.buy,
    this.kind = SpotKind.limit,
    this.buy = const SpotInputs(),
    this.sell = const SpotInputs(),
    this.errors = const {},
    this.notice,
    this.failure,
    this.submitting = false,
    this.placed = 0,
    this.timeInForce = SpotTimeInForce.gtc,
  });

  /// Limit and Stop Limit only ([SpotKind.timed]).
  final SpotTimeInForce timeInForce;
  final OrderSide side;
  final SpotKind kind;
  final SpotInputs buy;
  final SpotInputs sell;
  final Map<SpotField, FieldError> errors;

  /// A refusal of the whole order (balance, finished, limits).
  final PaperRefusal? notice;

  /// Any other failure of the last submit (network, server).
  final ApiFailure? failure;
  final bool submitting;

  /// Grows by one at every order that went (the screen says so).
  final int placed;

  SpotInputs get inputs => side == OrderSide.buy ? buy : sell;

  /// The fields [kind] asks for.
  List<SpotField> get fields => switch (kind) {
    SpotKind.limit => const [SpotField.price, SpotField.amount],
    SpotKind.market => [inputs.byTotal ? SpotField.total : SpotField.amount],
    SpotKind.stopLimit => const [
      SpotField.stop,
      SpotField.price,
      SpotField.amount,
      SpotField.trailing,
    ],
    SpotKind.stopMarket => const [
      SpotField.stop,
      SpotField.amount,
      SpotField.trailing,
    ],
    SpotKind.postOnly => const [SpotField.price, SpotField.amount],
    SpotKind.oto => const [
      SpotField.price,
      SpotField.amount,
      SpotField.pendingPrice,
    ],
    SpotKind.oco => const [
      SpotField.takeProfit,
      SpotField.stop,
      SpotField.stopLimit,
      SpotField.amount,
    ],
    SpotKind.limitTpSl => const [
      SpotField.price,
      SpotField.amount,
      SpotField.takeProfit,
      SpotField.stop,
      SpotField.stopLimit,
    ],
  };

  SpotFormState copyWith({
    OrderSide? side,
    SpotKind? kind,
    SpotInputs? buy,
    SpotInputs? sell,
    Map<SpotField, FieldError>? errors,
    PaperRefusal? notice,
    ApiFailure? failure,
    bool clearOutcome = false,
    bool? submitting,
    int? placed,
    SpotTimeInForce? timeInForce,
  }) => SpotFormState(
    timeInForce: timeInForce ?? this.timeInForce,
    side: side ?? this.side,
    kind: kind ?? this.kind,
    buy: buy ?? this.buy,
    sell: sell ?? this.sell,
    errors: errors ?? (clearOutcome ? const {} : this.errors),
    notice: clearOutcome ? null : notice ?? this.notice,
    failure: clearOutcome ? null : failure ?? this.failure,
    submitting: submitting ?? this.submitting,
    placed: placed ?? this.placed,
  );
}

final spotFormProvider = NotifierProvider.autoDispose
    .family<SpotFormController, SpotFormState, String>(SpotFormController.new);

/// The Spot order form of one pair (D-154, plan 9.2 and 9.9). Prices and
/// amounts are decimal strings checked on the phone (required, positive,
/// on the tick or step, a stop on the right side of the price) before the
/// server checks them again; a refusal of the server goes under its field.
/// Each submit carries a key, sent again unchanged when the network failed,
/// so a retried order is never placed twice.
class SpotFormController extends Notifier<SpotFormState> {
  SpotFormController(this.symbol);

  final String symbol;
  String? _pendingKey;

  @override
  SpotFormState build() => const SpotFormState();

  MarketPair? get _pair => ref
      .read(marketRepositoryProvider(Market.spot))
      .pairs
      ?.where((p) => p.symbol == symbol)
      .firstOrNull;

  String? get _last => ref
      .read(marketRepositoryProvider(Market.spot))
      .tickers[symbol]
      ?.lastPrice;

  void selectSide(OrderSide side) =>
      state = state.copyWith(side: side, clearOutcome: true);

  void selectKind(SpotKind kind) {
    _pendingKey = null;
    state = state.copyWith(kind: kind, clearOutcome: true);
  }

  void setByTotal(bool byTotal) => _update(state.inputs.withByTotal(byTotal));

  void setTimeInForce(SpotTimeInForce value) {
    _pendingKey = null;
    state = state.copyWith(timeInForce: value, clearOutcome: true);
  }

  /// The trailing percent as basis points (1 % = 100); null when empty.
  int? _trailingDelta() {
    final value = Decimal.tryParse(state.inputs.trailing);
    if (value == null) return null;
    return (value * Decimal.fromInt(100)).toBigInt().toInt();
  }

  void edit(SpotField field, String value) {
    _pendingKey = null;
    final errors = {...state.errors}..remove(field);
    _update(state.inputs.set(field, value.trim()), errors: errors);
  }

  /// A level tapped in the order book fills the price.
  void usePrice(String price) => edit(SpotField.price, price);

  /// The fields with − and + beside them: the prices and the amount.
  static bool steps(SpotField field) =>
      field != SpotField.total && field != SpotField.trailing;

  /// One step up or down (D-163, as on Futures): a price by the tick, the
  /// amount by the step. An empty price starts at the last price.
  void step(SpotField field, {required bool up}) {
    final pair = _pair;
    if (pair == null || !steps(field)) return;
    final amount = field == SpotField.amount;
    final step = Decimal.parse(amount ? pair.stepSize : pair.tickSize);
    if (step <= Decimal.zero) return;
    final start =
        Decimal.tryParse(state.inputs.of(field)) ??
        (amount ? Decimal.zero : Decimal.tryParse(_last ?? '')) ??
        Decimal.zero;
    final floored =
        (start / step).toDecimal(scaleOnInfinitePrecision: 20).floor() * step;
    var next = up
        ? floored + step
        : (floored == start ? start - step : floored);
    if (next < step) next = step;
    edit(field, next.toString());
  }

  /// The slider: a share of what is available, rounded down to the step.
  /// A Buy spends quote at the price typed (or the last one for Market).
  void useShare(double share, {required String available}) {
    final pair = _pair;
    final avbl = Decimal.tryParse(available);
    if (pair == null || avbl == null) return;
    final part = avbl * Decimal.parse(share.toStringAsFixed(4));
    if (state.kind == SpotKind.market && state.inputs.byTotal) {
      edit(SpotField.total, _down(part, '0.00000001').toString());
      return;
    }
    Decimal amount;
    if (state.side == OrderSide.buy) {
      final price = Decimal.tryParse(
        state.kind == SpotKind.market ? (_last ?? '') : state.inputs.price,
      );
      if (price == null || price <= Decimal.zero) return;
      amount = (part / price).toDecimal(scaleOnInfinitePrecision: 12);
    } else {
      amount = part;
    }
    edit(SpotField.amount, _down(amount, pair.stepSize).toString());
  }

  void _update(SpotInputs inputs, {Map<SpotField, FieldError>? errors}) {
    state = state.side == OrderSide.buy
        ? state.copyWith(buy: inputs, errors: errors)
        : state.copyWith(sell: inputs, errors: errors);
  }

  static Decimal _down(Decimal value, String step) {
    final size = Decimal.tryParse(step);
    if (size == null || size <= Decimal.zero) return value;
    return (value / size).toDecimal(scaleOnInfinitePrecision: 20).floor() *
        size;
  }

  static bool _onStep(Decimal value, String step) {
    final size = Decimal.tryParse(step);
    if (size == null || size <= Decimal.zero) return true;
    return (value % size) == Decimal.zero;
  }

  /// The client checks; empty when the form may go.
  Map<SpotField, FieldError> validate() {
    final pair = _pair;
    if (pair == null) return const {};
    final inputs = state.inputs;
    final errors = <SpotField, FieldError>{};
    final values = <SpotField, Decimal>{};
    for (final field in state.fields) {
      final text = inputs.of(field);
      if (text.isEmpty) {
        if (field != SpotField.stopLimit && field != SpotField.trailing) {
          errors[field] = const FieldError.issue(InputIssue.required);
        }
        continue;
      }
      final value = Decimal.tryParse(text);
      if (value == null || value <= Decimal.zero) {
        errors[field] = const FieldError.issue(InputIssue.notPositive);
        continue;
      }
      final step = switch (field) {
        SpotField.amount => pair.stepSize,
        SpotField.total => '0.00000001',
        // Whole basis points: a percent with at most two decimals.
        SpotField.trailing => '0.01',
        _ => pair.tickSize,
      };
      if (!_onStep(value, step)) {
        errors[field] = FieldError.issue(InputIssue.offStep, limit: step);
        continue;
      }
      values[field] = value;
    }
    _checkSides(values, errors);
    return errors;
  }

  /// OCO: for a Sell the take profit above and the stop below the last
  /// price, for a Buy the reverse; a Limit with TP/SL around its price,
  /// on the side that closes it.
  void _checkSides(
    Map<SpotField, Decimal> values,
    Map<SpotField, FieldError> errors,
  ) {
    final kind = state.kind;
    if (kind != SpotKind.oco && kind != SpotKind.limitTpSl) return;
    final reference = kind == SpotKind.oco
        ? Decimal.tryParse(_last ?? '')
        : values[SpotField.price];
    final tp = values[SpotField.takeProfit];
    final sl = values[SpotField.stop];
    if (reference == null) return;
    // The OCO closes: on a Limit with TP/SL it is the other side.
    final closesUp = kind == SpotKind.oco
        ? state.side == OrderSide.sell
        : state.side == OrderSide.buy;
    if (tp != null && (closesUp ? tp <= reference : tp >= reference)) {
      errors[SpotField.takeProfit] = const FieldError.issue(
        InputIssue.takeProfitSide,
      );
    }
    if (sl != null && (closesUp ? sl >= reference : sl <= reference)) {
      errors[SpotField.stop] = const FieldError.issue(InputIssue.stopSide);
    }
  }

  /// The stop type a stop order takes from where its stop lies: met at or
  /// above for a Buy stop loss and a Sell take profit, at or below for the
  /// other two (backend `SpotFilters`).
  SpotOrderType _stopType(Decimal stop, {required bool limit}) {
    final last = Decimal.tryParse(_last ?? '');
    final above = last == null || stop >= last;
    final stopLoss = state.side == OrderSide.buy ? above : !above;
    if (stopLoss) {
      return limit ? SpotOrderType.stopLossLimit : SpotOrderType.stopLoss;
    }
    return limit ? SpotOrderType.takeProfitLimit : SpotOrderType.takeProfit;
  }

  /// Places the order; true when it went. The screen asks first.
  Future<bool> submit() async {
    final pair = _pair;
    if (pair == null || state.submitting) return false;
    final errors = validate();
    if (errors.isNotEmpty) {
      state = state.copyWith(errors: errors);
      return false;
    }
    final key = _pendingKey ??= newClientId();
    state = state.copyWith(clearOutcome: true, submitting: true);
    final inputs = state.inputs;
    String? text(SpotField f) => inputs.of(f).isEmpty ? null : inputs.of(f);
    try {
      final orders = switch (state.kind) {
        SpotKind.oco || SpotKind.limitTpSl =>
          await ref
              .read(paperApiProvider)
              .placeOrderList(
                SpotOrderListRequest(
                  pairId: pair.pairId,
                  side: state.kind == SpotKind.oco
                      ? state.side
                      : (state.side == OrderSide.buy
                            ? OrderSide.sell
                            : OrderSide.buy),
                  quantity: state.kind == SpotKind.oco
                      ? text(SpotField.amount)
                      : null,
                  takeProfitPrice: inputs.takeProfit,
                  stopPrice: inputs.stop,
                  stopLimitPrice: text(SpotField.stopLimit),
                  workingPrice: state.kind == SpotKind.limitTpSl
                      ? inputs.price
                      : null,
                  workingQuantity: state.kind == SpotKind.limitTpSl
                      ? inputs.amount
                      : null,
                  listClientOrderId: key,
                ),
              ),
        SpotKind.oto =>
          await ref
              .read(paperApiProvider)
              .placeOto(
                SpotOtoRequest(
                  pairId: pair.pairId,
                  working: SpotLeg(
                    side: state.side,
                    type: SpotOrderType.limit,
                    price: inputs.price,
                    quantity: inputs.amount,
                  ),
                  // The way back: the other side, at its own price.
                  pending: SpotLeg(
                    side: state.side == OrderSide.buy
                        ? OrderSide.sell
                        : OrderSide.buy,
                    type: SpotOrderType.limit,
                    price: inputs.pendingPrice,
                    quantity: inputs.amount,
                  ),
                  listClientOrderId: key,
                ),
              ),
        _ => [await ref.read(paperApiProvider).placeOrder(_single(pair, key))],
      };
      _pendingKey = null;
      if (!ref.mounted) return true;
      ref.read(openOrdersProvider.notifier).apply(orders);
      final cleared = inputs.placed();
      state =
          (state.side == OrderSide.buy
                  ? state.copyWith(buy: cleared)
                  : state.copyWith(sell: cleared))
              .copyWith(submitting: false, placed: state.placed + 1);
      return true;
    } on ApiFailure catch (failure) {
      // The server answered: the next submit is a new order. A network
      // failure keeps the key, so sending again cannot place it twice.
      if (failure is! NetworkFailure) _pendingKey = null;
      if (ref.mounted) _refused(failure);
      return false;
    }
  }

  SpotOrderRequest _single(MarketPair pair, String key) {
    final inputs = state.inputs;
    final side = state.side;
    return switch (state.kind) {
      SpotKind.market => SpotOrderRequest(
        pairId: pair.pairId,
        side: side,
        type: SpotOrderType.market,
        quantity: inputs.byTotal ? null : inputs.amount,
        quoteOrderQty: inputs.byTotal ? inputs.total : null,
        clientOrderId: key,
      ),
      SpotKind.stopLimit => SpotOrderRequest(
        pairId: pair.pairId,
        side: side,
        type: _stopType(Decimal.parse(inputs.stop), limit: true),
        price: inputs.price,
        quantity: inputs.amount,
        stopPrice: inputs.stop,
        timeInForce: state.timeInForce,
        trailingDelta: _trailingDelta(),
        clientOrderId: key,
      ),
      SpotKind.stopMarket => SpotOrderRequest(
        pairId: pair.pairId,
        side: side,
        type: _stopType(Decimal.parse(inputs.stop), limit: false),
        quantity: inputs.amount,
        stopPrice: inputs.stop,
        trailingDelta: _trailingDelta(),
        clientOrderId: key,
      ),
      SpotKind.postOnly => SpotOrderRequest(
        pairId: pair.pairId,
        side: side,
        type: SpotOrderType.limitMaker,
        price: inputs.price,
        quantity: inputs.amount,
        clientOrderId: key,
      ),
      _ => SpotOrderRequest(
        pairId: pair.pairId,
        side: side,
        type: SpotOrderType.limit,
        price: inputs.price,
        quantity: inputs.amount,
        timeInForce: state.timeInForce,
        clientOrderId: key,
      ),
    };
  }

  static const _fieldOf = {
    'price': SpotField.price,
    'quantity': SpotField.amount,
    'quoteOrderQty': SpotField.total,
    'stopPrice': SpotField.stop,
    'working.price': SpotField.price,
    'working.quantity': SpotField.amount,
    'oco.quantity': SpotField.amount,
    'oco.takeProfitPrice': SpotField.takeProfit,
    'oco.stopPrice': SpotField.stop,
    'oco.stopLimitPrice': SpotField.stopLimit,
    'trailingDelta': SpotField.trailing,
    'pending.price': SpotField.pendingPrice,
    'pending.quantity': SpotField.amount,
  };

  void _refused(ApiFailure failure) {
    final refusal = paperRefusal(failure);
    final field = _fieldOf[refusal?.field];
    if (refusal != null && field != null) {
      state = state.copyWith(
        submitting: false,
        errors: {field: FieldError.refusal(refusal)},
      );
    } else if (refusal != null) {
      state = state.copyWith(submitting: false, notice: refusal);
    } else {
      state = state.copyWith(submitting: false, failure: failure);
    }
  }
}
