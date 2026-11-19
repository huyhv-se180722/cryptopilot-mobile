import 'package:flutter/foundation.dart';

import '../../../core/json/json_read.dart';
import 'paper.dart';

/// Paper Futures (D-127, D-128; `/api/v1/paper/futures`, checked on backend
/// develop 5c2398cb). Virtual funds only; decimals stay strings.

enum PositionSide {
  both('BOTH'),
  long('LONG'),
  short('SHORT');

  const PositionSide(this.wire);
  final String wire;
  static PositionSide decode(String v) => values.firstWhere(
    (e) => e.wire == v,
    orElse: () => throw DecodeException('position side $v is unknown'),
  );
}

enum MarginType {
  crossed('CROSSED'),
  isolated('ISOLATED');

  const MarginType(this.wire);
  final String wire;
  static MarginType decode(String v) => values.firstWhere(
    (e) => e.wire == v,
    orElse: () => throw DecodeException('margin type $v is unknown'),
  );
}

/// What a conditional order watches (`workingType`).
enum WorkingType {
  mark('MARK_PRICE'),
  last('CONTRACT_PRICE');

  const WorkingType(this.wire);
  final String wire;
}

enum WarningSeverity { blocking, warning, info }

/// A TR-26 warning of an order before it is placed.
@immutable
class OrderWarning {
  const OrderWarning({
    required this.type,
    required this.severity,
    required this.message,
  });

  final String type;
  final WarningSeverity severity;

  /// The server's words (English), shown as they come.
  final String message;
}

@immutable
class OrderWarnings {
  const OrderWarnings({
    required this.warnings,
    this.cost,
    this.liquidationPrice,
  });

  final List<OrderWarning> warnings;
  final String? cost;
  final String? liquidationPrice;

  /// A BLOCKING warning stops the order (TR-26).
  bool get blocked =>
      warnings.any((w) => w.severity == WarningSeverity.blocking);
}

@immutable
class FuturesAccount {
  const FuturesAccount({
    required this.walletBalance,
    required this.unrealizedProfit,
    required this.marginBalance,
    required this.availableBalance,
    required this.maxWithdrawAmount,
  });

  final String walletBalance;
  final String unrealizedProfit;
  final String marginBalance;
  final String availableBalance;

  /// The most USDT that can leave for Spot.
  final String maxWithdrawAmount;
}

@immutable
class FuturesPosition {
  const FuturesPosition({
    required this.symbol,
    required this.side,
    required this.amount,
    required this.entryPrice,
    required this.markPrice,
    required this.unrealizedProfit,
    required this.marginType,
    this.liquidationPrice,
    this.isolatedMargin,
    this.marginRatio,
    this.breakEvenPrice,
  });

  final String symbol;
  final PositionSide side;

  /// Signed: negative for a short in one-way mode.
  final String amount;
  final String entryPrice;
  final String markPrice;
  final String unrealizedProfit;
  final MarginType marginType;
  final String? liquidationPrice;
  final String? isolatedMargin;
  final String? marginRatio;
  final String? breakEvenPrice;

  bool get short => amount.startsWith('-') || side == PositionSide.short;

  /// The quantity without its sign.
  String get size => amount.startsWith('-') ? amount.substring(1) : amount;
}

@immutable
class FuturesOrder {
  const FuturesOrder({
    required this.orderId,
    required this.symbol,
    required this.side,
    required this.positionSide,
    required this.type,
    required this.origQty,
    required this.executedQty,
    required this.status,
    required this.time,
    this.price,
    this.stopPrice,
  });

  final String orderId;
  final String symbol;
  final OrderSide side;
  final PositionSide positionSide;
  final String type;
  final String? price;
  final String origQty;
  final String executedQty;
  final String? stopPrice;
  final OrderStatus status;
  final DateTime time;
}

/// A conditional order waiting for its trigger (`/algoOrder`).
@immutable
class AlgoOrder {
  const AlgoOrder({
    required this.algoId,
    required this.symbol,
    required this.side,
    required this.type,
    required this.triggerPrice,
    required this.status,
    this.quantity,
    this.price,
  });

  final String algoId;
  final String symbol;
  final OrderSide side;
  final String type;
  final String triggerPrice;
  final String? quantity;
  final String? price;
  final String status;
}

@immutable
class SymbolConfig {
  const SymbolConfig({
    required this.symbol,
    required this.marginType,
    required this.leverage,
  });

  final String symbol;
  final MarginType marginType;
  final int leverage;
}

