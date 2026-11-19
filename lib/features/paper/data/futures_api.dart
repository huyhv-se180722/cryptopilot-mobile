import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/http/http_providers.dart';
import '../domain/futures.dart';

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

  Future<FuturesOrder> placeOrder(FuturesOrderRequest request);

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
