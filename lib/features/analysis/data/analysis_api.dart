import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/http/http_providers.dart';
import '../../market/domain/candle.dart';
import '../../market/domain/market.dart';
import '../domain/analysis.dart';

/// Analysis of a pair (checked on backend develop 25ba960: T-107 gates,
/// D-126 push) and the Futures metrics of SCR-11.
abstract interface class AnalysisApi {
  /// 403 MSG29 for Futures without FUTURES_ANALYSIS; 404 MSG41 for a pair
  /// not enabled on [market].
  Future<Analysis> analysis(Market market, String symbol, Timeframe tf);

  /// Open interest and long/short ratio from [from] (at most 7 days back).
  Future<FuturesMetrics> metrics(String symbol, DateTime from);
}

class DioAnalysisApi implements AnalysisApi {
  const DioAnalysisApi(this._dio);

  final Dio _dio;

  @override
  Future<Analysis> analysis(Market market, String symbol, Timeframe tf) =>
      apiCall(
        () => _dio.get<Object?>(
          'analysis/${market.path}/$symbol',
          queryParameters: {'tf': tf.wire},
        ),
        decodeAnalysis,
      );

  @override
  Future<FuturesMetrics> metrics(String symbol, DateTime from) => apiCall(
    () => _dio.get<Object?>(
      'market/futures/$symbol/metrics',
      queryParameters: {'from': from.toUtc().toIso8601String()},
    ),
    decodeFuturesMetrics,
  );
}

final analysisApiProvider = Provider<AnalysisApi>(
  (ref) => DioAnalysisApi(ref.watch(apiDioProvider)),
);
