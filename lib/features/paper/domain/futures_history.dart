import 'package:flutter/foundation.dart';

import '../../../core/json/json_read.dart';
import 'futures.dart';
import 'paper.dart';

/// The Futures histories of plan 9.3 (T-123), each read from its own
/// endpoint with only the filters that endpoint has.

/// `incomeType` of `GET /futures/income`.
enum IncomeType {
  transfer('TRANSFER'),
  realizedPnl('REALIZED_PNL'),
  commission('COMMISSION'),
  fundingFee('FUNDING_FEE'),
  insuranceClear('INSURANCE_CLEAR'),
  insuranceCover('INSURANCE_COVER');

  const IncomeType(this.wire);
  final String wire;

  /// Null for a type this app does not know yet.
  static IncomeType? decode(String wire) =>
      values.where((t) => t.wire == wire).firstOrNull;
}

/// A line of `GET /futures/income`.
@immutable
class FuturesIncome {
  const FuturesIncome({
    required this.typeWire,
    required this.income,
    required this.time,
    required this.tranId,
    this.symbol,
    this.info,
    this.tradeId,
  });

  /// As sent; [type] is null for one this app does not know.
  final String typeWire;
  IncomeType? get type => IncomeType.decode(typeWire);

  /// Signed, in USDT.
  final String income;
  final DateTime time;
  final String tranId;

  /// Empty for a transfer.
  final String? symbol;
  final String? info;
  final String? tradeId;
}

/// A closed position of `GET /futures/positionHistory`.
@immutable
class ClosedPosition {
  const ClosedPosition({
    required this.positionId,
    required this.symbol,
    required this.side,
    required this.long,
    required this.marginType,
    required this.leverage,
    required this.maxQuantity,
    required this.closedQuantity,
    required this.entryPrice,
    required this.avgClosePrice,
    required this.realizedPnl,
    required this.fundingFee,
    required this.liquidationFee,
    required this.netProfit,
    required this.closeReason,
    required this.openTime,
    required this.closeTime,
  });

  final String positionId;
  final String symbol;
  final PositionSide side;
  final bool long;
  final MarginType marginType;
  final int leverage;
  final String maxQuantity;
  final String closedQuantity;
  final String entryPrice;
  final String avgClosePrice;
  final String realizedPnl;
  final String fundingFee;
  final String liquidationFee;

  /// Realised plus funding less the clearance fee.
  final String netProfit;

  /// MANUAL, LIQUIDATION, … as sent.
  final String closeReason;
  final DateTime openTime;
  final DateTime closeTime;
}

/// A fill of `GET /futures/userTrades`.
@immutable
class FuturesTrade {
  const FuturesTrade({
    required this.id,
    required this.orderId,
    required this.symbol,
    required this.side,
    required this.positionSide,
    required this.price,
    required this.qty,
    required this.quoteQty,
    required this.realizedPnl,
    required this.commission,
    required this.maker,
    required this.time,
  });

  final String id;
  final String orderId;
  final String symbol;
  final OrderSide side;
  final PositionSide positionSide;
  final String price;
  final String qty;
  final String quoteQty;
  final String realizedPnl;
  final String commission;
  final bool maker;
  final DateTime time;
}

/// A change of an isolated margin by the Trader
/// (`GET /futures/positionMargin/history`).
@immutable
class MarginChange {
  const MarginChange({
    required this.symbol,
    required this.added,
    required this.amount,
    required this.positionSide,
    required this.time,
    this.isolatedWallet,
  });

  final String symbol;

  /// Type 1 added, 2 reduced.
  final bool added;

  /// The USDT moved, positive.
  final String amount;
  final PositionSide positionSide;
  final DateTime time;

  /// The isolated wallet afterwards.
  final String? isolatedWallet;
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

int _int(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int) throw DecodeException(key);
  return value;
}

List<Object?> _list(Object? value, String what) {
  if (value is List) return value;
  throw DecodeException('$what is not a list');
}

FuturesIncome decodeIncome(Object? body) {
  final json = asJsonObject(body, 'income');
  final symbol = readOptionalString(json, 'symbol');
  return FuturesIncome(
    typeWire: readString(json, 'incomeType'),
    income: _decimal(json, 'income'),
    time: readInstant(json, 'time'),
    tranId: readString(json, 'tranId'),
    symbol: symbol == null || symbol.isEmpty ? null : symbol,
    info: readOptionalString(json, 'info'),
    tradeId: readOptionalString(json, 'tradeId'),
  );
}

List<FuturesIncome> decodeIncomes(Object? body) => [
  for (final item in _list(body, 'income')) decodeIncome(item),
];

ClosedPosition decodeClosedPosition(Object? body) {
  final json = asJsonObject(body, 'closed position');
  return ClosedPosition(
    positionId: readString(json, 'positionId'),
    symbol: readString(json, 'symbol'),
    side: PositionSide.decode(readString(json, 'positionSide')),
    long: switch (readString(json, 'direction')) {
      'LONG' => true,
      'SHORT' => false,
      _ => throw const DecodeException('direction'),
    },
    marginType: MarginType.decode(readString(json, 'marginType')),
    leverage: _int(json, 'leverage'),
    maxQuantity: _decimal(json, 'maxQuantity'),
    closedQuantity: _decimal(json, 'closedQuantity'),
    entryPrice: _decimal(json, 'entryPrice'),
    avgClosePrice: _decimal(json, 'avgClosePrice'),
    realizedPnl: _decimal(json, 'realizedPnl'),
    fundingFee: _decimal(json, 'fundingFee'),
    liquidationFee: _decimal(json, 'liquidationFee'),
    netProfit: _decimal(json, 'netProfit'),
    closeReason: readString(json, 'closeReason'),
    openTime: readInstant(json, 'openTime'),
    closeTime: readInstant(json, 'closeTime'),
  );
}

List<ClosedPosition> decodeClosedPositions(Object? body) => [
  for (final item in _list(body, 'position history'))
    decodeClosedPosition(item),
];

FuturesTrade decodeFuturesTrade(Object? body) {
  final json = asJsonObject(body, 'futures trade');
  return FuturesTrade(
    id: readString(json, 'id'),
    orderId: readString(json, 'orderId'),
    symbol: readString(json, 'symbol'),
    side: OrderSide.decode(readString(json, 'side')),
    positionSide: PositionSide.decode(readString(json, 'positionSide')),
    price: _decimal(json, 'price'),
    qty: _decimal(json, 'qty'),
    quoteQty: _decimal(json, 'quoteQty'),
    realizedPnl: _decimal(json, 'realizedPnl'),
    commission: _decimal(json, 'commission'),
    maker: readBool(json, 'maker'),
    time: readInstant(json, 'time'),
  );
}

List<FuturesTrade> decodeFuturesTrades(Object? body) => [
  for (final item in _list(body, 'futures trades')) decodeFuturesTrade(item),
];

MarginChange decodeMarginChange(Object? body) {
  final json = asJsonObject(body, 'margin change');
  return MarginChange(
    symbol: readString(json, 'symbol'),
    added: switch (_int(json, 'type')) {
      1 => true,
      2 => false,
      _ => throw const DecodeException('type'),
    },
    amount: _decimal(json, 'amount'),
    positionSide: PositionSide.decode(readString(json, 'positionSide')),
    time: readInstant(json, 'time'),
    isolatedWallet: _optionalDecimal(json, 'isolatedWallet'),
  );
}

List<MarginChange> decodeMarginChanges(Object? body) => [
  for (final item in _list(body, 'margin history')) decodeMarginChange(item),
];
