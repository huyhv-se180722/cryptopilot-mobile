import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/errors/api_failure.dart';
import '../../../core/realtime/realtime_hub.dart';
import '../data/notification_api.dart';
import '../domain/notification.dart';

/// Where a new notification is pushed while the app is open.
const notificationQueue = '/user/queue/notifications';

/// What other features do when a notification arrives (the alerts read
/// their list again on an ALERT one); composed in `main.dart`.
typedef NotificationHook = void Function(Ref ref, AppNotification arrived);

final notificationHooksProvider = Provider<List<NotificationHook>>(
  (ref) => const [],
);

/// Notifications pushed while the app is open, for the list, the in-app
/// banner and the hooks; lives as long as the app, across sign-ins.
final notificationArrivalsProvider =
    Provider<StreamController<AppNotification>>((ref) {
      final arrivals = StreamController<AppNotification>.broadcast();
      ref.onDispose(() => unawaited(arrivals.close()));
      return arrivals;
    });

/// The bell (SRS 3.4.5): the unread count, null until first read. Read when
/// signed in, at every (re)connection and when the app comes back; a push
/// adds one; every 60 s while the push channel is down, as the web does.
/// New notifications are also announced on [notificationArrivalsProvider].
final unreadCountProvider = NotifierProvider<UnreadCount, int?>(
  UnreadCount.new,
);

class UnreadCount extends Notifier<int?> {
  static const pollEvery = Duration(seconds: 60);

  Timer? _poll;

  @override
  int? build() {
    final signedIn = ref.watch(
      sessionControllerProvider.select((session) => session is SignedIn),
    );
    ref.onDispose(() {
      _poll?.cancel();
      _poll = null;
    });
    if (!signedIn) return null;

    final pushes = ref
        .read(realtimeHubProvider.notifier)
        .watch(notificationQueue)
        .listen(_onPush);
    final lifecycle = AppLifecycleListener(onResume: () => unawaited(load()));
    ref
      ..onDispose(() {
        // Not awaited: a broadcast cancel only detaches the listener.
        unawaited(pushes.cancel());
        lifecycle.dispose();
      })
      ..listen(realtimeHubProvider, (previous, next) {
        if (previous?.generation != next.generation) unawaited(load());
        _pollWhile(down: !next.connected);
      });
    _pollWhile(down: !ref.read(realtimeHubProvider).connected);
    unawaited(Future.microtask(load));
    return null;
  }

  NotificationApi get _api => ref.read(notificationApiProvider);

  Future<void> load() async {
    try {
      final unread = await _api.unreadCount();
      if (ref.mounted) state = unread;
    } on ApiFailure {
      // The bell keeps its last number; the list shows the failure.
    }
  }

  void _pollWhile({required bool down}) {
    if (!down) {
      _poll?.cancel();
      _poll = null;
    } else {
      _poll ??= Timer.periodic(pollEvery, (_) => unawaited(load()));
    }
  }

  void _onPush(Object? body) {
    final AppNotification arrived;
    try {
      arrived = decodeNotification(body);
    } on Exception {
      // A body the app cannot read: the next read of the count catches up.
      unawaited(load());
      return;
    }
    if (!arrived.read) state = (state ?? 0) + 1;
    ref.read(notificationArrivalsProvider).add(arrived);
    for (final hook in ref.read(notificationHooksProvider)) {
      hook(ref, arrived);
    }
  }

  /// After the Trader read one or all.
  void set(int unread) => state = unread < 0 ? 0 : unread;
}

@immutable
class NotificationsState {
  const NotificationsState({
    this.items,
    this.unreadOnly = false,
    this.page = 0,
    this.total = 0,
    this.failure,
    this.loadingMore = false,
  });

  /// Null until the first page arrives.
  final List<AppNotification>? items;
  final bool unreadOnly;
  final int page;
  final int total;
  final ApiFailure? failure;
  final bool loadingMore;

  bool get hasMore => items != null && items!.length < total;

