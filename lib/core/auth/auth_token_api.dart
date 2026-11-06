import 'package:dio/dio.dart';

import '../errors/api_failure.dart';
import 'session.dart';

/// The two token calls the session itself needs. They go through a client
/// without the auth interceptor, so a refresh never waits on a refresh.
abstract interface class AuthTokenApi {
  /// `POST /auth/refresh`: a new pair; the old refresh token is retired.
  Future<Session> refresh(String refreshToken);

  /// `POST /auth/logout`: always 204; works with an expired access token.
  Future<void> logout(String refreshToken, {String? fcmToken});
}

class DioAuthTokenApi implements AuthTokenApi {
  const DioAuthTokenApi(this._dio);

  final Dio _dio;

  @override
  Future<Session> refresh(String refreshToken) => apiCall(
    () => _dio.post<Object?>(
      'auth/refresh',
      data: {'refreshToken': refreshToken},
    ),
    decodeSession,
  );

  @override
  Future<void> logout(String refreshToken, {String? fcmToken}) => apiCall(
    () => _dio.post<Object?>(
      'auth/logout',
      data: {'refreshToken': refreshToken, 'fcmToken': ?fcmToken},
    ),
    (_) {},
  );
}
