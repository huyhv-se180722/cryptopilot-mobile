import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/json/json_read.dart';
import '../../../core/realtime/realtime_hub.dart';
import '../../../core/state/load_after_build.dart';
import '../domain/paper.dart';
import 'paper_api.dart';

const ordersQueue = '/user/queue/orders';
const balancesQueue = '/user/queue/balances';
const fillsQueue = '/user/queue/fills';

/// True once the demo account is known to be open in this run: readers that
/// must not open it themselves (the Home block) read again then.
final paperOpenedProvider = NotifierProvider<PaperOpened, bool>(
  PaperOpened.new,
);

class PaperOpened extends Notifier<bool> {
  @override
  bool build() => false;

  void opened() => state = true;
}

@immutable
class PaperAccountState {
  const PaperAccountState({this.spot, this.failure});

  /// The Spot wallet; null until the account is open and read.
  final Wallet? spot;
  final ApiFailure? failure;

  Balance? spotBalance(String asset) => spot?.of(asset);
}

final paperAccountProvider =
    NotifierProvider.autoDispose<PaperAccountRepository, PaperAccountState>(
      PaperAccountRepository.new,
    );

/// The demo account (D-86): opened on first entry (`POST /paper/account`
/// grants the virtual funds once, and answers an open account as it is),
/// then the Spot wallet, kept current by `/user/queue/balances` and read
/// again after each reconnection, since missed pushes are not replayed.
/// Shared by Trade, Assets and Home (D-150 (2)).
class PaperAccountRepository extends Notifier<PaperAccountState> {
  static const settle = Duration(seconds: 1);

  Completer<void> _opened = Completer<void>();
  Timer? _refresh;

  /// Completes once the account is open; other paper reads wait for it,
  /// since they answer 404 MSG41 before.
  Future<void> get opened => _opened.future;

  PaperApi get _api => ref.read(paperApiProvider);

  @override
  PaperAccountState build() {
    final balances = ref
        .read(realtimeHubProvider.notifier)
        .watch(balancesQueue)
        .listen(_onBalance);
    ref
      ..listen(realtimeHubProvider.select((s) => s.generation), (before, now) {
        if (before != null && before > 0 && now != before) unawaited(load());
      })
      ..onDispose(() {
        _refresh?.cancel();
        unawaited(balances.cancel());
      });
    ref.loadAfterBuild(load);
    return const PaperAccountState();
  }

  /// Opens the account when needed, then reads the Spot wallet.
  Future<void> load() async {
    try {
      if (!_opened.isCompleted) {
        // Held before the wait: this repository may be gone after it.
        final signal = ref.read(paperOpenedProvider.notifier);
        await _api.openAccount();
        // Open on the server whether this repository is still listened to.
        if (!_opened.isCompleted) _opened.complete();
        signal.opened();
        if (!ref.mounted) return;
      }
      final spot = await _api.wallet(PaperWallet.spot);
      if (ref.mounted) state = PaperAccountState(spot: spot);
    } on ApiFailure catch (failure) {
      if (ref.mounted) {
        state = PaperAccountState(spot: state.spot, failure: failure);
      }
    }
  }

  void _onBalance(Object? body) {
    final BalanceUpdate update;
    try {
      update = decodeBalanceUpdate(body);
    } on DecodeException {
      return;
    }
    final spot = state.spot;
    if (update.wallet != PaperWallet.spot || spot == null) return;
    final known = spot.of(update.asset);
    final changed = Balance(
      asset: update.asset,
      free: update.free,
      locked: update.locked,
      total: update.total,
      usdtValue: known?.usdtValue,
    );
    state = PaperAccountState(
      spot: Wallet(
        wallet: spot.wallet,
        balances: [
          for (final balance in spot.balances)
            if (balance.asset != update.asset) balance,
          changed,
        ],
        estimatedUsdt: spot.estimatedUsdt,
        complete: spot.complete,
      ),
    );
    // The push has no USDT value: the totals are read again once the
    // changes of one fill have all arrived.
    _refresh?.cancel();
    _refresh = Timer(settle, () => unawaited(load()));
  }

