import 'dart:async';

import 'package:cryptopilot_mobile/app.dart';
import 'package:cryptopilot_mobile/core/auth/token_store.dart';
import 'package:cryptopilot_mobile/core/router/app_router.dart';
import 'package:cryptopilot_mobile/core/settings/settings.dart';
import 'package:cryptopilot_mobile/features/ai/data/ai_api.dart';
import 'package:cryptopilot_mobile/features/ai/presentation/ai_chat_screen.dart';
import 'package:cryptopilot_mobile/features/journal/data/journal_api.dart';
import 'package:cryptopilot_mobile/features/journal/domain/journal.dart';
import 'package:cryptopilot_mobile/features/journal/presentation/journal_entry_screen.dart';
import 'package:cryptopilot_mobile/features/market/domain/market.dart';
import 'package:cryptopilot_mobile/features/plans/data/plan_detail_api.dart';
import 'package:cryptopilot_mobile/features/plans/domain/plan.dart';
import 'package:cryptopilot_mobile/features/plans/presentation/plan_detail_screen.dart';
import 'package:cryptopilot_mobile/features/plans/presentation/plans_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ai_fakes.dart';
import '../support/fakes.dart';
import '../support/plans_fakes.dart';
import '../support/realtime_fakes.dart';

/// `GET /plans` by tab, as the backend filters it.
class TabPlanApi extends FakePlanApi {
  final Map<PlanTab, List<PlanSummary>> byTab = {
    PlanTab.active: [planOf('p1', market: Market.futures, leverage: 5)],
    PlanTab.draft: [planOf('d1', status: PlanStatus.draft)],
    PlanTab.executed: [
      planOf(
        'p2',
        market: Market.futures,
        leverage: 5,
        status: PlanStatus.executed,
        position: PositionState.open,
      ),
      planOf(
        'p3',
        base: 'ETH',
        status: PlanStatus.executed,
        position: PositionState.closed,
      ),
    ],
    PlanTab.cancelledExpired: [planOf('c1', status: PlanStatus.cancelled)],
  };

  @override
  Future<PlanPage> list({PlanTab? tab, int page = 1, int pageSize = 20}) async {
    calls.add('${tab?.wire} $pageSize');
    final rows = byTab[tab] ?? const [];
    return PlanPage(items: rows.take(pageSize).toList(), total: rows.length);
  }
}

