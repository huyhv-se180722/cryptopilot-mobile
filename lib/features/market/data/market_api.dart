import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/http/http_providers.dart';
import '../../../core/json/json_read.dart';
import '../domain/market.dart';

/// Public market data (`/market/**`, fe-guide market module; checked on
/// backend develop 6d8a3d9).
abstract interface class MarketApi {
  /// Enabled pairs of [market] in the administrator's display order.
  Future<List<MarketPair>> pairs(Market market);

  /// One pair's REST snapshot, for the Delayed fallback (Q-65).
  Future<Ticker> stats(Market market, String symbol);
}

class DioMarketApi implements MarketApi {
  const DioMarketApi(this._dio);

  final Dio _dio;

  @override
  Future<List<MarketPair>> pairs(Market market) => apiCall(
    () => _dio.get<Object?>(
      'market/pairs',
      queryParameters: {'market': market.path, 'pageSize': 100},
    ),
    (body) {
      final json = asJsonObject(body, 'pairs page');
      final items = json['items'];
      if (items is! List) throw const DecodeException('items is not a list');
      return [for (final item in items) decodePair(item)]
        ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    },
  );

  @override
  Future<Ticker> stats(Market market, String symbol) => apiCall(
    () => _dio.get<Object?>('market/${market.path}/$symbol/stats'),
    market == Market.spot ? decodeSpotStats : decodeFuturesStats,
  );
}

final marketApiProvider = Provider<MarketApi>(
  (ref) => DioMarketApi(ref.watch(apiDioProvider)),
);