  /// A failed open is tried again from scratch.
  void retry() {
    if (_opened.isCompleted) {
      unawaited(load());
      return;
    }
    _opened = Completer<void>();
    unawaited(load());
  }
}

@immutable
class OpenOrdersState {
  const OpenOrdersState({this.orders, this.failure, this.fill, this.fills = 0});

  /// The latest fill pushed on `/user/queue/fills`; [fills] grows by one at
  /// each, so a screen tells every one apart.
  final PaperFill? fill;
  final int fills;

  /// Every open Spot order, newest first; null until read.
  final List<PaperOrder>? orders;
  final ApiFailure? failure;

  List<PaperOrder> of(String pairId) => [
    for (final order in orders ?? const <PaperOrder>[])
      if (order.pairId == pairId) order,
  ];
}

final openOrdersProvider =
    NotifierProvider.autoDispose<OpenOrdersRepository, OpenOrdersState>(
      OpenOrdersRepository.new,
    );

/// The open Spot orders of every pair, kept current by `/user/queue/orders`
/// (an order that is no longer open leaves the list) and read again after
/// each reconnection. Cancelling goes through here so every screen sees it.
class OpenOrdersRepository extends Notifier<OpenOrdersState> {
  PaperApi get _api => ref.read(paperApiProvider);

  @override
  OpenOrdersState build() {
    // The account must stay open (and read) while its orders are listened to.
    ref.listen(paperAccountProvider, (_, _) {});
    final orders = ref
        .read(realtimeHubProvider.notifier)
        .watch(ordersQueue)
        .listen(_onOrder);
    final fills = ref
        .read(realtimeHubProvider.notifier)
        .watch(fillsQueue)
        .listen(_onFill);
    ref
      ..listen(realtimeHubProvider.select((s) => s.generation), (before, now) {
        if (before != null && before > 0 && now != before) unawaited(load());
      })
      ..onDispose(() {
        unawaited(orders.cancel());
        unawaited(fills.cancel());
      });
    ref.loadAfterBuild(load);
    return const OpenOrdersState();
  }

  Future<void> load() async {
    try {
      await ref.read(paperAccountProvider.notifier).opened;
      if (!ref.mounted) return;
      final orders = await _api.openOrders();
      if (ref.mounted) {
        state = OpenOrdersState(
          orders: [...orders]..sort((a, b) => b.placedAt.compareTo(a.placedAt)),
          fill: state.fill,
          fills: state.fills,
        );
      }
    } on ApiFailure catch (failure) {
      if (ref.mounted) {
        state = OpenOrdersState(
          orders: state.orders,
          failure: failure,
          fill: state.fill,
          fills: state.fills,
        );
      }
    }
  }

  void _onOrder(Object? body) {
    try {
      apply([decodeOrder(body)]);
    } on DecodeException {
      // A bad push is dropped; the next read brings the order.
    }
  }

  void _onFill(Object? body) {
    final PaperFill fill;
    try {
      fill = decodeFill(body);
    } on DecodeException {
      return;
    }
    state = OpenOrdersState(
      orders: state.orders,
      failure: state.failure,
      fill: fill,
      fills: state.fills + 1,
    );
  }

  /// Orders as an answer or a push left them: open ones are kept, the
  /// others leave.
  void apply(List<PaperOrder> changed) {
    final byId = {for (final order in changed) order.orderId: order};
    final kept = [
      for (final order in state.orders ?? const <PaperOrder>[])
        if (!byId.containsKey(order.orderId)) order,
    ];
    final added = [
      for (final order in changed)
        if (order.status.open) order,
    ];
    state = OpenOrdersState(
      orders: [...added, ...kept]
        ..sort((a, b) => b.placedAt.compareTo(a.placedAt)),
      failure: state.failure,
      fill: state.fill,
      fills: state.fills,
    );
  }

  /// Cancels [order], and its whole group when it has one; throws the
  /// [ApiFailure] of the refusal.
  Future<void> cancel(PaperOrder order) async {
    final listId = order.listId;
    apply(
      listId == null
          ? [await _api.cancelOrder(order.orderId)]
          : await _api.cancelOrderList(listId),
    );
  }

  /// Every open order of the pair.
  Future<void> cancelAll(String pairId) async {
    apply(await _api.cancelAll(pairId));
  }
}
