import 'package:cryptopilot_mobile/app.dart';
import 'package:cryptopilot_mobile/core/auth/session.dart';
import 'package:cryptopilot_mobile/core/auth/token_store.dart';
import 'package:cryptopilot_mobile/core/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

class Harness {
  final store = MemoryTokenStore();
  final tokens = FakeAuthTokenApi();
  final auth = FakeAuthApi();
  final profile = FakeProfileApi();
  final web = FakeWebLinks();

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: baseOverrides(
          store: store,
          tokens: tokens,
          auth: auth,
          profile: profile,
          web: web,
        ),
        retry: (_, _) => null,
        child: const CryptoPilotApp(),
      ),
    );
    await frames(tester);
  }

  void go(WidgetTester tester, String location) => ProviderScope.containerOf(
    tester.element(find.byType(CryptoPilotApp)),
  ).read(appRouterProvider).go(location);
}

/// Splash and buttons animate forever, so pumpAndSettle cannot be used.
Future<void> frames(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> signIn(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('login-email')),
    'trader@cryptopilot.invalid',
  );
  await tester.enterText(
    find.descendant(
      of: find.byKey(const Key('login-password')),
      matching: find.byType(TextField),
    ),
    'Secret123',
  );
  await tester.tap(find.byKey(const Key('login-submit')));
  await frames(tester);
}

