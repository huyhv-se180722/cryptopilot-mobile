import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/json/json_read.dart';

/// The paper exchange of D-86 (`/api/v1/paper`, checked on backend develop
/// 5c2398cb). Virtual funds only; amounts and prices stay decimal strings.

enum PaperWallet {
  spot('SPOT'),
  futures('FUTURES');

  const PaperWallet(this.wire);
  final String wire;
  static PaperWallet decode(String v) =>
      _decode(values, v, (e) => e.wire, 'wallet');
}

enum OrderSide {
  buy('BUY'),
  sell('SELL');

  const OrderSide(this.wire);
  final String wire;
  static OrderSide decode(String v) =>
      _decode(values, v, (e) => e.wire, 'side');
}

/// The Spot order types the backend takes (`OrderType`, Spot part).
enum SpotOrderType {
  market('MARKET'),
  limit('LIMIT'),
  limitMaker('LIMIT_MAKER'),
  stopLoss('STOP_LOSS'),
  stopLossLimit('STOP_LOSS_LIMIT'),
  takeProfit('TAKE_PROFIT'),
  takeProfitLimit('TAKE_PROFIT_LIMIT'),
  stop('STOP'),
  stopMarket('STOP_MARKET'),
  takeProfitMarket('TAKE_PROFIT_MARKET'),
  trailingStopMarket('TRAILING_STOP_MARKET');

  const SpotOrderType(this.wire);
  final String wire;
  static SpotOrderType decode(String v) =>
      _decode(values, v, (e) => e.wire, 'order type');
}

enum OrderStatus {
  newOrder('NEW'),
  pendingNew('PENDING_NEW'),
  partiallyFilled('PARTIALLY_FILLED'),
  filled('FILLED'),
  canceled('CANCELED'),
  expired('EXPIRED'),
  rejected('REJECTED');

  const OrderStatus(this.wire);
  final String wire;
  static OrderStatus decode(String v) =>
      _decode(values, v, (e) => e.wire, 'order status');

  /// Still on the book or waiting for its trigger.
  bool get open =>
      this == newOrder || this == pendingNew || this == partiallyFilled;
}

enum LedgerType {
  initialGrant('INITIAL_GRANT'),
  trade('TRADE'),
  fee('FEE'),
  realizedPnl('REALIZED_PNL'),
  fundingFee('FUNDING_FEE'),
  transfer('TRANSFER'),
  liquidationFee('LIQUIDATION_FEE'),
  insuranceCover('INSURANCE_COVER');

  const LedgerType(this.wire);
  final String wire;
  static LedgerType decode(String v) =>
      _decode(values, v, (e) => e.wire, 'ledger type');
}

T _decode<T>(
  List<T> values,
  String value,
  String Function(T) wire,
  String what,
) => values.firstWhere(
  (e) => wire(e) == value,
  orElse: () => throw DecodeException('$what $value is unknown'),
);

