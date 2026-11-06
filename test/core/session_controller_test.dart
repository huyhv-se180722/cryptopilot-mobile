import 'dart:async';

import 'package:cryptopilot_mobile/core/auth/session.dart';
import 'package:cryptopilot_mobile/core/auth/session_controller.dart';
import 'package:cryptopilot_mobile/core/auth/token_store.dart';
import 'package:cryptopilot_mobile/core/errors/api_failure.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  late MemoryTokenStore store;
  late FakeAuthTokenApi tokens;
  late ProviderContainer container;

  ProviderContainer start() {
    container = ProviderContainer(
      overrides: baseOverrides(store: store, tokens: tokens),
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
    container.read(sessionControllerProvider);
    return container;
  }

  SessionState state() => container.read(sessionControllerProvider);
  SessionController controller() =>
      container.read(sessionControllerProvider.notifier);

  setUp(() {
    store = MemoryTokenStore();
    tokens = FakeAuthTokenApi();
  });

  group('resume at launch (T-088: refresh works after app restart)', () {
    test('without a stored session the user signs in', () async {
      start();
      await settle();

      expect(state(), isA<SignedOut>());
      expect(tokens.refreshCalls, 0);
    });

    test('a stored session is refreshed once and kept rotated', () async {
      store.stored = storedFor('saved');
      start();
      await settle();

      expect(state(), isA<SignedIn>());
      expect(tokens.refreshedWith, ['refresh-saved']);
      expect(store.stored!.refreshToken, 'refresh-rotated');
    });

    test('an Admin resumes as an Admin', () async {
      store.stored = storedFor('saved', role: UserRole.admin);
      tokens.onRefresh = (_) async => sessionFor('a', role: UserRole.admin);
      start();
      await settle();

      expect((state() as SignedIn).role, UserRole.admin);
    });

    test('a stored token past its expiry is dropped without a call', () async {
      store.stored = StoredSession(
        refreshToken: 'refresh-old',
        refreshTokenExpiresAt: now.subtract(const Duration(minutes: 1)),
        role: UserRole.trader,
      );
      start();
      await settle();

      expect(state(), isA<SignedOut>());
      expect(store.stored, isNull);
      expect(tokens.refreshCalls, 0);
    });

    test('a refused token signs out quietly (no MSG44 at launch)', () async {
      store.stored = storedFor('revoked');
      tokens.onRefresh = (_) async =>
          throw problem(401, 'SESSION_EXPIRED', 'MSG44');
      start();
      await settle();

      expect(state(), isA<SignedOut>());
      expect((state() as SignedOut).expired, isFalse);
      expect(store.stored, isNull);
    });

    test('offline keeps the token and offers to try again', () async {
      store.stored = storedFor('saved');
      tokens.onRefresh = (_) async => throw networkDown;
      start();
      await settle();

      expect(state(), isA<SessionUnavailable>());
      expect(store.stored, isNotNull);

      tokens.onRefresh = (_) async => sessionFor('back');
      await controller().restore();
      expect(state(), isA<SignedIn>());
    });
  });

  group('while signed in', () {
    Future<void> signedIn(Session session) async {
      start();
      await settle();
      await controller().signIn(session);
    }

    test('a fresh access token is used as it is', () async {
      await signedIn(sessionFor('fresh'));

      expect(await controller().accessToken(), 'access-fresh');
      expect(tokens.refreshCalls, 0);
    });

    test('refreshes about 60 s before the access token expires', () async {
      await signedIn(
        sessionFor('ending', accessFor: const Duration(seconds: 30)),
      );

      expect(await controller().accessToken(), 'access-rotated');
      expect(tokens.refreshCalls, 1);
    });

    test('concurrent callers share one refresh (TD 7.15 reuse)', () async {
      await signedIn(sessionFor('ending', accessFor: Duration.zero));
      final gate = Completer<Session>();
      tokens.onRefresh = (_) => gate.future;

      final first = controller().accessToken();
      final second = controller().accessToken();
      final third = controller().accessTokenAfterUnauthorized('access-ending');
      gate.complete(sessionFor('rotated'));

      expect(await Future.wait([first, second, third]), [
        'access-rotated',
        'access-rotated',
        'access-rotated',
      ]);
      expect(tokens.refreshCalls, 1);
    });

    test(
      'a 401 with a token already replaced does not refresh again',
      () async {
        await signedIn(sessionFor('new'));

        expect(
          await controller().accessTokenAfterUnauthorized('access-old'),
          'access-new',
        );
        expect(tokens.refreshCalls, 0);
      },
    );

    test('a refused refresh ends the session with MSG44', () async {
      await signedIn(sessionFor('ending', accessFor: Duration.zero));
      tokens.onRefresh = (_) async =>
          throw problem(401, 'SESSION_EXPIRED', 'MSG44');

      await expectLater(
        controller().accessToken(),
        throwsA(isA<SessionExpiredFailure>()),
      );
      expect((state() as SignedOut).expired, isTrue);
      expect(store.stored, isNull);
    });

    test('sign out clears the tokens even when the call fails', () async {
      await signedIn(sessionFor('s'));
      tokens.logoutError = networkDown;

      await controller().signOut();

      expect(tokens.logoutCalls, 1);
      expect(state(), isA<SignedOut>());
      expect(store.stored, isNull);
    });
  });
}