void main() {
  late TabPlanApi plans;
  late FakePlanDetailApi details;
  late FakeJournalApi journal;
  late FakeWebLinks web;
  late FakeTransport transport;

  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(CryptoPilotApp)));

  Future<void> open(
    WidgetTester tester,
    String location, {
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
            plans: plans,
            web: web,
          ),
          planDetailApiProvider.overrideWithValue(details),
          journalApiProvider.overrideWithValue(journal),
          aiApiProvider.overrideWithValue(FakeAiApi()),
        ],
        retry: (_, _) => null,
        child: const CryptoPilotApp(),
      ),
    );
    await frames(tester);
    transport.last.onConnected();
    final container = containerOf(tester);
    if (brightness == Brightness.dark) {
      unawaited(
        container.read(themeModeProvider.notifier).select(ThemeMode.dark),
      );
    }
    final router = container.read(appRouterProvider);
    if (location == '/plans') {
      router.go(location);
    } else {
      unawaited(router.push(location));
    }
    await frames(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 31));
  }

  /// Scrolls SCR-21 until [key] is built (the list builds lazily).
  Future<void> reach(WidgetTester tester, String key) async {
    await tester.scrollUntilVisible(
      find.byKey(Key(key)),
      300,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('journal-entry')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pump();
  }

  Future<void> tab(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(Key(key)));
    await frames(tester);
  }

  setUp(() {
    plans = TabPlanApi();
    details = FakePlanDetailApi();
    journal = FakeJournalApi();
    web = FakeWebLinks();
  });

  group('Plans tab (A-61)', () {
    testWidgets('Positions, Active with drafts, History by chip; a row opens '
        'SCR-18', (tester) async {
      await open(tester, '/plans');
      expect(find.byType(PlansScreen), findsOneWidget);
      expect(find.byKey(const Key('plan-row-p2')), findsOneWidget);
      expect(find.byKey(const Key('plan-row-p3')), findsNothing);
      expect(find.text('OPEN'), findsOneWidget);

      await tab(tester, 'plans-tab-active');
      expect(find.byKey(const Key('plan-row-p1')), findsOneWidget);
      expect(find.text('Drafts'), findsOneWidget);
      expect(find.byKey(const Key('plan-row-d1')), findsOneWidget);

      await tab(tester, 'plans-tab-history');
      expect(find.byKey(const Key('plan-row-p3')), findsOneWidget);
      await tester.tap(find.byKey(const Key('plans-history-cancelled')));
      await frames(tester);
      expect(find.byKey(const Key('plan-row-c1')), findsOneWidget);

      await tab(tester, 'plans-tab-positions');
      await tester.tap(find.byKey(const Key('plan-row-p2')));
      await frames(tester);
      expect(find.byType(PlanDetailScreen), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('empty Positions explain where plans come from; Create opens '
        'the web', (tester) async {
      plans.byTab[PlanTab.executed] = [];
      await open(tester, '/plans');
      expect(
        find.byKey(const Key('plans-empty-openPositions')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('plan-create-web')));
      await tester.pump();
      expect(web.opened, ['/plans/new']);
      await unmount(tester);
    });
  });

  group('SCR-18', () {
    testWidgets('an open position: server uPnL, distances, Set SL/TP and Close '
        'position', (tester) async {
      await open(tester, '/plan/p2');
      expect(find.byKey(const Key('plan-position')), findsOneWidget);
      expect(find.text('+6.15 USDT'), findsOneWidget);
      expect(find.text('Simulated position'), findsOneWidget);
      expect(find.textContaining('Liquidation'), findsWidgets);
      expect(find.byKey(const Key('plan-set-levels')), findsOneWidget);
      expect(find.byKey(const Key('plan-close')), findsOneWidget);
      expect(find.byKey(const Key('plan-activate')), findsNothing);
      await unmount(tester);
    });

    testWidgets('Futures: the liquidation distance goes by the mark price '
        '(SRS 3.5.3)', (tester) async {
      await open(tester, '/plan/p2');
      transport.last.push('/topic/overview.FUTURES', {
        'market': 'FUTURES',
        'tickers': [
          {
            'market': 'FUTURES',
            'symbol': 'BTCUSDT',
            'lastPrice': '67210.00',
            'markPrice': '67000.00',
          },
        ],
      });
      await frames(tester);
      expect(find.text('Mark price'), findsOneWidget);
      // (60,150 − 67,000) / 67,000 = −10.22 %, not the −10.50 % of the last
      // price.
      expect(find.textContaining('−10.22%'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('an executed plan links its journal entry; Ask AI opens a '
        'plan chat on it (SRS 3.9.1)', (tester) async {
      await open(tester, '/plan/p2');
      expect(find.byKey(const Key('plan-journal-entry')), findsOneWidget);
      expect(
        journal.calls.firstWhere((c) => c.startsWith('list')),
        startsWith('list SIMULATED'),
      );
      await tester.tap(find.byKey(const Key('plan-journal-entry')));
      await frames(tester);
      expect(find.byType(JournalEntryScreen), findsOneWidget);
      await tester.pageBack();
      await frames(tester);

      await tester.tap(find.byKey(const Key('plan-ask-ai')));
      await frames(tester);
      expect(find.byType(AiChatScreen), findsOneWidget);
      expect(find.text('Plan BTCUSDT Long'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('SCR-19: the estimate, MSG21 and the close', (tester) async {
      await open(tester, '/plan/p2');
      await tester.tap(find.byKey(const Key('plan-close')));
      await frames(tester);
      expect(find.byKey(const Key('plan-close-sheet')), findsOneWidget);
      expect(find.byKey(const Key('plan-msg21')), findsOneWidget);
      expect(find.textContaining('Estimated P/L: +4.85'), findsOneWidget);
      await tester.tap(find.byKey(const Key('plan-close-confirm')));
      await frames(tester);
      expect(details.calls, contains('close p2'));
      expect(find.text('Position closed.'), findsOneWidget);
      expect(find.byKey(const Key('plan-close')), findsNothing);
      await unmount(tester);
    });

    testWidgets('Set SL/TP: a wrong-side level shows MSG16 under its field', (
      tester,
    ) async {
      details.failNext['levels'] = problem(
        400,
        'VALIDATION_FAILED',
        'MSG16',
        fields: {'stopLoss': 'MSG16'},
      );
      await open(tester, '/plan/p2');
      await tester.tap(find.byKey(const Key('plan-set-levels')));
      await frames(tester);
      await tester.enterText(find.byKey(const Key('plan-stop-field')), '70000');
      await tester.tap(find.byKey(const Key('plan-levels-save')));
      await frames(tester);
      expect(
        find.text(
          'For LONG positions: stop loss below the last price, take profit '
          'above it.',
        ),
        findsOneWidget,
      );
      await tester.enterText(find.byKey(const Key('plan-stop-field')), '66200');
      await tester.tap(find.byKey(const Key('plan-levels-save')));
      await frames(tester);
      expect(details.calls, contains('levels p2 66200 null'));
      expect(find.byKey(const Key('plan-levels-sheet')), findsNothing);
      await unmount(tester);
    });

    testWidgets('a draft: MSG51 asks, then MSG19', (tester) async {
      details.failNext['activate'] = problem(
        400,
        'ENTRY_DEVIATION_CONFIRMATION_REQUIRED',
        'MSG51',
        args: ['0.4', '0.0142', '2.05'],
      );
      await open(tester, '/plan/d1');
      expect(find.byKey(const Key('plan-edit-web')), findsOneWidget);
      await tester.tap(find.byKey(const Key('plan-activate')));
      await frames(tester);
      expect(find.byKey(const Key('plan-msg51')), findsOneWidget);
      expect(find.textContaining('moved 0.4R'), findsOneWidget);
      await tester.tap(find.byKey(const Key('plan-msg51-confirm')));
      await frames(tester);
      expect(details.calls, contains('activate d1 true'));
      expect(find.text('Trading plan activated.'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('a refused activation (MSG18) is a dialog; Cancel asks MSG20', (
      tester,
    ) async {
      details.failNext['activate'] = problem(
        409,
        'TRADING_BLOCKING_WARNING',
        'MSG18',
      );
      await open(tester, '/plan/d1');
      await tester.tap(find.byKey(const Key('plan-activate')));
      await frames(tester);
      expect(find.byKey(const Key('plan-refused')), findsOneWidget);
      expect(
        find.text('This plan has blocking warnings and cannot be activated.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Close'));
      await frames(tester);
      await tester.tap(find.byKey(const Key('plan-cancel')));
      await frames(tester);
      expect(
        find.text('Cancel this trading plan? This action cannot be undone.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('plan-cancel-confirm')));
      await frames(tester);
      expect(details.calls, contains('cancel d1'));
      await unmount(tester);
    });

    testWidgets('MSG41 for a plan the Trader does not have', (tester) async {
      await open(tester, '/plan/gone');
      expect(find.byKey(const Key('plan-detail-failure')), findsOneWidget);
      expect(find.text('No results found.'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('SCR-20 and SCR-21', () {
    testWidgets('the journal in the Plans tab: rows with results, the filter '
        'and a trade', (tester) async {
      await open(tester, '/plans');
      await tab(tester, 'plans-tab-journal');
      expect(find.byKey(const Key('journal-row-j1')), findsOneWidget);
      expect(find.text('WIN'), findsOneWidget);
      expect(find.text('LOSS'), findsOneWidget);
      expect(find.text('+18.40'), findsOneWidget);

      await tester.tap(find.byKey(const Key('journal-filter')));
      await frames(tester);
      final manual = find.descendant(
        of: find.byKey(const Key('journal-filter-sheet')),
        matching: find.widgetWithText(ChoiceChip, 'Manual'),
      );
      await tester.ensureVisible(manual);
      await tester.pump();
      await tester.tap(manual);
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('journal-filter-apply')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('journal-filter-apply')));
      await frames(tester);
      expect(
        journal.calls.lastWhere((c) => c.startsWith('list')),
        startsWith('list MANUAL'),
      );
      expect(find.byKey(const Key('journal-row-j1')), findsNothing);
      expect(find.byKey(const Key('journal-row-j2')), findsOneWidget);

      await tester.tap(find.byKey(const Key('journal-row-j2')));
      await frames(tester);
      expect(find.byType(JournalEntryScreen), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('the filter narrows to one pair of the chosen market', (
      tester,
    ) async {
      journal.entries = [journalOf('j1'), journalOf('e1', base: 'ETH')];
      await open(tester, '/plans');
      await tab(tester, 'plans-tab-journal');
      await tester.tap(find.byKey(const Key('journal-filter')));
      await frames(tester);
      final futures = find.descendant(
        of: find.byKey(const Key('journal-filter-sheet')),
        matching: find.widgetWithText(ChoiceChip, 'Futures'),
      );
      await tester.tap(futures);
      await frames(tester);
      await tester.ensureVisible(find.byKey(const Key('journal-filter-pair')));
      await tester.tap(find.byKey(const Key('journal-filter-pair')));
      await frames(tester);
      await tester.tap(find.text('ETHUSDT').last);
      await frames(tester);
      await tester.ensureVisible(find.byKey(const Key('journal-filter-apply')));
      await tester.tap(find.byKey(const Key('journal-filter-apply')));
      await frames(tester);
      expect(find.byKey(const Key('journal-row-e1')), findsOneWidget);
      expect(find.byKey(const Key('journal-row-j1')), findsNothing);
      await unmount(tester);
    });

    testWidgets('SCR-21: the review is saved with MSG14; a simulated trade '
        'opens its plan', (tester) async {
      await open(tester, '/journal/j1');
      expect(find.byKey(const Key('journal-menu')), findsNothing);
      await reach(tester, 'journal-lessonsLearned');
      await tester.enterText(
        find.byKey(const Key('journal-lessonsLearned')),
        'Wait for the close.',
      );
      await reach(tester, 'journal-save');
      await tester.tap(find.byKey(const Key('journal-save')));
      await frames(tester);
      expect(journal.reviews.single['lessonsLearned'], 'Wait for the close.');
      expect(find.text('Saved successfully.'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.byKey(const Key('journal-open-plan')),
        -300,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('journal-entry')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.byKey(const Key('journal-open-plan')));
      await frames(tester);
      expect(find.byType(PlanDetailScreen), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('a trade with a chart image keeps its review read only '
        '(Q-95)', (tester) async {
      journal.details['j1'] = JournalDetail(
        entry: journalOf('j1'),
        setupDescription: 'Breakout',
        chartImageUrl: 'https://res.cloudinary.com/x/chart.png',
      );
      await open(tester, '/journal/j1');
      await reach(tester, 'journal-review-locked');
      expect(find.byKey(const Key('journal-review-locked')), findsOneWidget);
      await reach(tester, 'journal-setupDescription');
      expect(find.byKey(const Key('journal-save')), findsNothing);
      expect(
        tester
            .widget<TextField>(
              find.byKey(const Key('journal-setupDescription')),
            )
            .enabled,
        isFalse,
      );
      await unmount(tester);
    });

    testWidgets('a manual trade: edit on the web, or delete', (tester) async {
      await open(tester, '/journal/j2');
      await tester.tap(find.byKey(const Key('journal-menu')));
      await frames(tester);
      await tester.tap(find.byKey(const Key('journal-delete')));
      await frames(tester);
      await tester.tap(find.byKey(const Key('journal-delete-confirm')));
      await frames(tester);
      expect(journal.calls, contains('delete j2'));
      expect(find.byType(JournalEntryScreen), findsNothing);
      await unmount(tester);
    });
  });

  for (final brightness in Brightness.values) {
    testWidgets('360 dp, ${brightness.name}: Plans, SCR-18, SCR-19, the '
        'journal and SCR-21 do not overflow', (tester) async {
      tester.view
        ..physicalSize = const Size(360 * 3, 760 * 3)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await open(tester, '/plans', brightness: brightness);
      expect(tester.takeException(), isNull);
      expect(
        Theme.of(tester.element(find.byType(PlansScreen))).brightness,
        brightness,
      );
      await tab(tester, 'plans-tab-journal');
      expect(tester.takeException(), isNull);

      final router = containerOf(tester).read(appRouterProvider);
      unawaited(router.push('/plan/p2'));
      await frames(tester);
      expect(tester.takeException(), isNull);
      await tester.drag(
        find.byKey(const Key('plan-detail')),
        const Offset(0, -800),
      );
      await frames(tester);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('plan-close')));
      await frames(tester);
      expect(tester.takeException(), isNull);
      await tester.tapAt(const Offset(10, 10));
      await frames(tester);

      unawaited(router.push('/journal/j1'));
      await frames(tester);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  }
}
