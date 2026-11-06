import 'package:dio/dio.dart';

import '../json/json_read.dart';
import 'api_problem.dart';

/// What a repository throws: the screen turns it into text with
/// `failureText` and never sees dio.
sealed class ApiFailure implements Exception {
  const ApiFailure();
}

/// The backend answered with a problem body.
class ProblemFailure extends ApiFailure {
  const ProblemFailure(this.problem);

  final ApiProblem problem;

  String get code => problem.code;

  @override
  String toString() => 'ProblemFailure(${problem.status} ${problem.code})';
}

/// No answer: offline, refused connection or a timeout.
class NetworkFailure extends ApiFailure {
  const NetworkFailure({this.timeout = false});

  final bool timeout;

  @override
  String toString() => 'NetworkFailure(timeout: $timeout)';
}

/// The session ended while calling (refresh refused): MSG44.
class SessionExpiredFailure extends ApiFailure {
  const SessionExpiredFailure();
}

/// An answer the client cannot read (no problem body, or a body that does not
/// decode). Shown as MSG43.
class UnexpectedFailure extends ApiFailure {
  const UnexpectedFailure({this.status, this.traceId, this.cause});

  final int? status;
  final String? traceId;
  final Object? cause;

  @override
  String toString() => 'UnexpectedFailure($status, $cause)';
}

/// Maps whatever a dio call threw onto an [ApiFailure].
ApiFailure toApiFailure(Object error) {
  if (error is ApiFailure) return error;
  if (error is DecodeException) return UnexpectedFailure(cause: error);
  if (error is DioException) {
    final inner = error.error;
    if (inner is ApiFailure) return inner;
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const NetworkFailure(timeout: true);
      case DioExceptionType.connectionError:
        return const NetworkFailure();
      case DioExceptionType.badResponse:
        final response = error.response;
        final status = response?.statusCode ?? 0;
        final problem = decodeApiProblem(response?.data, status);
        if (problem != null) return ProblemFailure(problem);
        return UnexpectedFailure(status: status, cause: error);
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return inner == null || inner is! Exception
            ? UnexpectedFailure(cause: error)
            : const NetworkFailure();
    }
  }
  return UnexpectedFailure(cause: error);
}

/// Runs one API call and decodes its body, throwing only [ApiFailure].
Future<T> apiCall<T>(
  Future<Response<Object?>> Function() send,
  T Function(Object? body) decode,
) async {
  try {
    final response = await send();
    return decode(response.data);
  } catch (error) {
    throw toApiFailure(error);
  }
}
