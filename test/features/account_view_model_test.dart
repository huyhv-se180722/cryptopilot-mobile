import 'package:cryptopilot_mobile/core/auth/session_controller.dart';
import 'package:cryptopilot_mobile/core/auth/token_store.dart';
import 'package:cryptopilot_mobile/core/errors/api_failure.dart';
import 'package:cryptopilot_mobile/features/account/application/account_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

/// The view model of the account screen without its widget (D-150).
void main() {
  late MemoryTokenStore store;
  late FakeAuthTokenApi tokens;
  late FakeProfileApi profile;
  late ProviderContainer container;

  Future<void> start() async {
    container = ProviderContainer(
      overrides: baseOverrides(store: store, tokens: tokens, profile: profile),
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
    container.read(sessionControllerProvider);
    await settle();
    await container
        .read(sessionControllerProvider.notifier)
        .signIn(sessionFor('s'));
    final subscription = container.listen(accountControllerProvider, (_, _) {});
    addTearDown(subscription.close);
    await settle();
  }

  AccountState state() => container.read(accountControllerProvider);
  AccountController controller() =>
      container.read(accountControllerProvider.notifier);

  setUp(() {
    store = MemoryTokenStore();
    tokens = FakeAuthTokenApi();
    profile = FakeProfileApi();
  });

  test('reads who is signed in when the screen opens', () async {
    await start();
    expect(state().profile!.displayName, 'Pro Trader');
    expect(state().profile!.notifyEmail, isTrue);
    expect(state().loadFailure, isNull);
  });

  test('a profile that cannot be read says why; Try again reads it', () async {
    profile.loadError = networkDown;
    await start();
    expect(state().profile, isNull);
    expect(state().loadFailure, isA<NetworkFailure>());

    profile.loadError = null;
    await controller().load();
    expect(state().loadFailure, isNull);
    expect(state().profile!.email, 'trader@cryptopilot.invalid');
  });

  test('a switch shows at once and is saved', () async {
    await start();
    final next = state().profile!.copyWith(notifyPush: true);

    final saving = controller().saveNotifications(next);
    expect(state().profile!.notifyPush, isTrue);
    expect(state().saving, isTrue);

    expect(await saving, isNull);
    expect(profile.saved, [(true, true)]);
    expect(state().profile!.notifyPush, isTrue);
    expect(state().saving, isFalse);
  });

  test('a failed save puts the switch back and returns the failure', () async {
    profile.saveError = networkDown;
    await start();

    final failure = await controller().saveNotifications(
      state().profile!.copyWith(notifyEmail: false),
    );

    expect(failure, isA<NetworkFailure>());
    expect(state().profile!.notifyEmail, isTrue);
    expect(state().saving, isFalse);
  });

  test('sign out ends the session on the server and on the device', () async {
    await start();
    await controller().signOut();

    expect(tokens.logoutCalls, 1);
    expect(container.read(sessionControllerProvider), isA<SignedOut>());
    expect(store.stored, isNull);
  });
}
