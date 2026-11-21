import 'package:dio/dio.dart';

/// Reports each 429 of the API (ADR-014: `Retry-After` in seconds, and the
/// same seconds as the first argument of MSG50) so polling waits for the end
/// of the window instead of being refused again. The error goes on as before.
class RateLimitInterceptor extends Interceptor {
  RateLimitInterceptor(this.onLimited);

  final void Function(Duration retryAfter) onLimited;

  /// When neither the header nor the body names the window: one minute,
  /// the length of ADR-014's fixed window.
  static const fallback = Duration(seconds: 60);
  static const longest = Duration(minutes: 5);

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final response = err.response;
    if (response != null && response.statusCode == 429) {
      onLimited(retryAfter(response));
    }
    handler.next(err);
  }

  static Duration retryAfter(Response<Object?> response) {
    final seconds =
        int.tryParse(response.headers.value('retry-after')?.trim() ?? '') ??
        _fromBody(response.data);
    if (seconds == null || seconds <= 0) return fallback;
    final wait = Duration(seconds: seconds);
    return wait > longest ? longest : wait;
  }

  static int? _fromBody(Object? body) {
    if (body is! Map) return null;
    final args = body['messageArgs'];
    if (args is! List || args.isEmpty) return null;
    return int.tryParse('${args.first}');
  }
}
