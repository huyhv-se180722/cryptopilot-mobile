import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session_controller.dart';
import '../config/config_provider.dart';
import '../state/poll_gate.dart';
import 'auth_interceptor.dart';
import 'rate_limit_interceptor.dart';

Dio _baseDio(String apiBaseUrl) => Dio(
  BaseOptions(
    baseUrl: '$apiBaseUrl/',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 20),
    sendTimeout: const Duration(seconds: 20),
    contentType: Headers.jsonContentType,
    responseType: ResponseType.json,
  ),
);

/// Public calls (sign in, refresh, password reset): no bearer token.
final plainDioProvider = Provider<Dio>(
  (ref) => _baseDio(ref.watch(appConfigProvider).apiBaseUrl),
);

/// Calls of a signed-in user: bearer token, refresh before expiry and once
/// after a 401; a 429 holds polling until its window ends (T-138).
final apiDioProvider = Provider<Dio>((ref) {
  final dio = _baseDio(ref.watch(appConfigProvider).apiBaseUrl);
  dio.interceptors.addAll([
    AuthInterceptor(
      dio: dio,
      session: () => ref.read(sessionControllerProvider.notifier),
    ),
    RateLimitInterceptor(
      (retryAfter) =>
          ref.read(pollGateProvider.notifier).rateLimited(retryAfter),
    ),
  ]);
  return dio;
});

/// The client of the media storage's signed uploads (D-98): no base URL and
/// none of the app's tokens, which must never reach the storage.
final storageDioProvider = Provider<Dio>((_) => Dio());
