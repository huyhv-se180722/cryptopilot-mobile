/// The RFC 9457 problem body every backend error carries (TD 5.1, D-25): the
/// client branches on [code] and shows the text of [messageCode].
class ApiProblem {
  const ApiProblem({
    required this.status,
    required this.code,
    required this.messageCode,
    this.traceId,
    this.messageArgs = const [],
    this.fieldErrors = const {},
  });

  final int status;
  final String code;
  final String messageCode;
  final String? traceId;
  final List<String> messageArgs;

  /// Field name → message code. Binding notes such as "is required" arrive as
  /// plain English and are read as MSG01.
  final Map<String, String> fieldErrors;
}

/// Reads a problem body, or `null` when [body] is not one.
ApiProblem? decodeApiProblem(Object? body, int status) {
  if (body is! Map) return null;
  final code = body['code'];
  final messageCode = body['messageCode'];
  if (code is! String || messageCode is! String) return null;
  final traceId = body['traceId'];
  final args = body['messageArgs'];
  final errors = body['errors'];
  return ApiProblem(
    status: status,
    code: code,
    messageCode: messageCode,
    traceId: traceId is String ? traceId : null,
    messageArgs: args is List ? [for (final a in args) '$a'] : const [],
    fieldErrors: errors is Map
        ? {
            for (final entry in errors.entries)
              '${entry.key}': _fieldCode(entry.value),
          }
        : const {},
  );
}

String _fieldCode(Object? value) {
  if (value is String && RegExp(r'^MSG\d{2}$').hasMatch(value)) return value;
  return 'MSG01';
}
