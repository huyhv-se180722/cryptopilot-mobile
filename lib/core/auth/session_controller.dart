import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errors/api_failure.dart';
import '../http/http_providers.dart';
import 'auth_token_api.dart';
import 'session.dart';
import 'token_store.dart';

sealed class SessionState {
  const SessionState();
}

/// Reading the stored refresh token at launch.
class SessionRestoring extends SessionState {
  const SessionRestoring();
}

/// A stored session exists but the server could not be reached to resume it.
/// The token is kept for the next try.
class SessionUnavailable extends SessionState {
  const SessionUnavailable(this.failure);

  final ApiFailure failure;
}

class SignedOut extends SessionState {
  const SignedOut({this.expired = false});

  /// The session ended under the user (refresh refused): show MSG44 once.
  final bool expired;
}

class SignedIn extends SessionState {
  const SignedIn(this.role);

  final UserRole role;
}

final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());

final authTokenApiProvider = Provider<AuthTokenApi>(
  (ref) => DioAuthTokenApi(ref.watch(plainDioProvider)),
);

/// "Now" for expiry checks; tests pin it.
final clockProvider = Provider<DateTime Function()>(
  (ref) =>
      () => DateTime.now().toUtc(),
);

final sessionControllerProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);

/// Owns the token pair. One refresh at a time (two refreshes with the same
/// token read as reuse and revoke the whole session, TD 7.15), a refresh about
/// 60 s before the access token expires, and a resume from secure storage at
/// launch so the session survives a restart (T-088).
class SessionController extends Notifier<SessionState> {
  static const refreshMargin = Duration(seconds: 60);

  Session? _session;
  Future<Session>? _refreshing;

  TokenStore get _store => ref.read(tokenStoreProvider);
  AuthTokenApi get _api => ref.read(authTokenApiProvider);
  DateTime _now() => ref.read(clockProvider)();

  @override
  SessionState build() {
    scheduleMicrotask(restore);
    return const SessionRestoring();
  }

  /// The current access token, refreshed first when it is about to expire.
  Future<String> accessToken() async {
    final session = _session;
    if (session == null) throw const SessionExpiredFailure();
    if (!_now().isBefore(
      session.accessTokenExpiresAt.subtract(refreshMargin),
    )) {
      return (await refresh()).accessToken;
    }
    return session.accessToken;
  }

  /// After a 401 with [usedToken]: refresh unless another call already did.
  Future<String> accessTokenAfterUnauthorized(String usedToken) async {
    final session = _session;
    if (session == null) throw const SessionExpiredFailure();
    if (session.accessToken != usedToken) return session.accessToken;
    return (await refresh()).accessToken;
  }

  /// Single-flight refresh. A refused refresh ends the session (MSG44).
  Future<Session> refresh() {
    final pending = _refreshing;
    if (pending != null) return pending;
    final session = _session;
    if (session == null) return Future.error(const SessionExpiredFailure());
    final future = _rotate(session.refreshToken);
    _refreshing = future;
    return future.whenComplete(() => _refreshing = null);
  }

  Future<Session> _rotate(String refreshToken) async {
    try {
      final next = await _api.refresh(refreshToken);
      await _keep(next);
      return next;
    } on ProblemFailure catch (failure) {
      if (failure.problem.status == 401) {
        await _end(expired: true);
        throw const SessionExpiredFailure();
      }
      rethrow;
    }
  }

  Future<void> restore() async {
    final stored = await _store.read();
    if (stored == null) {
      state = const SignedOut();
      return;
    }
    if (!_now().isBefore(stored.refreshTokenExpiresAt)) {
      await _store.clear();
      state = const SignedOut();
      return;
    }
    state = const SessionRestoring();
    final future = _resume(stored.refreshToken);
    _refreshing = future;
    try {
      await future;
    } on ApiFailure catch (failure) {
      // A refused token already signed out in _resume; anything else (offline,
      // a server error, a rate limit) keeps the token for another try.
      if (state is! SignedOut) state = SessionUnavailable(failure);
    } finally {
      _refreshing = null;
    }
  }

  Future<Session> _resume(String refreshToken) async {
    try {
      final next = await _api.refresh(refreshToken);
      await _keep(next);
      return next;
    } on ProblemFailure catch (failure) {
      if (failure.problem.status == 401) {
        // A token that died while the app was closed: sign in again quietly.
        await _end(expired: false);
      }
      rethrow;
    }
  }

  /// After `/auth/login`.
  Future<void> signIn(Session session) => _keep(session);

  /// `POST /auth/logout`, best effort; local tokens go whatever the answer.
  Future<void> signOut() async {
    final session = _session;
    if (session != null) {
      try {
        await _api.logout(session.refreshToken);
      } on ApiFailure {
        // The server ends a session it never hears about at its expiry.
      }
    }
    await _end(expired: false);
  }

  /// A password reset revokes every session of the account.
  Future<void> forget() => _end(expired: false);

  Future<void> _keep(Session session) async {
    _session = session;
    await _store.write(session);
    state = SignedIn(session.role);
  }

  Future<void> _end({required bool expired}) async {
    _session = null;
    await _store.clear();
    state = SignedOut(expired: expired);
  }
}
