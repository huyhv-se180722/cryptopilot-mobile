import 'package:dio/dio.dart';

import '../auth/session_controller.dart';
import '../errors/api_failure.dart';

/// Puts the access token on each call, refreshes it shortly before expiry, and
/// on a 401 refreshes once (unless another call already did) and replays the
/// call. A refused refresh surfaces as [SessionExpiredFailure].
class AuthInterceptor extends Interceptor {
  AuthInterceptor({required this.dio, required this.session});

  static const _retried = 'auth_retried';

  final Dio dio;
  final SessionController Function() session;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final token = await session().accessToken();
      options.headers['Authorization'] = 'Bearer $token';
      handler.next(options);
    } catch (error) {
      handler.reject(
        DioException(requestOptions: options, error: toApiFailure(error)),
      );
    }
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    if (err.response?.statusCode != 401 || options.extra[_retried] == true) {
      handler.next(err);
      return;
    }
    final used = '${options.headers['Authorization'] ?? ''}'.replaceFirst(
      'Bearer ',
      '',
    );
    try {
      final token = await session().accessTokenAfterUnauthorized(used);
      options.headers['Authorization'] = 'Bearer $token';
      options.extra[_retried] = true;
      handler.resolve(await dio.fetch<Object?>(options));
    } on DioException catch (retryError) {
      handler.next(retryError);
    } catch (error) {
      handler.next(
        DioException(requestOptions: options, error: toApiFailure(error)),
      );
    }
  }
}
