import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/errors/api_failure.dart';
import '../../../core/errors/message_text.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/cp_colors.dart';
import '../../market/presentation/market_widgets.dart';
import '../application/notifications_controller.dart';
import '../domain/notification.dart';
import 'notification_bell.dart';
import 'notification_format.dart';

/// SCR-15 Notification center (SRS 3.4.5, UC-15): all or unread, newest
/// first, 20 a page loaded as the list scrolls; opening one marks it read
/// and goes to what it references; mark all as read.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // The list shows what a banner announced.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();
    });
    // The first read starts with the controller; a later visit reads again.
    if (ref.read(notificationsControllerProvider).items != null) {
      Future.microtask(
        () => ref.read(notificationsControllerProvider.notifier).load(),
      );
    }
  }

  Future<void> _markAll() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    try {
      await ref.read(notificationsControllerProvider.notifier).markAllRead();
      messenger.showSnackBar(SnackBar(content: Text(l.notificationsAllRead)));
    } on ApiFailure catch (failure) {
      messenger.showSnackBar(SnackBar(content: Text(failureText(l, failure))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(notificationsControllerProvider);
    final controller = ref.read(notificationsControllerProvider.notifier);
    final unread = ref.watch(unreadCountProvider) ?? 0;
    final items = state.items;

    Widget body;
    if (items == null && state.failure != null) {
      body = _Message(
        icon: Icons.cloud_off,
        title: failureText(l, state.failure!),
        action: TextButton(
          onPressed: controller.load,
          child: Text(l.commonRetry),
        ),
      );
    } else if (items == null) {
      body = const ListSkeleton();
    } else if (items.isEmpty) {
      body = state.unreadOnly
          ? _Message(icon: Icons.done_all, title: l.notificationsEmptyUnread)
          : _Message(
              icon: Icons.notifications_none,
              title: l.notificationsEmpty,
            );
    } else {
      body = NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.extentAfter < 400) {
            unawaited(controller.loadMore());
          }
          return false;
        },
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: items.length + (state.hasMore ? 1 : 0),
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            if (index == items.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return NotificationRow(notification: items[index]);
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l.notificationsTitle),
        actions: [
          if (unread > 0)
            TextButton(
              key: const Key('mark-all-read'),
              onPressed: _markAll,
              child: Text(l.notificationsMarkAll),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SegmentedButton<bool>(
              key: const Key('notification-filter'),
              segments: [
                ButtonSegment(value: false, label: Text(l.notificationsAll)),
                ButtonSegment(value: true, label: Text(l.notificationsUnread)),
              ],
              selected: {state.unreadOnly},
              showSelectedIcon: false,
              onSelectionChanged: (value) =>
                  unawaited(controller.show(unreadOnly: value.single)),
            ),
          ),
          if (items != null && state.failure != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Text(
                failureText(l, state.failure!),
                style: TextStyle(color: context.cp.negative),
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await Future.wait([
                  controller.load(),
                  ref.read(unreadCountProvider.notifier).load(),
                ]);
              },
              child: body,
            ),
          ),
        ],
      ),
    );
  }
}

class NotificationRow extends ConsumerWidget {
  const NotificationRow({
    required this.notification,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 12),
    super.key,
  });

  final AppNotification notification;

  /// Full-width in SCR-15; a card that pads itself (Home) passes less.
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final cp = context.cp;
    final unread = !notification.read;
    final now = ref.read(clockProvider)();
    return InkWell(
      key: Key('notification-${notification.id}'),
      onTap: () => openNotification(context, ref, notification),
      child: Padding(
        padding: padding,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(notificationIcon(notification.type), color: cp.muted),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: text.titleSmall?.copyWith(
                            fontWeight: unread
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        notificationAge(l, notification.createdAt, now),
                        style: text.bodySmall?.copyWith(color: cp.muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notification.content,
                    style: text.bodyMedium?.copyWith(
                      color: unread ? null : cp.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // The dot repeats the bold title; the word is in the semantics.
            Semantics(
              label: unread ? l.notificationsUnread : null,
              child: Container(
                key: unread ? Key('unread-dot-${notification.id}') : null,
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                  color: unread ? cp.primary : Colors.transparent,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, this.action});

  final IconData icon;
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(32, 64, 32, 32),
        child: Column(
          children: [
            Icon(icon, size: 36, color: context.cp.muted),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    ],
  );
}