  NotificationsState copyWith({
    List<AppNotification>? items,
    int? page,
    int? total,
    ApiFailure? failure,
    bool clearFailure = false,
    bool? loadingMore,
  }) => NotificationsState(
    items: items ?? this.items,
    unreadOnly: unreadOnly,
    page: page ?? this.page,
    total: total ?? this.total,
    failure: clearFailure ? null : failure ?? this.failure,
    loadingMore: loadingMore ?? this.loadingMore,
  );
}

final notificationsControllerProvider =
    NotifierProvider<NotificationsController, NotificationsState>(
      NotificationsController.new,
    );

/// SCR-15 (UC-15): all or unread notifications, newest first, 20 a page.
class NotificationsController extends Notifier<NotificationsState> {
  static const pageSize = 20;

  int _generation = 0;

  @override
  NotificationsState build() {
    final signedIn = ref.watch(
      sessionControllerProvider.select((session) => session is SignedIn),
    );
    if (!signedIn) return const NotificationsState();
    // A new notification shows at the top of a list someone looks at.
    final arrivals = ref.read(notificationArrivalsProvider).stream.listen((_) {
      if (state.items != null) unawaited(load());
    });
    ref.onDispose(() => unawaited(arrivals.cancel()));
    unawaited(Future.microtask(load));
    return const NotificationsState();
  }

  NotificationApi get _api => ref.read(notificationApiProvider);

  Future<void> load() => _loadFirst(state.unreadOnly);

  Future<void> show({required bool unreadOnly}) {
    if (unreadOnly == state.unreadOnly && state.items != null) return load();
    state = NotificationsState(unreadOnly: unreadOnly);
    return _loadFirst(unreadOnly);
  }

  Future<void> _loadFirst(bool unreadOnly) async {
    final generation = ++_generation;
    try {
      final page = await _api.list(unreadOnly: unreadOnly, pageSize: pageSize);
      if (!ref.mounted || generation != _generation) return;
      state = NotificationsState(
        items: page.items,
        unreadOnly: unreadOnly,
        page: 1,
        total: page.total,
      );
    } on ApiFailure catch (failure) {
      if (!ref.mounted || generation != _generation) return;
      state = state.copyWith(failure: failure);
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.loadingMore) return;
    final generation = _generation;
    state = state.copyWith(loadingMore: true);
    try {
      final page = await _api.list(
        unreadOnly: state.unreadOnly,
        page: state.page + 1,
        pageSize: pageSize,
      );
      if (!ref.mounted || generation != _generation) return;
      final known = {for (final n in state.items!) n.id};
      state = state.copyWith(
        items: [
          ...state.items!,
          for (final n in page.items)
            if (!known.contains(n.id)) n,
        ],
        page: page.page,
        total: page.total,
        loadingMore: false,
        clearFailure: true,
      );
    } on ApiFailure catch (failure) {
      if (!ref.mounted || generation != _generation) return;
      state = state.copyWith(failure: failure, loadingMore: false);
    }
  }

  /// Marks [notification] read; the row and the bell change at once. Throws
  /// [ApiFailure] (MSG41) for the screen to show.
  Future<void> markRead(AppNotification notification) async {
    if (notification.read) return;
    final read = await _api.markRead(notification.id);
    if (!ref.mounted) return;
    _replace(read);
    final count = ref.read(unreadCountProvider);
    if (count != null) ref.read(unreadCountProvider.notifier).set(count - 1);
  }

  Future<void> markAllRead() async {
    final unread = await _api.markAllRead();
    if (!ref.mounted) return;
    ref.read(unreadCountProvider.notifier).set(unread);
    final at = ref.read(clockProvider)();
    final items = state.items;
    if (items != null) {
      state = state.copyWith(items: [for (final n in items) n.asRead(at)]);
    }
    if (state.unreadOnly) await load();
  }

  void _replace(AppNotification read) {
    final items = state.items;
    if (items == null) return;
    state = state.copyWith(
      items: state.unreadOnly
          ? [
              for (final n in items)
                if (n.id != read.id) n,
            ]
          : [for (final n in items) n.id == read.id ? read : n],
      total: state.unreadOnly ? state.total - 1 : state.total,
    );
  }
}
