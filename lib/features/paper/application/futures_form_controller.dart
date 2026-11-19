import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../market/data/market_repository.dart';
import '../../market/domain/market.dart';
import '../data/futures_api.dart';
import '../data/futures_repository.dart';
import '../domain/futures.dart';
import '../domain/paper.dart';
import '../domain/paper_refusal.dart';

/// The Futures order kinds of the first version (D-154 (2)).
enum FuturesKind {
  limit,
  market,
  stopLimit,
  stopMarket,
  takeProfitLimit,
  takeProfitMarket;

  bool get conditional => index >= 2;
  bool get limitPrice =>
      this == limit || this == stopLimit || this == takeProfitLimit;

  /// The `type` the server takes.
  String get wire => switch (this) {
    limit => 'LIMIT',
    market => 'MARKET',
    stopLimit => 'STOP',
    stopMarket => 'STOP_MARKET',
    takeProfitLimit => 'TAKE_PROFIT',
    takeProfitMarket => 'TAKE_PROFIT_MARKET',
  };
}

enum FuturesField { price, size, trigger, takeProfit, stopLoss }

enum FuturesIssue { required, notPositive, offStep, tpSlWithReduceOnly }

@immutable
class FuturesFormState {
  const FuturesFormState({
    this.kind = FuturesKind.limit,
    this.price = '',
    this.size = '',
    this.sizeInUsdt = false,
    this.trigger = '',
    this.working = WorkingType.mark,
    this.reduceOnly = false,
    this.tpSl = false,
    this.takeProfit = '',
    this.stopLoss = '',
    this.issues = const {},
    this.refusal,
    this.failure,
    this.review,
    this.reviewSide,
    this.busy = false,
    this.placed = 0,
  });

  final FuturesKind kind;
  final String price;

  /// In the coin, or in USDT when [sizeInUsdt] (sent as the coin quantity).
  final String size;
  final bool sizeInUsdt;
  final String trigger;
  final WorkingType working;
  final bool reduceOnly;

  /// TP/SL with the order; not with reduce-only (the server refuses both).
  final bool tpSl;
  final String takeProfit;
  final String stopLoss;
  final Map<FuturesField, FuturesIssue> issues;
  final PaperRefusal? refusal;
  final ApiFailure? failure;

  /// What the server said of the order about to go (TR-26).
  final OrderWarnings? review;
  final OrderSide? reviewSide;
  final bool busy;
  final int placed;

  List<FuturesField> get fields => [
    if (kind.conditional) FuturesField.trigger,
    if (kind.limitPrice) FuturesField.price,
    FuturesField.size,
    if (tpSl && !kind.conditional) ...[
      FuturesField.takeProfit,
      FuturesField.stopLoss,
    ],
  ];

  String of(FuturesField field) => switch (field) {
    FuturesField.price => price,
    FuturesField.size => size,
    FuturesField.trigger => trigger,
    FuturesField.takeProfit => takeProfit,
    FuturesField.stopLoss => stopLoss,
  };

  FuturesFormState copyWith({
    FuturesKind? kind,
    String? price,
    String? size,
    bool? sizeInUsdt,
    String? trigger,
    WorkingType? working,
    bool? reduceOnly,
    bool? tpSl,
    String? takeProfit,
    String? stopLoss,
    Map<FuturesField, FuturesIssue>? issues,
    PaperRefusal? refusal,
    ApiFailure? failure,
    OrderWarnings? review,
    OrderSide? reviewSide,
    bool clearOutcome = false,
    bool? busy,
    int? placed,
  }) => FuturesFormState(
    kind: kind ?? this.kind,
    price: price ?? this.price,
    size: size ?? this.size,
    sizeInUsdt: sizeInUsdt ?? this.sizeInUsdt,
    trigger: trigger ?? this.trigger,
    working: working ?? this.working,
    reduceOnly: reduceOnly ?? this.reduceOnly,
    tpSl: tpSl ?? this.tpSl,
    takeProfit: takeProfit ?? this.takeProfit,
    stopLoss: stopLoss ?? this.stopLoss,
    issues: issues ?? (clearOutcome ? const {} : this.issues),
    refusal: clearOutcome ? null : refusal ?? this.refusal,
    failure: clearOutcome ? null : failure ?? this.failure,
    review: clearOutcome ? null : review ?? this.review,
    reviewSide: clearOutcome ? null : reviewSide ?? this.reviewSide,
    busy: busy ?? this.busy,
    placed: placed ?? this.placed,
  );
}

final futuresFormProvider = NotifierProvider.autoDispose
    .family<FuturesFormController, FuturesFormState, String>(
      FuturesFormController.new,
    );

/// The Futures order form of one pair (D-154, plan 9.9): Buy/Long and
/// Sell/Short from the same inputs. [review] checks on the phone, then asks
/// the server's TR-26 warnings for a Limit or Market order (a BLOCKING one
/// stops it); [place] sends it with a key kept after a network failure.
class FuturesFormController extends Notifier<FuturesFormState> {
  FuturesFormController(this.symbol);

