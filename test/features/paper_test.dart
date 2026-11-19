import 'dart:math';

import 'package:cryptopilot_mobile/core/errors/api_failure.dart';
import 'package:cryptopilot_mobile/core/json/json_read.dart';
import 'package:cryptopilot_mobile/features/paper/domain/paper.dart';
import 'package:cryptopilot_mobile/features/paper/domain/paper_refusal.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

/// `OrderResponse` as backend develop 5c2398cb writes it.
Map<String, Object?> orderJson({
  String type = 'LIMIT',
  String status = 'NEW',
  Object? price = '76000.00000000',
  String? listId,
}) => {
  'orderId': '0193-order',
  'clientOrderId': 'c-1',
  'pairId': 'pair-BTC',
  'symbol': 'BTCUSDT',
  'market': 'SPOT',
  'side': 'BUY',
  'type': type,
  'timeInForce': 'GTC',
  'price': price,
  'quantity': '0.01000000',
  'quoteOrderQty': null,
  'executedQuantity': '0.00000000',
  'cumQuote': '0.00000000',
  'avgPrice': null,
  'status': status,
  'statusReason': null,
  'placedAt': '2026-11-19T02:00:00Z',
  'closedAt': null,
  'stopPrice': null,
  'trailingDelta': null,
  'triggeredAt': null,
  'listId': listId,
};

ProblemFailure refusal(String code, String messageCode, List<String> args) =>
    problem(400, code, messageCode, args: args);

