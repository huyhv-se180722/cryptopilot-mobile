/// Hand-written readers for API bodies: every payload is decoded from `Object?`
/// into domain types, and anything unexpected fails loudly instead of leaking
/// `dynamic` into the app (D-141: no code generation).
class DecodeException implements Exception {
  const DecodeException(this.message);

  final String message;

  @override
  String toString() => 'DecodeException: $message';
}

Map<String, Object?> asJsonObject(Object? value, String what) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) return value.cast<String, Object?>();
  throw DecodeException('$what is not an object');
}

String readString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is String) return value;
  throw DecodeException('$key is not a string');
}

String? readOptionalString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null || value is String) return value as String?;
  throw DecodeException('$key is not a string');
}

bool readBool(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is bool) return value;
  throw DecodeException('$key is not a boolean');
}

/// An ISO 8601 instant, returned in UTC.
DateTime readInstant(Map<String, Object?> json, String key) {
  final text = readString(json, key);
  final parsed = DateTime.tryParse(text);
  if (parsed == null) throw DecodeException('$key is not an instant');
  return parsed.toUtc();
}
