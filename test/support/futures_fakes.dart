import 'dart:async';

import 'package:cryptopilot_mobile/features/paper/data/futures_api.dart';
import 'package:cryptopilot_mobile/features/paper/domain/futures.dart';
import 'package:cryptopilot_mobile/features/paper/domain/futures_history.dart';
import 'package:cryptopilot_mobile/features/paper/domain/paper.dart';

FuturesPosition positionOf({
  String symbol = 'BTCUSDT',
  String amount = '0.010',
  PositionSide side = PositionSide.both,
  MarginType marginType = MarginType.crossed,
}) => FuturesPosition(
  symbol: symbol,
  side: side,
  amount: amount,
  entryPrice: '76000.00',
  markPrice: '76100.00',
  unrealizedProfit: amount.startsWith('-') ? '-1.00' : '1.00',
  marginType: marginType,
  liquidationPrice: '61000.00',
  marginRatio: '0.0040',
);

/// Paper Futures in memory, as backend develop 5c2398cb answers.
class FakeFuturesApi implements FuturesApi {
  FuturesAccount accountAnswer = const FuturesAccount(
    walletBalance: '5000.00',
    unrealizedProfit: '0.00',
    marginBalance: '5000.00',
    availableBalance: '5000.00',
    maxWithdrawAmount: '5000.00',
  );
  List<FuturesPosition> positionList = [];
  List<FuturesOrder> orderList = [];
  List<AlgoOrder> algoList = [];
  SymbolConfig config = const SymbolConfig(
    symbol: 'BTCUSDT',
    marginType: MarginType.crossed,
    leverage: 20,
  );
  int max = 125;
  OrderWarnings warningsAnswer = const OrderWarnings(
    warnings: [],
    cost: '38.00',
    liquidationPrice: '61000.00',
  );

  final List<String> calls = [];
  final List<FuturesOrderRequest> placed = [];
  final List<AlgoOrderRequest> placedAlgo = [];
  Object? placeError;
  Object? changeError;

  /// The max open answers, by LONG / SHORT; each request is kept.
  MaxOpen maxLong = const MaxOpen(maxQuantity: '1.300', maxNotional: '97500');
  MaxOpen maxShort = const MaxOpen(maxQuantity: '1.200', maxNotional: '90000');
  final List<MaxOpenRequest> maxRequests = [];
  final List<FuturesOrderRequest> warningRequests = [];

  /// Thrown by every read of the account (a plan without Futures).
  Object? loadError;

  @override
  Future<FuturesAccount> account() async {
    calls.add('account');
    if (loadError case final error?) throw error;
    return accountAnswer;
  }

  @override
  Future<List<FuturesPosition>> positions({String? symbol}) async {
    calls.add('positions');
    return positionList;
  }

  @override
  Future<List<FuturesOrder>> openOrders({String? symbol}) async {
    calls.add('open orders');
    return orderList;
  }

  @override
  Future<List<AlgoOrder>> openAlgoOrders({String? symbol}) async {
    calls.add('open algo');
    return algoList;
  }

  @override
  Future<SymbolConfig> symbolConfig(String symbol) async {
    calls.add('config $symbol');
    return SymbolConfig(
      symbol: symbol,
      marginType: config.marginType,
      leverage: config.leverage,
    );
  }

  @override
  Future<int> maxLeverage(String symbol) async => max;

  @override
  Future<void> setLeverage(String symbol, int leverage) async {
    calls.add('leverage $symbol $leverage');
    if (changeError case final error?) throw error;
    config = SymbolConfig(
      symbol: symbol,
      marginType: config.marginType,
      leverage: leverage,
    );
  }

  @override
  Future<void> setMarginType(String symbol, MarginType type) async {
    calls.add('margin type $symbol ${type.wire}');
    if (changeError case final error?) throw error;
    config = SymbolConfig(
      symbol: symbol,
      marginType: type,
      leverage: config.leverage,
    );
  }

  @override
  Future<OrderWarnings> warnings(FuturesOrderRequest request) async {
    calls.add('warnings ${request.side.wire} ${request.quantity}');
    warningRequests.add(request);
    return warningsFor[request.side] ?? warningsAnswer;
  }

  // Histories (T-123): each answer as set; every read is in [calls] with
  // its filters, so a test can tell what the screen asked.
  List<FuturesIncome> incomeList = [];
  List<ClosedPosition> closedList = [];
  List<FuturesOrder> allOrderList = [];
  List<FuturesTrade> tradeList = [];
  List<AlgoOrder> allAlgoList = [];
  List<FuturesOrder> forceList = [];
  List<MarginChange> marginList = [];
  Object? historyError;

  String _range(DateTime? from, DateTime? to, int? limit) =>
      '${from == null ? '-' : from.toUtc().toIso8601String()}'
      '..${to == null ? '-' : to.toUtc().toIso8601String()} $limit';

  Future<T> _history<T>(String call, T answer) async {
    calls.add(call);
    if (historyError case final error?) throw error;
    return answer;
  }

  @override
  Future<List<FuturesIncome>> income({
    String? symbol,
    IncomeType? type,
    DateTime? from,
    DateTime? to,
    int? limit,
  }) => _history(
    'income ${symbol ?? '*'} ${type?.wire ?? '*'} ${_range(from, to, limit)}',
    incomeList,
  );

  @override
  Future<List<ClosedPosition>> positionHistory({
    String? symbol,
    DateTime? from,
    DateTime? to,
    int? limit,
  }) => _history(
    'positionHistory ${symbol ?? '*'} ${_range(from, to, limit)}',
    closedList,
  );

