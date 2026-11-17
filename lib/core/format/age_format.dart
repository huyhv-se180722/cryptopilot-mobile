import 'package:intl/intl.dart';

import '../i18n/app_localizations.dart';

/// "now", "5m ago" … up to a week, then the date in the device's zone with
/// the app's locale (A-43), as the web words it.
String formatAge(AppLocalizations l, DateTime at, DateTime now) {
  final elapsed = now.difference(at);
  if (elapsed.isNegative || elapsed.inMinutes < 1) return l.notificationAgeNow;
  if (elapsed.inHours < 1) return l.notificationAgeMinutes(elapsed.inMinutes);
  if (elapsed.inDays < 1) return l.notificationAgeHours(elapsed.inHours);
  if (elapsed.inDays < 7) return l.notificationAgeDays(elapsed.inDays);
  return DateFormat('d MMM yyyy', 'en_US').format(at.toLocal());
}
