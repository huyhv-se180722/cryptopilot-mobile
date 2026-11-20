import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/state/load_after_build.dart';
import '../data/ai_api.dart';
import '../domain/ai.dart';

@immutable
class AiQuotaState {
  const AiQuotaState({this.quota, this.failure});

  /// Null until first read.
  final AiQuota? quota;
  final ApiFailure? failure;
}

final aiQuotaProvider =
    NotifierProvider.autoDispose<AiQuotaController, AiQuotaState>(
      AiQuotaController.new,
    );

/// Today's questions (BR-50), read when an AI screen opens, again after each
/// answer or failure (a FAILED question gives its unit back), and replaced by
/// the quota a question returns.
class AiQuotaController extends Notifier<AiQuotaState> {
  @override
  AiQuotaState build() {
    ref.loadAfterBuild(load);
    return const AiQuotaState();
  }

  Future<void> load() async {
    try {
      final quota = await ref.read(aiApiProvider).quota();
      if (ref.mounted) state = AiQuotaState(quota: quota);
    } on ApiFailure catch (failure) {
      // The last known quota stays; the screen still lets the server decide.
      if (ref.mounted) {
        state = AiQuotaState(quota: state.quota, failure: failure);
      }
    }
  }

  void set(AiQuota quota) => state = AiQuotaState(quota: quota);
}
