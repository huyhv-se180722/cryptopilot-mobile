import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/http/http_providers.dart';
import '../domain/plan.dart';

/// `GET /plans` (SCR-16 tabs; checked on backend develop 25ba960). The rest
/// of the plan API arrives with T-091.
abstract interface class PlanApi {
  Future<PlanPage> list({PlanTab? tab, int page = 1, int pageSize = 20});
}

class DioPlanApi implements PlanApi {
  const DioPlanApi(this._dio);

  final Dio _dio;

  @override
  Future<PlanPage> list({PlanTab? tab, int page = 1, int pageSize = 20}) =>
      apiCall(
        () => _dio.get<Object?>(
          'plans',
          queryParameters: {
            'tab': ?tab?.wire,
            'page': page,
            'pageSize': pageSize,
          },
        ),
        decodePlanPage,
      );
}

final planApiProvider = Provider<PlanApi>(
  (ref) => DioPlanApi(ref.watch(apiDioProvider)),
);
