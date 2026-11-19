import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/errors/api_failure.dart';
import '../data/auth_api.dart';
import '../domain/credentials_rules.dart';

/// Under the confirmation field when it differs from the new password; not
/// a server message code.
const passwordsDifferCode = 'PASSWORDS_DIFFER';

@immutable
class ResetPasswordState {
  const ResetPasswordState({
    this.pending = false,
    this.linkInvalid = false,
    this.fieldErrors = const {},
    this.failure,
  });

  final bool pending;

  /// No token, or the server refused it: MSG07 and a way to ask a new link.
  final bool linkInvalid;

  /// `newPassword` / `confirmPassword` → the message code under the field,
  /// or [passwordsDifferCode].
  final Map<String, String> fieldErrors;
  final ApiFailure? failure;

  ResetPasswordState copyWith({
    bool? pending,
    bool? linkInvalid,
    Map<String, String>? fieldErrors,
    ApiFailure? failure,
    bool clearFailure = false,
  }) => ResetPasswordState(
    pending: pending ?? this.pending,
    linkInvalid: linkInvalid ?? this.linkInvalid,
    fieldErrors: fieldErrors ?? this.fieldErrors,
    failure: clearFailure ? null : failure ?? this.failure,
  );
}

final resetPasswordControllerProvider = NotifierProvider.autoDispose
    .family<ResetPasswordController, ResetPasswordState, String?>(
      ResetPasswordController.new,
    );

/// The view model of SCR-06 for the `token` of the mailed link (D-108).
class ResetPasswordController extends Notifier<ResetPasswordState> {
  ResetPasswordController(this.token);

  final String? token;

  @override
  ResetPasswordState build() =>
      ResetPasswordState(linkInvalid: (token ?? '').isEmpty);

  /// True when the password was changed; every session of the account ended
  /// on the server, so this device forgets its own.
  Future<bool> submit({
    required String password,
    required String confirm,
  }) async {
    final errors = <String, String>{
      if (password.isEmpty)
        'newPassword': 'MSG01'
      else if (!PasswordRules(password).all)
        'newPassword': 'MSG03',
      if (confirm.isEmpty)
        'confirmPassword': 'MSG01'
      else if (confirm != password)
        'confirmPassword': passwordsDifferCode,
    };
    state = state.copyWith(fieldErrors: errors, clearFailure: true);
    if (errors.isNotEmpty) return false;
    state = state.copyWith(pending: true);
    try {
      await ref
          .read(authApiProvider)
          .resetPassword(
            token: token!,
            newPassword: password,
            confirmPassword: confirm,
          );
      await ref.read(sessionControllerProvider.notifier).forget();
      return true;
    } on ApiFailure catch (failure) {
      if (ref.mounted) _show(failure);
      return false;
    } finally {
      if (ref.mounted) state = state.copyWith(pending: false);
    }
  }

  void _show(ApiFailure failure) {
    if (failure is ProblemFailure) {
      if (failure.code == 'TOKEN_INVALID_OR_EXPIRED') {
        state = state.copyWith(linkInvalid: true);
        return;
      }
      final fields = failure.problem.fieldErrors;
      if (fields.isNotEmpty) {
        state = state.copyWith(
          fieldErrors: {
            for (final MapEntry(:key, :value) in fields.entries)
              key == 'confirmPasswordMatching' ? 'confirmPassword' : key: value,
          },
        );
        return;
      }
    }
    state = state.copyWith(failure: failure);
  }
}
