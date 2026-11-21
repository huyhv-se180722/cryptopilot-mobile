import 'package:cryptopilot_mobile/core/auth/session_controller.dart';
import 'package:cryptopilot_mobile/core/auth/token_store.dart';
import 'package:cryptopilot_mobile/core/state/poll_gate.dart';
import 'package:cryptopilot_mobile/features/market/data/market_repository.dart';
import 'package:cryptopilot_mobile/features/market/domain/market.dart';
import 'package:cryptopilot_mobile/features/notifications/application/notifications_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/realtime_fakes.dart';

/// T-138 2.5: the heaviest polling one screen can cause, against the
/// 120 calls a minute per account of ADR-014. The socket never connects, so
/// the bell polls and the Markets list is Delayed with more rows marked
/// visible than [MarketRepository.maxPolled].
void main() {
  testWidgets('Markets Delayed plus the bell stay at 61 calls a minute, '
      'none in the background, none inside a 429 window', (tester) async {
    final market = FakeMarketApi();
    final notifications = FakeNotificationApi();
    final container = ProviderContainer(
      overrides: baseOverrides(
        store: MemoryTokenStore(storedFor('saved')),
        tokens: FakeAuthTokenApi(),
        transport: FakeTransport(),
        market: market,
        notifications: notifications,
      ),
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
    container.read(sessionControllerProvider);
    await tester.pump();
    await tester.pump();
    final spot = marketRepositoryProvider(Market.spot);
    container
      ..listen(spot, (_, _) {})
      ..listen(unreadCountProvider, (_, _) {});
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    for (var i = 0; i < 14; i++) {
      container.read(spot.notifier).markVisible('C${i}USDT', visible: true);
    }
    int calls() =>
        market.statsCalls.length +
        notifications.calls.where((c) => c == 'count').length;

    // The first minute holds the screen's own reads; measure the next five.
    await tester.pump(const Duration(minutes: 1));
    final perMinute = <int>[];
    for (var minute = 0; minute < 5; minute++) {
      final before = calls();
      for (var s = 0; s < 60; s++) {
        await tester.pump(const Duration(seconds: 1));
      }
      perMinute.add(calls() - before);
    }
    expect(perMinute, everyElement(lessThanOrEqualTo(61)));
    expect(perMinute.reduce((a, b) => a + b), 5 * 61);

    final beforeBackground = calls();
    tester.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
      ..handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(minutes: 10));
    expect(calls(), beforeBackground);

    tester.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    container
        .read(pollGateProvider.notifier)
        .rateLimited(const Duration(seconds: 90));
    final beforeLimit = calls();
    for (var s = 0; s < 89; s++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(calls(), beforeLimit);

    container.dispose();
    await tester.pump();
  });
}