void main() {
  group('paper decoders (backend develop 5c2398cb)', () {
    test('an order; an open status; a group id', () {
      final order = decodeOrder(orderJson(listId: 'list-1'));
      expect(order.type, SpotOrderType.limit);
      expect(order.status.open, isTrue);
      expect(order.price, '76000.00000000');
      expect(order.listId, 'list-1');
      expect(decodeOrder(orderJson(status: 'FILLED')).status.open, isFalse);
    });

    test('a wallet with an unvalued coin; a balance push', () {
      final wallet = decodeWallet({
        'wallet': 'SPOT',
        'balances': [
          {
            'coinId': 'c',
            'asset': 'USDT',
            'free': '9000.00000000',
            'locked': '1000.00000000',
            'total': '10000.00000000',
            'usdtValue': '10000.00000000',
          },
          {
            'coinId': 'd',
            'asset': 'XYZ',
            'free': '1',
            'locked': '0',
            'total': '1',
            'usdtValue': null,
          },
        ],
        'estimatedUsdt': '10000.00000000',
        'estimatedBtc': '0.13',
        'complete': false,
      });
      expect(wallet.of('USDT')!.free, '9000.00000000');
      expect(wallet.of('XYZ')!.usdtValue, isNull);
      expect(wallet.complete, isFalse);

      final update = decodeBalanceUpdate({
        'wallet': 'SPOT',
        'coinId': 'c',
        'asset': 'BTC',
        'free': '0.11',
        'locked': '0',
        'total': '0.11',
      });
      expect(update.asset, 'BTC');
    });

    test('pages of fills, ledger entries and transfers', () {
      final fills = decodePaperPage({
        'items': [
          {
            'fillId': 'f',
            'orderId': 'o',
            'pairId': 'p',
            'symbol': 'BTCUSDT',
            'market': 'SPOT',
            'side': 'SELL',
            'price': '76000',
            'quantity': '0.01',
            'quoteAmount': '760',
            'fee': '0.76',
            'feeAsset': 'USDT',
            'liquidity': 'TAKER',
            'source': 'LIVE',
            'tradedAt': '2026-11-19T02:00:00Z',
          },
        ],
        'page': 1,
        'pageSize': 20,
        'total': 1,
      }, decodeFill);
      expect(fills.items.single.side, OrderSide.sell);

      final ledger = decodeLedgerEntry({
        'entryId': 'e',
        'wallet': 'FUTURES',
        'asset': 'USDT',
        'type': 'TRANSFER',
        'amount': '-50',
        'balanceAfter': '4950',
        'refType': 'TRANSFER',
        'refId': 't',
        'createdAt': '2026-11-19T02:00:00Z',
      });
      expect(ledger.type, LedgerType.transfer);
      expect(ledger.amount, '-50');

      final transfer = decodeTransfer({
        'transferId': 't',
        'clientTransferId': 'k',
        'asset': 'USDT',
        'from': 'SPOT',
        'to': 'FUTURES',
        'amount': '50',
        'transferredAt': '2026-11-19T02:00:00Z',
      });
      expect(transfer.to, PaperWallet.futures);
      expect(
        decodeAccount({'openedAt': '2026-11-19T01:00:00Z'}),
        DateTime.utc(2026, 11, 19, 1),
      );
    });

    test('a number where a decimal string is due, or an unknown type, is '
        'refused', () {
      expect(
        () => decodeOrder(orderJson(price: 76000)),
        throwsA(isA<DecodeException>()),
      );
      expect(
        () => decodeOrder(orderJson(type: 'ICEBERG')),
        throwsA(isA<DecodeException>()),
      );
    });
  });

  group('requests', () {
    test('a limit is GTC; a market by total sends quoteOrderQty only', () {
      final limit = const SpotOrderRequest(
        pairId: 'p',
        side: OrderSide.buy,
        type: SpotOrderType.limit,
        price: '76000',
        quantity: '0.01',
        clientOrderId: 'k',
      ).toJson();
      expect(limit['timeInForce'], 'GTC');
      expect(limit['market'], 'SPOT');

      final market = const SpotOrderRequest(
        pairId: 'p',
        side: OrderSide.buy,
        type: SpotOrderType.market,
        quoteOrderQty: '100',
        clientOrderId: 'k',
      ).toJson();
      expect(market.containsKey('timeInForce'), isFalse);
      expect(market.containsKey('quantity'), isFalse);
      expect(market['quoteOrderQty'], '100');
    });

    test('an OCO sends its legs; a limit with TP/SL works the other side '
        'first', () {
      final oco = const SpotOrderListRequest(
        pairId: 'p',
        side: OrderSide.sell,
        quantity: '0.01',
        takeProfitPrice: '80000',
        stopPrice: '70000',
        stopLimitPrice: '69900',
        listClientOrderId: 'k',
      ).toJson();
      expect(oco['type'], 'OCO');
      expect(oco.containsKey('working'), isFalse);
      expect((oco['oco']! as Map)['stopLimitPrice'], '69900');

      final otoco = const SpotOrderListRequest(
        pairId: 'p',
        side: OrderSide.sell,
        takeProfitPrice: '80000',
        stopPrice: '70000',
        workingPrice: '75000',
        workingQuantity: '0.01',
        listClientOrderId: 'k',
      ).toJson();
      expect(otoco['type'], 'OTOCO');
      expect((otoco['working']! as Map)['side'], 'BUY');
      expect((otoco['oco']! as Map).containsKey('quantity'), isFalse);
    });

    test('client ids are UUID v4 and fit the server pattern', () {
      final id = newClientId(Random(1));
      expect(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-'
          r'[0-9a-f]{12}$',
        ).hasMatch(id),
        isTrue,
      );
      expect(RegExp(r'^[A-Za-z0-9._:-]{1,64}$').hasMatch(id), isTrue);
      expect(newClientId(), isNot(newClientId()));
    });
  });

  group('refusals by code (plan 9.8)', () {
    test('a filter names its field, limit and bound', () {
      final step = paperRefusal(
        refusal('PAPER_PRICE_FILTER', 'MSG15', [
          'price',
          '1.005',
          '0.01',
          'STEP',
        ]),
      )!;
      expect(step.kind, RefusalKind.step);
      expect(step.field, 'price');
      expect(step.limit, '0.01');

      expect(
        paperRefusal(
          refusal('PAPER_LOT_SIZE', 'MSG15', [
            'quantity',
            '0',
            '0.00001',
            'MIN',
          ]),
        )!.kind,
        RefusalKind.atLeast,
      );
      expect(
        paperRefusal(
          refusal('PAPER_NOTIONAL', 'MSG15', ['quantity', '1', '5', 'MIN']),
        )!.kind,
        RefusalKind.minNotional,
      );
      expect(
        paperRefusal(
          refusal('PAPER_PERCENT_PRICE', 'MSG15', ['price', '1', '9', 'MAX']),
        )!.kind,
        RefusalKind.percentAbove,
      );
    });

    test('balance, finished order and limits; anything else is not one', () {
      final balance = paperRefusal(
        refusal('PAPER_INSUFFICIENT_BALANCE', 'MSG01', ['USDT', '760', '10']),
      )!;
      expect(balance.kind, RefusalKind.insufficientBalance);
      expect(balance.asset, 'USDT');
      expect(balance.limit, '760');
      expect(
        paperRefusal(problem(409, 'PAPER_ORDER_NOT_OPEN', 'MSG43'))!.kind,
        RefusalKind.orderNotOpen,
      );
      expect(
        paperRefusal(
          problem(
            409,
            'PAPER_MAX_NUM_ORDERS',
            'MSG43',
            args: ['orders', '200', '200', 'MAX'],
          ),
        )!.limit,
        '200',
      );
      expect(paperRefusal(problem(503, 'UNAVAILABLE', 'MSG43')), isNull);
      expect(paperRefusal(const NetworkFailure()), isNull);
    });
  });
}
