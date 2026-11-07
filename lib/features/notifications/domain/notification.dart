import '../../../core/json/json_read.dart';

/// What a notification is about (SRS 3.4.5; D-99, D-125, TR-43).
enum NotificationType {
  alert('ALERT'),
  plan('PLAN'),
  moderation('MODERATION'),
  subscription('SUBSCRIPTION'),
  comment('COMMENT'),
  system('SYSTEM'),
  follow('FOLLOW'),
  mention('MENTION'),
  futures('FUTURES');

  const NotificationType(this.wire);

  final String wire;

  static NotificationType decode(String value) => values.firstWhere(
    (type) => type.wire == value,
    orElse: () => throw DecodeException('notification type $value is unknown'),
  );
}

/// What opening a notification navigates to (SRS 3.4.5).
enum NotificationReference {
  alert('ALERT'),
  plan('PLAN'),
  post('POST'),
  subscription('SUBSCRIPTION'),
  newsSource('NEWS_SOURCE'),
  member('MEMBER'),
  futuresPosition('FUTURES_POSITION');

  const NotificationReference(this.wire);

  final String wire;

  static NotificationReference decode(String value) => values.firstWhere(
    (reference) => reference.wire == value,
    orElse: () => throw DecodeException('reference $value is unknown'),
  );
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
  const AppScreen(this.location);

  final String location;
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
    // SCR-18 arrives with T-091.
    NotificationReference.plan =>
      id == null ? null : WebPage('/plans/$encoded'),
    NotificationReference.post =>
      id == null ? null : WebPage('/community/$encoded'),
    NotificationReference.member =>
      id == null ? null : WebPage('/community/members/$encoded'),
    NotificationReference.subscription => const WebPage('/subscription'),
    // The paper Futures screen arrives with T-122.
    NotificationReference.futuresPosition => const WebPage('/trade/futures'),
    // An administrator's object; a Trader has nothing to open.
    NotificationReference.newsSource => null,
  };
}
