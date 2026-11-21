import 'dart:async';

import 'package:cryptopilot_mobile/app.dart';
import 'package:cryptopilot_mobile/core/auth/token_store.dart';
import 'package:cryptopilot_mobile/core/router/app_router.dart';
import 'package:cryptopilot_mobile/features/academy/presentation/academy_links.dart';
import 'package:cryptopilot_mobile/features/academy/presentation/academy_widgets.dart';
import 'package:cryptopilot_mobile/features/paper/presentation/trade_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/academy_fakes.dart';
import '../support/fakes.dart';
import '../support/realtime_fakes.dart';

/// T-131: a lesson's trade link opens the Trade tab in the app.
void main() {
  test('trade paths: Spot or Futures, a pair when named; others the web', () {
    final spot = academyLinkTarget('/trade/spot');
    expect(spot, isA<TradeTab>());
    expect((spot as TradeTab).futures, isFalse);
    expect(spot.symbol, isNull);
    final futures = academyLinkTarget('/trade/futures/btcusdt');
    expect((futures as TradeTab).futures, isTrue);
    expect(futures.symbol, 'BTCUSDT');
    for (final path in ['/trade', '/trade/margin', '/trade/spot/a/b']) {
      expect(academyLinkTarget(path), isA<WebPath>(), reason: path);
    }
  });

  testWidgets('"Try it in the app" on a /trade/futures lesson opens Trade in '
      'Futures on its pair; nothing opens the web', (tester) async {
    final api = FakeAcademyApi();
    final web = FakeWebLinks();
    final transport = FakeTransport();
    api.appLinks['lesson-2'] = '/trade/futures/ETHUSDT';
    await tester.pumpWidget(
      ProviderScope(
        overrides: baseOverrides(
          store: MemoryTokenStore(storedFor('saved')),
          tokens: FakeAuthTokenApi(),
          transport: transport,
          web: web,
          academy: api,
        ),
        retry: (_, _) => null,
        child: const CryptoPilotApp(),
      ),
    );
    Future<void> frames() async {
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    await frames();
    transport.last.onConnected();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(CryptoPilotApp)),
    );
    unawaited(
      container.read(appRouterProvider).push(lessonLocation('lesson-2')),
    );
    await frames();
    await tester.scrollUntilVisible(
      find.byKey(const Key('lesson-try')),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('lesson-page')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.byKey(const Key('lesson-try')));
    await frames();
    expect(find.byType(TradeScreen), findsOneWidget);
    expect(find.byKey(const Key('trade-futures')), findsOneWidget);
    expect(find.text('ETH/USDT', findRichText: true), findsOneWidget);
    expect(web.opened, isEmpty);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 31));
  });
}