/// A key the server uses to answer a request sent again with the same one
/// (`clientOrderId`, `listClientOrderId`, `clientTransferId`): a UUID v4.
String newClientId([Random? random]) {
  final r = random ?? Random.secure();
  final bytes = [for (var i = 0; i < 16; i++) r.nextInt(256)];
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = [
    for (final b in bytes) b.toRadixString(16).padLeft(2, '0'),
  ].join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

@immutable
class Balance {
  const Balance({
    required this.asset,
    required this.free,
    required this.locked,
    required this.total,
    this.usdtValue,
  });

  final String asset;
  final String free;
  final String locked;
  final String total;

  /// Null when the coin has no USDT price.
  final String? usdtValue;
}

@immutable
class Wallet {
  const Wallet({
    required this.wallet,
    required this.balances,
    required this.estimatedUsdt,
    required this.complete,
  });

  final PaperWallet wallet;
  final List<Balance> balances;
  final String estimatedUsdt;

  /// False when a coin could not be valued: the estimate leaves it out.
  final bool complete;

  Balance? of(String asset) =>
      balances.where((b) => b.asset == asset).firstOrNull;
}

/// One coin of a wallet as a change left it (`/user/queue/balances`).
@immutable
class BalanceUpdate {
  const BalanceUpdate({
    required this.wallet,
    required this.asset,
    required this.free,
    required this.locked,
    required this.total,
  });

  final PaperWallet wallet;
  final String asset;
  final String free;
  final String locked;
  final String total;
}

@immutable
class PaperOrder {
  const PaperOrder({
    required this.orderId,
    required this.pairId,
    required this.symbol,
    required this.side,
    required this.type,
    required this.executedQuantity,
    required this.cumQuote,
    required this.status,
    required this.placedAt,
    this.clientOrderId,
    this.price,
    this.quantity,
    this.quoteOrderQty,
    this.avgPrice,
    this.stopPrice,
    this.statusReason,
    this.listId,
  });

  final String orderId;
  final String? clientOrderId;
  final String pairId;
  final String symbol;
  final OrderSide side;
  final SpotOrderType type;
  final String? price;
  final String? quantity;
  final String? quoteOrderQty;
  final String executedQuantity;
  final String cumQuote;
  final String? avgPrice;
  final OrderStatus status;
  final String? statusReason;
  final DateTime placedAt;
  final String? stopPrice;

  /// The group (OCO, OTOCO) the order belongs to; cancelling one cancels it.
  final String? listId;
}

@immutable
class PaperFill {
  const PaperFill({
    required this.fillId,
    required this.orderId,
    required this.symbol,
    required this.side,
    required this.price,
    required this.quantity,
    required this.quoteAmount,
    required this.fee,
    required this.feeAsset,
    required this.tradedAt,
  });

  final String fillId;
  final String orderId;
  final String symbol;
  final OrderSide side;
  final String price;
  final String quantity;
  final String quoteAmount;
  final String fee;
  final String feeAsset;
  final DateTime tradedAt;
}

@immutable
class LedgerEntry {
  const LedgerEntry({
    required this.entryId,
    required this.wallet,
    required this.asset,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    required this.createdAt,
  });

  final String entryId;
  final PaperWallet wallet;
  final String asset;
  final LedgerType type;

  /// Signed: negative when it took from the balance.
  final String amount;
  final String balanceAfter;
  final DateTime createdAt;
}

@immutable
class Transfer {
  const Transfer({
    required this.transferId,
    required this.asset,
    required this.from,
    required this.to,
    required this.amount,
    required this.transferredAt,
  });

  final String transferId;
  final String asset;
  final PaperWallet from;
  final PaperWallet to;
  final String amount;
  final DateTime transferredAt;
}

/// A page of a paper history (`PageResponse`).
@immutable
class PaperPage<T> {
  const PaperPage({
    required this.items,
    required this.page,
    required this.total,
  });

  final List<T> items;
  final int page;
  final int total;
}

/// A Spot order to place (`PlaceOrderRequest`); null fields are left out.
@immutable
class SpotOrderRequest {
  const SpotOrderRequest({
    required this.pairId,
    required this.side,
    required this.type,
    required this.clientOrderId,
    this.price,
    this.quantity,
    this.quoteOrderQty,
    this.stopPrice,
  });

  final String pairId;
  final OrderSide side;
  final SpotOrderType type;
  final String? price;
  final String? quantity;

  /// Market by total: what a Buy spends or a Sell receives.
  final String? quoteOrderQty;
  final String? stopPrice;
  final String clientOrderId;

  Map<String, Object?> toJson() => {
    'pairId': pairId,
    'market': 'SPOT',
    'side': side.wire,
    'type': type.wire,
    if (type == SpotOrderType.limit ||
        type == SpotOrderType.stopLossLimit ||
        type == SpotOrderType.takeProfitLimit)
      'timeInForce': 'GTC',
    'price': ?price,
    'quantity': ?quantity,
    'quoteOrderQty': ?quoteOrderQty,
    'stopPrice': ?stopPrice,
    'clientOrderId': clientOrderId,
  };
}

/// An OCO, or a Limit with TP/SL (OTOCO), to place (`PlaceOrderListRequest`).
@immutable
class SpotOrderListRequest {
  const SpotOrderListRequest({
    required this.pairId,
    required this.side,
    required this.takeProfitPrice,
    required this.stopPrice,
    required this.listClientOrderId,
    this.quantity,
    this.stopLimitPrice,
    this.workingPrice,
    this.workingQuantity,
  });

  final String pairId;

  /// The side of the OCO legs; a Limit with TP/SL buys with the opposite.
  final OrderSide side;
  final String? quantity;
  final String takeProfitPrice;
  final String stopPrice;

  /// Absent: the stop is a STOP_LOSS that sells at market when triggered.
  final String? stopLimitPrice;

  /// Set for an OTOCO: the limit placed now, the OCO once it filled.
  final String? workingPrice;
  final String? workingQuantity;
  final String listClientOrderId;

  bool get otoco => workingPrice != null;

  Map<String, Object?> toJson() => {
    'pairId': pairId,
    'market': 'SPOT',
    'type': otoco ? 'OTOCO' : 'OCO',
    if (otoco)
      'working': {
        'side': (side == OrderSide.sell ? OrderSide.buy : OrderSide.sell).wire,
        'type': 'LIMIT',
        'price': workingPrice,
        'quantity': workingQuantity,
      },
    'oco': {
      'side': side.wire,
      'quantity': ?quantity,
      'takeProfitPrice': takeProfitPrice,
      'stopPrice': stopPrice,
      'stopLimitPrice': ?stopLimitPrice,
    },
    'listClientOrderId': listClientOrderId,
  };
}

int _readInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw DecodeException('$key is not a whole number');
}

