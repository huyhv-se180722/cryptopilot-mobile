import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session_controller.dart';
import '../config/config_provider.dart';
import 'auth_interceptor.dart';

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
/// after a 401.
final apiDioProvider = Provider<Dio>((ref) {
  final dio = _baseDio(ref.watch(appConfigProvider).apiBaseUrl);
  dio.interceptors.add(
    AuthInterceptor(
      dio: dio,
      session: () => ref.read(sessionControllerProvider.notifier),
    ),
  );
  return dio;
});
