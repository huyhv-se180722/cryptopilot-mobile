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

  /// MSG14. 400 MSG15 on a text over 4,000 characters, 404 MSG41. The
  /// review replaces the stored one: a field left out is cleared, the chart
  /// image too, whose key the detail does not return (Q-95), so the app
  /// saves a review only for a trade without an image.
  Future<JournalDetail> review(
    String id, {
    String? strategyId,
    String? setupDescription,
    String? lessonsLearned,
    String? mistakes,
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

class DioJournalApi implements JournalApi {
  const DioJournalApi(this._dio);

  final Dio _dio;

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
  }) => apiCall(
    () => _dio.put<Object?>(
      'journal/${Uri.encodeComponent(id)}/review',
      data: {
        'strategyId': strategyId,
        'setupDescription': setupDescription,
        'lessonsLearned': lessonsLearned,
        'mistakes': mistakes,
      },
    ),
    decodeJournalDetail,
  );

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
  (ref) => DioJournalApi(ref.watch(apiDioProvider)),
);
