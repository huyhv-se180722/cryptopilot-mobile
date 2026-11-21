import 'dart:async';

import 'package:cryptopilot_mobile/app.dart';
import 'package:cryptopilot_mobile/core/auth/token_store.dart';
import 'package:cryptopilot_mobile/core/router/app_router.dart';
import 'package:cryptopilot_mobile/core/settings/settings.dart';
import 'package:cryptopilot_mobile/core/theme/cp_colors.dart';
import 'package:cryptopilot_mobile/features/paper/domain/futures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/futures_fakes.dart';
import '../support/paper_fakes.dart';
import '../support/realtime_fakes.dart';

/// T-150 (D-163): the Trade tab on the exchange layout — Spot and Futures
/// as text tabs, − and + in the Spot fields, the position card's figures.
void main() {
  late FakeTransport transport;
  late FakePaperApi paper;
  late FakeFuturesApi futures;

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
        overrides: baseOverrides(
          store: MemoryTokenStore(storedFor('saved')),
          tokens: FakeAuthTokenApi(),
          transport: transport,
          paper: paper,
          futures: futures,
          settings: MemorySettingsStore(),
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
    if (brightness == Brightness.dark) {
      unawaited(
        container.read(themeModeProvider.notifier).select(ThemeMode.dark),
      );
    }
    container.read(appRouterProvider).go('/trade');
    await frames(tester);
    transport.last.push('/topic/overview.SPOT', {
      'market': 'SPOT',
      'serverTime': '2026-11-19T02:00:00Z',
      'tickers': [
        {
          'market': 'SPOT',
          'symbol': 'BTCUSDT',
          'sourceTime': '2026-11-19T02:00:00Z',
          'lastPrice': '76000.00',
          'changePercent24h': '1.5',
          'quoteVolume24h': '1',
          'markPrice': null,
        },
      ],
    });
    await frames(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 31));
  }

  String field(WidgetTester tester, String name) => tester
      .widget<TextField>(
        find.descendant(
          of: find.byKey(Key('trade-field-$name')),
          matching: find.byType(TextField),
        ),
      )
      .controller!
      .text;

  setUp(() {
    paper = FakePaperApi();
    futures = FakeFuturesApi();
  });

  testWidgets('Spot and Futures are text tabs in the app bar, the chosen one '
      'bold; no segmented row is left', (tester) async {
    await open(tester);
    final tabs = find.byKey(const Key('trade-segment'));
    expect(
      find.descendant(of: find.byType(AppBar), matching: tabs),
      findsOneWidget,
    );
    expect(find.byType(SegmentedButton<bool>), findsNothing);
    FontWeight? weight(String label) => tester
        .widget<Text>(find.descendant(of: tabs, matching: find.text(label)))
        .style
        ?.fontWeight;
    expect(weight('Spot'), FontWeight.w700);
    expect(weight('Futures'), FontWeight.w500);
    await tester.tap(find.descendant(of: tabs, matching: find.text('Futures')));
    await frames(tester);
    expect(find.byKey(const Key('trade-futures')), findsOneWidget);
    expect(weight('Futures'), FontWeight.w700);
    await unmount(tester);
  });

  testWidgets('Spot − and +: an empty price starts at the last price and '
      'moves by the tick; the amount moves by the step, never below it', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('trade-plus-price')));
    await tester.pump();
    expect(field(tester, 'price'), '76000.01');
    await tester.tap(find.byKey(const Key('trade-minus-price')));
    await tester.tap(find.byKey(const Key('trade-minus-price')));
    await tester.pump();
    expect(field(tester, 'price'), '75999.99');

    await tester.tap(find.byKey(const Key('trade-plus-amount')));
    await tester.pump();
    expect(field(tester, 'amount'), '0.00001');
    await tester.tap(find.byKey(const Key('trade-minus-amount')));
    await tester.pump();
    expect(field(tester, 'amount'), '0.00001');
    // No − and + on the total.
    expect(find.byKey(const Key('trade-plus-total')), findsNothing);
    await unmount(tester);
  });

  testWidgets('the percent marks sit under the share slider', (tester) async {
    await open(tester);
    for (final mark in ['0%', '25%', '50%', '75%', '100%']) {
      expect(find.text(mark), findsOneWidget);
    }
    expect(
      tester.getTopLeft(find.text('50%')).dy,
      greaterThan(
        tester.getBottomLeft(find.byKey(const Key('trade-share'))).dy - 8,
      ),
    );
    await unmount(tester);
  });

  for (final brightness in Brightness.values) {
    testWidgets('360 dp, ${brightness.name}: the position card shows the '
        'side, mode and leverage as tags, uPnL and the figures', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(360 * 3, 760 * 3)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      futures.positionList = [positionOf(marginType: MarginType.isolated)];
      await open(tester, brightness: brightness);
      await tester.tap(find.text('Futures'));
      await frames(tester);
      const key = 'BTCUSDT-BOTH';
      await tester.scrollUntilVisible(
        find.byKey(const Key('market-close-$key')),
        200,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('trade-futures')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await frames(tester);
      final card = find.byKey(const Key('position-$key'));
      for (final label in [
        'Long',
        'Unrealized PnL (USDT)',
        'Size (BTC)',
        'Margin (USDT)',
        'Margin ratio',
        'Entry price',
        'Mark price',
        'Liq. price',
      ]) {
        expect(
          find.descendant(of: card, matching: find.text(label)),
          findsOneWidget,
          reason: label,
        );
      }
      final cp = brightness == Brightness.dark ? CpColors.dark : CpColors.light;
      expect(
        tester
            .widget<Text>(find.byKey(const Key('position-pnl-$key')))
            .style
            ?.color,
        cp.positive,
      );
      for (final action in ['tpsl', 'close', 'market-close', 'margin']) {
        expect(find.byKey(Key('$action-$key')), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  }
}
