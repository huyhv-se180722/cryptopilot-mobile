import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/http/http_providers.dart';
import '../domain/academy.dart';

/// The Academy of T-114 (checked on backend develop 5c2398cb; outside the
/// SRS, D-155). The catalogue is public; the progress is the Trader's.
abstract interface class AcademyApi {
  /// Every topic, in display order.
  Future<List<AcademyTopic>> topics();

  /// Published lessons in reading order. [query] is 2–100 characters
  /// (400 MSG15 otherwise).
  Future<LessonPage> lessons({
    String? topic,
    LessonLevel? level,
    String? query,
    int page = 1,
    int pageSize = 20,
  });

  /// A published lesson; 404 MSG41 when there is none with [slug].
  Future<Lesson> lesson(String slug);

  /// The beginner path, in order.
  Future<List<LessonSummary>> path();

  /// The glossary, alphabetical; [letter] is one letter (400 MSG15).
  Future<List<GlossaryTerm>> terms({String? query, String? letter});

  Future<AcademyProgress> progress();

  /// Idempotent; 404 MSG41 for a lesson no longer published.
  Future<void> mark(String slug);

  /// Idempotent; 404 MSG41 for a lesson no longer published.
  Future<void> unmark(String slug);
}

class DioAcademyApi implements AcademyApi {
  const DioAcademyApi(this._dio);

  final Dio _dio;

  @override
  Future<List<AcademyTopic>> topics() =>
      apiCall(() => _dio.get<Object?>('academy/topics'), decodeTopics);

  @override
  Future<LessonPage> lessons({
    String? topic,
    LessonLevel? level,
    String? query,
    int page = 1,
    int pageSize = 20,
  }) => apiCall(
    () => _dio.get<Object?>(
      'academy/articles',
      queryParameters: {
        'topic': ?topic,
        'level': ?level?.wire,
        'q': ?query,
        'page': page,
        'pageSize': pageSize,
      },
    ),
    decodeLessonPage,
  );

  @override
  Future<Lesson> lesson(String slug) => apiCall(
    () => _dio.get<Object?>('academy/articles/${Uri.encodeComponent(slug)}'),
    decodeLesson,
  );

  @override
  Future<List<LessonSummary>> path() =>
      apiCall(() => _dio.get<Object?>('academy/path'), decodeLessonList);

  @override
  Future<List<GlossaryTerm>> terms({String? query, String? letter}) => apiCall(
    () => _dio.get<Object?>(
      'academy/terms',
      queryParameters: {'q': ?query, 'letter': ?letter},
    ),
    decodeTerms,
  );

  @override
  Future<AcademyProgress> progress() =>
      apiCall(() => _dio.get<Object?>('me/academy/progress'), decodeProgress);

  @override
  Future<void> mark(String slug) => apiCall(
    () =>
        _dio.post<Object?>('me/academy/progress/${Uri.encodeComponent(slug)}'),
    (_) {},
  );

  @override
  Future<void> unmark(String slug) => apiCall(
    () => _dio.delete<Object?>(
      'me/academy/progress/${Uri.encodeComponent(slug)}',
    ),
    (_) {},
  );
}

final academyApiProvider = Provider<AcademyApi>(
  (ref) => DioAcademyApi(ref.watch(apiDioProvider)),
);
