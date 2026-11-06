import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/http/http_providers.dart';
import '../domain/profile.dart';

/// The parts of the profile the account screen uses (A-59; fe-guide user
/// module). Admins have no profile endpoint.
abstract interface class ProfileApi {
  /// `GET /me/profile`.
  Future<Profile> profile();

  /// `PUT /me/notification-preferences` (request `email`/`push`, response
  /// fields `notifyEmail`/`notifyPush`).
  Future<void> saveNotifications({required bool email, required bool push});
}

class DioProfileApi implements ProfileApi {
  const DioProfileApi(this._dio);

  final Dio _dio;

  @override
  Future<Profile> profile() =>
      apiCall(() => _dio.get<Object?>('me/profile'), decodeProfile);

  @override
  Future<void> saveNotifications({required bool email, required bool push}) =>
      apiCall(
        () => _dio.put<Object?>(
          'me/notification-preferences',
          data: {'email': email, 'push': push},
        ),
        (_) {},
      );
}

final profileApiProvider = Provider<ProfileApi>(
  (ref) => DioProfileApi(ref.watch(apiDioProvider)),
);
