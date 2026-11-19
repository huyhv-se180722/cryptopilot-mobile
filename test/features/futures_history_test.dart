import 'package:cryptopilot_mobile/core/json/json_read.dart';
import 'package:cryptopilot_mobile/features/paper/domain/futures.dart';
import 'package:cryptopilot_mobile/features/paper/domain/futures_history.dart';
import 'package:cryptopilot_mobile/features/paper/domain/paper.dart';
import 'package:flutter_test/flutter_test.dart';

/// T-123: the Futures histories as backend develop 5c2398cb sends them.
void main() {
  test('income: signed, a transfer without a pair, an unknown type kept', () {
    final lines = decodeIncomes([
      {
        'symbol': 'BTCUSDT',
        'incomeType': 'REALIZED_PNL',
        'income': '-1.25000000',
        'asset': 'USDT',
        'info': 'FUTURES_REALIZED_PNL',
        'time': '2026-11-19T02:00:00Z',
        'tranId': 'a1',
        'tradeId': 't1',
      },
      {
        'symbol': '',
        'incomeType': 'TRANSFER',
        'income': '100',
        'asset': 'USDT',
        'info': null,
        'time': '2026-11-19T01:00:00Z',
        'tranId': 'a2',
        'tradeId': null,
      },
      {
        'symbol': 'BTCUSDT',
        'incomeType': 'SOMETHING_NEW',
        'income': '0',
        'asset': 'USDT',
        'info': null,
        'time': '2026-11-19T00:00:00Z',
        'tranId': 'a3',
        'tradeId': null,
      },
    ]);
    expect(lines.first.type, IncomeType.realizedPnl);
    expect(lines.first.income, '-1.25000000');
    expect(lines[1].symbol, isNull);
    expect(lines[1].type, IncomeType.transfer);
    expect(lines[2].type, isNull);
    expect(lines[2].typeWire, 'SOMETHING_NEW');
    expect(
      () => decodeIncome({'incomeType': 'X', 'time': 'x'}),
      throwsA(isA<DecodeException>()),
    );
  });

  test('a closed position, a fill and a margin change', () {
    final closed = decodeClosedPosition({
      'positionId': 'p1',
      'symbol': 'BTCUSDT',
      'positionSide': 'BOTH',
      'direction': 'SHORT',
      'marginType': 'ISOLATED',
      'leverage': 10,
      'maxQuantity': '0.020',
      'closedQuantity': '0.020',
      'entryPrice': '76000',
      'avgClosePrice': '75000',
      'realizedPnl': '20',
      'fundingFee': '-0.5',
      'liquidationFee': '0',
      'netProfit': '19.5',
      'closeReason': 'MANUAL',
      'openTime': '2026-11-18T02:00:00Z',
      'closeTime': '2026-11-19T02:00:00Z',
    });
    expect(closed.long, isFalse);
    expect(closed.leverage, 10);
    expect(closed.marginType, MarginType.isolated);
    expect(closed.netProfit, '19.5');

    final fill = decodeFuturesTrade({
      'id': 'f1',
      'orderId': 'o1',
      'symbol': 'BTCUSDT',
      'side': 'SELL',
      'positionSide': 'BOTH',
      'price': '75000',
      'qty': '0.010',
      'quoteQty': '750',
      'realizedPnl': '10',
      'commission': '0',
      'commissionAsset': 'USDT',
      'maker': false,
      'buyer': false,
      'positionId': 'p1',
      'time': '2026-11-19T02:00:00Z',
      'sourceTime': null,
    });
    expect(fill.side, OrderSide.sell);
    expect(fill.maker, isFalse);

    final change = decodeMarginChange({
      'symbol': 'BTCUSDT',
      'type': 2,
      'deltaType': 'USER_ADJUST',
      'amount': '5',
      'asset': 'USDT',
      'positionSide': 'BOTH',
      'isolatedWallet': '33',
      'time': '2026-11-19T02:00:00Z',
    });
    expect(change.added, isFalse);
    expect(change.isolatedWallet, '33');
    expect(
      () => decodeMarginChange({
        'symbol': 'BTCUSDT',
        'type': 3,
        'amount': '5',
        'positionSide': 'BOTH',
        'time': '2026-11-19T02:00:00Z',
      }),
      throwsA(isA<DecodeException>()),
    );
  });
}
