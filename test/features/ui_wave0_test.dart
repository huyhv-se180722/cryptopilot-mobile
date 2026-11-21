// T-148 (D-163) wave 0: the display defects found by the UI audit.
import 'dart:async';

import 'package:cryptopilot_mobile/app.dart';
import 'package:cryptopilot_mobile/core/auth/token_store.dart';
import 'package:cryptopilot_mobile/core/router/app_router.dart';
import 'package:cryptopilot_mobile/core/settings/settings.dart';
import 'package:cryptopilot_mobile/core/theme/app_theme.dart';
import 'package:cryptopilot_mobile/core/theme/cp_colors.dart';
import 'package:cryptopilot_mobile/features/market/presentation/market_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/realtime_fakes.dart';

/// WCAG contrast ratio of two opaque colours.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  Future<void> frames(WidgetTester tester, [int n = 12]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// The signed-in app at 360 × 800, opened on [location].
  Future<void> open(
    WidgetTester tester,
    String location, {
    bool dark = false,
    bool push = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.reset);
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
    final container = ProviderScope.containerOf(
      tester.element(find.byType(CryptoPilotApp)),
    );
    if (dark) {
      unawaited(
        container.read(themeModeProvider.notifier).select(ThemeMode.dark),
      );
    }
    final router = container.read(appRouterProvider);
    if (push) {
      unawaited(router.push<void>(location));
    } else {
      router.go(location);
    }
    await frames(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 31));
  }

  Color foregroundOf(WidgetTester tester, Finder button) => tester
      .widget<FilledButton>(button)
      .style!
      .foregroundColor!
      .resolve(<WidgetState>{})!;

  group('M1 text on green and red', () {
    for (final (name, cp) in [
      ('light', CpColors.light),
      ('dark', CpColors.dark),
    ]) {
      test('$name: on-positive and on-negative reach 4.5:1', () {
        expect(contrast(cp.onPositive, cp.positive), greaterThanOrEqualTo(4.5));
        expect(contrast(cp.onNegative, cp.negative), greaterThanOrEqualTo(4.5));
      });
    }

    testWidgets('the change pill writes with the on-colour of its side', (
      tester,
    ) async {
      for (final brightness in Brightness.values) {
        final cp = brightness == Brightness.dark
            ? CpColors.dark
            : CpColors.light;
        // A fresh app per theme: a theme change animates between the two.
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          MaterialApp(
            theme: appTheme(brightness),
            home: const Scaffold(
              body: Column(
                children: [
                  ChangePill(percent: '2.41'),
                  ChangePill(percent: '-1.27'),
                ],
              ),
            ),
          ),
        );
        expect(
          tester.widget<Text>(find.text('+2.41%')).style!.color,
          cp.onPositive,
        );
        expect(
          // The formatter writes the minus sign U+2212.
          tester.widget<Text>(find.text('−1.27%')).style!.color,
          cp.onNegative,
        );
      }
    });

    testWidgets('dark: Spot side and order buttons use the on-colours', (
      tester,
    ) async {
      await open(tester, '/trade?market=spot', dark: true);
      final cp = CpColors.dark;
      expect(
        foregroundOf(tester, find.byKey(const Key('trade-submit'))),
        cp.onPositive,
      );
      expect(
        foregroundOf(
          tester,
          find.descendant(
            of: find.byKey(const Key('trade-side-BUY')),
            matching: find.byType(FilledButton),
          ),
        ),
        cp.onPositive,
      );
      await tester.tap(find.byKey(const Key('trade-side-SELL')));
      await frames(tester);
      expect(
        foregroundOf(tester, find.byKey(const Key('trade-submit'))),
        cp.onNegative,
      );
      await unmount(tester);
    });

    testWidgets('dark: Buy / Long and Sell / Short use the on-colours', (
      tester,
    ) async {
      await open(tester, '/trade?market=futures', dark: true);
      final cp = CpColors.dark;
      expect(
        foregroundOf(tester, find.byKey(const Key('futures-BUY'))),
        cp.onPositive,
      );
      expect(
        foregroundOf(tester, find.byKey(const Key('futures-SELL'))),
        cp.onNegative,
      );
      await unmount(tester);
    });
  });

  testWidgets('Assets history tabs start at the left edge', (tester) async {
    await open(tester, Routes.assetsHistory, push: true);
    expect(tester.getTopLeft(find.byType(Tab).first).dx, lessThan(24));
    await unmount(tester);
  });

  testWidgets('the composer Publish button sits inside the app bar', (
    tester,
  ) async {
    await open(tester, Routes.communityNew, push: true);
    final button = tester.getRect(find.byKey(const Key('composer-publish')));
    final bar = tester.getRect(find.byType(AppBar));
    expect(button.height, lessThanOrEqualTo(40));
    expect(button.top - bar.top, greaterThanOrEqualTo(8));
    expect(bar.bottom - button.bottom, greaterThanOrEqualTo(8));
    expect(bar.right - button.right, greaterThanOrEqualTo(12));
    await unmount(tester);
  });

  testWidgets('no market overview text under 10.5', (tester) async {
    await open(tester, Routes.markets);
    // Wide enough that the strip builds every card, the altcoin season
    // card with its small notes included.
    tester.view.physicalSize = const Size(2400, 800);
    await frames(tester);
    final texts = find.descendant(
      of: find.byKey(const Key('market-overview')),
      matching: find.byType(RichText),
    );
    expect(texts, findsWidgets);
    for (final element in texts.evaluate()) {
      final size = (element.widget as RichText).text.style?.fontSize;
      expect(size, isNotNull);
      expect(size, greaterThanOrEqualTo(10.5));
    }
    await unmount(tester);
  });
}
