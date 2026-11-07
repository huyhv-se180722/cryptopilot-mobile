import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/http/http_providers.dart';
import '../domain/performance.dart';

/// `GET /journal/performance/summary` (T-051, backend develop 25ba960):
/// simulated trades, from the first trade, without a filter.
abstract interface class PerformanceApi {
  Future<PerformanceSummary> summary();
}

class DioPerformanceApi implements PerformanceApi {
  const DioPerformanceApi(this._dio);

  final Dio _dio;

  @override
  Future<PerformanceSummary> summary() => apiCall(
    () => _dio.get<Object?>('journal/performance/summary'),
    decodePerformanceSummary,
  );
}

final performanceApiProvider = Provider<PerformanceApi>(
  (ref) => DioPerformanceApi(ref.watch(apiDioProvider)),
);
