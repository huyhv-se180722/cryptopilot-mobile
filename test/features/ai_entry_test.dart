import 'dart:async';

import 'package:cryptopilot_mobile/app.dart';
import 'package:cryptopilot_mobile/core/auth/token_store.dart';
import 'package:cryptopilot_mobile/core/router/app_router.dart';
import 'package:cryptopilot_mobile/core/settings/settings.dart';
import 'package:cryptopilot_mobile/features/ai/data/ai_api.dart';
import 'package:cryptopilot_mobile/features/ai/presentation/ai_chat_screen.dart';
import 'package:cryptopilot_mobile/features/ai/presentation/ai_conversations_screen.dart';
import 'package:cryptopilot_mobile/features/market/presentation/pair_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ai_fakes.dart';
import '../support/fakes.dart';
import '../support/realtime_fakes.dart';

/// The ways into SCR-29: the Home header and Ask AI on SCR-10/11 (SRS 3.9.1).
void main() {
  late FakeTransport transport;

  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<ProviderContainer> start(
    WidgetTester tester, {
    bool askAi = true,
    Brightness brightness = Brightness.light,
  }) async {
    transport = FakeTransport();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...baseOverrides(
            store: MemoryTokenStore(storedFor('saved')),
            tokens: FakeAuthTokenApi(),
            transport: transport,
          ),
          aiApiProvider.overrideWithValue(FakeAiApi()),
          // As composed in main.dart.
          if (askAi) askAiOnPairProvider.overrideWithValue(askAiOnPair),
        ],
        retry: (_, _) => null,
        child: const CryptoPilotApp(),
      ),
    );
    await frames(tester);
    transport.last.onConnected();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(CryptoPilotApp)),
    );
    if (brightness == Brightness.dark) {
      unawaited(
        container.read(themeModeProvider.notifier).select(ThemeMode.dark),
      );
    }
    await frames(tester);
    return container;
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 31));
  }

  testWidgets('the AI icon of the Home header opens the conversations', (
    tester,
  ) async {
    await start(tester);
    await tester.tap(find.byKey(const Key('open-ai')));
    await frames(tester);
    expect(find.byType(AiConversationsScreen), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('Ask AI on SCR-10 opens a chat on the pair at the timeframe on '
      'screen', (tester) async {
    final container = await start(tester);
    unawaited(container.read(appRouterProvider).push('/analysis/spot/ETHUSDT'));
    await frames(tester);
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('analysis-timeframes')),
        matching: find.text('4h'),
      ),
    );
    await frames(tester);
    await tester.tap(find.byKey(const Key('ask-ai')));
    await frames(tester);
    expect(find.byType(AiChatScreen), findsOneWidget);
    expect(find.text('ETHUSDT · Spot'), findsOneWidget);
    expect(find.text('4h ▾'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('without the composition there is no Ask AI button', (
    tester,
  ) async {
    final container = await start(tester, askAi: false);
    unawaited(container.read(appRouterProvider).push('/analysis/spot/ETHUSDT'));
    await frames(tester);
    expect(find.byKey(const Key('ask-ai')), findsNothing);
    await unmount(tester);
  });

  for (final brightness in Brightness.values) {
    testWidgets('360 dp, ${brightness.name}: the action bar of SCR-11 with '
        'Ask AI and the Home header fit', (tester) async {
      tester.view
        ..physicalSize = const Size(360 * 3, 760 * 3)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final container = await start(tester, brightness: brightness);
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('open-ai')), findsOneWidget);
      unawaited(
        container.read(appRouterProvider).push('/analysis/futures/BTCUSDT'),
      );
      await frames(tester);
      expect(find.byKey(const Key('ask-ai')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  }
}
