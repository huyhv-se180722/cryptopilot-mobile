import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../data/academy_api.dart';
import '../data/academy_progress_repository.dart';
import '../domain/academy.dart';
import '../domain/markdown.dart';

@immutable
class LessonState {
  const LessonState({
    this.lesson,
    this.blocks = const [],
    this.failure,
    this.marking = false,
    this.markFailure,
  });

  final Lesson? lesson;

  /// The body, parsed once.
  final List<Block> blocks;
  final ApiFailure? failure;

  /// A mark or unmark is under way: the button waits.
  final bool marking;
  final ApiFailure? markFailure;

  /// No published lesson with the slug (404 MSG41).
  bool get missing =>
      failure is ProblemFailure &&
      (failure! as ProblemFailure).problem.messageCode == 'MSG41';
}

final lessonControllerProvider = NotifierProvider.autoDispose
    .family<LessonController, LessonState, String>(LessonController.new);

/// A lesson page: the lesson read once, its body parsed, and "Mark as
/// learned", which waits for the server as the web does.
class LessonController extends Notifier<LessonState> {
  LessonController(this.slug);

  final String slug;

  @override
  LessonState build() {
    unawaited(Future.microtask(load));
    return const LessonState();
  }

  Future<void> load() async {
    state = const LessonState();
    try {
      final lesson = await ref.read(academyApiProvider).lesson(slug);
      if (!ref.mounted) return;
      state = LessonState(lesson: lesson, blocks: parseMarkdown(lesson.body));
    } on ApiFailure catch (failure) {
      if (ref.mounted) state = LessonState(failure: failure);
    }
  }

  Future<void> setLearned({required bool learned}) async {
    if (state.marking) return;
    state = _marking(true);
    try {
      await ref
          .read(academyProgressProvider.notifier)
          .setLearned(slug, learned: learned);
      if (ref.mounted) state = _marking(false);
    } on ApiFailure catch (failure) {
      if (ref.mounted) state = _marking(false, failure: failure);
    }
  }

  LessonState _marking(bool marking, {ApiFailure? failure}) => LessonState(
    lesson: state.lesson,
    blocks: state.blocks,
    failure: state.failure,
    marking: marking,
    markFailure: failure,
  );
}
