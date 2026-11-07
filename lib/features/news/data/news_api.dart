import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/http/http_providers.dart';
import '../domain/news.dart';

/// `GET /news` (checked on backend develop 25ba960): the last 7 days by
/// default, newest first.
abstract interface class NewsApi {
  Future<List<NewsArticle>> latest({int pageSize = 3});
}

class DioNewsApi implements NewsApi {
  const DioNewsApi(this._dio);

  final Dio _dio;

  @override
  Future<List<NewsArticle>> latest({int pageSize = 3}) => apiCall(
    () => _dio.get<Object?>(
      'news',
      queryParameters: {'page': 1, 'pageSize': pageSize},
    ),
    decodeNewsPage,
  );
}

final newsApiProvider = Provider<NewsApi>(
  (ref) => DioNewsApi(ref.watch(apiDioProvider)),
);
