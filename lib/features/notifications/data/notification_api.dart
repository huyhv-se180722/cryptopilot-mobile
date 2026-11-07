import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/http/http_providers.dart';
import '../domain/notification.dart';

/// `/notifications` (UC-15; checked on backend develop 25ba960). The only
/// filter is unread; a new notification is also pushed on
/// `/user/queue/notifications`.
abstract interface class NotificationApi {
  Future<NotificationPage> list({
    bool unreadOnly = false,
    int page = 1,
    int pageSize = 20,
  });

  Future<int> unreadCount();

  /// 404 MSG41 when it is not the caller's.
  Future<AppNotification> markRead(String id);

  /// The unread count afterwards, zero.
  Future<int> markAllRead();
}

class DioNotificationApi implements NotificationApi {
  const DioNotificationApi(this._dio);

  final Dio _dio;

  @override
  Future<NotificationPage> list({
    bool unreadOnly = false,
    int page = 1,
    int pageSize = 20,
  }) => apiCall(
    () => _dio.get<Object?>(
      'notifications',
      queryParameters: {
        'unreadOnly': unreadOnly,
        'page': page,
        'pageSize': pageSize,
      },
    ),
    decodeNotificationPage,
  );

  @override
  Future<int> unreadCount() => apiCall(
    () => _dio.get<Object?>('notifications/unread-count'),
    decodeUnreadCount,
  );

  @override
  Future<AppNotification> markRead(String id) => apiCall(
    () => _dio.post<Object?>('notifications/$id/read'),
    decodeNotification,
  );

  @override
  Future<int> markAllRead() => apiCall(
    () => _dio.post<Object?>('notifications/read-all'),
    decodeUnreadCount,
  );
}

final notificationApiProvider = Provider<NotificationApi>(
  (ref) => DioNotificationApi(ref.watch(apiDioProvider)),
);
