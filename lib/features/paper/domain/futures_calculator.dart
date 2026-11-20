import 'package:flutter/foundation.dart';

import '../../../core/json/json_read.dart';
import 'futures.dart';

/// The five tabs of the Futures calculator (TR-25, T-123); nothing is
/// stored or placed.
enum CalcTab {
  pnl('pnl'),
  target('target'),
  liquidation('liquidation'),
  maxOpen('maxOpen'),
  openPrice('openPrice');

  const CalcTab(this.path);

  /// `POST /paper/futures/calculator/{path}`.
  final String path;
}

/// One part of an open price: a price and a quantity.
@immutable
class CalcLot {
  const CalcLot({required this.price, required this.quantity});

  final String price;
  final String quantity;
}

/// What one tab sends; each tab takes only its fields (the backend's
/// `Futures*CalcRequest` records).
@immutable
class CalcRequest {
  const CalcRequest({
    required this.tab,
    required this.symbol,
    this.long = true,
    this.leverage,
    this.entryPrice,
    this.exitPrice,
    this.quantity,
    this.roe,
    this.marginType = MarginType.crossed,
    this.walletBalance,
    this.lots = const [],
  });

  final CalcTab tab;
  final String symbol;
  final bool long;
  final int? leverage;
  final String? entryPrice;
  final String? exitPrice;
  final String? quantity;

  /// Target: the return on the initial margin in percent, negative a loss.
  final String? roe;
  final MarginType marginType;

  /// Liquidation (required for cross) and max open.
  final String? walletBalance;
  final List<CalcLot> lots;

  Map<String, Object?> toJson() {
    final side = long ? 'LONG' : 'SHORT';
    return switch (tab) {
      CalcTab.pnl => {
        'symbol': symbol,
        'side': side,
        'leverage': leverage,
        'entryPrice': entryPrice,
        'exitPrice': exitPrice,
        'quantity': quantity,
      },
      CalcTab.target => {
        'symbol': symbol,
        'side': side,
        'leverage': leverage,
        'entryPrice': entryPrice,
        'roe': roe,
      },
      CalcTab.liquidation => {
        'symbol': symbol,
        'side': side,
        'marginType': marginType.wire,
        'leverage': leverage,
        'entryPrice': entryPrice,
        'quantity': quantity,
        'walletBalance': ?walletBalance,
      },
      CalcTab.maxOpen => {
        'symbol': symbol,
        'side': side,
        'leverage': leverage,
        'entryPrice': entryPrice,
        'walletBalance': walletBalance,
      },
      CalcTab.openPrice => {
        'symbol': symbol,
        'lots': [
          for (final lot in lots)
            {'price': lot.price, 'quantity': lot.quantity},
        ],
      },
    };
  }
}

/// `FuturesCalculatorResponse`: each tab fills only its own figures.
@immutable
class CalcResult {
  const CalcResult({
    this.initialMargin,
    this.pnl,
    this.roe,
    this.targetPrice,
    this.liquidationPrice,
    this.walletBalance,
    this.maxQuantity,
    this.maxNotional,
    this.maxPositionAtLeverage,
    this.openPrice,
    this.quantity,
  });

  final String? initialMargin;
  final String? pnl;
  final String? roe;

  /// Zero when no price gives the return asked.
  final String? targetPrice;

  /// Zero when no price liquidates it.
  final String? liquidationPrice;
  final String? walletBalance;
  final String? maxQuantity;
  final String? maxNotional;
  final String? maxPositionAtLeverage;
  final String? openPrice;
  final String? quantity;
}

String? _decimal(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String || num.tryParse(value) == null) {
    throw DecodeException('$key is not a decimal');
  }
  return value;
}

CalcResult decodeCalcResult(Object? body) {
  final json = asJsonObject(body, 'calculator');
  return CalcResult(
    initialMargin: _decimal(json, 'initialMargin'),
    pnl: _decimal(json, 'pnl'),
    roe: _decimal(json, 'roe'),
    targetPrice: _decimal(json, 'targetPrice'),
    liquidationPrice: _decimal(json, 'liquidationPrice'),
    walletBalance: _decimal(json, 'walletBalance'),
    maxQuantity: _decimal(json, 'maxQuantity'),
    maxNotional: _decimal(json, 'maxNotional'),
    maxPositionAtLeverage: _decimal(json, 'maxPositionAtLeverage'),
    openPrice: _decimal(json, 'openPrice'),
    quantity: _decimal(json, 'quantity'),
  );
}
