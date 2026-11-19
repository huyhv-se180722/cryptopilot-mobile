import 'dart:async';

import 'package:cryptopilot_mobile/core/auth/token_store.dart';
import 'package:cryptopilot_mobile/features/academy/application/academy_controller.dart';
import 'package:cryptopilot_mobile/features/academy/application/glossary_controller.dart';
import 'package:cryptopilot_mobile/features/academy/application/lesson_controller.dart';
import 'package:cryptopilot_mobile/features/academy/data/academy_progress_repository.dart';
import 'package:cryptopilot_mobile/features/academy/domain/academy.dart';
import 'package:cryptopilot_mobile/features/academy/domain/markdown.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/academy_fakes.dart';
import '../support/fakes.dart';

void main() {
  late FakeAcademyApi api;
  late ProviderContainer container;

  Future<void> pump(
    WidgetTester tester,
    List<ProviderListenable<Object?>> watched,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: baseOverrides(
          store: MemoryTokenStore(storedFor('saved')),
          tokens: FakeAuthTokenApi(),
          academy: api,
        ),
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
    for (var i = 0; i < 6; i++) {
      await tester.pump();
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 31));
  }

  List<String> lessonCalls() => [
    for (final call in api.calls)
      if (call.startsWith('lessons')) call,
  ];

  setUp(() => api = FakeAcademyApi());

  group('AcademyController', () {
    testWidgets('topics, path and the first 20 lessons; the end of the list '
        'reads the rest once', (tester) async {
      await pump(tester, [academyControllerProvider]);
      var state = container.read(academyControllerProvider);
      expect(state.topics, hasLength(2));
      expect(state.path, hasLength(3));
      expect(state.lessons, hasLength(academyPageSize));
      expect(state.total, 35);
      expect(state.hasMore, isTrue);

      await container.read(academyControllerProvider.notifier).loadMore();
      state = container.read(academyControllerProvider);
      expect(state.lessons, hasLength(35));
      expect(state.hasMore, isFalse);

      await container.read(academyControllerProvider.notifier).loadMore();
      expect(lessonCalls(), ['lessons page=1', 'lessons page=2']);
      await unmount(tester);
    });

    testWidgets('a topic or a level starts again from page 1; an answer to '
        'the older filter is dropped', (tester) async {
      await pump(tester, [academyControllerProvider]);
      final controller = container.read(academyControllerProvider.notifier);
      api.lessonsHold = Completer<void>();
      controller.selectLevel(LessonLevel.beginner);
      controller.selectTopic('risk');
      await tester.pump();
      expect(container.read(academyControllerProvider).lessons, isNull);

      api.lessonsHold!.complete();
      api.lessonsHold = null;
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }
      final state = container.read(academyControllerProvider);
      expect(lessonCalls().skip(1), [
        'lessons page=1 level=BEGINNER',
        'lessons page=1 topic=risk level=BEGINNER',
      ]);
      // Risk lessons are INTERMEDIATE: the older, wider answer did not land.
      expect(state.lessons, isEmpty);
      expect(state.filtered, isTrue);

      controller
        ..selectLevel(null)
        ..selectTopic(null);
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }
      expect(container.read(academyControllerProvider).lessons, hasLength(20));
      await unmount(tester);
    });

    testWidgets('search waits for a pause and at least 2 characters', (
      tester,
    ) async {
      await pump(tester, [academyControllerProvider]);
      final controller = container.read(academyControllerProvider.notifier);
      controller.search('l');
      await tester.pump(const Duration(seconds: 1));
      expect(lessonCalls(), ['lessons page=1']);

      controller.search('le');
      await tester.pump(const Duration(milliseconds: 200));
      controller.search('lesson-3');
      await tester.pump(const Duration(milliseconds: 300));
      expect(lessonCalls(), ['lessons page=1']);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();
      expect(lessonCalls().last, 'lessons page=1 q=lesson-3');
      expect(container.read(academyControllerProvider).query, 'lesson-3');
      await unmount(tester);
    });

    testWidgets('a first page that cannot be read gives the failure; Try '
        'again reads it', (tester) async {
      api.lessonsError = problem(503, 'UNAVAILABLE', 'MSG43');
      await pump(tester, [academyControllerProvider]);
      expect(container.read(academyControllerProvider).failure, isNotNull);

      api.lessonsError = null;
      await container.read(academyControllerProvider.notifier).load();
      final state = container.read(academyControllerProvider);
      expect(state.failure, isNull);
      expect(state.lessons, hasLength(20));
      await unmount(tester);
    });
  });

  group('AcademyProgressRepository and the lesson page', () {
    testWidgets('marking reads the totals again; every reader sees it', (
      tester,
    ) async {
      await pump(tester, [
        academyProgressProvider,
        lessonControllerProvider('lesson-2'),
      ]);
      var progress = container.read(academyProgressProvider);
      expect(progress.learned('lesson-1'), isTrue);
      expect(progress.learned('lesson-2'), isFalse);
      expect(progress.progress!.pathCompleted, 1);

      await container
          .read(lessonControllerProvider('lesson-2').notifier)
          .setLearned(learned: true);
      progress = container.read(academyProgressProvider);
      expect(progress.learned('lesson-2'), isTrue);
      expect(progress.progress!.pathCompleted, 2);
      expect(api.calls.where((c) => c == 'progress'), hasLength(2));

      await container
          .read(lessonControllerProvider('lesson-2').notifier)
          .setLearned(learned: false);
      expect(
        container.read(academyProgressProvider).learned('lesson-2'),
        isFalse,
      );
      await unmount(tester);
    });

    testWidgets('the button waits for the server; a refusal is kept for the '
        'page and the mark is unchanged', (tester) async {
      await pump(tester, [
        academyProgressProvider,
        lessonControllerProvider('lesson-2'),
      ]);
      final lesson = lessonControllerProvider('lesson-2');
      api.markHold = Completer<void>();
      final done = container.read(lesson.notifier).setLearned(learned: true);
      await tester.pump();
      expect(container.read(lesson).marking, isTrue);
      // A second tap while waiting sends nothing.
      unawaited(container.read(lesson.notifier).setLearned(learned: true));
      api.markError = problem(404, 'NOT_FOUND', 'MSG41');
      api.markHold!.complete();
      await done;
      final state = container.read(lesson);
      expect(state.marking, isFalse);
      expect(state.markFailure, isNotNull);
      expect(api.calls.where((c) => c.startsWith('mark')), hasLength(1));
      expect(
        container.read(academyProgressProvider).learned('lesson-2'),
        isFalse,
      );
      await unmount(tester);
    });

    testWidgets('the lesson body is parsed once; a lesson no longer '
        'published is missing (MSG41)', (tester) async {
      api.bodies['lesson-2'] = '## A\n\n- x\n- y';
      await pump(tester, [lessonControllerProvider('lesson-2')]);
      final state = container.read(lessonControllerProvider('lesson-2'));
      expect(state.lesson!.summary.slug, 'lesson-2');
      expect(state.blocks.map((b) => b.runtimeType), [HeadingBlock, ListBlock]);
      await unmount(tester);

      api.lessonError = problem(404, 'NOT_FOUND', 'MSG41');
      await pump(tester, [lessonControllerProvider('gone')]);
      expect(container.read(lessonControllerProvider('gone')).missing, isTrue);
      await unmount(tester);
    });
  });

  group('GlossaryController', () {
    testWidgets('every term under its first letter; a letter and a search '
        'go to the server', (tester) async {
      await pump(tester, [glossaryControllerProvider]);
      var state = container.read(glossaryControllerProvider);
      expect(state.groups.keys, ['A', 'B']);
      expect(state.groups['A'], hasLength(2));

      container.read(glossaryControllerProvider.notifier).selectLetter('B');
      await tester.pump();
      await tester.pump();
      state = container.read(glossaryControllerProvider);
      expect(state.terms!.single.term, 'Bitcoin (BTC)');

      container.read(glossaryControllerProvider.notifier)
        ..selectLetter(null)
        ..search('alt');
      await tester.pump(academySearchDelay);
      await tester.pump();
      expect(api.calls.last, 'terms q=alt');
      expect(
        container.read(glossaryControllerProvider).terms!.single.slug,
        'altcoin',
      );
      await unmount(tester);
    });

    testWidgets('a glossary that cannot be read gives the failure', (
      tester,
    ) async {
      api.termsError = problem(503, 'UNAVAILABLE', 'MSG43');
      await pump(tester, [glossaryControllerProvider]);
      expect(container.read(glossaryControllerProvider).failure, isNotNull);
      await unmount(tester);
    });
  });

  test('Đ is a letter of its own, as on the web', () {
    expect(glossaryLetters, contains('Đ'));
    expect(glossaryLetters.indexOf('Đ'), glossaryLetters.indexOf('D') + 1);
  });
}
