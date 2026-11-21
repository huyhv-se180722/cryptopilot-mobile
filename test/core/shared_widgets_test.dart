// T-149 (D-163) wave A: the shared pair label, tag and empty state, and
// where they replace the per-screen variants.
import 'dart:async';

import 'package:cryptopilot_mobile/app.dart';
import 'package:cryptopilot_mobile/core/auth/token_store.dart';
import 'package:cryptopilot_mobile/core/router/app_router.dart';
import 'package:cryptopilot_mobile/core/theme/app_theme.dart';
import 'package:cryptopilot_mobile/core/theme/cp_colors.dart';
import 'package:cryptopilot_mobile/core/widgets/cp_tag.dart';
import 'package:cryptopilot_mobile/core/widgets/empty_state.dart';
import 'package:cryptopilot_mobile/core/widgets/pair_label.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/realtime_fakes.dart';

Widget _host(Widget child) => MaterialApp(
  theme: appTheme(Brightness.light),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('splitSymbol', () {
    test('cuts a known quote off the end', () {
      expect(splitSymbol('BTCUSDT'), ('BTC', 'USDT'));
      expect(splitSymbol('ETHUSDC'), ('ETH', 'USDC'));
      expect(splitSymbol('SOLFDUSD'), ('SOL', 'FDUSD'));
    });

    test('keeps a symbol with no known quote whole', () {
      expect(splitSymbol('XAUBTC'), ('XAUBTC', ''));
      expect(splitSymbol('USDT'), ('USDT', ''));
    });
  });

  group('PairLabel', () {
    testWidgets('the base in bold and the quote muted', (tester) async {
      await tester.pumpWidget(
        _host(const PairLabel(base: 'BTC', quote: 'USDT')),
      );
      expect(find.text('BTC/USDT', findRichText: true), findsOneWidget);
      final spans = <TextSpan>[];
      tester.widget<RichText>(find.byType(RichText)).text.visitChildren((span) {
        if (span is TextSpan && span.text != null) spans.add(span);
        return true;
      });
      expect(spans.first.text, 'BTC');
      expect(spans.first.style!.fontWeight, FontWeight.w700);
      expect(spans.last.text, '/USDT');
      expect(spans.last.style!.color, CpColors.light.muted);
    });

    testWidgets('a market tag beside the name', (tester) async {
      await tester.pumpWidget(
        _host(const PairLabel(base: 'BTC', quote: 'USDT', tag: 'Perp')),
      );
      expect(find.text('BTC/USDT', findRichText: true), findsOneWidget);
      expect(
        find.descendant(of: find.byType(CpTag), matching: find.text('Perp')),
        findsOneWidget,
      );
    });

    testWidgets('from a bare symbol', (tester) async {
      await tester.pumpWidget(_host(PairLabel.symbol('ETHUSDT')));
      expect(find.text('ETH/USDT', findRichText: true), findsOneWidget);
    });
  });

  testWidgets('a tag tints its ground with its own colour', (tester) async {
    await tester.pumpWidget(
      _host(CpTag('Active', color: CpColors.light.positive)),
    );
    final box = tester.widget<Container>(
      find.descendant(of: find.byType(CpTag), matching: find.byType(Container)),
    );
    expect(
      (box.decoration! as BoxDecoration).color,
      CpColors.light.positive.withValues(alpha: 0.14),
    );
    expect(
      tester.widget<Text>(find.text('Active')).style!.color,
      CpColors.light.positive,
    );
  });

  testWidgets('an empty state shows its icon above the sentence', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const EmptyState(message: 'Nothing yet.', icon: Icons.history)),
    );
    expect(find.byIcon(Icons.history), findsOneWidget);
    expect(find.text('Nothing yet.'), findsOneWidget);
    expect(
      tester.getCenter(find.byIcon(Icons.history)).dy,
      lessThan(tester.getCenter(find.text('Nothing yet.')).dy),
    );
  });

  group('in the app', () {
    Future<void> open(WidgetTester tester, String location) async {
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
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      transport.last.onConnected();
      unawaited(
        ProviderScope.containerOf(
          tester.element(find.byType(CryptoPilotApp)),
        ).read(appRouterProvider).push<void>(location),
      );
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 31));
    }

    testWidgets('segmented buttons carry no check mark', (tester) async {
      await open(tester, Routes.notifications);
      expect(find.byType(SegmentedButton<bool>), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SegmentedButton<bool>),
          matching: find.byIcon(Icons.check),
        ),
        findsNothing,
      );
      await unmount(tester);
    });

    testWidgets('Trade says Demo once, in the strip at the top', (
      tester,
    ) async {
      await open(tester, '/trade?market=spot');
      expect(
        find.text('Demo · virtual funds. Orders never reach an exchange.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('paper-demo-banner')), findsOneWidget);
      await unmount(tester);
    });
  });
}
