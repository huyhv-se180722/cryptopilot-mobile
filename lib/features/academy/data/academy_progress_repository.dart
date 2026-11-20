import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/state/load_after_build.dart';
import '../domain/academy.dart';
import 'academy_api.dart';

@immutable
class ProgressState {
  const ProgressState({this.progress, this.failure});

  final AcademyProgress? progress;
  final ApiFailure? failure;

  bool learned(String slug) => progress?.completed.contains(slug) ?? false;
}

final academyProgressProvider =
    NotifierProvider.autoDispose<AcademyProgressRepository, ProgressState>(
      AcademyProgressRepository.new,
    );

/// One source of truth for the Trader's Academy progress (D-150 (2)): the
/// Home card, the Academy screen and the lesson page read it, and the lesson
/// page changes it. After a mark the totals are read again, since only the
/// server knows whether the lesson is on the beginner path.
class AcademyProgressRepository extends Notifier<ProgressState> {
  @override
  ProgressState build() {
    ref.loadAfterBuild(load);
    return const ProgressState();
  }

  AcademyApi get _api => ref.read(academyApiProvider);

  Future<void> load() async {
    try {
      final progress = await _api.progress();
      if (ref.mounted) state = ProgressState(progress: progress);
    } on ApiFailure catch (failure) {
      // What was shown stays; the failure says the totals may be old.
      if (ref.mounted) {
        state = ProgressState(progress: state.progress, failure: failure);
      }
    }
  }

  /// Marks or unmarks [slug]; throws the [ApiFailure] of the change.
  Future<void> setLearned(String slug, {required bool learned}) async {
    if (learned) {
      await _api.mark(slug);
    } else {
      await _api.unmark(slug);
    }
    if (ref.mounted) await load();
  }
}
