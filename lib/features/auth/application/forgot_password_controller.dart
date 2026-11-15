import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../data/auth_api.dart';
import '../domain/credentials_rules.dart';

@immutable
class ForgotPasswordState {
  const ForgotPasswordState({
    this.pending = false,
    this.sent = false,
    this.emailError,
    this.failure,
    this.wait = 0,
  });

  final bool pending;

  /// The request was accepted: MSG12, whoever the address belongs to.
  final bool sent;

  /// The message code under the e-mail field.
  final String? emailError;
  final ApiFailure? failure;

  /// Seconds until the link may be asked again.
  final int wait;

  /// [errors] replaces both the field's error and the failed call.
  ForgotPasswordState copyWith({
    bool? pending,
    bool? sent,
    ({String? email, ApiFailure? failure})? errors,
    int? wait,
  }) => ForgotPasswordState(
    pending: pending ?? this.pending,
    sent: sent ?? this.sent,
    emailError: errors == null ? emailError : errors.email,
    failure: errors == null ? failure : errors.failure,
    wait: wait ?? this.wait,
  );
}

final forgotPasswordControllerProvider =
    NotifierProvider.autoDispose<ForgotPasswordController, ForgotPasswordState>(
      ForgotPasswordController.new,
    );

/// The view model of SCR-05 (UC-04): asks for the reset link, then holds the
/// button for the cooldown.
class ForgotPasswordController extends Notifier<ForgotPasswordState> {
  static const cooldown = 60;

  Timer? _timer;

  @override
  ForgotPasswordState build() {
    ref.onDispose(() => _timer?.cancel());
    return const ForgotPasswordState();
  }

  void _startCooldown() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!ref.mounted || state.wait <= 1) {
        timer.cancel();
        if (ref.mounted) state = state.copyWith(wait: 0);
        return;
      }
      state = state.copyWith(wait: state.wait - 1);
    });
  }

  Future<void> submit(String email) async {
    final address = email.trim();
    final error = address.isEmpty
        ? 'MSG01'
        : (looksLikeEmail(address) ? null : 'MSG02');
    state = state.copyWith(errors: (email: error, failure: null));
    if (error != null) return;
    state = state.copyWith(pending: true);
    try {
      await ref.read(authApiProvider).forgotPassword(address);
      if (!ref.mounted) return;
      state = state.copyWith(sent: true, wait: cooldown);
      _startCooldown();
    } on ApiFailure catch (failure) {
      if (!ref.mounted) return;
      final field = failure is ProblemFailure
          ? failure.problem.fieldErrors['email']
          : null;
      state = state.copyWith(
        errors: field != null
            ? (email: field, failure: null)
            : (email: null, failure: failure),
      );
    } finally {
      if (ref.mounted) state = state.copyWith(pending: false);
    }
  }
}
