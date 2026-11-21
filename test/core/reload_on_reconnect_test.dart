import 'dart:async';

import 'package:cryptopilot_mobile/core/auth/session_controller.dart';
import 'package:cryptopilot_mobile/core/auth/token_store.dart';
import 'package:cryptopilot_mobile/core/realtime/realtime_hub.dart';
import 'package:cryptopilot_mobile/core/realtime/reload_on_reconnect.dart';
import 'package:cryptopilot_mobile/features/notifications/application/notifications_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/realtime_fakes.dart';

void main() {
  late FakeTransport transport;
  late ProviderContainer container;
  late int reloads;

  // A screen controller in miniature: it listens to one queue and reads its
  // REST snapshot again only when pushes may have been missed.
  final screen = Provider<void>((ref) {
    final pushes = ref
        .read(realtimeHubProvider.notifier)
        .watch('/user/queue/test')
        .listen((_) {});
    ref
      ..onDispose(() => unawaited(pushes.cancel()))
      ..reloadOnReconnect(() => reloads++);
  });

  Future<void> start(WidgetTester tester) async {
    reloads = 0;
    transport = FakeTransport();
    container = ProviderContainer(
      overrides: baseOverrides(
        store: MemoryTokenStore(storedFor('saved')),
        tokens: FakeAuthTokenApi(),
        transport: transport,
      ),
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
    // The saved session is restored first, as when the app opens.
    container.read(sessionControllerProvider);
    await tester.pump();
    await tester.pump();
    container.listen(screen, (_, _) {});
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
  }

  void background(WidgetTester tester) {
    tester.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
      ..handleAppLifecycleStateChanged(AppLifecycleState.paused);
  }

  void foreground(WidgetTester tester) {
    tester.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  }

  testWidgets('the first connection right after the screen opens reads '
      'nothing again; a later reconnect reads once', (tester) async {
    await start(tester);
    expect(transport.connections, hasLength(1));
    transport.last.onConnected();
    await tester.pump();
    expect(reloads, 0);

    transport.last.drop();
    await tester.pump(const Duration(seconds: 1));
    expect(transport.connections, hasLength(2));
    transport.last.onConnected();
    await tester.pump();
    expect(reloads, 1);
    expect(container.read(realtimeHubProvider).generation, 2);
    await tester.pump(const Duration(seconds: 10));
    expect(reloads, 1);
  });

  testWidgets('a first connection that comes late reads once, since the '
      "screen's own read may have failed meanwhile", (tester) async {
    await start(tester);
    await tester.pump(const Duration(seconds: 11));
    transport.last.onConnected();
    await tester.pump();
    expect(reloads, 1);
  });

  testWidgets('a resume within the background grace reads nothing: the '
      'socket stayed open and missed no push', (tester) async {
    await start(tester);
    transport.last.onConnected();
    await tester.pump(const Duration(seconds: 11));

    background(tester);
    await tester.pump(const Duration(seconds: 20));
    foreground(tester);
    await tester.pump(const Duration(seconds: 15));
    expect(transport.connections, hasLength(1));
    expect(reloads, 0);
  });

  testWidgets('a resume after the socket closed reads once, on the new '
      'connection, not on resume as well', (tester) async {
    await start(tester);
    transport.last.onConnected();
    await tester.pump(const Duration(seconds: 11));

    background(tester);
    await tester.pump(const Duration(seconds: 31));
    expect(container.read(realtimeHubProvider).connected, isFalse);
    // Nothing reads while the app is away.
    await tester.pump(const Duration(minutes: 5));
    expect(reloads, 0);

    foreground(tester);
    await tester.pump();
    expect(transport.connections, hasLength(2));
    await tester.pump(const Duration(seconds: 2));
    transport.last.onConnected();
    await tester.pump(const Duration(seconds: 15));
    expect(reloads, 1);
  });

  testWidgets('a resume whose socket does not come back reads once after '
      'the fallback delay', (tester) async {
    await start(tester);
    transport.last.onConnected();
    await tester.pump(const Duration(seconds: 11));

    background(tester);
    await tester.pump(const Duration(seconds: 31));
    foreground(tester);
    await tester.pump(const Duration(seconds: 9));
    expect(reloads, 0);
    await tester.pump(const Duration(seconds: 2));
    expect(reloads, 1);
    // The late connection reads once more: the fallback could not know what
    // the socket would have pushed between the two.
    transport.last.onConnected();
    await tester.pump();
    expect(reloads, 2);
  });

  testWidgets('leaves no timer or listener behind once disposed', (
    tester,
  ) async {
    await start(tester);
    container.dispose();
    await tester.pump(const Duration(seconds: 31));
    expect(reloads, 0);
  });

  testWidgets('the bell reads its count once when the app opens and '
      'connects, once after a reconnect', (tester) async {
    final api = FakeNotificationApi();
    transport = FakeTransport();
    container = ProviderContainer(
      overrides: baseOverrides(
        store: MemoryTokenStore(storedFor('saved')),
        tokens: FakeAuthTokenApi(),
        transport: transport,
        notifications: api,
      ),
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
    container.read(sessionControllerProvider);
    await tester.pump();
    await tester.pump();
    container.listen(unreadCountProvider, (_, _) {});
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    transport.last.onConnected();
    await tester.pump(const Duration(seconds: 11));
    expect(api.calls.where((c) => c == 'count'), hasLength(1));

    transport.last.drop();
    await tester.pump(const Duration(seconds: 1));
    transport.last.onConnected();
    await tester.pump();
    expect(api.calls.where((c) => c == 'count'), hasLength(2));
  });

  testWidgets('the bell polls every minute while the socket is down, but '
      'not in the background', (tester) async {
    final api = FakeNotificationApi();
    transport = FakeTransport();
    container = ProviderContainer(
      overrides: baseOverrides(
        store: MemoryTokenStore(storedFor('saved')),
        tokens: FakeAuthTokenApi(),
        transport: transport,
        notifications: api,
      ),
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
    container.read(sessionControllerProvider);
    await tester.pump();
    await tester.pump();
    container.listen(unreadCountProvider, (_, _) {});
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    int counts() => api.calls.where((c) => c == 'count').length;
    expect(counts(), 1);

    // Never connected: the bell falls back to a read a minute.
    await tester.pump(const Duration(minutes: 2));
    expect(counts(), 3);

    background(tester);
    await tester.pump(const Duration(minutes: 10));
    expect(counts(), 3);
    // The periodic timer lives as long as the bell; end it with the app.
    container.dispose();
    await tester.pump();
  });
}
