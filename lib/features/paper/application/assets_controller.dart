import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/settings/settings.dart';
import '../data/paper_api.dart';
import '../data/paper_repository.dart';
import '../domain/futures.dart';
import '../domain/paper.dart';

/// A coin is "small" below this value in USDT (plan 9.3).
final smallBalance = Decimal.one;

@immutable
class AssetsState {
  const AssetsState({
    this.futures,
    this.failure,
    this.hideBalances = false,
    this.hideSmall = false,
  });

  /// The Futures wallet (USDT only in T-128; positions with T-129).
  final Wallet? futures;
  final ApiFailure? failure;

  /// 👁: every amount masked, kept on the device.
  final bool hideBalances;

  /// Coins worth less than 1 USDT left out; an unvalued coin stays.
  final bool hideSmall;

  AssetsState copyWith({
    Wallet? futures,
    ApiFailure? failure,
    bool clearFailure = false,
    bool? hideBalances,
    bool? hideSmall,
  }) => AssetsState(
    futures: futures ?? this.futures,
    failure: clearFailure ? null : failure ?? this.failure,
    hideBalances: hideBalances ?? this.hideBalances,
    hideSmall: hideSmall ?? this.hideSmall,
  );
}

/// The coins of [wallet] to list: the ones held, small ones left out when
/// asked; USDT first, then by value.
List<Balance> shownCoins(Wallet wallet, {required bool hideSmall}) {
  Decimal value(Balance b) =>
      Decimal.tryParse(b.usdtValue ?? '') ?? Decimal.zero;
  final held = [
    for (final balance in wallet.balances)
      if ((Decimal.tryParse(balance.total) ?? Decimal.zero) > Decimal.zero &&
          (!hideSmall ||
              balance.usdtValue == null ||
              value(balance) >= smallBalance))
        balance,
  ];
  return held..sort((a, b) {
    if (a.asset == 'USDT') return -1;
    if (b.asset == 'USDT') return 1;
    return value(b).compareTo(value(a));
  });
}

final assetsControllerProvider =
    NotifierProvider.autoDispose<AssetsController, AssetsState>(
      AssetsController.new,
    );

/// The Assets tab (plan 9.3): the Spot wallet comes from
/// [PaperAccountRepository]; this reads the Futures wallet and keeps the
/// two display choices on the device.
class AssetsController extends Notifier<AssetsState> {
  static const hideBalancesKey = 'paper.hideBalances';
  static const hideSmallKey = 'paper.hideSmall';

  @override
  AssetsState build() {
    ref.listen(paperAccountProvider, (_, _) {});
    unawaited(Future.microtask(_start));
    return const AssetsState();
  }

  Future<void> _start() async {
    final store = ref.read(settingsStoreProvider);
    final hide = await store.read(hideBalancesKey);
    final small = await store.read(hideSmallKey);
    if (!ref.mounted) return;
    state = state.copyWith(
      hideBalances: hide == 'true',
      hideSmall: small == 'true',
    );
    await load();
  }

  Future<void> load() async {
    try {
      await ref.read(paperAccountProvider.notifier).opened;
      if (!ref.mounted) return;
      final futures = await ref
          .read(paperApiProvider)
          .wallet(PaperWallet.futures);
      if (ref.mounted) {
        state = state.copyWith(futures: futures, clearFailure: true);
      }
    } on ApiFailure catch (failure) {
      if (ref.mounted) state = state.copyWith(failure: failure);
    }
  }

  /// Both wallets again (pull to refresh, after a transfer).
  Future<void> refresh() async {
    await Future.wait([ref.read(paperAccountProvider.notifier).load(), load()]);
  }

  Future<void> toggleHideBalances() async {
    state = state.copyWith(hideBalances: !state.hideBalances);
    await ref
        .read(settingsStoreProvider)
        .write(hideBalancesKey, '${state.hideBalances}');
  }

  Future<void> toggleHideSmall() async {
    state = state.copyWith(hideSmall: !state.hideSmall);
    await ref
        .read(settingsStoreProvider)
        .write(hideSmallKey, '${state.hideSmall}');
  }
}

@immutable
class TransferState {
  const TransferState({
    this.from = PaperWallet.spot,
    this.amount = '',
    this.issue,
    this.failure,
    this.sending = false,
  });

  final PaperWallet from;
  final String amount;

  /// The amount is missing, not positive, over 8 decimals or over what
  /// the wallet holds.
  final TransferIssue? issue;
  final ApiFailure? failure;
  final bool sending;

  PaperWallet get to =>
      from == PaperWallet.spot ? PaperWallet.futures : PaperWallet.spot;
}

enum TransferIssue { required, notPositive, tooPrecise, overAvailable }

final transferControllerProvider =
    NotifierProvider.autoDispose<TransferController, TransferState>(
      TransferController.new,
    );

/// USDT between the Spot and Futures wallets (plan 9.3, 9.8): at most what
/// the source holds free, 8 decimals; a key per transfer, sent again
/// unchanged after a network failure so it cannot move twice.
class TransferController extends Notifier<TransferState> {
  String? _pendingKey;

  @override
  TransferState build() => const TransferState();

  void swap() {
    _pendingKey = null;
    state = TransferState(from: state.to, amount: state.amount);
  }

  void edit(String amount) {
    _pendingKey = null;
    state = TransferState(from: state.from, amount: amount.trim());
  }

  /// What can leave the source wallet in USDT: the Spot USDT free, or out
  /// of Futures its `maxWithdrawAmount` (TR-18: neither the margin in use
  /// nor unrealized profit leaves), the wallet's free USDT until the
  /// account is read.
  String? available(Wallet? spot, Wallet? futures, [FuturesAccount? account]) =>
      state.from == PaperWallet.spot
      ? spot?.of('USDT')?.free
      : account?.maxWithdrawAmount ?? futures?.of('USDT')?.free;

  /// True when the transfer went.
  Future<bool> send({required String? available}) async {
    if (state.sending) return false;
    final amount = Decimal.tryParse(state.amount);
    final issue = state.amount.isEmpty
        ? TransferIssue.required
        : amount == null || amount <= Decimal.zero
        ? TransferIssue.notPositive
        : amount.scale > 8
        ? TransferIssue.tooPrecise
        : available != null && amount > Decimal.parse(available)
        ? TransferIssue.overAvailable
        : null;
    if (issue != null) {
      state = TransferState(
        from: state.from,
        amount: state.amount,
        issue: issue,
      );
      return false;
    }
    final key = _pendingKey ??= newClientId();
    state = TransferState(
      from: state.from,
      amount: state.amount,
      sending: true,
    );
    try {
      await ref
          .read(paperApiProvider)
          .transfer(
            from: state.from,
            amount: state.amount,
            clientTransferId: key,
          );
      _pendingKey = null;
      if (ref.mounted) state = TransferState(from: state.from);
      return true;
    } on ApiFailure catch (failure) {
      if (failure is! NetworkFailure) _pendingKey = null;
      if (ref.mounted) {
        state = TransferState(
          from: state.from,
          amount: state.amount,
          failure: failure,
        );
      }
      return false;
    }
  }
}