/// The highest leverage the pair allows (bracket 1).
int maxLeverageOf(Object? body) {
  final json = asJsonObject(body, 'leverage bracket');
  final brackets = json['brackets'];
  if (brackets is! List || brackets.isEmpty) {
    throw const DecodeException('brackets is not a list');
  }
  var max = 1;
  for (final item in brackets) {
    final value = asJsonObject(item, 'bracket')['initialLeverage'];
    if (value is! int) throw const DecodeException('initialLeverage');
    if (value > max) max = value;
  }
  return max;
}

@immutable
class MarginCall {
  const MarginCall({
    required this.symbol,
    required this.side,
    required this.markPrice,
    this.marginRatio,
  });

  final String symbol;
  final PositionSide side;
  final String markPrice;
  final String? marginRatio;
}

/// A Futures order to place, or to ask the warnings of (`FuturesOrderRequest`).
@immutable
class FuturesOrderRequest {
  const FuturesOrderRequest({
    required this.symbol,
    required this.side,
    required this.type,
    required this.quantity,
    required this.clientOrderId,
    this.positionSide = PositionSide.both,
    this.price,
    this.reduceOnly = false,
    this.takeProfitPrice,
    this.stopLossPrice,
    this.tpSlWorking = WorkingType.last,
  });

  final String symbol;
  final OrderSide side;
  final PositionSide positionSide;

  /// LIMIT or MARKET.
  final String type;
  final String quantity;
  final String? price;
  final bool reduceOnly;
  final String? takeProfitPrice;
  final String? stopLossPrice;
  final WorkingType tpSlWorking;
  final String clientOrderId;

  Map<String, Object?> toJson() => {
    'symbol': symbol,
    'side': side.wire,
    'positionSide': positionSide.wire,
    'type': type,
    if (type == 'LIMIT') 'timeInForce': 'GTC',
    'quantity': quantity,
    'price': ?price,
    if (reduceOnly) 'reduceOnly': true,
    'takeProfitPrice': ?takeProfitPrice,
    'stopLossPrice': ?stopLossPrice,
    if (takeProfitPrice != null || stopLossPrice != null)
      'tpSlWorkingType': tpSlWorking.wire,
    'newClientOrderId': clientOrderId,
  };
}

/// A conditional order (`FuturesAlgoOrderRequest`, CONDITIONAL).
@immutable
class AlgoOrderRequest {
  const AlgoOrderRequest({
    required this.symbol,
    required this.side,
    required this.type,
    required this.triggerPrice,
    required this.working,
    required this.clientAlgoId,
    this.positionSide = PositionSide.both,
    this.quantity,
    this.price,
    this.reduceOnly = false,
    this.closePosition = false,
  });

  final String symbol;
  final OrderSide side;
  final PositionSide positionSide;

  /// STOP, TAKE_PROFIT (with [price]), STOP_MARKET or TAKE_PROFIT_MARKET.
  final String type;
  final String triggerPrice;
  final WorkingType working;
  final String? quantity;
  final String? price;
  final bool reduceOnly;

  /// The whole position (a TP/SL of the position).
  final bool closePosition;
  final String clientAlgoId;

  Map<String, Object?> toJson() => {
    'algoType': 'CONDITIONAL',
    'symbol': symbol,
    'side': side.wire,
    'positionSide': positionSide.wire,
    'type': type,
    if (price != null) 'timeInForce': 'GTC',
    'quantity': ?quantity,
    'price': ?price,
    'triggerPrice': triggerPrice,
    'workingType': working.wire,
    if (reduceOnly) 'reduceOnly': true,
    if (closePosition) 'closePosition': true,
    'clientAlgoId': clientAlgoId,
  };
}

String _decimal(Map<String, Object?> json, String key) {
  final text = readString(json, key);
  if (num.tryParse(text) == null) {
    throw DecodeException('$key is not a decimal');
  }
  return text;
}

String? _optionalDecimal(Map<String, Object?> json, String key) =>
    json[key] == null ? null : _decimal(json, key);

List<Object?> _list(Object? value, String what) {
  if (value is List) return value;
  throw DecodeException('$what is not a list');
}

FuturesAccount decodeFuturesAccount(Object? body) {
  final json = asJsonObject(body, 'futures account');
  return FuturesAccount(
    walletBalance: _decimal(json, 'totalWalletBalance'),
    unrealizedProfit: _decimal(json, 'totalUnrealizedProfit'),
    marginBalance: _decimal(json, 'totalMarginBalance'),
    availableBalance: _decimal(json, 'availableBalance'),
    maxWithdrawAmount: _decimal(json, 'maxWithdrawAmount'),
  );
}

