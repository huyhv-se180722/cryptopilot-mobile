import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/errors/api_failure.dart';
import '../data/auth_api.dart';
import '../domain/credentials_rules.dart';

/// What the banner above the form says besides a failed call.
enum LoginNotice {
  /// The last session ended (MSG44).
  sessionExpired,

  /// The verification e-mail was sent again.
  resendSent,
}

@immutable
class LoginState {
  const LoginState({
    this.pending = false,
    this.fieldErrors = const {},
    this.failure,
    this.notice,
    this.offerResend = false,
    this.resendWait = 0,
  });

  final bool pending;

  /// `email` / `password` → the message code under the field (MSG01, MSG02
  /// or the server's).
  final Map<String, String> fieldErrors;

  /// The failed call the banner explains.
  final ApiFailure? failure;
  final LoginNotice? notice;

  /// The account's e-mail is not verified yet: offer to send the link again.
  final bool offerResend;

  /// Seconds until the link may be sent again.
  final int resendWait;

  /// [banner] replaces what the banner says: a failure, a notice or nothing.
  LoginState copyWith({
    bool? pending,
    Map<String, String>? fieldErrors,
    ({ApiFailure? failure, LoginNotice? notice})? banner,
    bool? offerResend,
    int? resendWait,
  }) => LoginState(
    pending: pending ?? this.pending,
    fieldErrors: fieldErrors ?? this.fieldErrors,
    failure: banner == null ? failure : banner.failure,
    notice: banner == null ? notice : banner.notice,
    offerResend: offerResend ?? this.offerResend,
    resendWait: resendWait ?? this.resendWait,
  );
}

const _noBanner = (failure: null, notice: null);

final loginControllerProvider =
    NotifierProvider.autoDispose<LoginController, LoginState>(
      LoginController.new,
    );

/// The view model of SCR-04 (UC-03): checks the form, signs in and keeps the
/// session, offers the verification link again with a cooldown.
class LoginController extends Notifier<LoginState> {
  static const resendCooldown = 60;

  Timer? _resendTimer;

  @override
  LoginState build() {
    ref.onDispose(() => _resendTimer?.cancel());
    final session = ref.read(sessionControllerProvider);
    return LoginState(
      notice: session is SignedOut && session.expired
          ? LoginNotice.sessionExpired
          : null,
    );
  }

  Future<void> submit({
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    final address = email.trim();
    final errors = <String, String>{
      if (address.isEmpty)
        'email': 'MSG01'
      else if (!looksLikeEmail(address))
        'email': 'MSG02',
      if (password.isEmpty) 'password': 'MSG01',
    };
    state = state.copyWith(
      fieldErrors: errors,
      banner: _noBanner,
      offerResend: false,
    );
    if (errors.isNotEmpty) return;
    state = state.copyWith(pending: true);
    try {
      final session = await ref
          .read(authApiProvider)
          .login(email: address, password: password, rememberMe: rememberMe);
      await ref.read(sessionControllerProvider.notifier).signIn(session);
    } on ApiFailure catch (failure) {
      if (!ref.mounted) return;
      final fields = failure is ProblemFailure
          ? failure.problem.fieldErrors
          : const <String, String>{};
      state = fields.isNotEmpty
          ? state.copyWith(fieldErrors: fields)
          : state.copyWith(
              banner: (failure: failure, notice: null),
              offerResend:
                  failure is ProblemFailure &&
                  failure.code == 'EMAIL_NOT_VERIFIED',
            );
    } finally {
      if (ref.mounted) state = state.copyWith(pending: false);
    }
  }

  Future<void> resend(String email) async {
    state = state.copyWith(resendWait: resendCooldown);
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!ref.mounted || state.resendWait <= 1) {
        timer.cancel();
        if (ref.mounted) state = state.copyWith(resendWait: 0);
        return;
      }
      state = state.copyWith(resendWait: state.resendWait - 1);
    });
    try {
      await ref.read(authApiProvider).resendVerification(email.trim());
      if (!ref.mounted) return;
      state = state.copyWith(
        banner: (failure: null, notice: LoginNotice.resendSent),
        offerResend: false,
      );
    } on ApiFailure catch (failure) {
      if (ref.mounted) {
        state = state.copyWith(banner: (failure: failure, notice: null));
      }
    }
  }
}
