import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/http/http_providers.dart';
import '../domain/watchlist.dart';

/// `/watchlist` (fe-guide watchlist module; checked on backend develop
/// 6d8a3d9, `sortOrder` on 25ba960) and the setup score from `/analysis`.
abstract interface class WatchlistApi {
  Future<Watchlist> list();

  /// 409 MSG45 already watched, 409 MSG27 at the plan limit, 404 MSG41.
  Future<WatchItem> add(String pairId);

  /// `label` / `note`: "" clears, null keeps. [sortOrder] (0…10 000, MSG15
  /// outside) moves this row only; the others keep their positions.
  Future<WatchItem> update(
    String id, {
    String? label,
    String? note,
    int? sortOrder,
  });

  /// A row with alerts answers 400 MSG26 `[symbol, n]` until [confirm] with
  /// the same [expectedAlertCount].
  Future<void> remove(
    String id, {
    bool confirm = false,
    int? expectedAlertCount,
  });

  Future<SetupScore?> score(String symbol);
}

class DioWatchlistApi implements WatchlistApi {
  const DioWatchlistApi(this._dio);

  final Dio _dio;

  @override
  Future<Watchlist> list() =>
      apiCall(() => _dio.get<Object?>('watchlist'), decodeWatchlist);

  @override
  Future<WatchItem> add(String pairId) => apiCall(
    () => _dio.post<Object?>('watchlist', data: {'pairId': pairId}),
    decodeWatchItem,
  );

  @override
  Future<WatchItem> update(
    String id, {
    String? label,
    String? note,
    int? sortOrder,
  }) => apiCall(
    () => _dio.patch<Object?>(
      'watchlist/$id',
      data: {'label': ?label, 'note': ?note, 'sortOrder': ?sortOrder},
    ),
    decodeWatchItem,
  );

  @override
  Future<void> remove(
    String id, {
    bool confirm = false,
    int? expectedAlertCount,
  }) => apiCall(
    () => _dio.delete<Object?>(
      'watchlist/$id',
      queryParameters: {
        'confirm': confirm,
        'expectedAlertCount': ?expectedAlertCount,
      },
    ),
    (_) {},
  );

  @override
  Future<SetupScore?> score(String symbol) => apiCall(
    () => _dio.get<Object?>('analysis/spot/$symbol'),
    decodeSetupScore,
  );
}

final watchlistApiProvider = Provider<WatchlistApi>(
  (ref) => DioWatchlistApi(ref.watch(apiDioProvider)),
);
