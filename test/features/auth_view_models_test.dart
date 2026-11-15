import 'package:cryptopilot_mobile/core/auth/session_controller.dart';
import 'package:cryptopilot_mobile/core/auth/token_store.dart';
import 'package:cryptopilot_mobile/core/errors/api_failure.dart';
import 'package:cryptopilot_mobile/features/auth/application/forgot_password_controller.dart';
import 'package:cryptopilot_mobile/features/auth/application/login_controller.dart';
import 'package:cryptopilot_mobile/features/auth/application/reset_password_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

/// The view models of SCR-04, SCR-05 and SCR-06 without their widgets
/// (D-150): the screens only show these states.
void main() {
  late MemoryTokenStore store;
  late FakeAuthTokenApi tokens;
  late FakeAuthApi auth;
  late ProviderContainer container;

  Future<void> start() async {
    container = ProviderContainer(
      overrides: baseOverrides(store: store, tokens: tokens, auth: auth),
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
    container.read(sessionControllerProvider);
    await settle();
  }

  /// Keeps an auto-disposed view model alive, as its screen does.
  void hold<T>(ProviderListenable<T> provider) {
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
  }

  setUp(() {
    store = MemoryTokenStore();
    tokens = FakeAuthTokenApi();
    auth = FakeAuthApi();
  });

  group('LoginController (SCR-04)', () {
    LoginState state() => container.read(loginControllerProvider);
    LoginController controller() =>
        container.read(loginControllerProvider.notifier);

    Future<void> begin() async {
      await start();
      hold(loginControllerProvider);
    }

    test('empty fields: MSG01 under each, no call', () async {
      var calls = 0;
      auth.onLogin = (_, _, _) async {
        calls++;
        return sessionFor('login');
      };
      await begin();

      await controller().submit(email: '  ', password: '', rememberMe: true);

      expect(state().fieldErrors, {'email': 'MSG01', 'password': 'MSG01'});
      expect(state().pending, isFalse);
      expect(calls, 0);
    });

    test('a malformed e-mail: MSG02, no call', () async {
      await begin();
      await controller().submit(
        email: 'trader@',
        password: 'Secret123',
        rememberMe: true,
      );
      expect(state().fieldErrors, {'email': 'MSG02'});
      expect(container.read(sessionControllerProvider), isA<SignedOut>());
    });

    test('success sends the trimmed address and keeps the session', () async {
      final sent = <Object>[];
      auth.onLogin = (email, password, rememberMe) async {
        sent.addAll([email, password, rememberMe]);
        return sessionFor('login');
      };
      await begin();

      await controller().submit(
        email: ' trader@cryptopilot.invalid ',
        password: 'Secret123',
        rememberMe: false,
      );

      expect(sent, ['trader@cryptopilot.invalid', 'Secret123', false]);
      expect(container.read(sessionControllerProvider), isA<SignedIn>());
      expect(store.stored, isNotNull);
      expect(state().pending, isFalse);
      expect(state().failure, isNull);
    });

    test(
      'wrong credentials (MSG08) explain themselves in the banner',
      () async {
        auth.onLogin = (_, _, _) async =>
            throw problem(401, 'INVALID_CREDENTIALS', 'MSG08');
        await begin();

        await controller().submit(
          email: 'trader@cryptopilot.invalid',
          password: 'Wrong123',
          rememberMe: true,
        );

        final failure = state().failure! as ProblemFailure;
        expect(failure.problem.messageCode, 'MSG08');
        expect(state().offerResend, isFalse);
        expect(state().fieldErrors, isEmpty);
        expect(state().pending, isFalse);
      },
    );

    test('a field error from the server goes under its field, not the '
        'banner', () async {
      auth.onLogin = (_, _, _) async => throw problem(
        400,
        'VALIDATION_FAILED',
        'MSG01',
        fields: {'email': 'MSG02'},
      );
      await begin();

      await controller().submit(
        email: 'trader@cryptopilot.invalid',
        password: 'Secret123',
        rememberMe: true,
      );

      expect(state().fieldErrors, {'email': 'MSG02'});
      expect(state().failure, isNull);
    });

    testWidgets('an unverified e-mail offers the link again; sending it '
        'starts a 60 s cooldown', (tester) async {
      auth.onLogin = (_, _, _) async =>
          throw problem(403, 'EMAIL_NOT_VERIFIED', 'MSG10');
      await tester.runAsync(begin);
      await tester.runAsync(
        () => controller().submit(
          email: 'trader@cryptopilot.invalid',
          password: 'Secret123',
          rememberMe: true,
        ),
      );
      expect(state().offerResend, isTrue);
      expect(state().failure, isNotNull);

      await controller().resend(' trader@cryptopilot.invalid ');
      expect(auth.emails, ['trader@cryptopilot.invalid']);
      expect(state().notice, LoginNotice.resendSent);
      expect(state().failure, isNull);
      expect(state().offerResend, isFalse);
      expect(state().resendWait, 60);

      await tester.pump(const Duration(seconds: 1));
      expect(state().resendWait, 59);
      await tester.pump(const Duration(seconds: 59));
      expect(state().resendWait, 0);
    });

    testWidgets('a link that cannot be sent says why and stays on offer', (
      tester,
    ) async {
      auth.onLogin = (_, _, _) async =>
          throw problem(403, 'EMAIL_NOT_VERIFIED', 'MSG10');
      auth.resendError = networkDown;
      await tester.runAsync(begin);
      await tester.runAsync(
        () => controller().submit(
          email: 'trader@cryptopilot.invalid',
          password: 'Secret123',
          rememberMe: true,
        ),
      );

      await controller().resend('trader@cryptopilot.invalid');

      expect(state().failure, isA<NetworkFailure>());
      expect(state().notice, isNull);
      expect(state().offerResend, isTrue);
      await tester.pump(const Duration(seconds: 60));
      expect(state().resendWait, 0);
    });

    test('after a session that ended (MSG44) the banner says so; the next '
        'attempt clears it', () async {
      await start();
      final session = container.read(sessionControllerProvider.notifier);
      await session.signIn(sessionFor('ending', accessFor: Duration.zero));
      tokens.onRefresh = (_) async =>
          throw problem(401, 'SESSION_EXPIRED', 'MSG44');
      await expectLater(
        session.accessToken(),
        throwsA(isA<SessionExpiredFailure>()),
      );
      hold(loginControllerProvider);

      expect(state().notice, LoginNotice.sessionExpired);

      await controller().submit(email: '', password: '', rememberMe: true);
      expect(state().notice, isNull);
    });
  });

  group('ForgotPasswordController (SCR-05)', () {
    ForgotPasswordState state() =>
        container.read(forgotPasswordControllerProvider);
    ForgotPasswordController controller() =>
        container.read(forgotPasswordControllerProvider.notifier);

    Future<void> begin() async {
      await start();
      hold(forgotPasswordControllerProvider);
    }

    test('an empty or malformed address is refused before a call', () async {
      await begin();
      await controller().submit('');
      expect(state().emailError, 'MSG01');
      await controller().submit('trader@');
      expect(state().emailError, 'MSG02');
      expect(auth.forgotCalls, 0);
      expect(state().sent, isFalse);
    });

    testWidgets('an accepted request is MSG12 and holds the button 60 s', (
      tester,
    ) async {
      await tester.runAsync(begin);

      await controller().submit(' trader@cryptopilot.invalid ');

      expect(auth.emails, ['trader@cryptopilot.invalid']);
      expect(state().sent, isTrue);
      expect(state().emailError, isNull);
      expect(state().pending, isFalse);
      expect(state().wait, 60);
      await tester.pump(const Duration(seconds: 30));
      expect(state().wait, 30);
      await tester.pump(const Duration(seconds: 30));
      expect(state().wait, 0);
    });

    test('a field error goes under the field, any other failure in the '
        'banner', () async {
      auth.forgotError = problem(
        400,
        'VALIDATION_FAILED',
        'MSG01',
        fields: {'email': 'MSG02'},
      );
      await begin();
      await controller().submit('trader@cryptopilot.invalid');
      expect(state().emailError, 'MSG02');
      expect(state().failure, isNull);

      auth.forgotError = networkDown;
      await controller().submit('trader@cryptopilot.invalid');
      expect(state().emailError, isNull);
      expect(state().failure, isA<NetworkFailure>());
      expect(state().sent, isFalse);
      expect(state().wait, 0);
    });
  });

  group('ResetPasswordController (SCR-06)', () {
    ResetPasswordState state(String? token) =>
        container.read(resetPasswordControllerProvider(token));
    ResetPasswordController controller(String? token) =>
        container.read(resetPasswordControllerProvider(token).notifier);

    Future<void> begin(String? token) async {
      await start();
      hold(resetPasswordControllerProvider(token));
    }

    test('a link without a token is invalid at once (MSG07)', () async {
      await begin(null);
      expect(state(null).linkInvalid, isTrue);
      await begin('');
      expect(state('').linkInvalid, isTrue);
    });

    test(
      'the new password must meet BR-02 and match its confirmation',
      () async {
        var calls = 0;
        auth.onReset = () async => calls++;
        await begin('t');

        expect(
          await controller('t').submit(password: '', confirm: ''),
          isFalse,
        );
        expect(state('t').fieldErrors, {
          'newPassword': 'MSG01',
          'confirmPassword': 'MSG01',
        });

        await controller('t').submit(password: 'weak', confirm: 'other');
        expect(state('t').fieldErrors, {
          'newPassword': 'MSG03',
          'confirmPassword': passwordsDifferCode,
        });
        expect(calls, 0);
      },
    );

    test('a changed password forgets the session of this device', () async {
      await begin('t');
      await container
          .read(sessionControllerProvider.notifier)
          .signIn(sessionFor('s'));

      final changed = await controller(
        't',
      ).submit(password: 'Secret123', confirm: 'Secret123');

      expect(changed, isTrue);
      expect(container.read(sessionControllerProvider), isA<SignedOut>());
      expect(store.stored, isNull);
      expect(state('t').pending, isFalse);
    });

    test('a link the server refuses becomes invalid (MSG07)', () async {
      auth.onReset = () async =>
          throw problem(400, 'TOKEN_INVALID_OR_EXPIRED', 'MSG07');
      await begin('t');

      final changed = await controller(
        't',
      ).submit(password: 'Secret123', confirm: 'Secret123');

      expect(changed, isFalse);
      expect(state('t').linkInvalid, isTrue);
    });

    test('server field errors go under their field; the matching rule '
        'under the confirmation', () async {
      auth.onReset = () async => throw problem(
        400,
        'VALIDATION_FAILED',
        'MSG01',
        fields: {'newPassword': 'MSG03', 'confirmPasswordMatching': 'MSG15'},
      );
      await begin('t');

      await controller('t').submit(password: 'Secret123', confirm: 'Secret123');

      expect(state('t').fieldErrors, {
        'newPassword': 'MSG03',
        'confirmPassword': 'MSG15',
      });
      expect(state('t').failure, isNull);
    });

    test('any other failure is kept for the banner', () async {
      auth.onReset = () async => throw networkDown;
      await begin('t');

      await controller('t').submit(password: 'Secret123', confirm: 'Secret123');

      expect(state('t').failure, isA<NetworkFailure>());
      expect(state('t').linkInvalid, isFalse);
      expect(state('t').pending, isFalse);
    });
  });
}