void main() {
  group('SCR-04 sign in', () {
    testWidgets('empty fields show MSG01 under each field', (tester) async {
      await Harness().pump(tester);

      expect(find.text('Sign in'), findsWidgets);
      await tester.tap(find.byKey(const Key('login-submit')));
      await frames(tester);

      expect(find.text('The email field is required.'), findsOneWidget);
      expect(find.text('The password field is required.'), findsOneWidget);
    });

    testWidgets('a malformed email shows MSG02 without a call', (tester) async {
      final h = Harness();
      var calls = 0;
      h.auth.onLogin = (_, _, _) async {
        calls++;
        return sessionFor('x');
      };
      await h.pump(tester);
      await tester.enterText(find.byKey(const Key('login-email')), 'nope');
      await tester.tap(find.byKey(const Key('login-submit')));
      await frames(tester);

      expect(find.text('Please enter a valid email address.'), findsOneWidget);
      expect(calls, 0);
    });

    testWidgets('wrong credentials show MSG08', (tester) async {
      final h = Harness();
      h.auth.onLogin = (_, _, _) async =>
          throw problem(401, 'INVALID_CREDENTIALS', 'MSG08');
      await h.pump(tester);
      await signIn(tester);

      expect(
        find.text('Incorrect email or password. Please check again.'),
        findsOneWidget,
      );
      expect(h.tokens.refreshCalls, 0);
    });

    testWidgets('a lock shows MSG09 with the minutes left', (tester) async {
      final h = Harness();
      h.auth.onLogin = (_, _, _) async =>
          throw problem(429, 'LOGIN_TEMPORARILY_LOCKED', 'MSG09', args: ['12']);
      await h.pump(tester);
      await signIn(tester);

      expect(
        find.text(
          'Too many failed attempts. Please try again after 12 minutes.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('an unverified email offers to resend the link', (
      tester,
    ) async {
      final h = Harness();
      h.auth.onLogin = (_, _, _) async =>
          throw problem(403, 'EMAIL_NOT_VERIFIED', 'MSG11');
      await h.pump(tester);
      await signIn(tester);

      expect(
        find.text(
          'Please verify your email before logging in. Resend verification email?',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Resend verification email'));
      await frames(tester);

      expect(h.auth.resendCalls, 1);
      expect(
        find.text(
          'If the address is registered and unverified, a new link is on its way.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('success opens Home and keeps a 30-day session', (
      tester,
    ) async {
      final h = Harness();
      bool? remembered;
      h.auth.onLogin = (_, _, rememberMe) async {
        remembered = rememberMe;
        return sessionFor('login');
      };
      await h.pump(tester);
      await signIn(tester);

      expect(remembered, isTrue);
      expect(h.store.stored!.refreshToken, 'refresh-login');
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Markets'), findsOneWidget);
    });

    testWidgets('Create account opens the website', (tester) async {
      final h = Harness();
      await h.pump(tester);
      await tester.scrollUntilVisible(
        find.text('Create a free account'),
        100,
        // The page, not the scrollables inside its text fields.
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Create a free account'));

      expect(h.web.opened, ['/register']);
    });
  });

  testWidgets('a stored session opens Home after a restart (T-088)', (
    tester,
  ) async {
    final h = Harness()..store.stored = storedFor('saved');
    await h.pump(tester);

    expect(h.tokens.refreshedWith, ['refresh-saved']);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('offline at launch keeps the session and retries', (
    tester,
  ) async {
    final h = Harness()..store.stored = storedFor('saved');
    h.tokens.onRefresh = (_) async => throw networkDown;
    await h.pump(tester);

    expect(find.text('Cannot reach CryptoPilot'), findsOneWidget);
    h.tokens.onRefresh = (_) async => sessionFor('back');
    await tester.tap(find.text('Try again'));
    await frames(tester);

    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('an Admin sees the web console notice and can sign out', (
    tester,
  ) async {
    final h = Harness();
    h.auth.onLogin = (_, _, _) async =>
        sessionFor('admin', role: UserRole.admin);
    await h.pump(tester);
    await signIn(tester);

    expect(
      find.text('The administration console is on the web'),
      findsOneWidget,
    );
    await tester.tap(find.text('Open the web console'));
    expect(h.web.opened, ['/admin']);

    await tester.tap(find.text('Sign out'));
    await frames(tester);
    expect(h.tokens.logoutCalls, 1);
    expect(find.byKey(const Key('login-submit')), findsOneWidget);
  });

  group('account screen (A-59)', () {
    Future<Harness> openAccount(WidgetTester tester) async {
      final h = Harness()..store.stored = storedFor('saved');
      await h.pump(tester);
      await tester.tap(find.byKey(const Key('open-account')));
      await frames(tester);
      return h;
    }

    testWidgets('shows who is signed in and saves the push switch', (
      tester,
    ) async {
      final h = await openAccount(tester);

      expect(find.text('Pro Trader'), findsOneWidget);
      expect(find.text('trader@cryptopilot.invalid'), findsOneWidget);
      await tester.tap(find.byKey(const Key('notify-push')));
      await frames(tester);

      expect(h.profile.saved, [(true, true)]);
      expect(find.text('Saved successfully.'), findsOneWidget);
    });

    testWidgets('a failed save puts the switch back', (tester) async {
      final h = Harness()..store.stored = storedFor('saved');
      h.profile.saveError = networkDown;
      await h.pump(tester);
      await tester.tap(find.byKey(const Key('open-account')));
      await frames(tester);
      await tester.tap(find.byKey(const Key('notify-push')));
      await frames(tester);

      final push = tester.widget<SwitchListTile>(
        find.byKey(const Key('notify-push')),
      );
      expect(push.value, isFalse);
      expect(
        find.text(
          'Unable to reach the server. Check your connection and try again.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('sign out asks first, then returns to sign in', (tester) async {
      final h = await openAccount(tester);
      await tester.scrollUntilVisible(find.byKey(const Key('sign-out')), 100);
      await tester.tap(find.byKey(const Key('sign-out')));
      await frames(tester);
      expect(
        find.text('Sign out of CryptoPilot on this device?'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
      await frames(tester);

      expect(h.tokens.logoutCalls, 1);
      expect(h.store.stored, isNull);
      expect(find.byKey(const Key('login-submit')), findsOneWidget);
    });
  });

  group('SCR-05 and SCR-06', () {
    testWidgets('forgot password always answers MSG12', (tester) async {
      final h = Harness();
      await h.pump(tester);
      await tester.tap(find.text('Forgot password?'));
      await frames(tester);
      await tester.enterText(
        find.byKey(const Key('forgot-email')),
        'someone@cryptopilot.invalid',
      );
      await tester.tap(find.byKey(const Key('forgot-submit')));
      await frames(tester);

      expect(h.auth.forgotCalls, 1);
      expect(
        find.text('If the email is registered, a reset link has been sent.'),
        findsOneWidget,
      );
      expect(find.text('Resend in 60s'), findsOneWidget);
    });

    testWidgets('a reset link without a token shows MSG07', (tester) async {
      final h = Harness();
      await h.pump(tester);
      h.go(tester, '/reset-password');
      await frames(tester);

      expect(find.text('This link is invalid or has expired.'), findsOneWidget);
      expect(find.text('Request a new link'), findsOneWidget);
    });

    testWidgets('a new password must meet BR-02 and match', (tester) async {
      final h = Harness();
      await h.pump(tester);
      h.go(tester, '/reset-password?token=t');
      await frames(tester);
      Finder field(String key) => find.descendant(
        of: find.byKey(Key(key)),
        matching: find.byType(TextField),
      );
      await tester.enterText(field('reset-password'), 'short');
      await tester.enterText(field('reset-confirm'), 'other');
      await tester.tap(find.byKey(const Key('reset-submit')));
      await frames(tester);

      expect(
        find.text(
          'Password must be 8-64 characters and include uppercase, lowercase letters and a digit.',
        ),
        findsOneWidget,
      );
      expect(find.text('The passwords do not match.'), findsOneWidget);
    });

    testWidgets('a reset ends the session and returns to sign in', (
      tester,
    ) async {
      final h = Harness();
      await h.pump(tester);
      h.go(tester, '/reset-password?token=t');
      await frames(tester);
      Finder field(String key) => find.descendant(
        of: find.byKey(Key(key)),
        matching: find.byType(TextField),
      );
      await tester.enterText(field('reset-password'), 'NewSecret1');
      await tester.enterText(field('reset-confirm'), 'NewSecret1');
      await tester.tap(find.byKey(const Key('reset-submit')));
      await frames(tester);

      expect(
        find.text('Your password has been changed. Please log in again.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('login-submit')), findsOneWidget);
    });

    testWidgets('an expired reset link from the server shows MSG07', (
      tester,
    ) async {
      final h = Harness();
      h.auth.onReset = () async =>
          throw problem(400, 'TOKEN_INVALID_OR_EXPIRED', 'MSG07');
      await h.pump(tester);
      h.go(tester, '/reset-password?token=old');
      await frames(tester);
      Finder field(String key) => find.descendant(
        of: find.byKey(Key(key)),
        matching: find.byType(TextField),
      );
      await tester.enterText(field('reset-password'), 'NewSecret1');
      await tester.enterText(field('reset-confirm'), 'NewSecret1');
      await tester.tap(find.byKey(const Key('reset-submit')));
      await frames(tester);

      expect(find.text('This link is invalid or has expired.'), findsOneWidget);
    });
  });
}
