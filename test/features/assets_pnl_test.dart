import 'dart:async';

import 'package:cryptopilot_mobile/app.dart';
import 'package:cryptopilot_mobile/core/auth/token_store.dart';
import 'package:cryptopilot_mobile/core/router/app_router.dart';
import 'package:cryptopilot_mobile/core/settings/settings.dart';
import 'package:cryptopilot_mobile/features/home/presentation/home_screen.dart';
import 'package:cryptopilot_mobile/features/paper/domain/paper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/chart_fakes.dart';
import '../support/fakes.dart';
import '../support/paper_fakes.dart';
import '../support/realtime_fakes.dart';

/// T-123: Spot PnL and the equity history in Assets (plan 9.3).
void main() {
  late FakeTransport transport;
  late FakePaperApi paper;
  late FakeMetricSurface metric;

  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> open(
    WidgetTester tester,
    String location, {
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
          metricChart: metric,
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
    container.read(appRouterProvider).go(location);
    await frames(tester);
  }

  Finder list() => find
      .descendant(
        of: find.byKey(const Key('assets-list')),
        matching: find.byType(Scrollable),
      )
      .first;

  Future<void> show(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 200, scrollable: list());
    await frames(tester);
  }

  String textOf(WidgetTester tester, String key) =>
      tester.widget<Text>(find.byKey(Key(key))).data!;

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 31));
  }

  PaperEquity equityOf(int days) => PaperEquity(
    totalEquity: '15000.00',
    todayPnl: null,
    history: [
      for (var i = 0; i < days; i++)
        EquityPoint(
          date: DateTime.utc(2026, 10, 1).add(Duration(days: i)),
          totalEquity: '${15000 + i}.00',
        ),
    ],
  );

  setUp(() {
    paper = FakePaperApi()
      ..equityAnswer = equityOf(30)
      ..pnlAnswer = const SpotPnl(
        coins: [
          CoinPnl(
            asset: 'BTC',
            quantity: '0.1',
            averageCost: '70000',
            costBasis: '7000',
            value: '7600',
            unrealizedPnl: '600',
            unrealizedPnlPercent: '8.57',
          ),
        ],
        complete: false,
        totalValue: '7600',
        totalUnrealizedPnl: '600',
      );
    metric = FakeMetricSurface();
  });

  test('equity: today unknown before the first snapshot, a daily history; '
      'spot PnL with figures the backend may not know', () {
    final equity = decodeEquity({
      'spotEquity': '10000',
      'futuresEquity': '5000',
      'totalEquity': '15000',
      'todayPnl': null,
      'todayPnlPercent': null,
      'history': [
        {
          'date': '2026-11-18',
          'spotEquity': '10000',
          'futuresEquity': '5000',
          'totalEquity': '15000',
        },
      ],
    });
    expect(equity.todayPnl, isNull);
    expect(equity.history.single.date, DateTime.utc(2026, 11, 18));
    final pnl = decodeSpotPnl({
      'coins': [
        {
          'coinId': 'c1',
          'asset': 'XYZ',
          'quantity': '1',
          'averageCost': null,
          'costBasis': null,
          'lastPrice': null,
          'value': null,
          'unrealizedPnl': null,
          'unrealizedPnlPercent': null,
        },
      ],
      'totalValue': '0',
      'totalUnrealizedPnl': '0',
      'complete': false,
    });
    expect(pnl.of('XYZ')!.averageCost, isNull);
    expect(pnl.complete, isFalse);
  });

  testWidgets('a coin shows its average cost and PnL; the equity of 30 days '
      'then 7; the eye masks both', (tester) async {
    await open(tester, '/assets');
    expect(
      textOf(tester, 'coin-pnl-BTC'),
      'Avg cost 70,000 · PnL +600.00 (+8.57%)',
    );
    await show(tester, find.byKey(const Key('assets-equity')));
    expect(paper.calls, contains('equity days=30'));
    expect(metric.lines.single['points'], hasLength(30));
    expect(find.byKey(const Key('assets-spot-upnl')), findsOneWidget);
    expect(
      find.text(
        'Some coins have no cost or price yet; the totals leave them out.',
      ),
      findsOneWidget,
    );

    paper.equityAnswer = equityOf(7);
    await tester.tap(find.byKey(const Key('equity-7')));
    await frames(tester);
    expect(paper.calls.last, 'equity days=7');
    expect(metric.lines.single['points'], hasLength(7));

    await tester.drag(list(), const Offset(0, 3000));
    await frames(tester);
    await tester.tap(find.byKey(const Key('assets-eye')));
    await frames(tester);
    expect(textOf(tester, 'coin-pnl-BTC'), isNot(contains('600')));
    await unmount(tester);
  });

  testWidgets('Home shows a dash for today before the first snapshot', (
    tester,
  ) async {
    paper.opened = true;
    await open(tester, '/assets');
    ProviderScope.containerOf(
      tester.element(find.byType(CryptoPilotApp)),
    ).read(appRouterProvider).go('/home');
    await frames(tester);
    await tester.scrollUntilVisible(
      find.byKey(const Key('home-demo')),
      300,
      scrollable: find
          .descendant(
            of: find.byType(HomeScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await frames(tester);
    expect(find.textContaining('Today --', findRichText: true), findsOneWidget);
    await unmount(tester);
  });

  for (final brightness in Brightness.values) {
    testWidgets('360 dp, ${brightness.name}: the PnL lines and the equity '
        'fit', (tester) async {
      tester.view
        ..physicalSize = const Size(360 * 3, 760 * 3)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await open(tester, '/assets', brightness: brightness);
      expect(tester.takeException(), isNull);
      await show(tester, find.byKey(const Key('assets-equity')));
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  }
}