List<Object?> _readList(Object? value, String what) {
  if (value is List) return value;
  throw DecodeException('$what is not a list');
}

/// A decimal string; refuses a JSON number (the backend writes strings).
String _decimal(Map<String, Object?> json, String key) {
  final text = readString(json, key);
  if (num.tryParse(text) == null) {
    throw DecodeException('$key is not a decimal');
  }
  return text;
}

String? _optionalDecimal(Map<String, Object?> json, String key) =>
    json[key] == null ? null : _decimal(json, key);

DateTime? _optionalInstant(Map<String, Object?> json, String key) =>
    json[key] == null ? null : readInstant(json, key);

Balance decodeBalance(Object? body) {
  final json = asJsonObject(body, 'balance');
  return Balance(
    asset: readString(json, 'asset'),
    free: _decimal(json, 'free'),
    locked: _decimal(json, 'locked'),
    total: _decimal(json, 'total'),
    usdtValue: _optionalDecimal(json, 'usdtValue'),
  );
}

Wallet decodeWallet(Object? body) {
  final json = asJsonObject(body, 'wallet');
  return Wallet(
    wallet: PaperWallet.decode(readString(json, 'wallet')),
    balances: [
      for (final item in _readList(json['balances'], 'balances'))
        decodeBalance(item),
    ],
    estimatedUsdt: _decimal(json, 'estimatedUsdt'),
    complete: readBool(json, 'complete'),
  );
}

BalanceUpdate decodeBalanceUpdate(Object? body) {
  final json = asJsonObject(body, 'balance update');
  return BalanceUpdate(
    wallet: PaperWallet.decode(readString(json, 'wallet')),
    asset: readString(json, 'asset'),
    free: _decimal(json, 'free'),
    locked: _decimal(json, 'locked'),
    total: _decimal(json, 'total'),
  );
}

