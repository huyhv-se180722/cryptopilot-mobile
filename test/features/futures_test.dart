import 'package:cryptopilot_mobile/core/json/json_read.dart';
import 'package:cryptopilot_mobile/features/paper/domain/futures.dart';
import 'package:cryptopilot_mobile/features/paper/domain/paper.dart';
import 'package:cryptopilot_mobile/features/paper/domain/paper_refusal.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

Map<String, Object?> positionJson({
  String amount = '0.010',
  String side = 'BOTH',
}) => {
  'symbol': 'BTCUSDT',
  'positionSide': side,
  'positionAmt': amount,
  'entryPrice': '76000.00',
  'breakEvenPrice': '76030.40',
  'markPrice': '76100.00',
  'unRealizedProfit': '1.00000000',
  'liquidationPrice': '61000.00',
  'isolatedMargin': '0',
  'notional': '761.00',
  'marginAsset': 'USDT',
  'isolatedWallet': '0',
  'initialMargin': '38.05',
  'maintMargin': '3.04',
  'positionInitialMargin': '38.05',
  'openOrderInitialMargin': '0',
  'bidNotional': '0',
  'askNotional': '0',
  'marginType': 'CROSSED',
  'marginRatio': '0.0040',
  'updateTime': '2026-11-19T02:00:00Z',
};

void main() {
  group('Futures decoders (backend develop 5c2398cb)', () {
    test('positions: a flat side is left out; a short is signed', () {
      final positions = decodePositions([
        positionJson(),
        positionJson(amount: '0.000', side: 'BOTH'),
        positionJson(amount: '-0.020'),
      ]);
      expect(positions, hasLength(2));
      expect(positions.first.short, isFalse);
      expect(positions.last.short, isTrue);
      expect(positions.last.size, '0.020');
      expect(positions.first.liquidationPrice, '61000.00');
    });

    test('the account, the leverage bracket and a symbol config', () {
      final account = decodeFuturesAccount({
        'totalInitialMargin': '0',
        'totalMaintMargin': '0',
        'totalWalletBalance': '5000.00',
        'totalUnrealizedProfit': '1.00',
        'totalMarginBalance': '5001.00',
        'totalPositionInitialMargin': '0',
        'totalOpenOrderInitialMargin': '0',
        'totalCrossWalletBalance': '5000',
        'totalCrossUnPnl': '1',
        'availableBalance': '4960.00',
        'maxWithdrawAmount': '4960.00',
        'marginRatio': '0',
        'assets': <Object?>[],
        'positions': <Object?>[],
      });
      expect(account.availableBalance, '4960.00');
      expect(
        maxLeverageOf({
          'symbol': 'BTCUSDT',
          'notionalCoef': '1',
          'brackets': [
            {
              'bracket': 1,
              'initialLeverage': 125,
              'notionalCap': '50000',
              'notionalFloor': '0',
              'maintMarginRatio': '0.004',
              'cum': '0',
            },
            {
              'bracket': 2,
              'initialLeverage': 100,
              'notionalCap': '250000',
              'notionalFloor': '50000',
              'maintMarginRatio': '0.005',
              'cum': '50',
            },
          ],
        }),
        125,
      );
      final config = decodeSymbolConfig({
        'symbol': 'BTCUSDT',
        'marginType': 'ISOLATED',
        'isAutoAddMargin': false,
        'leverage': 20,
        'maxNotionalValue': '1000000',
      });
      expect(config.marginType, MarginType.isolated);
      expect(config.leverage, 20);
    });

    test('warnings: a BLOCKING one stops the order', () {
      final warnings = decodeWarnings({
        'cost': '38.05',
        'budget': '4960',
        'liquidationPrice': '61000',
        'warnings': [
          {
            'type': 'HIGH_LEVERAGE',
            'severity': 'WARNING',
            'message': 'Leverage 50x is high.',
          },
          {
            'type': 'INSUFFICIENT_MARGIN',
            'severity': 'BLOCKING',
            'message': 'Not enough margin.',
          },
        ],
      });
      expect(warnings.blocked, isTrue);
      expect(warnings.cost, '38.05');
      expect(
        () => decodeWarnings({
          'warnings': [
            {'type': 'X', 'severity': 'LOUD', 'message': 'm'},
          ],
        }),
        throwsA(isA<DecodeException>()),
      );
    });

    test('a margin call', () {
      final call = decodeMarginCall({
        'symbol': 'BTCUSDT',
        'positionSide': 'BOTH',
        'marginType': 'CROSSED',
        'markPrice': '62000',
        'marginRatio': '0.81',
        'maintenanceMargin': '3',
        'marginBalance': '3.7',
        'eventTime': '2026-11-19T02:00:00Z',
      });
      expect(call.marginRatio, '0.81');
    });
  });

  group('Futures requests', () {
    test('a limit is GTC; TP/SL carry their working type; reduce-only when '
        'asked', () {
      final json = const FuturesOrderRequest(
        symbol: 'BTCUSDT',
        side: OrderSide.buy,
        type: 'LIMIT',
        quantity: '0.010',
        price: '75000.0',
        takeProfitPrice: '80000.0',
        stopLossPrice: '72000.0',
        tpSlWorking: WorkingType.mark,
        clientOrderId: 'k',
      ).toJson();
      expect(json['timeInForce'], 'GTC');
      expect(json['tpSlWorkingType'], 'MARK_PRICE');
      expect(json.containsKey('reduceOnly'), isFalse);
      expect(json['newClientOrderId'], 'k');

      final close = const FuturesOrderRequest(
        symbol: 'BTCUSDT',
        side: OrderSide.sell,
        type: 'MARKET',
        quantity: '0.010',
        reduceOnly: true,
        clientOrderId: 'k',
      ).toJson();
      expect(close['reduceOnly'], isTrue);
      expect(close.containsKey('tpSlWorkingType'), isFalse);
    });

    test('a conditional order is CONDITIONAL on Mark or Last', () {
      final json = const AlgoOrderRequest(
        symbol: 'BTCUSDT',
        side: OrderSide.sell,
        type: 'STOP_MARKET',
        triggerPrice: '72000.0',
        working: WorkingType.mark,
        closePosition: true,
        clientAlgoId: 'k',
      ).toJson();
      expect(json['algoType'], 'CONDITIONAL');
      expect(json['workingType'], 'MARK_PRICE');
      expect(json['closePosition'], isTrue);
      expect(json.containsKey('timeInForce'), isFalse);
    });
  });

  test('Futures refusals by code', () {
    expect(
      paperRefusal(problem(400, 'PAPER_INSUFFICIENT_MARGIN', 'MSG01'))!.kind,
      RefusalKind.insufficientMargin,
    );
    expect(
      paperRefusal(problem(409, 'PAPER_REDUCE_ONLY_REJECTED', 'MSG43'))!.kind,
      RefusalKind.reduceOnlyRejected,
    );
    final leverage = paperRefusal(
      problem(
        400,
        'PAPER_LEVERAGE',
        'MSG15',
        args: ['leverage', '150', '125', 'MAX'],
      ),
    )!;
    expect(leverage.kind, RefusalKind.atMost);
    expect(leverage.field, 'leverage');
  });
}