  @override
  Future<List<FuturesOrder>> allOrders(
    String symbol, {
    DateTime? from,
    DateTime? to,
    int? limit,
  }) => _history('allOrders $symbol ${_range(from, to, limit)}', allOrderList);

  @override
  Future<List<FuturesTrade>> userTrades(
    String symbol, {
    DateTime? from,
    DateTime? to,
    int? limit,
  }) => _history('userTrades $symbol ${_range(from, to, limit)}', tradeList);

  @override
  Future<List<AlgoOrder>> allAlgoOrders(
    String symbol, {
    DateTime? from,
    DateTime? to,
    int? limit,
  }) =>
      _history('allAlgoOrders $symbol ${_range(from, to, limit)}', allAlgoList);

  @override
  Future<List<FuturesOrder>> forceOrders({
    String? symbol,
    DateTime? from,
    DateTime? to,
    int? limit,
  }) => _history(
    'forceOrders ${symbol ?? '*'} ${_range(from, to, limit)}',
    forceList,
  );

  @override
  Future<List<MarginChange>> marginHistory(
    String symbol, {
    bool? added,
    DateTime? from,
    DateTime? to,
    int? limit,
  }) => _history(
    'marginHistory $symbol ${added == null ? '*' : (added ? 1 : 2)} '
    '${_range(from, to, limit)}',
    marginList,
  );

  /// A side's own warnings, else [warningsAnswer].
  final Map<OrderSide, OrderWarnings> warningsFor = {};
  Object? maxError;

  @override
  Future<MaxOpen> maxOpen(MaxOpenRequest request) async {
    calls.add(
      'max ${request.long ? 'LONG' : 'SHORT'} ${request.leverage}x '
      '${request.entryPrice} ${request.walletBalance}',
    );
    maxRequests.add(request);
    if (maxError case final error?) throw error;
    return request.long ? maxLong : maxShort;
  }

  @override
  Future<FuturesOrder> placeOrder(FuturesOrderRequest request) async {
    calls.add('place ${request.type} ${request.side.wire} ${request.quantity}');
    placed.add(request);
    if (placeError case final error?) throw error;
    return FuturesOrder(
      orderId: 'f-${placed.length}',
      symbol: request.symbol,
      side: request.side,
      positionSide: request.positionSide,
      type: request.type,
      price: request.price,
      origQty: request.quantity,
      executedQty: '0',
      status: OrderStatus.newOrder,
      time: DateTime.utc(2026, 11, 19, 3),
    );
  }

  @override
  Future<AlgoOrder> placeAlgoOrder(AlgoOrderRequest request) async {
    calls.add('algo ${request.type} ${request.side.wire}');
    placedAlgo.add(request);
    if (placeError case final error?) throw error;
    return AlgoOrder(
      algoId: 'a-${placedAlgo.length}',
      symbol: request.symbol,
      side: request.side,
      type: request.type,
      triggerPrice: request.triggerPrice ?? '0',
      status: 'NEW',
    );
  }

  bool hedge = false;

  @override
  Future<bool> positionMode() async {
    calls.add('mode');
    return hedge;
  }

  @override
  Future<bool> setPositionMode({required bool hedge}) async {
    calls.add('set mode ${hedge ? 'hedge' : 'one-way'}');
    if (changeError case final error?) throw error;
    this.hedge = hedge;
    return hedge;
  }

  final List<FuturesAmendRequest> amended = [];

  @override
  Future<FuturesOrder> amendOrder(FuturesAmendRequest request) async {
    calls.add('amend ${request.orderId} ${request.price} ${request.quantity}');
    amended.add(request);
    if (changeError case final error?) throw error;
    return FuturesOrder(
      orderId: request.orderId,
      symbol: request.symbol,
      side: request.side,
      positionSide: PositionSide.both,
      type: 'LIMIT',
      origQty: request.quantity,
      executedQty: '0',
      status: OrderStatus.newOrder,
      time: DateTime.utc(2026, 11, 19),
      price: request.price,
    );
  }

  @override
  Future<void> cancelOrder(String symbol, String orderId) async {
    calls.add('cancel $orderId');
    orderList = [
      for (final o in orderList)
        if (o.orderId != orderId) o,
    ];
  }

  @override
  Future<void> cancelAlgoOrder(String symbol, String algoId) async {
    calls.add('cancel algo $algoId');
    algoList = [
      for (final o in algoList)
        if (o.algoId != algoId) o,
    ];
  }

  @override
  Future<void> cancelAll(String symbol) async {
    calls.add('cancel all $symbol');
    orderList = [];
  }

  @override
  Future<void> closePosition({
    required String symbol,
    required PositionSide side,
    required int percent,
    String? price,
  }) async {
    calls.add(
      'close $symbol ${side.wire} $percent${price == null ? '' : ' at $price'}',
    );
    if (changeError case final error?) throw error;
    if (percent == 100 && price == null) {
      positionList = [
        for (final p in positionList)
          if (p.symbol != symbol || p.side != side) p,
      ];
    }
  }

  @override
  Future<void> closeAll() async {
    calls.add('close all');
    positionList = [];
  }

  @override
  Future<void> changeMargin({
    required String symbol,
    required PositionSide side,
    required String amount,
    required bool add,
  }) async {
    calls.add('margin ${add ? 'add' : 'remove'} $amount');
    if (changeError case final error?) throw error;
  }

  /// Unused hook so tests can hold a call open when needed.
  Completer<void>? hold;
}
