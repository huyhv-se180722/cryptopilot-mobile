import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/http/http_providers.dart';
import '../domain/futures.dart';
import '../domain/futures_calculator.dart';
import '../domain/futures_history.dart';

/// Paper Futures (D-127, D-128, D-154; read on backend develop 5c2398cb,
/// module unchanged since 25ba960; no fe-guide chapter).
abstract interface class FuturesApi {
  Future<FuturesAccount> account();

  /// Open positions of [symbol], or of every pair.
  Future<List<FuturesPosition>> positions({String? symbol});

  Future<List<FuturesOrder>> openOrders({String? symbol});

  Future<List<AlgoOrder>> openAlgoOrders({String? symbol});

  Future<SymbolConfig> symbolConfig(String symbol);

  /// The highest leverage of the pair's first bracket.
  Future<int> maxLeverage(String symbol);

  /// 400 MSG15 `PAPER_LEVERAGE` beyond the bracket.
  Future<void> setLeverage(String symbol, int leverage);

  /// 409 MSG43 `PAPER_MARGIN_TYPE` with an open position or order.
  Future<void> setMarginType(String symbol, MarginType type);

  /// TR-26: what the order would cost and what to warn about.
  Future<OrderWarnings> warnings(FuturesOrderRequest request);

  /// The largest position a balance opens at a price (TR-25).
  Future<MaxOpen> maxOpen(MaxOpenRequest request);

  /// One tab of the calculator (TR-25, T-123).
  Future<CalcResult> calculate(CalcRequest request);

  // The histories (plan 9.3, T-123): newest first; a range is optional.

  Future<List<FuturesIncome>> income({
    String? symbol,
    IncomeType? type,
    DateTime? from,
    DateTime? to,
    int? limit,
  });

  Future<List<ClosedPosition>> positionHistory({
    String? symbol,
    DateTime? from,
    DateTime? to,
    int? limit,
  });

  Future<List<FuturesOrder>> allOrders(
    String symbol, {
    DateTime? from,
    DateTime? to,
    int? limit,
  });

  Future<List<FuturesTrade>> userTrades(
    String symbol, {
    DateTime? from,
    DateTime? to,
    int? limit,
  });

  Future<List<AlgoOrder>> allAlgoOrders(
    String symbol, {
    DateTime? from,
    DateTime? to,
    int? limit,
  });

  /// Liquidations.
  Future<List<FuturesOrder>> forceOrders({
    String? symbol,
    DateTime? from,
    DateTime? to,
    int? limit,
  });

  /// [added] true for additions, false for reductions, null for both.
  Future<List<MarginChange>> marginHistory(
    String symbol, {
    bool? added,
    DateTime? from,
    DateTime? to,
    int? limit,
  });

  Future<FuturesOrder> placeOrder(FuturesOrderRequest request);

  /// A new price and quantity for an open Limit (T-123).
  Future<FuturesOrder> amendOrder(FuturesAmendRequest request);

  /// True in hedge mode (a Long and a Short position per pair, TR-14b).
  Future<bool> positionMode();

  /// Answers the mode after the change.
  Future<bool> setPositionMode({required bool hedge});

  Future<AlgoOrder> placeAlgoOrder(AlgoOrderRequest request);

  Future<void> cancelOrder(String symbol, String orderId);

  Future<void> cancelAlgoOrder(String symbol, String algoId);

  Future<void> cancelAll(String symbol);

  /// [percent] 1–100 of the position by MARKET, or by LIMIT at [price].
  Future<void> closePosition({
    required String symbol,
    required PositionSide side,
    required int percent,
    String? price,
  });

  /// Market close of every position.
  Future<void> closeAll();

  /// Isolated only: adds ([add]) or removes margin.
  Future<void> changeMargin({
    required String symbol,
    required PositionSide side,
    required String amount,
    required bool add,
  });
}

class DioFuturesApi implements FuturesApi {
  const DioFuturesApi(this._dio);

  final Dio _dio;
  static const _base = 'paper/futures';

  @override
  Future<FuturesAccount> account() =>
      apiCall(() => _dio.get<Object?>('$_base/account'), decodeFuturesAccount);

  @override
  Future<List<FuturesPosition>> positions({String? symbol}) => apiCall(
    () => _dio.get<Object?>(
      '$_base/positionRisk',
      queryParameters: {'symbol': ?symbol},
    ),
    decodePositions,
  );