FuturesPosition decodePosition(Object? body) {
  final json = asJsonObject(body, 'position');
  return FuturesPosition(
    symbol: readString(json, 'symbol'),
    side: PositionSide.decode(readString(json, 'positionSide')),
    amount: _decimal(json, 'positionAmt'),
    entryPrice: _decimal(json, 'entryPrice'),
    markPrice: _decimal(json, 'markPrice'),
    unrealizedProfit: _decimal(json, 'unRealizedProfit'),
    marginType: MarginType.decode(readString(json, 'marginType')),
    liquidationPrice: _optionalDecimal(json, 'liquidationPrice'),
    isolatedMargin: _optionalDecimal(json, 'isolatedMargin'),
    marginRatio: _optionalDecimal(json, 'marginRatio'),
    breakEvenPrice: _optionalDecimal(json, 'breakEvenPrice'),
  );
}

/// Open positions only (a zero amount is a flat side).
List<FuturesPosition> decodePositions(Object? body) => [
  for (final item in _list(body, 'positions'))
    if (num.parse(_decimal(asJsonObject(item, 'position'), 'positionAmt')) != 0)
      decodePosition(item),
];

FuturesOrder decodeFuturesOrder(Object? body) {
  final json = asJsonObject(body, 'futures order');
  return FuturesOrder(
    orderId: readString(json, 'orderId'),
    symbol: readString(json, 'symbol'),
    side: OrderSide.decode(readString(json, 'side')),
    positionSide: PositionSide.decode(readString(json, 'positionSide')),
    type: readString(json, 'type'),
    price: _optionalDecimal(json, 'price'),
    origQty: _decimal(json, 'origQty'),
    executedQty: _decimal(json, 'executedQty'),
    stopPrice: _optionalDecimal(json, 'stopPrice'),
    status: OrderStatus.decode(readString(json, 'status')),
    time: readInstant(json, 'time'),
  );
}

List<FuturesOrder> decodeFuturesOrders(Object? body) => [
  for (final item in _list(body, 'futures orders')) decodeFuturesOrder(item),
];

AlgoOrder decodeAlgoOrder(Object? body) {
  final json = asJsonObject(body, 'algo order');
  return AlgoOrder(
    algoId: readString(json, 'algoId'),
    symbol: readString(json, 'symbol'),
    side: OrderSide.decode(readString(json, 'side')),
    type: readString(json, 'orderType'),
    triggerPrice: _decimal(json, 'triggerPrice'),
    quantity: _optionalDecimal(json, 'quantity'),
    price: _optionalDecimal(json, 'price'),
    status: readString(json, 'algoStatus'),
  );
}

List<AlgoOrder> decodeAlgoOrders(Object? body) => [
  for (final item in _list(body, 'algo orders')) decodeAlgoOrder(item),
];

SymbolConfig decodeSymbolConfig(Object? body) {
  final json = asJsonObject(body, 'symbol config');
  final leverage = json['leverage'];
  if (leverage is! int) throw const DecodeException('leverage');
  return SymbolConfig(
    symbol: readString(json, 'symbol'),
    marginType: MarginType.decode(readString(json, 'marginType')),
    leverage: leverage,
  );
}

OrderWarnings decodeWarnings(Object? body) {
  final json = asJsonObject(body, 'warnings');
  return OrderWarnings(
    cost: _optionalDecimal(json, 'cost'),
    liquidationPrice: _optionalDecimal(json, 'liquidationPrice'),
    warnings: [
      for (final item in _list(json['warnings'], 'warnings'))
        () {
          final w = asJsonObject(item, 'warning');
          return OrderWarning(
            type: readString(w, 'type'),
            severity: switch (readString(w, 'severity')) {
              'BLOCKING' => WarningSeverity.blocking,
              'WARNING' => WarningSeverity.warning,
              'INFO' => WarningSeverity.info,
              final other => throw DecodeException('severity $other'),
            },
            message: readString(w, 'message'),
          );
        }(),
    ],
  );
}

MarginCall decodeMarginCall(Object? body) {
  final json = asJsonObject(body, 'margin call');
  return MarginCall(
    symbol: readString(json, 'symbol'),
    side: PositionSide.decode(readString(json, 'positionSide')),
    markPrice: _decimal(json, 'markPrice'),
    marginRatio: _optionalDecimal(json, 'marginRatio'),
  );
}
