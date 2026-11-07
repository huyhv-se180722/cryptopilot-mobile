import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/i18n/app_localizations.dart';
import '../domain/notification.dart';

/// "now", "5m ago" … up to a week, then the date in the device's zone, as
/// the web words it.
String notificationAge(AppLocalizations l, DateTime createdAt, DateTime now) {
  final elapsed = now.difference(createdAt);
  if (elapsed.isNegative || elapsed.inMinutes < 1) return l.notificationAgeNow;
  if (elapsed.inHours < 1) return l.notificationAgeMinutes(elapsed.inMinutes);
  if (elapsed.inDays < 1) return l.notificationAgeHours(elapsed.inHours);
  if (elapsed.inDays < 7) return l.notificationAgeDays(elapsed.inDays);
  return DateFormat('d MMM yyyy', 'en_US').format(createdAt.toLocal());
}

/// The bell's badge: the count, 99+ above that.
String badgeText(int count) => count > 99 ? '99+' : '$count';

IconData notificationIcon(NotificationType type) => switch (type) {
  NotificationType.alert => Icons.alarm,
  NotificationType.plan => Icons.assignment_outlined,
  NotificationType.futures => Icons.candlestick_chart_outlined,
  NotificationType.subscription => Icons.workspace_premium_outlined,
  NotificationType.comment => Icons.chat_bubble_outline,
  NotificationType.mention => Icons.alternate_email,
  NotificationType.follow => Icons.person_add_alt,
  NotificationType.moderation => Icons.gavel_outlined,
  NotificationType.system => Icons.info_outline,
};