  @override
  Future<List<FuturesOrder>> openOrders({String? symbol}) => apiCall(
    () => _dio.get<Object?>(
      '$_base/openOrders',
      queryParameters: {'symbol': ?symbol},
    ),
    decodeFuturesOrders,
  );

  @override
  Future<List<AlgoOrder>> openAlgoOrders({String? symbol}) => apiCall(
    () => _dio.get<Object?>(
      '$_base/openAlgoOrders',
      queryParameters: {'symbol': ?symbol},
    ),
    decodeAlgoOrders,
  );

  @override
  Future<SymbolConfig> symbolConfig(String symbol) => apiCall(
    () => _dio.get<Object?>(
      '$_base/symbolConfig',
      queryParameters: {'symbol': symbol},
    ),
    (body) => body is List && body.isNotEmpty
        ? decodeSymbolConfig(body.first)
        : decodeSymbolConfig(body),
  );

  @override
  Future<int> maxLeverage(String symbol) => apiCall(
    () => _dio.get<Object?>(
      '$_base/leverageBracket',
      queryParameters: {'symbol': symbol},
    ),
    (body) => body is List && body.isNotEmpty
        ? maxLeverageOf(body.first)
        : maxLeverageOf(body),
  );

  @override
  Future<void> setLeverage(String symbol, int leverage) => apiCall(
    () => _dio.post<Object?>(
      '$_base/leverage',
      data: {'symbol': symbol, 'leverage': leverage},
    ),
    (_) {},
  );

  @override
  Future<void> setMarginType(String symbol, MarginType type) => apiCall(
    () => _dio.post<Object?>(
      '$_base/marginType',
      data: {'symbol': symbol, 'marginType': type.wire},
    ),
    (_) {},
  );

  @override
  Future<OrderWarnings> warnings(FuturesOrderRequest request) => apiCall(
    () => _dio.post<Object?>('$_base/order/warnings', data: request.toJson()),
    decodeWarnings,
  );

  static Map<String, Object?> _range(
    DateTime? from,
    DateTime? to,
    int? limit,
  ) => {
    'startTime': ?from?.toUtc().toIso8601String(),
    'endTime': ?to?.toUtc().toIso8601String(),
    'limit': ?limit,
  };

  @override
  Future<List<FuturesIncome>> income({
    String? symbol,
    IncomeType? type,
    DateTime? from,
    DateTime? to,
    int? limit,
  }) => apiCall(
    () => _dio.get<Object?>(
      '$_base/income',
      queryParameters: {
        'symbol': ?symbol,
        'incomeType': ?type?.wire,
        ..._range(from, to, limit),
      },
    ),
    decodeIncomes,
  );

  @override
  Future<List<ClosedPosition>> positionHistory({
    String? symbol,
    DateTime? from,
    DateTime? to,
    int? limit,
  }) => apiCall(
    () => _dio.get<Object?>(
      '$_base/positionHistory',
      queryParameters: {'symbol': ?symbol, ..._range(from, to, limit)},
    ),
    decodeClosedPositions,
  );

  @override
  Future<List<FuturesOrder>> allOrders(
    String symbol, {
    DateTime? from,
    DateTime? to,
    int? limit,
  }) => apiCall(
    () => _dio.get<Object?>(
      '$_base/allOrders',
      queryParameters: {'symbol': symbol, ..._range(from, to, limit)},
    ),
    decodeFuturesOrders,
  );

  @override
  Future<List<FuturesTrade>> userTrades(
    String symbol, {
    DateTime? from,
    DateTime? to,
    int? limit,
  }) => apiCall(
    () => _dio.get<Object?>(
      '$_base/userTrades',
      queryParameters: {'symbol': symbol, ..._range(from, to, limit)},
    ),
    decodeFuturesTrades,
  );

  @override
  Future<List<AlgoOrder>> allAlgoOrders(
    String symbol, {
    DateTime? from,
    DateTime? to,
    int? limit,
  }) => apiCall(
    () => _dio.get<Object?>(
      '$_base/allAlgoOrders',
      queryParameters: {'symbol': symbol, ..._range(from, to, limit)},
    ),
    decodeAlgoOrders,
  );

