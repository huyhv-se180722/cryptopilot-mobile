import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/http/http_providers.dart';
import '../domain/plan_detail.dart';

/// The Trader's queue a plan's position change is pushed to (TR-08).
const positionsQueue = '/user/queue/positions';

/// SCR-18 and SCR-19 (UC-18, UC-19, UC-21; checked on backend develop
/// 5c2398cb): one plan, its activation, cancellation and the manual close of
/// its simulated position, and the position's stop loss and take profit.
abstract interface class PlanDetailApi {
  /// 404 MSG41.
  Future<PlanDetail> plan(String id);

  /// MSG19 when ACTIVE. 400 MSG51 asks to confirm a MARKET entry that moved
  /// (send again with [confirmDeviation]); 409 MSG52, MSG18 (BLOCKING), MSG27;
  /// 403 MSG29; 503 MSG43.
  Future<PlanDetail> activate(String id, {bool confirmDeviation = false});

  /// After MSG20. 409 MSG43 once executed, cancelled or expired.
  Future<PlanDetail> cancel(String id);

  /// 409 MSG43 without an OPEN position; 503 MSG43 without a last price.
  Future<CloseEstimate> closeEstimate(String id);

  /// MSG23. 409 MSG43 when the engine closed it first.
  Future<PlanDetail> closePosition(String id);

  /// At least one level. 400 MSG01, MSG15, MSG16 on the field; 409 MSG43.
  Future<PlanDetail> changeLevels(
    String id, {
    String? stopLoss,
    String? takeProfit,
  });
}

class DioPlanDetailApi implements PlanDetailApi {
  const DioPlanDetailApi(this._dio);

  final Dio _dio;

  String _path(String id, [String rest = '']) =>
      'plans/${Uri.encodeComponent(id)}$rest';

  @override
  Future<PlanDetail> plan(String id) =>
      apiCall(() => _dio.get<Object?>(_path(id)), decodePlanDetail);

  @override
  Future<PlanDetail> activate(String id, {bool confirmDeviation = false}) =>
      apiCall(
        () => _dio.post<Object?>(
          _path(id, '/activate'),
          queryParameters: {'confirmDeviation': confirmDeviation},
        ),
        decodePlanDetail,
      );

  @override
  Future<PlanDetail> cancel(String id) =>
      apiCall(() => _dio.post<Object?>(_path(id, '/cancel')), decodePlanDetail);

  @override
  Future<CloseEstimate> closeEstimate(String id) => apiCall(
    () => _dio.get<Object?>(_path(id, '/close-estimate')),
    decodeCloseEstimate,
  );

  @override
  Future<PlanDetail> closePosition(String id) => apiCall(
    () => _dio.post<Object?>(_path(id, '/close-position')),
    decodePlanDetail,
  );

  @override
  Future<PlanDetail> changeLevels(
    String id, {
    String? stopLoss,
    String? takeProfit,
  }) => apiCall(
    () => _dio.patch<Object?>(
      _path(id, '/position-levels'),
      data: {'stopLoss': ?stopLoss, 'takeProfit': ?takeProfit},
    ),
    decodePlanDetail,
  );
}

final planDetailApiProvider = Provider<PlanDetailApi>(
  (ref) => DioPlanDetailApi(ref.watch(apiDioProvider)),
);
