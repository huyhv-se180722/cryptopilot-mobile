import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session.dart';
import '../../../core/errors/api_failure.dart';
import '../../../core/http/http_providers.dart';

/// The public auth calls of SCR-04…06 (fe-guide auth module).
abstract interface class AuthApi {
  /// `POST /auth/login`. 401 here is MSG08, never "session expired".
  Future<Session> login({
    required String email,
    required String password,
    required bool rememberMe,
  });

  /// `POST /auth/resend-verification`: 202 MSG05 whatever the address holds.
  Future<void> resendVerification(String email);

  /// `POST /auth/forgot-password`: 202 MSG12 for every address.
  Future<void> forgotPassword(String email);

  /// `POST /auth/reset-password`: 200 MSG13; every session of the account ends.
  Future<void> resetPassword({
    required String token,
    required String newPassword,
    required String confirmPassword,
  });
}

class DioAuthApi implements AuthApi {
  const DioAuthApi(this._dio);

  final Dio _dio;

  @override
  Future<Session> login({
    required String email,
    required String password,
    required bool rememberMe,
  }) => apiCall(
    () => _dio.post<Object?>(
      'auth/login',
      data: {'email': email, 'password': password, 'rememberMe': rememberMe},
    ),
    decodeSession,
  );

  @override
  Future<void> resendVerification(String email) => apiCall(
    () =>
        _dio.post<Object?>('auth/resend-verification', data: {'email': email}),
    (_) {},
  );

  @override
  Future<void> forgotPassword(String email) => apiCall(
    () => _dio.post<Object?>('auth/forgot-password', data: {'email': email}),
    (_) {},
  );

  @override
  Future<void> resetPassword({
    required String token,
    required String newPassword,
    required String confirmPassword,
  }) => apiCall(
    () => _dio.post<Object?>(
      'auth/reset-password',
      data: {
        'token': token,
        'newPassword': newPassword,
        'confirmPassword': confirmPassword,
      },
    ),
    (_) {},
  );
}

final authApiProvider = Provider<AuthApi>(
  (ref) => DioAuthApi(ref.watch(plainDioProvider)),
);