  final String symbol;
  String? _pendingKey;

  @override
  FuturesFormState build() => const FuturesFormState();

  MarketPair? get _pair => ref
      .read(marketRepositoryProvider(Market.futures))
      .pairs
      ?.where((p) => p.symbol == symbol)
      .firstOrNull;

  /// The mark price (the last one until a mark arrives).
  String? get _mark {
    final ticker = ref
        .read(marketRepositoryProvider(Market.futures))
        .tickers[symbol];
    return ticker?.markPrice ?? ticker?.displayPrice;
  }

  void _set(FuturesFormState next) {
    _pendingKey = null;
    state = next.copyWith(clearOutcome: true);
  }

  void selectKind(FuturesKind kind) => _set(state.copyWith(kind: kind));
  void setSizeInUsdt(bool value) => _set(state.copyWith(sizeInUsdt: value));
  void setWorking(WorkingType value) => _set(state.copyWith(working: value));
  void setReduceOnly(bool value) => _set(state.copyWith(reduceOnly: value));
  void setTpSl(bool value) => _set(state.copyWith(tpSl: value));

  void edit(FuturesField field, String value) {
    final v = value.trim();
    _set(switch (field) {
      FuturesField.price => state.copyWith(price: v),
      FuturesField.size => state.copyWith(size: v),
      FuturesField.trigger => state.copyWith(trigger: v),
      FuturesField.takeProfit => state.copyWith(takeProfit: v),
      FuturesField.stopLoss => state.copyWith(stopLoss: v),
    });
  }

  void usePrice(String price) => edit(FuturesField.price, price);

  static bool _onStep(Decimal value, String step) {
    final size = Decimal.tryParse(step);
    return size == null || size <= Decimal.zero || value % size == Decimal.zero;
  }

  Map<FuturesField, FuturesIssue> validate() {
    final pair = _pair;
    if (pair == null) return const {};
    final issues = <FuturesField, FuturesIssue>{};
    for (final field in state.fields) {
      final text = state.of(field);
      final value = Decimal.tryParse(text);
      if (text.isEmpty) {
        issues[field] = FuturesIssue.required;
      } else if (value == null || value <= Decimal.zero) {
        issues[field] = FuturesIssue.notPositive;
      } else if (field != FuturesField.size && !_onStep(value, pair.tickSize)) {
        issues[field] = FuturesIssue.offStep;
      } else if (field == FuturesField.size &&
          !state.sizeInUsdt &&
          !_onStep(value, pair.stepSize)) {
        issues[field] = FuturesIssue.offStep;
      }
    }
    if (state.tpSl && state.reduceOnly && !state.kind.conditional) {
      issues[FuturesField.takeProfit] = FuturesIssue.tpSlWithReduceOnly;
    }
    return issues;
  }

  /// The coin quantity to send: the size typed, or USDT at the price (the
  /// mark for Market) rounded down to the step; null when it cannot be told.
  String? quantity() {
    final pair = _pair;
    final size = Decimal.tryParse(state.size);
    if (pair == null || size == null) return null;
    if (!state.sizeInUsdt) return state.size;
    final price = Decimal.tryParse(
      state.kind.limitPrice
          ? state.price
          : (state.trigger.isNotEmpty ? state.trigger : _mark ?? ''),
    );
    final step = Decimal.tryParse(pair.stepSize);
    if (price == null || price <= Decimal.zero || step == null) return null;
    final coins = (size / price).toDecimal(scaleOnInfinitePrecision: 20);
    final rounded =
        (coins / step).toDecimal(scaleOnInfinitePrecision: 20).floor() * step;
    return rounded > Decimal.zero ? rounded.toString() : null;
  }

  FuturesOrderRequest _order(OrderSide side, String quantity, String key) =>
      FuturesOrderRequest(
        symbol: symbol,
        side: side,
        type: state.kind.wire,
        quantity: quantity,
        price: state.kind == FuturesKind.limit ? state.price : null,
        reduceOnly: state.reduceOnly,
        takeProfitPrice: state.tpSl && state.takeProfit.isNotEmpty
            ? state.takeProfit
            : null,
        stopLossPrice: state.tpSl && state.stopLoss.isNotEmpty
            ? state.stopLoss
            : null,
        tpSlWorking: state.working,
        clientOrderId: key,
      );

  /// The order as it stands, to ask its warnings before any tap (T-131);
  /// null for a conditional kind or while a field is missing or wrong.
  /// Its key is thrown away: nothing is placed or stored.
  FuturesOrderRequest? draft(OrderSide side) {
    if (state.kind.conditional || validate().isNotEmpty) return null;
    final quantity = this.quantity();
    return quantity == null ? null : _order(side, quantity, newClientId());
  }

  /// The price an opening order is worked out at: the limit price, the
  /// trigger of a conditional Market kind, else the mark.
  String? entryPrice() {
    String? valid(String text) {
      final value = Decimal.tryParse(text);
      return value != null && value > Decimal.zero ? text : null;
    }

    if (state.kind.limitPrice) return valid(state.price);
    if (state.kind.conditional) return valid(state.trigger);
    return _mark;
  }

