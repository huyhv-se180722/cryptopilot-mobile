import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/http/http_providers.dart';
import '../domain/paper.dart';

/// The paper exchange, Spot part (D-86, D-154; checked on backend develop
/// 5c2398cb, module unchanged since 25ba960). No fe-guide chapter: every
/// call was read on the backend code. Most calls answer 404 MSG41 until the
/// account is opened.
abstract interface class PaperApi {
  /// Opens the account and grants the virtual funds once; an account
  /// already opened is answered as it is. Returns when it was opened.
  Future<DateTime> openAccount();

  Future<Wallet> wallet(PaperWallet wallet);

  /// USDT only between Spot and Futures (plan 9.3); 409 MSG43 when the key
  /// was used for another transfer.
  Future<Transfer> transfer({
    required PaperWallet from,
    required String amount,
    required String clientTransferId,
  });

  Future<PaperPage<Transfer>> transfers({int page = 1, int pageSize = 20});

  Future<PaperPage<LedgerEntry>> ledger({
    PaperWallet? wallet,
    LedgerType? type,
    DateTime? from,
    DateTime? to,
    int page = 1,
    int pageSize = 20,
  });

  Future<PaperOrder> placeOrder(SpotOrderRequest request);

  /// The orders of the placed group.
  Future<List<PaperOrder>> placeOrderList(SpotOrderListRequest request);

  /// 409 MSG43 (`PAPER_ORDER_NOT_OPEN`) for an order that has finished.
  Future<PaperOrder> cancelOrder(String orderId);

  Future<List<PaperOrder>> cancelOrderList(String listId);

  /// Every open order of [pairId]; the server asks for the pair.
  Future<List<PaperOrder>> cancelAll(String pairId);

  /// Open orders of [pairId], or of every pair.
  Future<List<PaperOrder>> openOrders({String? pairId});

  Future<PaperPage<PaperOrder>> orders({
    String? pairId,
    OrderStatus? status,
    DateTime? from,
    DateTime? to,
    int page = 1,
    int pageSize = 20,
  });

  Future<PaperPage<PaperFill>> fills({
    String? pairId,
    DateTime? from,
    DateTime? to,
    int page = 1,
    int pageSize = 20,
  });

  /// Spot plus Futures and today's PnL, with the start of each of the last
  /// [days] (1 to 365); 404 MSG41 before the account opens.
  Future<PaperEquity> equity({int days = 1});

  /// Each Spot coin's average cost and unrealised PnL (TR-13, T-123).
  Future<SpotPnl> spotPnl();
}

class DioPaperApi implements PaperApi {
  const DioPaperApi(this._dio);

  final Dio _dio;

  static String? _utc(DateTime? at) => at?.toUtc().toIso8601String();

  @override
  Future<DateTime> openAccount() =>
      apiCall(() => _dio.post<Object?>('paper/account'), decodeAccount);

  @override
  Future<Wallet> wallet(PaperWallet wallet) => apiCall(
    () => _dio.get<Object?>('paper/wallets/${wallet.wire}'),
    decodeWallet,
  );

  @override
  Future<Transfer> transfer({
    required PaperWallet from,
    required String amount,
    required String clientTransferId,
  }) => apiCall(
    () => _dio.post<Object?>(
      'paper/transfers',
      data: {
        'asset': 'USDT',
        'from': from.wire,
        'amount': amount,
        'clientTransferId': clientTransferId,
      },
    ),
    decodeTransfer,
  );

  @override
  Future<PaperPage<Transfer>> transfers({int page = 1, int pageSize = 20}) =>
      apiCall(
        () => _dio.get<Object?>(
          'paper/transfers',
          queryParameters: {'page': page, 'pageSize': pageSize},
        ),
        (body) => decodePaperPage(body, decodeTransfer),
      );

  @override
  Future<PaperPage<LedgerEntry>> ledger({
    PaperWallet? wallet,
    LedgerType? type,
    DateTime? from,
    DateTime? to,
    int page = 1,
    int pageSize = 20,
  }) => apiCall(
    () => _dio.get<Object?>(
      'paper/ledger',
      queryParameters: {
        'wallet': ?wallet?.wire,
        'type': ?type?.wire,
        'from': ?_utc(from),
        'to': ?_utc(to),
        'page': page,
        'pageSize': pageSize,
      },
    ),
    (body) => decodePaperPage(body, decodeLedgerEntry),
  );

  @override
  Future<PaperOrder> placeOrder(SpotOrderRequest request) => apiCall(
    () => _dio.post<Object?>('paper/orders', data: request.toJson()),
    decodeOrder,
  );

  @override
  Future<List<PaperOrder>> placeOrderList(SpotOrderListRequest request) =>
      apiCall(
        () => _dio.post<Object?>('paper/order-lists', data: request.toJson()),
        decodeOrderList,
      );

  @override
  Future<PaperOrder> cancelOrder(String orderId) => apiCall(
    () => _dio.post<Object?>('paper/orders/$orderId/cancel'),
    decodeOrder,
  );

  @override
  Future<List<PaperOrder>> cancelOrderList(String listId) => apiCall(
    () => _dio.post<Object?>('paper/order-lists/$listId/cancel'),
    decodeOrderList,
  );

  @override
  Future<List<PaperOrder>> cancelAll(String pairId) => apiCall(
    () => _dio.delete<Object?>(
      'paper/orders/open',
      queryParameters: {'pairId': pairId},
    ),
    decodeOrders,
  );

  @override
  Future<List<PaperOrder>> openOrders({String? pairId}) => apiCall(
    () => _dio.get<Object?>(
      'paper/orders/open',
      queryParameters: {'pairId': ?pairId},
    ),
    decodeOrders,
  );

  @override
  Future<PaperPage<PaperOrder>> orders({
    String? pairId,
    OrderStatus? status,
    DateTime? from,
    DateTime? to,
    int page = 1,
    int pageSize = 20,
  }) => apiCall(
    () => _dio.get<Object?>(
      'paper/orders',
      queryParameters: {
        'pairId': ?pairId,
        'status': ?status?.wire,
        'from': ?_utc(from),
        'to': ?_utc(to),
        'page': page,
        'pageSize': pageSize,
      },
    ),
    (body) => decodePaperPage(body, decodeOrder),
  );

  @override
  Future<PaperPage<PaperFill>> fills({
    String? pairId,
    DateTime? from,
    DateTime? to,
    int page = 1,
    int pageSize = 20,
  }) => apiCall(
    () => _dio.get<Object?>(
      'paper/fills',
      queryParameters: {
        'pairId': ?pairId,
        'from': ?_utc(from),
        'to': ?_utc(to),
        'page': page,
        'pageSize': pageSize,
      },
    ),
    (body) => decodePaperPage(body, decodeFill),
  );

  @override
  Future<PaperEquity> equity({int days = 1}) => apiCall(
    () => _dio.get<Object?>('paper/equity', queryParameters: {'days': days}),
    decodeEquity,
  );

  @override
  Future<SpotPnl> spotPnl() =>
      apiCall(() => _dio.get<Object?>('paper/spot/pnl'), decodeSpotPnl);
}

final paperApiProvider = Provider<PaperApi>(
  (ref) => DioPaperApi(ref.watch(apiDioProvider)),
);
