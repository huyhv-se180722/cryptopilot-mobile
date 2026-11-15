import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/errors/api_failure.dart';
import '../data/profile_api.dart';
import '../domain/profile.dart';

@immutable
class AccountState {
  const AccountState({this.profile, this.loadFailure, this.saving = false});

  /// Null until the first read.
  final Profile? profile;
  final ApiFailure? loadFailure;

  /// A switch is being saved: both wait.
  final bool saving;

  AccountState copyWith({
    Profile? profile,
    ApiFailure? loadFailure,
    bool clearLoadFailure = false,
    bool? saving,
  }) => AccountState(
    profile: profile ?? this.profile,
    loadFailure: clearLoadFailure ? null : loadFailure ?? this.loadFailure,
    saving: saving ?? this.saving,
  );
}

final accountControllerProvider =
    NotifierProvider.autoDispose<AccountController, AccountState>(
      AccountController.new,
    );

/// The view model of the account screen (A-59): who is signed in, the
/// notification switches of SCR-07, Log out.
class AccountController extends Notifier<AccountState> {
  @override
  AccountState build() {
    unawaited(Future.microtask(load));
    return const AccountState();
  }

  Future<void> load() async {
    state = state.copyWith(clearLoadFailure: true);
    try {
      final profile = await ref.read(profileApiProvider).profile();
      if (ref.mounted) state = state.copyWith(profile: profile);
    } on ApiFailure catch (failure) {
      if (ref.mounted) state = state.copyWith(loadFailure: failure);
    }
  }

  /// Shows [next] at once and saves it; a failed save puts the switches
  /// back and is returned for the screen to tell.
  Future<ApiFailure?> saveNotifications(Profile next) async {
    final api = ref.read(profileApiProvider);
    final before = state.profile;
    state = state.copyWith(profile: next, saving: true);
    try {
      await api.saveNotifications(
        email: next.notifyEmail,
        push: next.notifyPush,
      );
      return null;
    } on ApiFailure catch (failure) {
      if (ref.mounted) state = state.copyWith(profile: before);
      return failure;
    } finally {
      if (ref.mounted) state = state.copyWith(saving: false);
    }
  }

  Future<void> signOut() =>
      ref.read(sessionControllerProvider.notifier).signOut();
}
