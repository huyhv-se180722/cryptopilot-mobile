import 'dart:async';

import 'package:cryptopilot_mobile/core/auth/session_controller.dart';
import 'package:cryptopilot_mobile/core/auth/token_store.dart';
import 'package:cryptopilot_mobile/core/realtime/realtime_hub.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/realtime_fakes.dart';

void main() {
  late FakeTransport transport;
  late ProviderContainer container;
  late MemoryTokenStore store;

  Future<void> start(WidgetTester tester, {bool signedIn = false}) async {
    transport = FakeTransport();
    store = MemoryTokenStore(signedIn ? storedFor('saved') : null);
    container = ProviderContainer(
      overrides: baseOverrides(
        store: store,
        tokens: FakeAuthTokenApi(),
        transport: transport,
      ),
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
    container.read(sessionControllerProvider);
    await tester.pump();
    await tester.pump();
  }

  RealtimeHub hub() => container.read(realtimeHubProvider.notifier);
  RealtimeState state() => container.read(realtimeHubProvider);

  testWidgets('connects on the first listener and delivers decoded pushes', (
    tester,
  ) async {
    await start(tester);
    final received = <Object?>[];
    final sub = hub().watch('/topic/overview.SPOT').listen(received.add);
    await tester.pump();

    expect(transport.connections, hasLength(1));
    expect(transport.last.headers, isEmpty);
    transport.last.onConnected();
    expect(state().connected, isTrue);
    expect(state().generation, 1);

    transport.last.push('/topic/overview.SPOT', {'market': 'SPOT'});
    await tester.pump();
    expect(received, [
      {'market': 'SPOT'},
    ]);
    // Not awaited: awaiting a broadcast cancel stalls fake time in flutter_test.
    unawaited(sub.cancel());
    await tester.pump(const Duration(seconds: 31));
  });

  testWidgets('a signed-in session sends its token and may use user queues', (
    tester,
  ) async {
    await start(tester, signedIn: true);
    final sub = hub().watch('/user/queue/notifications').listen((_) {});
    await tester.pump();
    await tester.pump();

    expect(transport.last.headers['Authorization'], 'Bearer access-rotated');
    transport.last.onConnected();
    expect(
      transport.last.subscriptions.keys,
      contains('/user/queue/notifications'),
    );
    // Not awaited: awaiting a broadcast cancel stalls fake time in flutter_test.
    unawaited(sub.cancel());
    await tester.pump(const Duration(seconds: 31));
  });

  testWidgets('a guest never subscribes to a user queue', (tester) async {
    await start(tester);
    final sub = hub().watch('/user/queue/notifications').listen((_) {});
    await tester.pump();
    transport.last.onConnected();

    expect(transport.last.subscriptions, isEmpty);
    // Not awaited: awaiting a broadcast cancel stalls fake time in flutter_test.
    unawaited(sub.cancel());
    await tester.pump(const Duration(seconds: 31));
  });

  testWidgets('a dropped connection retries with backoff and resubscribes', (
    tester,
  ) async {
    await start(tester);
    final sub = hub().watch('/topic/ticker.SPOT.BTCUSDT').listen((_) {});
    await tester.pump();
    transport.last.onConnected();
    transport.last.drop();
    expect(state().connected, isFalse);

    await tester.pump(const Duration(milliseconds: 900));
    expect(transport.connections, hasLength(1));
    await tester.pump(const Duration(milliseconds: 200));
    expect(transport.connections, hasLength(2));

    transport.last.onConnected();
    expect(state().generation, 2);
    expect(
      transport.last.subscriptions.keys,
      contains('/topic/ticker.SPOT.BTCUSDT'),
    );
    // Not awaited: awaiting a broadcast cancel stalls fake time in flutter_test.
    unawaited(sub.cancel());
    await tester.pump(const Duration(seconds: 31));
  });

  testWidgets('the background closes the connection after 30 s', (
    tester,
  ) async {
    await start(tester);
    final sub = hub().watch('/topic/overview.SPOT').listen((_) {});
    await tester.pump();
    transport.last.onConnected();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 29));
    expect(transport.last.closed, isFalse);
    await tester.pump(const Duration(seconds: 2));
    expect(transport.last.closed, isTrue);
    expect(state().connected, isFalse);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(transport.connections, hasLength(2));
    // Not awaited: awaiting a broadcast cancel stalls fake time in flutter_test.
    unawaited(sub.cancel());
    await tester.pump(const Duration(seconds: 31));
  });

  testWidgets('signing out reconnects without the token', (tester) async {
    await start(tester, signedIn: true);
    final sub = hub().watch('/topic/overview.SPOT').listen((_) {});
    await tester.pump();
    await tester.pump();
    transport.last.onConnected();

    await container.read(sessionControllerProvider.notifier).signOut();
    await tester.pump();
    await tester.pump();

    expect(transport.connections.first.closed, isTrue);
    expect(transport.last.headers, isEmpty);
    // Not awaited: awaiting a broadcast cancel stalls fake time in flutter_test.
    unawaited(sub.cancel());
    await tester.pump(const Duration(seconds: 31));
  });

  testWidgets('the last listener leaving closes the connection later', (
    tester,
  ) async {
    await start(tester);
    final sub = hub().watch('/topic/overview.SPOT').listen((_) {});
    await tester.pump();
    transport.last.onConnected();
    // Not awaited: awaiting a broadcast cancel stalls fake time in flutter_test.
    unawaited(sub.cancel());
    await tester.pump(const Duration(seconds: 29));
    expect(transport.last.closed, isFalse);
    await tester.pump(const Duration(seconds: 2));

    expect(transport.last.closed, isTrue);
  });
}
