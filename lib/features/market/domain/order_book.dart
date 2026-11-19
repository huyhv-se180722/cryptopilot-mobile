import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';

import '../../../core/json/json_read.dart';

/// One price level: price and base quantity, as decimal strings.
@immutable
class BookLevel {
  const BookLevel(this.price, this.quantity);

  final String price;
  final String quantity;

  @override
  bool operator ==(Object other) =>
      other is BookLevel && other.price == price && other.quantity == quantity;

  @override
  int get hashCode => Object.hash(price, quantity);

  @override
  String toString() => '$price × $quantity';
}

/// The top levels of a pair's book (`DepthResponse`, TR-03): REST first,
/// then `/topic/depth.{M}.{S}` replaces it whole.
@immutable
class DepthSnapshot {
  const DepthSnapshot({required this.bids, required this.asks});

  /// Best (highest) first.
  final List<BookLevel> bids;

  /// Best (lowest) first.
  final List<BookLevel> asks;

  static const empty = DepthSnapshot(bids: [], asks: []);
}

/// A market trade (`MarketTradeResponse`).
@immutable
class MarketTrade {
  const MarketTrade({
    required this.id,
    required this.price,
    required this.quantity,
    required this.time,
    required this.buyerMaker,
  });

  final int id;
  final String price;
  final String quantity;
  final DateTime time;

  /// The seller took the bid: a sell, shown red.
  final bool buyerMaker;
}

List<BookLevel> _levels(Object? value, String what) {
  if (value is! List) throw DecodeException('$what is not a list');
  return [
    for (final level in value)
      if (level is List &&
          level.length >= 2 &&
          level[0] is String &&
          level[1] is String)
        BookLevel(level[0] as String, level[1] as String)
      else
        throw DecodeException('$what holds a level that is not [price, qty]'),
  ];
}

DepthSnapshot decodeDepth(Object? body) {
  final json = asJsonObject(body, 'depth');
  return DepthSnapshot(
    bids: _levels(json['bids'], 'bids'),
    asks: _levels(json['asks'], 'asks'),
  );
}

MarketTrade decodeMarketTrade(Object? body) {
  final json = asJsonObject(body, 'trade');
  final id = json['id'];
  if (id is! int) throw const DecodeException('id is not a whole number');
  return MarketTrade(
    id: id,
    price: readString(json, 'price'),
    quantity: readString(json, 'quantity'),
    time: readInstant(json, 'time'),
    buyerMaker: readBool(json, 'buyerMaker'),
  );
}

/// The trades of a REST answer (newest first) or a push (oldest first).
List<MarketTrade> decodeMarketTrades(Object? body) {
  final json = asJsonObject(body, 'trades');
  final trades = json['trades'];
  if (trades is! List) throw const DecodeException('trades is not a list');
  return [for (final trade in trades) decodeMarketTrade(trade)];
}

/// Levels gathered on multiples of [step] (the order book "tick" choice):
/// bids round down and asks round up, as exchanges show them, quantities
/// summed. Best first, at most [count].
List<BookLevel> groupLevels(
  List<BookLevel> levels,
  String step, {
  required bool bids,
  int count = 7,
}) {
  final size = Decimal.tryParse(step);
  if (size == null || size <= Decimal.zero) return levels.take(count).toList();
  final sums = <Decimal, Decimal>{};
  final order = <Decimal>[];
  for (final level in levels) {
    final price = Decimal.tryParse(level.price);
    final quantity = Decimal.tryParse(level.quantity);
    if (price == null || quantity == null) continue;
    final steps = (price / size).toDecimal(scaleOnInfinitePrecision: 20);
    final rounded = (bids ? steps.floor() : steps.ceil()) * size;
    if (!sums.containsKey(rounded)) order.add(rounded);
    sums[rounded] = (sums[rounded] ?? Decimal.zero) + quantity;
  }
  return [
    for (final price in order.take(count))
      BookLevel(price.toString(), sums[price]!.toString()),
  ];
}

/// The share of bid quantity in the levels shown (the B/S bar), 0 to 1.
double bidShare(List<BookLevel> bids, List<BookLevel> asks) {
  Decimal sum(List<BookLevel> levels) => levels.fold(
    Decimal.zero,
    (total, level) =>
        total + (Decimal.tryParse(level.quantity) ?? Decimal.zero),
  );
  final buy = sum(bids);
  final total = buy + sum(asks);
  if (total == Decimal.zero) return 0.5;
  return (buy / total).toDouble();
}