PaperOrder decodeOrder(Object? body) {
  final json = asJsonObject(body, 'order');
  return PaperOrder(
    orderId: readString(json, 'orderId'),
    clientOrderId: readOptionalString(json, 'clientOrderId'),
    pairId: readString(json, 'pairId'),
    symbol: readString(json, 'symbol'),
    side: OrderSide.decode(readString(json, 'side')),
    type: SpotOrderType.decode(readString(json, 'type')),
    price: _optionalDecimal(json, 'price'),
    quantity: _optionalDecimal(json, 'quantity'),
    quoteOrderQty: _optionalDecimal(json, 'quoteOrderQty'),
    executedQuantity: _decimal(json, 'executedQuantity'),
    cumQuote: _decimal(json, 'cumQuote'),
    avgPrice: _optionalDecimal(json, 'avgPrice'),
    status: OrderStatus.decode(readString(json, 'status')),
    statusReason: readOptionalString(json, 'statusReason'),
    placedAt: readInstant(json, 'placedAt'),
    stopPrice: _optionalDecimal(json, 'stopPrice'),
    listId: readOptionalString(json, 'listId'),
  );
}

List<PaperOrder> decodeOrders(Object? body) => [
  for (final item in _readList(body, 'orders')) decodeOrder(item),
];

/// The orders of a placed or cancelled group.
List<PaperOrder> decodeOrderList(Object? body) {
  final json = asJsonObject(body, 'order list');
  readString(json, 'listId');
  return decodeOrders(json['orders']);
}

PaperFill decodeFill(Object? body) {
  final json = asJsonObject(body, 'fill');
  return PaperFill(
    fillId: readString(json, 'fillId'),
    orderId: readString(json, 'orderId'),
    symbol: readString(json, 'symbol'),
    side: OrderSide.decode(readString(json, 'side')),
    price: _decimal(json, 'price'),
    quantity: _decimal(json, 'quantity'),
    quoteAmount: _decimal(json, 'quoteAmount'),
    fee: _decimal(json, 'fee'),
    feeAsset: readString(json, 'feeAsset'),
    tradedAt: readInstant(json, 'tradedAt'),
  );
}

LedgerEntry decodeLedgerEntry(Object? body) {
  final json = asJsonObject(body, 'ledger entry');
  return LedgerEntry(
    entryId: readString(json, 'entryId'),
    wallet: PaperWallet.decode(readString(json, 'wallet')),
    asset: readString(json, 'asset'),
    type: LedgerType.decode(readString(json, 'type')),
    amount: _decimal(json, 'amount'),
    balanceAfter: _decimal(json, 'balanceAfter'),
    createdAt: readInstant(json, 'createdAt'),
  );
}

Transfer decodeTransfer(Object? body) {
  final json = asJsonObject(body, 'transfer');
  return Transfer(
    transferId: readString(json, 'transferId'),
    asset: readString(json, 'asset'),
    from: PaperWallet.decode(readString(json, 'from')),
    to: PaperWallet.decode(readString(json, 'to')),
    amount: _decimal(json, 'amount'),
    transferredAt: readInstant(json, 'transferredAt'),
  );
}

PaperPage<T> decodePaperPage<T>(Object? body, T Function(Object?) item) {
  final json = asJsonObject(body, 'page');
  return PaperPage(
    items: [for (final i in _readList(json['items'], 'items')) item(i)],
    page: _readInt(json, 'page'),
    total: _readInt(json, 'total'),
  );
}

/// The demo account's worth (`EquityResponse`; the daily history is left
/// for T-123).
@immutable
class PaperEquity {
  const PaperEquity({
    required this.totalEquity,
    required this.todayPnl,
    this.todayPnlPercent,
  });

  final String totalEquity;
  final String todayPnl;
  final String? todayPnlPercent;
}

PaperEquity decodeEquity(Object? body) {
  final json = asJsonObject(body, 'equity');
  return PaperEquity(
    totalEquity: _decimal(json, 'totalEquity'),
    todayPnl: _decimal(json, 'todayPnl'),
    todayPnlPercent: _optionalDecimal(json, 'todayPnlPercent'),
  );
}

/// When the account was opened (`PaperAccountResponse`).
DateTime decodeAccount(Object? body) {
  final json = asJsonObject(body, 'paper account');
  return _optionalInstant(json, 'openedAt') ??
      (throw const DecodeException('openedAt is missing'));
}
