import 'package:cryptopilot_mobile/app.dart';
import 'package:cryptopilot_mobile/core/auth/token_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/realtime_fakes.dart';

void main() {
  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('the five tabs of D-154 in order: Home, Markets, Trade, Plans, '
      'Assets; no Journal tab', (tester) async {
    final transport = FakeTransport();
    await tester.pumpWidget(
      ProviderScope(
        overrides: baseOverrides(
          store: MemoryTokenStore(storedFor('saved')),
          tokens: FakeAuthTokenApi(),
          transport: transport,
        ),
        retry: (_, _) => null,
        child: const CryptoPilotApp(),
      ),
    );
    await frames(tester);
    transport.last.onConnected();
    await frames(tester);

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(
      [
        for (final destination in bar.destinations)
          (destination as NavigationDestination).label,
      ],
      ['Home', 'Markets', 'Trade', 'Plans', 'Assets'],
    );

    // Trade's app bar shows its Spot / Futures tabs (T-150, D-163).
    for (final (index, title, header) in [
      (2, 'Trade', 'Spot'),
      (4, 'Assets', 'Assets'),
    ]) {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(title),
        ),
      );
      await frames(tester);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        index,
      );
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text(header)),
        findsOneWidget,
      );
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 31));
  });
}
