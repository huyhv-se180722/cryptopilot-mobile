import 'package:cryptopilot_mobile/core/json/json_read.dart';
import 'package:cryptopilot_mobile/features/paper/domain/futures.dart';
import 'package:flutter_test/flutter_test.dart';

import 'futures_test.dart' show positionJson;

Map<String, Object?> algoJson({
  String type = 'STOP_MARKET',
  String positionSide = 'BOTH',
  Object? closePosition = true,
  Object? reduceOnly = false,
}) => {
  'algoId': 'a-1',
  'clientAlgoId': 'k-1',
  'algoType': 'CONDITIONAL',
  'orderType': type,
  'symbol': 'BTCUSDT',
  'side': 'SELL',
  'positionSide': positionSide,
  'timeInForce': 'GTC',
  'quantity': '0',
  'algoStatus': 'NEW',
  'triggerPrice': '72000.00',
  'price': null,
  'workingType': 'MARK_PRICE',
  'closePosition': closePosition,
  'priceProtect': false,
  'reduceOnly': reduceOnly,
  'createTime': '2026-11-19T02:00:00Z',
};

/// T-131: the fields the Futures form and the position card add
/// (backend develop 5c2398cb).
void main() {
  test('a position: its leverage, initial margin and ROE in percent', () {
    final position = decodePosition({
      ...positionJson(),
      'leverage': 20,
      'positionInitialMargin': '38.05',
    });
    expect(position.leverage, 20);
    expect(position.roePercent, '2.63');
    expect(
      () => decodePosition({...positionJson(), 'leverage': '20'}),
      throwsA(isA<DecodeException>()),
    );
    expect(
      decodePosition({
        ...positionJson(),
        'positionInitialMargin': '0',
      }).roePercent,
      isNull,
    );
  });

  test('an algo order tells its side and whether it guards a position', () {
    final position = decodePosition(positionJson());
    final sl = decodeAlgoOrder(algoJson());
    expect(sl.positionSide, PositionSide.both);
    expect(sl.closePosition, isTrue);
    expect(sl.stopLoss && sl.guards(position), isTrue);
    final tp = decodeAlgoOrder(
      algoJson(
        type: 'TAKE_PROFIT_MARKET',
        closePosition: false,
        reduceOnly: true,
      ),
    );
    expect(tp.takeProfit && tp.guards(position), isTrue);
    // An entry stop neither closes nor reduces: not a TP/SL of the position.
    expect(
      decodeAlgoOrder(algoJson(closePosition: false)).guards(position),
      isFalse,
    );
    expect(
      () => decodeAlgoOrder(algoJson(closePosition: 'yes')),
      throwsA(isA<DecodeException>()),
    );
  });

  test('max open: request and answer; warnings carry their budget', () {
    const request = MaxOpenRequest(
      symbol: 'BTCUSDT',
      long: false,
      leverage: 20,
      entryPrice: '75000.00',
      walletBalance: '4900.00',
    );
    expect(request.toJson(), {
      'symbol': 'BTCUSDT',
      'side': 'SHORT',
      'leverage': 20,
      'entryPrice': '75000.00',
      'walletBalance': '4900.00',
    });
    final max = decodeMaxOpen({
      'initialMargin': null,
      'maxQuantity': '1.306',
      'maxNotional': '97950.00',
      'maxPositionAtLeverage': '1000000',
    });
    expect(max.maxQuantity, '1.306');
    expect(max.maxNotional, '97950.00');
    expect(
      () => decodeMaxOpen({'maxQuantity': 1}),
      throwsA(isA<DecodeException>()),
    );
    final warnings = decodeWarnings({
      'cost': '38.00',
      'budget': '4900.00',
      'liquidationPrice': '61000.00',
      'warnings': <Object?>[],
    });
    expect(warnings.budget, '4900.00');
  });
}
