import 'package:flutter/material.dart';

import '../../../core/format/age_format.dart';
import '../../../core/i18n/app_localizations.dart';
import '../domain/notification.dart';

/// The age of a notification, worded as every age in the app.
String notificationAge(AppLocalizations l, DateTime createdAt, DateTime now) =>
    formatAge(l, createdAt, now);

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
