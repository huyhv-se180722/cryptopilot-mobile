import 'dart:async';

import 'package:cryptopilot_mobile/core/auth/token_store.dart';
import 'package:cryptopilot_mobile/core/errors/api_failure.dart';
import 'package:cryptopilot_mobile/core/media/media_picker.dart';
import 'package:cryptopilot_mobile/features/journal/application/journal_controllers.dart';
import 'package:cryptopilot_mobile/features/journal/data/journal_api.dart';
import 'package:cryptopilot_mobile/features/journal/domain/journal.dart';
import 'package:cryptopilot_mobile/features/plans/application/plan_detail_controller.dart';
import 'package:cryptopilot_mobile/features/plans/application/plan_lists.dart';
import 'package:cryptopilot_mobile/features/plans/data/plan_detail_api.dart';
import 'package:cryptopilot_mobile/features/plans/domain/plan.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/community_fakes.dart' show FakeMediaPicker;
import '../support/fakes.dart';
import '../support/plans_fakes.dart';
import '../support/realtime_fakes.dart';

void main() {
  late FakeTransport transport;
  late FakePlanApi plans;
  late FakePlanDetailApi details;
  late FakeJournalApi journal;
  late FakeMediaPicker picker;
  late ProviderContainer container;

  Future<void> pump(
    WidgetTester tester,
    List<ProviderListenable<Object?>> watched,
  ) async {
    transport = FakeTransport();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...baseOverrides(
            store: MemoryTokenStore(storedFor('saved')),
            tokens: FakeAuthTokenApi(),
            transport: transport,
            plans: plans,
          ),
          planDetailApiProvider.overrideWithValue(details),
          journalApiProvider.overrideWithValue(journal),
          mediaPickerProvider.overrideWithValue(picker),
        ],
        retry: (_, _) => null,
        child: Consumer(
          builder: (context, ref, _) {
            for (final provider in watched) {
              ref.watch(provider);
            }
            return const SizedBox();
          },
        ),
      ),
    );
    container = ProviderScope.containerOf(
      tester.element(find.byType(Consumer)),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }
    if (transport.connections.isNotEmpty) transport.last.onConnected();
    await tester.pump();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 31));
  }

  setUp(() {
    plans = FakePlanApi();
    details = FakePlanDetailApi();
    journal = FakeJournalApi();
    picker = FakeMediaPicker()
      ..nextImages = const [
        PickedFile(path: '/tmp/chart.png', name: 'chart.png', size: 1000),
      ];
  });

  group('Plans tab lists (A-61)', () {
    testWidgets('Open positions are the OPEN rows of the newest 100 executed '
        'plans; a position change reads every list again', (tester) async {
      final open = planListProvider(PlanList.openPositions);
      final active = planListProvider(PlanList.active);
      await pump(tester, [open, active]);
      expect(container.read(open).items!.map((p) => p.id), ['p2']);
      expect(plans.calls, containsAll(['EXECUTED 100', 'ACTIVE 20']));

      final before = plans.calls.length;
      transport.last.push(positionsQueue, {'planId': 'p2', 'status': 'CLOSED'});
      await tester.pump();
      await tester.pump();
      expect(plans.calls.length, before + 2);
      await unmount(tester);
    });

    testWidgets('a failed read keeps the failure for Retry', (tester) async {
      plans.error = problem(503, 'SERVICE_UNAVAILABLE', 'MSG43');
      final drafts = planListProvider(PlanList.drafts);
      await pump(tester, [drafts]);
      expect(container.read(drafts).items, isNull);
      expect(container.read(drafts).failure, isA<ProblemFailure>());
      plans.error = null;
      await container.read(drafts.notifier).load();
      expect(container.read(drafts).items, isNotEmpty);
      await unmount(tester);
    });
  });

  group('SCR-18 plan detail', () {
    testWidgets('an OPEN position is read again every 10 s and on its push, '
        'not on the push of another plan', (tester) async {
      final provider = planDetailControllerProvider('p2');
      await pump(tester, [provider]);
      expect(container.read(provider).plan?.hasOpenPosition, isTrue);
      int reads() => details.calls.where((c) => c == 'plan p2').length;
      final first = reads();

      await tester.pump(PlanDetailController.pollEvery);
      await tester.pump();
      expect(reads(), first + 1);

      transport.last.push(positionsQueue, {
        'planId': 'other',
        'status': 'CLOSED',
      });
      await tester.pump();
      expect(reads(), first + 1);
      transport.last.push(positionsQueue, {'planId': 'p2', 'status': 'CLOSED'});
      await tester.pump();
      await tester.pump();
      expect(reads(), first + 2);
      await unmount(tester);
    });

    testWidgets('an ACTIVE plan is not polled', (tester) async {
      final provider = planDetailControllerProvider('p1');
      await pump(tester, [provider]);
      final reads = details.calls.length;
      await tester.pump(PlanDetailController.pollEvery * 2);
      expect(details.calls.length, reads);
      await unmount(tester);
    });

    testWidgets('Activate: MSG51 asks first, then activates with the '
        'confirmation and the lists read again', (tester) async {
      final provider = planDetailControllerProvider('d1');
      final active = planListProvider(PlanList.active);
      await pump(tester, [provider, active]);
      details.failNext['activate'] = problem(
        400,
        'ENTRY_DEVIATION_CONFIRMATION_REQUIRED',
        'MSG51',
        args: ['0.4', '0.0142', '2.05'],
      );
      final controller = container.read(provider.notifier);
      final first = await controller.activate();
      expect(first, isA<NeedsConfirmation>());
      expect(container.read(provider).plan?.status, PlanStatus.draft);

      final listReads = plans.calls.length;
      final second = await controller.activate(confirmDeviation: true);
      await tester.pump();
      expect(second, isA<Activated>());
      expect(details.calls, contains('activate d1 true'));
      expect(container.read(provider).plan?.status, PlanStatus.active);
      expect(plans.calls.length, greaterThan(listReads));
      await unmount(tester);
    });

    testWidgets('Activate refused: MSG18 BLOCKING and MSG52', (tester) async {
      final provider = planDetailControllerProvider('d1');
      await pump(tester, [provider]);
      final controller = container.read(provider.notifier);
      details.failNext['activate'] = problem(
        409,
        'TRADING_BLOCKING_WARNING',
        'MSG18',
      );
      final blocked = await controller.activate();
      expect(blocked, isA<ActivateRefused>());
      details.failNext['activate'] = problem(
        409,
        'ENTRY_DEVIATION_REFUSED',
        'MSG52',
      );
      // MSG52 refuses even with the confirmation (BR-69).
      expect(
        await controller.activate(confirmDeviation: true),
        isA<ActivateRefused>(),
      );
      expect(container.read(provider).busy, isFalse);
      await unmount(tester);
    });

    testWidgets('Cancel and Close position show the new plan; a close the '
        'engine made first reads the plan again', (tester) async {
      final active = planDetailControllerProvider('p1');
      final open = planDetailControllerProvider('p2');
      await pump(tester, [active, open]);
      await container.read(active.notifier).cancel();
      expect(container.read(active).plan?.status, PlanStatus.cancelled);

      details.failNext['close'] = problem(409, 'CONFLICT', 'MSG43');
      final reads = details.calls.where((c) => c == 'plan p2').length;
      await expectLater(
        container.read(open.notifier).closePosition(),
        throwsA(isA<ProblemFailure>()),
      );
      await tester.pump();
      expect(details.calls.where((c) => c == 'plan p2').length, reads + 1);

      await container.read(open.notifier).closePosition();
      expect(container.read(open).plan?.hasOpenPosition, isFalse);
      await unmount(tester);
    });

    testWidgets('Set SL/TP sends the levels; a field error is thrown', (
      tester,
    ) async {
      final provider = planDetailControllerProvider('p2');
      await pump(tester, [provider]);
      final controller = container.read(provider.notifier);
      await controller.changeLevels(stopLoss: '66200');
      expect(details.calls, contains('levels p2 66200 null'));
      details.failNext['levels'] = problem(
        400,
        'VALIDATION_FAILED',
        'MSG16',
        fields: {'stopLoss': 'MSG16'},
      );
      await expectLater(
        controller.changeLevels(stopLoss: '70000'),
        throwsA(
          isA<ProblemFailure>().having(
            (f) => f.problem.fieldErrors['stopLoss'],
            'stopLoss',
            'MSG16',
          ),
        ),
      );
      await unmount(tester);
    });

    testWidgets('SCR-19 reads its estimate every 5 s while open', (
      tester,
    ) async {
      final provider = closeEstimateProvider('p2');
      await pump(tester, [provider]);
      expect(container.read(provider).estimate?.estimatedNetPnl, isNotNull);
      final reads = details.calls.where((c) => c == 'estimate p2').length;
      await tester.pump(CloseEstimateController.refreshEvery);
      await tester.pump();
      expect(details.calls.where((c) => c == 'estimate p2').length, reads + 1);
      await unmount(tester);
    });
  });

  group('SCR-20 journal', () {
    testWidgets('the last 30 days at first; filters and the next page', (
      tester,
    ) async {
      journal.entries = [
        for (var i = 0; i < 25; i++) journalOf('j$i'),
        journalOf('m1', source: TradeSource.manual),
      ];
      await pump(tester, [journalControllerProvider]);
      // The fake clock is 2026-11-06: 30 days from 2026-10-08.
      expect(journal.calls.first, 'list null null 2026-10-08 1');
      final controller = container.read(journalControllerProvider.notifier);
      expect(container.read(journalControllerProvider).hasMore, isTrue);
      await controller.loadMore();
      expect(container.read(journalControllerProvider).items, hasLength(26));

      await controller.setFilter(
        const JournalFilter(source: TradeSource.manual),
      );
      expect(
        container.read(journalControllerProvider).items!.map((e) => e.id),
        ['m1'],
      );
      await controller.setFilter(const JournalFilter(days: null));
      expect(journal.calls.last, 'list null null null 1');
      await unmount(tester);
    });
  });

  group('SCR-21 journal entry', () {
    testWidgets('saving the review trims the texts, clears empty ones and '
        'updates the list', (tester) async {
      final provider = journalEntryControllerProvider('j1');
      await pump(tester, [provider, journalControllerProvider]);
      expect(container.read(provider).reviewEditable, isTrue);
      await container
          .read(provider.notifier)
          .saveReview(
            strategyId: 's2',
            setupDescription: '  Pullback to EMA20  ',
            lessonsLearned: '   ',
          );
      expect(journal.reviews.single, {
        'strategyId': 's2',
        'setupDescription': 'Pullback to EMA20',
        'lessonsLearned': null,
        'mistakes': null,
      });
      expect(
        container.read(provider).detail?.setupDescription,
        'Pullback to EMA20',
      );
      await unmount(tester);
    });

    testWidgets('a trade with a chart image keeps its review read only '
        '(Q-97)', (tester) async {
      journal.details['j1'] = JournalDetail(
        entry: journalOf('j1'),
        chartImageUrl: 'https://res.cloudinary.com/x/chart.png',
      );
      final provider = journalEntryControllerProvider('j1');
      await pump(tester, [provider]);
      expect(container.read(provider).reviewEditable, isFalse);
      await container.read(provider.notifier).saveReview(setupDescription: 'x');
      expect(journal.reviews, isEmpty);
      await unmount(tester);
    });

    testWidgets('a manual trade is deleted and leaves the list', (
      tester,
    ) async {
      final provider = journalEntryControllerProvider('j2');
      await pump(tester, [provider, journalControllerProvider]);
      await container.read(provider.notifier).delete();
      expect(
        container.read(journalControllerProvider).items!.map((e) => e.id),
        isNot(contains('j2')),
      );
      await unmount(tester);
    });

    testWidgets('MSG41 for a trade the Trader does not have', (tester) async {
      final provider = journalEntryControllerProvider('gone');
      await pump(tester, [provider]);
      expect(container.read(provider).missing, isTrue);
      await unmount(tester);
    });
  });

  group('SCR-21 chart image (SRS 3.6.1; Q-97)', () {
    const stored =
        'cryptopilot/journal/owner/0b6f1c2e-1111-4222-8333-444455556666';
    final provider = journalEntryControllerProvider('j1');
    JournalEntryState read() => container.read(provider);
    JournalEntryController controller() => container.read(provider.notifier);

    testWidgets('a stored image keeps its key, read from its address, when '
        'the review is saved', (tester) async {
      journal.details['j1'] = JournalDetail(
        entry: journalOf('j1'),
        chartImageUrl: '${FakeJournalApi.storageBase}/v17/$stored.png',
      );
      await pump(tester, [provider]);
      expect(read().reviewEditable, isTrue);
      expect(read().image?.key, stored);
      expect(read().canSave, isTrue);
      await controller().saveReview(mistakes: 'Late entry');
      expect(journal.reviews.single['chartImagePublicId'], stored);
      expect(read().image?.key, stored);
      await unmount(tester);
    });

    testWidgets('a picked image is uploaded at once and saved by its key', (
      tester,
    ) async {
      await pump(tester, [provider]);
      journal.holdUpload = Completer<void>();
      final picking = controller().pickImage();
      await tester.pump();
      expect(picker.limits, [1]);
      expect(read().image?.progress, 0.5);
      expect(read().image?.path, '/tmp/chart.png');
      // Nothing is saved while the image is on its way.
      expect(read().canSave, isFalse);
      await controller().saveReview(mistakes: 'x');
      expect(journal.reviews, isEmpty);
      controller().removeImage();
      expect(read().image, isNotNull);

      journal.holdUpload!.complete();
      await picking;
      expect(journal.calls, containsAllInOrder(['chartImageForm j1']));
      expect(read().image?.ready, isTrue);
      expect(read().canSave, isTrue);
      await controller().saveReview(setupDescription: 'Retest');
      final key = journal.uploads.single;
      expect(journal.reviews.single['chartImagePublicId'], key);
      expect(read().detail?.chartImageUrl, endsWith('$key.png'));
      expect(read().image?.key, key);
      await unmount(tester);
    });

    testWidgets('a file too large or of another format is not sent (MSG32)', (
      tester,
    ) async {
      await pump(tester, [provider]);
      journal.maxBytes = 500;
      await controller().pickImage();
      expect(read().image?.problem, ReviewImageProblem.tooLarge);
      expect(read().image?.maxBytes, 500);
      picker.nextImages = const [
        PickedFile(path: '/tmp/chart.gif', name: 'chart.gif', size: 10),
      ];
      await controller().pickImage();
      expect(read().image?.problem, ReviewImageProblem.format);
      expect(journal.calls.where((c) => c.startsWith('upload')), isEmpty);
      // A picked file without a key holds the review back until removed.
      expect(read().canSave, isFalse);
      controller().removeImage();
      expect(read().image, isNull);
      expect(read().canSave, isTrue);
      await unmount(tester);
    });

    testWidgets('a refused upload is tried again with the same file', (
      tester,
    ) async {
      await pump(tester, [provider]);
      journal.refuseUploads = true;
      await controller().pickImage();
      expect(read().image?.problem, ReviewImageProblem.refused);
      journal.refuseUploads = false;
      await controller().retryImage();
      expect(read().image?.ready, isTrue);
      expect(read().image?.problem, isNull);
      expect(journal.calls.where((c) => c == 'upload /tmp/chart.png'), [
        'upload /tmp/chart.png',
        'upload /tmp/chart.png',
      ]);
      await unmount(tester);
    });

    testWidgets('the signed form not given keeps its failure', (tester) async {
      await pump(tester, [provider]);
      journal.failNext['chartImageForm'] = problem(
        503,
        'MEDIA_STORAGE_UNAVAILABLE',
        'MSG43',
      );
      await controller().pickImage();
      expect(read().image?.problem, ReviewImageProblem.form);
      expect(read().image?.failure, isA<ProblemFailure>());
      await controller().retryImage();
      expect(read().image?.ready, isTrue);
      await unmount(tester);
    });

    testWidgets('a removed image is left out of the review, which drops it', (
      tester,
    ) async {
      journal.details['j1'] = JournalDetail(
        entry: journalOf('j1'),
        chartImageUrl: '${FakeJournalApi.storageBase}/$stored.webp',
      );
      await pump(tester, [provider]);
      controller().removeImage();
      await controller().saveReview(mistakes: 'm');
      expect(journal.reviews.single.containsKey('chartImagePublicId'), isFalse);
      expect(read().detail?.chartImageUrl, isNull);
      expect(read().image, isNull);
      await unmount(tester);
    });

    testWidgets('MSG32 on saving keeps the image and the texts editable', (
      tester,
    ) async {
      await pump(tester, [provider]);
      await controller().pickImage();
      journal.failNext['review'] = problem(
        400,
        'MEDIA_INVALID',
        'MSG32',
        fields: const {'chartImagePublicId': 'MSG32'},
      );
      await expectLater(
        controller().saveReview(mistakes: 'm'),
        throwsA(isA<ProblemFailure>()),
      );
      expect(read().saving, isFalse);
      expect(read().image?.ready, isTrue);
      expect(read().canSave, isTrue);
      await unmount(tester);
    });

    testWidgets('a review kept read only picks no image', (tester) async {
      journal.details['j1'] = JournalDetail(
        entry: journalOf('j1'),
        chartImageUrl: 'https://res.cloudinary.com/x/chart.png',
      );
      await pump(tester, [provider]);
      await controller().pickImage();
      expect(picker.limits, isEmpty);
      expect(read().image?.url, 'https://res.cloudinary.com/x/chart.png');
      await unmount(tester);
    });
  });
}
