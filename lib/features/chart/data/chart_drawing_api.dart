import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/http/http_providers.dart';
import '../domain/drawing.dart';

/// `/chart-layouts` and `/chart-drawings` (D-149 (5), T-119; checked on
/// backend `develop` `e02a7c3b`): the signed-in Trader's copies of a pair
/// and the drawings of each. Owner only: another user's row answers 404.
abstract interface class ChartDrawingApi {
  /// By number; empty when the Trader never drew on the pair.
  Future<List<ChartLayout>> layouts(String pairId);

  /// Empty, or a copy of [copyFrom]'s drawings; 409 MSG43
  /// `CHART_LAYOUT_LIMIT_REACHED` past 10 copies.
  Future<ChartLayout> createLayout(String pairId, {String? copyFrom});

  /// A blank [name] brings back "Copy n".
  Future<ChartLayout> renameLayout(String id, String? name);

  /// With its drawings.
  Future<void> removeLayout(String id);

  /// Oldest first.
  Future<List<ChartDrawing>> drawings(String layoutId);

  /// 409 MSG43 `CHART_DRAWING_LIMIT_REACHED` past 200 drawings.
  Future<ChartDrawing> create(String layoutId, DrawingDraft draft);

  /// [version] is the one last read; a stale one answers 409 and writes
  /// nothing.
  Future<ChartDrawing> update(String id, int version, DrawingChange change);

  Future<void> remove(String id);

  Future<void> removeAll(String layoutId);
}

class DioChartDrawingApi implements ChartDrawingApi {
  const DioChartDrawingApi(this._dio);

  final Dio _dio;

  @override
  Future<List<ChartLayout>> layouts(String pairId) => apiCall(
    () =>
        _dio.get<Object?>('chart-layouts', queryParameters: {'pairId': pairId}),
    decodeChartLayouts,
  );

  @override
  Future<ChartLayout> createLayout(String pairId, {String? copyFrom}) =>
      apiCall(
        () => _dio.post<Object?>(
          'chart-layouts',
          data: {'pairId': pairId, 'copyFrom': ?copyFrom},
        ),
        ChartLayout.fromJson,
      );

  @override
  Future<ChartLayout> renameLayout(String id, String? name) => apiCall(
    () => _dio.put<Object?>('chart-layouts/$id', data: {'name': name}),
    ChartLayout.fromJson,
  );

  @override
  Future<void> removeLayout(String id) =>
      apiCall(() => _dio.delete<Object?>('chart-layouts/$id'), (_) {});

  @override
  Future<List<ChartDrawing>> drawings(String layoutId) => apiCall(
    () => _dio.get<Object?>(
      'chart-drawings',
      queryParameters: {'layoutId': layoutId},
    ),
    decodeChartDrawings,
  );

  @override
  Future<ChartDrawing> create(String layoutId, DrawingDraft draft) => apiCall(
    () => _dio.post<Object?>(
      'chart-drawings',
      data: {
        'layoutId': layoutId,
        'type': draft.type,
        ...draft.change.toJson(),
      },
    ),
    ChartDrawing.fromJson,
  );

  @override
  Future<ChartDrawing> update(String id, int version, DrawingChange change) =>
      apiCall(
        () => _dio.put<Object?>(
          'chart-drawings/$id',
          data: {'version': version, ...change.toJson()},
        ),
        ChartDrawing.fromJson,
      );

  @override
  Future<void> remove(String id) =>
      apiCall(() => _dio.delete<Object?>('chart-drawings/$id'), (_) {});

  @override
  Future<void> removeAll(String layoutId) => apiCall(
    () => _dio.delete<Object?>(
      'chart-drawings',
      queryParameters: {'layoutId': layoutId},
    ),
    (_) {},
  );
}

final chartDrawingApiProvider = Provider<ChartDrawingApi>(
  (ref) => DioChartDrawingApi(ref.watch(apiDioProvider)),
);
