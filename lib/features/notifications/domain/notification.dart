import '../../../core/json/json_read.dart';

/// What a notification is about (SRS 3.4.5; D-99, D-125, TR-43; `MARKET`:
/// D-159 trading pauses and Spot demo orders, backend #111 and #113).
enum NotificationType {
  alert('ALERT'),
  plan('PLAN'),
  moderation('MODERATION'),
  subscription('SUBSCRIPTION'),
  comment('COMMENT'),
  system('SYSTEM'),
  follow('FOLLOW'),
  mention('MENTION'),
  futures('FUTURES'),
  market('MARKET');

  const NotificationType(this.wire);

  final String wire;

  /// A type this build does not know reads as [system]: one notification of
  /// a newer backend must not make the whole list unreadable.
  static NotificationType decode(String value) =>
      values.firstWhere((type) => type.wire == value, orElse: () => system);
}

/// What opening a notification navigates to (SRS 3.4.5).
enum NotificationReference {
  alert('ALERT'),
  plan('PLAN'),
  post('POST'),
  subscription('SUBSCRIPTION'),
  newsSource('NEWS_SOURCE'),
  member('MEMBER'),
  futuresPosition('FUTURES_POSITION'),
  paperOrder('PAPER_ORDER');

  const NotificationReference(this.wire);

  final String wire;

  /// Null for a reference this build does not know: the notification still
  /// shows, it only opens nothing.
  static NotificationReference? decode(String value) {
    for (final reference in values) {
      if (reference.wire == value) return reference;
    }
    return null;
  }
}

/// One notification of SCR-15 (`NotificationResponse`), also the body of
/// `/user/queue/notifications`. The title and the text are the server's.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.content,
    required this.read,
    required this.createdAt,
    this.referenceType,
    this.referenceId,
    this.readAt,
  });

  final String id;
  final NotificationType type;
  final String title;
  final String content;
  final NotificationReference? referenceType;
  final String? referenceId;
  final bool read;
  final DateTime? readAt;
  final DateTime createdAt;

  AppNotification asRead(DateTime at) => AppNotification(
    id: id,
    type: type,
    title: title,
    content: content,
    referenceType: referenceType,
    referenceId: referenceId,
    read: true,
    readAt: readAt ?? at,
    createdAt: createdAt,
  );
}

class NotificationPage {
  const NotificationPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
  });

  final List<AppNotification> items;
  final int page;
  final int pageSize;
  final int total;
}

int _int(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw DecodeException('$key is not a whole number');
}

AppNotification decodeNotification(Object? body) {
  final json = asJsonObject(body, 'notification');
  final reference = readOptionalString(json, 'referenceType');
  return AppNotification(
    id: readString(json, 'id'),
    type: NotificationType.decode(readString(json, 'type')),
    title: readString(json, 'title'),
    content: readString(json, 'content'),
    referenceType: reference == null
        ? null
        : NotificationReference.decode(reference),
    referenceId: readOptionalString(json, 'referenceId'),
    read: readBool(json, 'read'),
    readAt: json['readAt'] == null ? null : readInstant(json, 'readAt'),
    createdAt: readInstant(json, 'createdAt'),
  );
}

NotificationPage decodeNotificationPage(Object? body) {
  final json = asJsonObject(body, 'notification page');
  final items = json['items'];
  if (items is! List) throw const DecodeException('items is not a list');
  return NotificationPage(
    items: [for (final item in items) decodeNotification(item)],
    page: _int(json, 'page'),
    pageSize: _int(json, 'pageSize'),
    total: _int(json, 'total'),
  );
}

/// `{unread}` of `/unread-count` and `/read-all`.
int decodeUnreadCount(Object? body) {
  final json = asJsonObject(body, 'unread count');
  return _int(json, 'unread');
}

/// Where opening a notification goes. The app's own screens, or a web path
/// for the screens SRS 3.1.1 keeps on the web (and those not built yet).
sealed class NotificationTarget {
  const NotificationTarget();
}

class AppScreen extends NotificationTarget {
  const AppScreen(this.location, {this.tab = false});

  final String location;

  /// A bottom-bar tab: gone to, not pushed.
  final bool tab;
}

class WebPage extends NotificationTarget {
  const WebPage(this.path);

  final String path;
}

/// Null when the notification references nothing the Trader can open.
NotificationTarget? targetOf(AppNotification notification) {
  final id = notification.referenceId;
  final encoded = id == null ? '' : Uri.encodeComponent(id);
  return switch (notification.referenceType) {
    null => null,
    // Alerts have no page of their own: the list opens, as on the web.
    NotificationReference.alert => const AppScreen('/alerts'),
    // SCR-18 (T-091).
    NotificationReference.plan =>
      id == null ? null : AppScreen('/plan/$encoded'),
    // SCR-25 (A-64, T-133).
    NotificationReference.post =>
      id == null ? null : AppScreen('/community/$encoded'),
    // The member page (A-66, T-136).
    NotificationReference.member =>
      id == null ? null : AppScreen('/community/members/$encoded'),
    NotificationReference.subscription => const WebPage('/subscription'),
    // The Futures side of the Trade tab (T-129).
    NotificationReference.futuresPosition => const AppScreen(
      '/trade?market=futures',
      tab: true,
    ),
    // A demo order filled, triggered, cancelled or expired (backend #113):
    // the side of the Trade tab it belongs to, FUTURES or else Spot.
    NotificationReference.paperOrder => AppScreen(
      notification.type == NotificationType.futures
          ? '/trade?market=futures'
          : '/trade?market=spot',
      tab: true,
    ),
    // An administrator's object; a Trader has nothing to open.
    NotificationReference.newsSource => null,
  };
}
