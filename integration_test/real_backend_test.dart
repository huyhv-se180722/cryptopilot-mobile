// Runs on a device against a running backend (not part of `flutter test`):
//
//   flutter test integration_test/real_backend_test.dart -d emulator-5554 \
//     --dart-define=LOGIN_EMAIL=... --dart-define=LOGIN_PASSWORD=...
//
// Uses the real secure storage and the real API; only the browser is faked.
import 'package:cryptopilot_mobile/app.dart';
import 'package:cryptopilot_mobile/core/auth/token_store.dart';
import 'package:cryptopilot_mobile/core/web/web_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const email = String.fromEnvironment('LOGIN_EMAIL');
const password = String.fromEnvironment('LOGIN_PASSWORD');

class NoBrowser implements WebLinks {
  @override
  Future<bool> open(String path) async => true;
}

Widget app() => ProviderScope(
  overrides: [webLinksProvider.overrideWithValue(NoBrowser())],
  retry: (_, _) => null,
  child: const CryptoPilotApp(),
);

/// Waits for [finder] on a slow device without pumpAndSettle (spinners run
/// forever).
Future<void> waitFor(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 300; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out waiting for $finder');
}

Future<void> enterCredentials(WidgetTester tester, String secret) async {
  await tester.enterText(find.byKey(const Key('login-email')), email);
  await tester.enterText(
    find.descendant(
      of: find.byKey(const Key('login-password')),
      matching: find.byType(TextField),
    ),
    secret,
  );
  await tester.tap(find.byKey(const Key('login-submit')));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('sign in, then a restart resumes the session (T-088)', (
    tester,
  ) async {
    expect(email, isNotEmpty, reason: 'pass --dart-define=LOGIN_EMAIL');
    await SecureTokenStore().clear();

    await tester.pumpWidget(app());
    await waitFor(tester, find.byKey(const Key('login-submit')));

    await enterCredentials(tester, 'WrongPassword1');
    await waitFor(
      tester,
      find.text('Incorrect email or password. Please check again.'),
    );

    await enterCredentials(tester, password);
    await waitFor(tester, find.byType(NavigationBar));
    final stored = await SecureTokenStore().read();
    expect(stored, isNotNull, reason: 'refresh token kept in the Keystore');

    await tester.tap(find.byKey(const Key('open-account')).first);
    await waitFor(tester, find.text(email));

    // "Restart": drop every provider (tokens in memory are gone) and start
    // again from secure storage, as a new process does.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app());
    await waitFor(tester, find.byType(NavigationBar));
    final rotated = await SecureTokenStore().read();
    expect(rotated!.refreshToken, isNot(stored!.refreshToken));

    // SCR-09 over the real STOMP channel: the overview fills the prices and
    // the board says Live.
    await tester.tap(find.text('Markets'));
    await waitFor(tester, find.byKey(const Key('row-spot-BTCUSDT')));
    await waitFor(tester, find.text('Live'));
    await waitFor(
      tester,
      find.descendant(
        of: find.byKey(const Key('row-spot-BTCUSDT')),
        matching: find.textContaining(RegExp(r'^\d{1,3}(,\d{3})*\.\d{2}$')),
      ),
    );
    await tester.tap(find.byKey(const Key('row-spot-BTCUSDT')));
    await waitFor(tester, find.text('24h high'));
  });
}
