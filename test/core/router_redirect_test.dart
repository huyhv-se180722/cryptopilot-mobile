import 'package:cryptopilot_mobile/core/auth/session.dart';
import 'package:cryptopilot_mobile/core/auth/session_controller.dart';
import 'package:cryptopilot_mobile/core/router/app_router.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  test('while the session resumes, everything waits on the splash', () {
    expect(redirectFor(const SessionRestoring(), Routes.home), Routes.splash);
    expect(
      redirectFor(const SessionUnavailable(networkDown), Routes.login),
      Routes.splash,
    );
    expect(redirectFor(const SessionRestoring(), Routes.splash), isNull);
  });

  test('signed out, only the public auth screens open', () {
    const out = SignedOut();
    expect(redirectFor(out, Routes.home), Routes.login);
    expect(redirectFor(out, Routes.account), Routes.login);
    expect(redirectFor(out, Routes.splash), Routes.login);
    expect(redirectFor(out, Routes.forgotPassword), isNull);
    expect(redirectFor(out, Routes.resetPassword), isNull);
  });

  test('a Trader lands on Home and stays inside the app', () {
    const trader = SignedIn(UserRole.trader);
    expect(redirectFor(trader, Routes.login), Routes.home);
    expect(redirectFor(trader, Routes.splash), Routes.home);
    expect(redirectFor(trader, Routes.plans), isNull);
    expect(redirectFor(trader, Routes.account), isNull);
    expect(redirectFor(trader, Routes.resetPassword), isNull);
  });

  test('an Admin only sees the notice (Q-90 proposal)', () {
    const admin = SignedIn(UserRole.admin);
    expect(redirectFor(admin, Routes.home), Routes.adminNotice);
    expect(redirectFor(admin, Routes.adminNotice), isNull);
  });
}
