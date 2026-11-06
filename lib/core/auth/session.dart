import '../json/json_read.dart';

enum UserRole { trader, admin }

UserRole decodeRole(String value) => switch (value) {
  'TRADER' => UserRole.trader,
  'ADMIN' => UserRole.admin,
  _ => throw DecodeException('role $value is unknown'),
};

String encodeRole(UserRole role) => switch (role) {
  UserRole.trader => 'TRADER',
  UserRole.admin => 'ADMIN',
};

/// The token pair of `/auth/login` and `/auth/refresh` (fe-guide auth chapter).
/// The access token lives in memory only; the refresh token is also kept in
/// secure storage so the session survives an app restart (T-088).
class Session {
  const Session({
    required this.accessToken,
    required this.accessTokenExpiresAt,
    required this.refreshToken,
    required this.refreshTokenExpiresAt,
    required this.role,
  });

  final String accessToken;
  final DateTime accessTokenExpiresAt;
  final String refreshToken;
  final DateTime refreshTokenExpiresAt;
  final UserRole role;

  @override
  String toString() => 'Session($role, access until $accessTokenExpiresAt)';
}

Session decodeSession(Object? body) {
  final json = asJsonObject(body, 'session');
  return Session(
    accessToken: readString(json, 'accessToken'),
    accessTokenExpiresAt: readInstant(json, 'accessTokenExpiresAt'),
    refreshToken: readString(json, 'refreshToken'),
    refreshTokenExpiresAt: readInstant(json, 'refreshTokenExpiresAt'),
    role: decodeRole(readString(json, 'role')),
  );
}

/// What secure storage keeps between launches.
class StoredSession {
  const StoredSession({
    required this.refreshToken,
    required this.refreshTokenExpiresAt,
    required this.role,
  });

  final String refreshToken;
  final DateTime refreshTokenExpiresAt;
  final UserRole role;
}
