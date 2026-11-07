import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/http/http_providers.dart';
import '../domain/alert.dart';

/// `/alerts` (UC-13, UC-14; checked on backend develop 25ba960). Errors:
/// 400 field errors (MSG01, MSG15), 403 MSG29 (indicator, Futures, email or
/// push not in the plan), 404 MSG41, 409 MSG27 (active alert limit), 409
/// MSG43 (a pause or resume the status does not allow).
abstract interface class AlertApi {
  Future<AlertPage> list({
    AlertStatus? status,
    AlertType? type,
    int page = 1,
    int pageSize = 20,
  });

  /// A pair not watched yet is added to the watchlist with it (BR-16).
  Future<Alert> create(String pairId, AlertRule rule);

  /// The whole rule again; a TRIGGERED or EXPIRED alert becomes ACTIVE.
  Future<Alert> update(String id, AlertRule rule);

  Future<void> delete(String id);

  Future<Alert> pause(String id);

  Future<Alert> resume(String id);
}

/// The body of `POST` / `PUT /alerts`: absent fields are sent as null, which
/// the server reads as "not part of this rule".
Map<String, Object?> encodeRule(AlertRule rule) => {
  'market': rule.market.wire,
  'type': rule.type.wire,
  'indicator': rule.indicator?.wire,
  'timeframe': rule.timeframe,
  'condition': rule.condition.wire,
  'threshold': rule.threshold,
  'triggerMode': rule.triggerMode.wire,
  'cooldownMinutes': rule.cooldownMinutes,
  'notifyEmail': rule.notifyEmail,
  'notifyPush': rule.notifyPush,
  'expiresAt': rule.expiresAt?.toUtc().toIso8601String(),
};

class DioAlertApi implements AlertApi {
  const DioAlertApi(this._dio);

  final Dio _dio;

  @override
  Future<AlertPage> list({
    AlertStatus? status,
    AlertType? type,
    int page = 1,
    int pageSize = 20,
  }) => apiCall(
    () => _dio.get<Object?>(
      'alerts',
      queryParameters: {
        'status': ?status?.wire,
        'type': ?type?.wire,
        'page': page,
        'pageSize': pageSize,
      },
    ),
    decodeAlertPage,
  );

  @override
  Future<Alert> create(String pairId, AlertRule rule) => apiCall(
    () => _dio.post<Object?>(
      'alerts',
      data: {'pairId': pairId, ...encodeRule(rule)},
    ),
    decodeAlert,
  );

  @override
  Future<Alert> update(String id, AlertRule rule) => apiCall(
    () => _dio.put<Object?>('alerts/$id', data: encodeRule(rule)),
    decodeAlert,
  );

  @override
  Future<void> delete(String id) =>
      apiCall(() => _dio.delete<Object?>('alerts/$id'), (_) {});

  @override
  Future<Alert> pause(String id) =>
      apiCall(() => _dio.post<Object?>('alerts/$id/pause'), decodeAlert);

  @override
  Future<Alert> resume(String id) =>
      apiCall(() => _dio.post<Object?>('alerts/$id/resume'), decodeAlert);
}

final alertApiProvider = Provider<AlertApi>(
  (ref) => DioAlertApi(ref.watch(apiDioProvider)),
);
