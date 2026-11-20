import 'dart:async';

import 'package:cryptopilot_mobile/app.dart';
import 'package:cryptopilot_mobile/core/auth/token_store.dart';
import 'package:cryptopilot_mobile/core/router/app_router.dart';
import 'package:cryptopilot_mobile/core/settings/settings.dart';
import 'package:cryptopilot_mobile/features/account/domain/profile.dart';
import 'package:cryptopilot_mobile/features/ai/data/ai_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ai_fakes.dart';
import '../support/fakes.dart';
import '../support/realtime_fakes.dart';

/// T-126 follow-up (T-074): the trading style and risk profile the
/// assistant answers for, as the web's style chip.
void main() {
  late FakeAiApi api;
  late FakeWebLinks web;
  late FakeProfileApi profile;
  late FakeTransport transport;

  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> open(
    WidgetTester tester, {
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
            web: web,
            profile: profile,
          ),
          aiApiProvider.overrideWithValue(api),
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
    unawaited(
      container
          .read(appRouterProvider)
          .push('/ai/c/c1', extra: api.conversationList.first),
    );
    await frames(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 31));
  }

  Profile withStyle(TradingStyle? style, RiskProfile risk) => Profile(
    email: 'trader@cryptopilot.invalid',
    displayName: 'Pro Trader',
    notifyEmail: true,
    notifyPush: false,
    tradingStyle: style,
    riskProfile: risk,
  );

  setUp(() {
    api = FakeAiApi()..conversationList = [conversationOf('c1')];
    web = FakeWebLinks();
    profile = FakeProfileApi();
  });

  testWidgets('the style and risk profile the assistant answers for; the '
      'chip opens the profile on the web', (tester) async {
    profile.current = withStyle(TradingStyle.swing, RiskProfile.balanced);
    await open(tester);
    expect(find.text('Style: Swing · Balanced'), findsOneWidget);
    await tester.tap(find.byKey(const Key('ai-style')));
    await tester.pump();
    expect(web.opened, ['/profile']);
    await unmount(tester);
  });

  testWidgets('no style chosen yet: the chip asks for one', (tester) async {
    profile.current = withStyle(null, RiskProfile.conservative);
    await open(tester);
    expect(find.text('Set your trading style'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('no chip on FREE (the upgrade card) or when the profile '
      'cannot be read; the input still works', (tester) async {
    api.quotaValue = quotaOf(limit: 0, remaining: 0, used: 0, canAsk: false);
    await open(tester);
    expect(find.byKey(const Key('ai-upgrade')), findsOneWidget);
    expect(find.byKey(const Key('ai-style')), findsNothing);
    await unmount(tester);

    api = FakeAiApi()..conversationList = [conversationOf('c1')];
    profile.loadError = Exception('offline');
    await open(tester);
    expect(find.byKey(const Key('ai-style')), findsNothing);
    expect(find.byKey(const Key('ai-input')), findsOneWidget);
    await unmount(tester);
  });

  for (final brightness in Brightness.values) {
    testWidgets('360 dp, ${brightness.name}: the longest label fits', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(360 * 3, 760 * 3)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      profile.current = withStyle(TradingStyle.day, RiskProfile.conservative);
      await open(tester, brightness: brightness);
      expect(find.text('Style: Day trading · Conservative'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  }

  testWidgets('a market chat with no coin yet asks about a coin '
      '(device check)', (tester) async {
    await open(tester);
    expect(find.text('Ask about a coin…'), findsOneWidget);
    expect(find.textContaining('……'), findsNothing);
    await unmount(tester);
  });
}