  /// One step up or down (plan 9.2): a price by the tick, a size by the
  /// step, or by 1 when typed in USDT. An empty price starts at the mark.
  void step(FuturesField field, {required bool up}) {
    final pair = _pair;
    if (pair == null) return;
    final size = field == FuturesField.size;
    final step = Decimal.parse(
      size ? (state.sizeInUsdt ? '1' : pair.stepSize) : pair.tickSize,
    );
    if (step <= Decimal.zero) return;
    final start =
        Decimal.tryParse(state.of(field)) ??
        (size ? Decimal.zero : Decimal.tryParse(_mark ?? '')) ??
        Decimal.zero;
    final floored =
        (start / step).toDecimal(scaleOnInfinitePrecision: 20).floor() * step;
    var next = up
        ? floored + step
        : (floored == start ? start - step : floored);
    if (next < step) next = step;
    edit(field, next.toString());
  }

  /// [percent] of the [max] the balance opens (plan 9.2 slider): in the
  /// coin down to the step, or in USDT down to the cent.
  void useShare(int percent, MaxOpen max) {
    final pair = _pair;
    if (pair == null) return;
    final share = Decimal.fromInt(percent.clamp(0, 100));
    final hundred = Decimal.fromInt(100);
    final String size;
    if (state.sizeInUsdt) {
      final cents = (Decimal.parse(max.maxNotional) * share)
          .floor(); // hundredths of a USDT
      size = (Decimal.fromBigInt(cents.toBigInt()) / hundred)
          .toDecimal(scaleOnInfinitePrecision: 2)
          .toStringAsFixed(2);
    } else {
      final step = Decimal.parse(pair.stepSize);
      final coins = (Decimal.parse(max.maxQuantity) * share / hundred)
          .toDecimal(scaleOnInfinitePrecision: 20);
      final rounded = step <= Decimal.zero
          ? coins
          : (coins / step).toDecimal(scaleOnInfinitePrecision: 20).floor() *
                step;
      size = rounded.toString();
    }
    edit(FuturesField.size, Decimal.parse(size) > Decimal.zero ? size : '');
  }

  /// Checks the order and, for Limit and Market, asks its warnings; true
  /// when it may go (the screen then confirms it).
  Future<bool> review(OrderSide side) async {
    if (state.busy) return false;
    final issues = validate();
    if (issues.isNotEmpty) {
      state = state.copyWith(issues: issues);
      return false;
    }
    final quantity = this.quantity();
    if (quantity == null) {
      state = state.copyWith(
        issues: {FuturesField.size: FuturesIssue.notPositive},
      );
      return false;
    }
    if (state.kind.conditional) {
      state = state.copyWith(clearOutcome: true, reviewSide: side);
      return true;
    }
    state = state.copyWith(clearOutcome: true, busy: true);
    try {
      final warnings = await ref
          .read(futuresApiProvider)
          .warnings(_order(side, quantity, _pendingKey ??= newClientId()));
      if (!ref.mounted) return false;
      state = state.copyWith(busy: false, review: warnings, reviewSide: side);
      return !warnings.blocked;
    } on ApiFailure catch (failure) {
      if (ref.mounted) _refused(failure);
      return false;
    }
  }

  /// Places the reviewed order; true when it went.
  Future<bool> place(OrderSide side) async {
    final quantity = this.quantity();
    if (state.busy || quantity == null) return false;
    if (state.review?.blocked ?? false) return false;
    final key = _pendingKey ??= newClientId();
    state = state.copyWith(busy: true);
    try {
      final api = ref.read(futuresApiProvider);
      if (state.kind.conditional) {
        await api.placeAlgoOrder(
          AlgoOrderRequest(
            symbol: symbol,
            side: side,
            type: state.kind.wire,
            triggerPrice: state.trigger,
            working: state.working,
            quantity: quantity,
            price: state.kind.limitPrice ? state.price : null,
            reduceOnly: state.reduceOnly,
            clientAlgoId: key,
          ),
        );
      } else {
        await api.placeOrder(_order(side, quantity, key));
      }
      _pendingKey = null;
      if (!ref.mounted) return true;
      // The positions screen reads again; nothing to do when none listens.
      if (ref.exists(futuresProvider)) {
        unawaited(ref.read(futuresProvider.notifier).load());
      }
      state = state.copyWith(
        size: '',
        clearOutcome: true,
        busy: false,
        placed: state.placed + 1,
      );
      return true;
    } on ApiFailure catch (failure) {
      if (failure is! NetworkFailure) _pendingKey = null;
      if (ref.mounted) _refused(failure);
      return false;
    }
  }

  void _refused(ApiFailure failure) {
    final refusal = paperRefusal(failure);
    state = refusal != null
        ? state.copyWith(busy: false, refusal: refusal)
        : state.copyWith(busy: false, failure: failure);
  }
}