  @override
  Future<List<FuturesOrder>> forceOrders({
    String? symbol,
    DateTime? from,
    DateTime? to,
    int? limit,
  }) => apiCall(
    () => _dio.get<Object?>(
      '$_base/forceOrders',
      queryParameters: {'symbol': ?symbol, ..._range(from, to, limit)},
    ),
    decodeFuturesOrders,
  );

  @override
  Future<List<MarginChange>> marginHistory(
    String symbol, {
    bool? added,
    DateTime? from,
    DateTime? to,
    int? limit,
  }) => apiCall(
    () => _dio.get<Object?>(
      '$_base/positionMargin/history',
      queryParameters: {
        'symbol': symbol,
        'type': ?(added == null ? null : (added ? 1 : 2)),
        ..._range(from, to, limit),
      },
    ),
    decodeMarginChanges,
  );

  @override
  Future<CalcResult> calculate(CalcRequest request) => apiCall(
    () => _dio.post<Object?>(
      '$_base/calculator/${request.tab.path}',
      data: request.toJson(),
    ),
    decodeCalcResult,
  );

  @override
  Future<MaxOpen> maxOpen(MaxOpenRequest request) => apiCall(
    () =>
        _dio.post<Object?>('$_base/calculator/maxOpen', data: request.toJson()),
    decodeMaxOpen,
  );

  @override
  Future<FuturesOrder> placeOrder(FuturesOrderRequest request) => apiCall(
    () => _dio.post<Object?>('$_base/order', data: request.toJson()),
    decodeFuturesOrder,
  );

  @override
  Future<bool> positionMode() => apiCall(
    () => _dio.get<Object?>('$_base/positionSide/dual'),
    decodePositionMode,
  );

  @override
  Future<bool> setPositionMode({required bool hedge}) => apiCall(
    () => _dio.post<Object?>(
      '$_base/positionSide/dual',
      data: {'dualSidePosition': hedge},
    ),
    decodePositionMode,
  );

  @override
  Future<FuturesOrder> amendOrder(FuturesAmendRequest request) => apiCall(
    () => _dio.put<Object?>('$_base/order', data: request.toJson()),
    decodeFuturesOrder,
  );

  @override
  Future<AlgoOrder> placeAlgoOrder(AlgoOrderRequest request) => apiCall(
    () => _dio.post<Object?>('$_base/algoOrder', data: request.toJson()),
    decodeAlgoOrder,
  );

  @override
  Future<void> cancelOrder(String symbol, String orderId) => apiCall(
    () => _dio.delete<Object?>(
      '$_base/order',
      queryParameters: {'symbol': symbol, 'orderId': orderId},
    ),
    (_) {},
  );

  @override
  Future<void> cancelAlgoOrder(String symbol, String algoId) => apiCall(
    () => _dio.delete<Object?>(
      '$_base/algoOrder',
      queryParameters: {'symbol': symbol, 'algoId': algoId},
    ),
    (_) {},
  );

  @override
  Future<void> cancelAll(String symbol) => apiCall(
    () => _dio.delete<Object?>(
      '$_base/allOpenOrders',
      queryParameters: {'symbol': symbol},
    ),
    (_) {},
  );

  @override
  Future<void> closePosition({
    required String symbol,
    required PositionSide side,
    required int percent,
    String? price,
  }) => apiCall(
    () => _dio.post<Object?>(
      '$_base/closePosition',
      data: {
        'symbol': symbol,
        'type': price == null ? 'MARKET' : 'LIMIT',
        'price': ?price,
        'percent': percent,
        'positionSide': side.wire,
      },
    ),
    (_) {},
  );

  @override
  Future<void> closeAll() => apiCall(
    () => _dio.post<Object?>('$_base/closePosition', data: {'type': 'MARKET'}),
    (_) {},
  );

  @override
  Future<void> changeMargin({
    required String symbol,
    required PositionSide side,
    required String amount,
    required bool add,
  }) => apiCall(
    () => _dio.post<Object?>(
      '$_base/positionMargin',
      data: {
        'symbol': symbol,
        'positionSide': side.wire,
        'amount': amount,
        'type': add ? 1 : 2,
      },
    ),
    (_) {},
  );
}

final futuresApiProvider = Provider<FuturesApi>(
  (ref) => DioFuturesApi(ref.watch(apiDioProvider)),
);
