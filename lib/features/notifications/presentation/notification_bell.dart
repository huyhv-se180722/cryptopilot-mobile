import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/errors/message_text.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/web/web_links.dart';
import '../application/notifications_controller.dart';
import '../domain/notification.dart';
import 'notification_format.dart';

/// Marks [notification] read and opens what it references (SRS 3.4.5). A
/// failed mark still opens it; the failure shows as a snackbar.
Future<void> openNotification(
  BuildContext context,
  WidgetRef ref,
  AppNotification notification,
) async {
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);
  final web = ref.read(webLinksProvider);
  final target = targetOf(notification);
  unawaited(
    ref
        .read(notificationsControllerProvider.notifier)
        .markRead(notification)
        .catchError((Object error) {
          if (error is ApiFailure) {
            messenger.showSnackBar(
              SnackBar(content: Text(failureText(l, error))),
            );
          }
        }),
  );
  switch (target) {
    case AppScreen(:final location):
      unawaited(router.push(location));
    case WebPage(:final path):
      await web.open(path);
    case null:
      break;
  }
}

/// The bell of the header with the unread count (SRS 3.4.5); opens SCR-15.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final unread = ref.watch(unreadCountProvider) ?? 0;
    return IconButton(
      key: const Key('open-notifications'),
      tooltip: unread > 0
          ? l.notificationsUnreadCount(unread)
          : l.notificationsTitle,
      onPressed: () => context.push('/notifications'),
      icon: Badge(
        key: const Key('notification-badge'),
        isLabelVisible: unread > 0,
        label: Text(badgeText(unread)),
        child: Icon(
          unread > 0 ? Icons.notifications : Icons.notifications_none_outlined,
        ),
      ),
    );
  }
}

/// How long the banner of a new notification shows.
const bannerDuration = Duration(seconds: 5);

/// Shows a notification pushed while the app is open as a snackbar with
/// View (no push service until T-092). Placed once, around the tabs.
class NotificationBanner extends ConsumerStatefulWidget {
  const NotificationBanner({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<NotificationBanner> createState() => _NotificationBannerState();
}

class _NotificationBannerState extends ConsumerState<NotificationBanner> {
  StreamSubscription<AppNotification>? _arrivals;

  @override
  void initState() {
    super.initState();
    // Starts the bell (and so the push channel) with the signed-in shell.
    ref.read(unreadCountProvider);
    _arrivals = ref.read(notificationArrivalsProvider).stream.listen(_show);
  }

  @override
  void dispose() {
    unawaited(_arrivals?.cancel());
    super.dispose();
  }

  void _show(AppNotification arrived) {
    if (!mounted) return;
    final l = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(arrived.title),
          // A banner with View would otherwise stay until dismissed; the
          // notification itself stays in SCR-15.
          persist: false,
          duration: bannerDuration,
          action: targetOf(arrived) == null
              ? null
              : SnackBarAction(
                  label: l.notificationsView,
                  onPressed: () => openNotification(context, ref, arrived),
                ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    // Keeps the bell's count alive while the tabs are shown.
    ref.watch(unreadCountProvider);
    return widget.child;
  }
}
