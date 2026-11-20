import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/http/http_providers.dart';
import '../domain/journal.dart';

/// `/journal` and `/strategies` (UC-22, UC-23; checked on backend develop
/// 5c2398cb). Recording or editing the facts of a manual trade is SCR-22, on
/// the web; the app reads, reviews and deletes a manual trade.
abstract interface class JournalApi {
  /// Newest first; [from] and [to] are dates (UTC), inclusive.
  Future<JournalPage> list({
    JournalFilter filter = const JournalFilter(),
    DateTime? from,
    DateTime? to,
    int page = 1,
    int pageSize = 20,
  });

  /// 404 MSG41.
  Future<JournalDetail> entry(String id);

  /// MSG14. 400 MSG15 on a text over 4,000 characters, MSG32 on a chart
  /// image that is not the caller's, too large or of another format; 404
  /// MSG41. The review replaces the stored one: a field left out is
  /// cleared, and [chartImagePublicId] keeps the stored image when it is
  /// its key, attaches a new upload, or removes the image when null.
  Future<JournalDetail> review(
    String id, {
    String? strategyId,
    String? setupDescription,
    String? lessonsLearned,
    String? mistakes,
    String? chartImagePublicId,
  });

  /// A signed form for one chart image of the trade (404 MSG41, 503 MSG43
  /// without a media storage).
  Future<ChartImageForm> chartImageForm(String id);

  /// Posts the file to the storage, without the app's tokens. Throws
  /// [ChartImageRefused] on any refusal of the storage.
  Future<void> uploadChartImage(
    ChartImageForm form,
    String path, {
    void Function(double share)? onProgress,
  });

  /// MANUAL only: 409 MSG43 on a SIMULATED trade (BR-40), 404 MSG41.
  Future<void> delete(String id);

  Future<List<Strategy>> strategies();
}

String _date(DateTime day) {
  final utc = day.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${utc.year}-${two(utc.month)}-${two(utc.day)}';
}

/// The storage refused a chart image (MSG32).
class ChartImageRefused implements Exception {
  const ChartImageRefused();
}

class DioJournalApi implements JournalApi {
  DioJournalApi(this._dio, {Dio? storage}) : _storage = storage ?? Dio();

  final Dio _dio;

  /// Never [_dio]: the storage must not see the app's tokens.
  final Dio _storage;

  @override
  Future<JournalPage> list({
    JournalFilter filter = const JournalFilter(),
    DateTime? from,
    DateTime? to,
    int page = 1,
    int pageSize = 20,
  }) => apiCall(
    () => _dio.get<Object?>(
      'journal',
      queryParameters: {
        'status': ?filter.status?.wire,
        'market': ?filter.market?.wire,
        'source': ?filter.source?.wire,
        'result': ?filter.result?.wire,
        'strategyId': ?filter.strategyId,
        'pairId': ?filter.pairId,
        if (from != null) 'from': _date(from),
        if (to != null) 'to': _date(to),
        'page': page,
        'pageSize': pageSize,
      },
    ),
    decodeJournalPage,
  );

  @override
  Future<JournalDetail> entry(String id) => apiCall(
    () => _dio.get<Object?>('journal/${Uri.encodeComponent(id)}'),
    decodeJournalDetail,
  );

  @override
  Future<JournalDetail> review(
    String id, {
    String? strategyId,
    String? setupDescription,
    String? lessonsLearned,
    String? mistakes,
    String? chartImagePublicId,
  }) => apiCall(
    () => _dio.put<Object?>(
      'journal/${Uri.encodeComponent(id)}/review',
      data: {
        'strategyId': strategyId,
        'setupDescription': setupDescription,
        'lessonsLearned': lessonsLearned,
        'mistakes': mistakes,
        // Left out, as null, the review has no image (BR-40).
        'chartImagePublicId': ?chartImagePublicId,
      },
    ),
    decodeJournalDetail,
  );

  @override
  Future<ChartImageForm> chartImageForm(String id) => apiCall(
    () => _dio.post<Object?>(
      'journal/${Uri.encodeComponent(id)}/chart-image/upload-signature',
    ),
    decodeChartImageForm,
  );

  @override
  Future<void> uploadChartImage(
    ChartImageForm form,
    String path, {
    void Function(double share)? onProgress,
  }) async {
    try {
      await _storage.post<Object?>(
        form.uploadUrl,
        data: FormData.fromMap({
          'file': await MultipartFile.fromFile(path),
          'api_key': form.apiKey,
          'timestamp': '${form.timestamp}',
          'signature': form.signature,
          'public_id': form.publicId,
          'allowed_formats': form.allowedFormats.join(','),
          // Signed by the backend with the other fields.
          'overwrite': 'false',
        }),
        onSendProgress: (sent, total) {
          if (total > 0) onProgress?.call(sent / total);
        },
      );
      onProgress?.call(1);
    } on Object {
      throw const ChartImageRefused();
    }
  }

  @override
  Future<void> delete(String id) => apiCall(
    () => _dio.delete<Object?>('journal/${Uri.encodeComponent(id)}'),
    (_) {},
  );

  @override
  Future<List<Strategy>> strategies() =>
      apiCall(() => _dio.get<Object?>('strategies'), decodeStrategies);
}

final journalApiProvider = Provider<JournalApi>(
  (ref) => DioJournalApi(
    ref.watch(apiDioProvider),
    storage: ref.watch(storageDioProvider),
  ),
);
