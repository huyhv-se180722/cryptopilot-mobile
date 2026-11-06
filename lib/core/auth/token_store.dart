import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'session.dart';

/// Keeps the refresh token between launches; never the access token.
abstract interface class TokenStore {
  Future<StoredSession?> read();

  Future<void> write(Session session);

  Future<void> clear();
}

/// Android Keystore / iOS Keychain through `flutter_secure_storage` (D-141).
class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _token = 'refresh_token';
  static const _expiresAt = 'refresh_token_expires_at';
  static const _role = 'role';

  final FlutterSecureStorage _storage;

  @override
  Future<StoredSession?> read() async {
    final token = await _storage.read(key: _token);
    final expiresAt = DateTime.tryParse(
      await _storage.read(key: _expiresAt) ?? '',
    );
    final role = await _storage.read(key: _role);
    if (token == null || expiresAt == null || role == null) return null;
    try {
      return StoredSession(
        refreshToken: token,
        refreshTokenExpiresAt: expiresAt.toUtc(),
        role: decodeRole(role),
      );
    } on Exception {
      return null;
    }
  }

  @override
  Future<void> write(Session session) async {
    await _storage.write(key: _token, value: session.refreshToken);
    await _storage.write(
      key: _expiresAt,
      value: session.refreshTokenExpiresAt.toIso8601String(),
    );
    await _storage.write(key: _role, value: encodeRole(session.role));
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _token);
    await _storage.delete(key: _expiresAt);
    await _storage.delete(key: _role);
  }
}

/// For tests and previews.
class MemoryTokenStore implements TokenStore {
  MemoryTokenStore([this.stored]);

  StoredSession? stored;

  @override
  Future<StoredSession?> read() async => stored;

  @override
  Future<void> write(Session session) async {
    stored = StoredSession(
      refreshToken: session.refreshToken,
      refreshTokenExpiresAt: session.refreshTokenExpiresAt,
      role: session.role,
    );
  }

  @override
  Future<void> clear() async => stored = null;
}
