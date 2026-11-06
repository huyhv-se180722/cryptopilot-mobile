import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptopilot_mobile/core/auth/session_controller.dart';
import 'package:cryptopilot_mobile/core/auth/token_store.dart';
import 'package:cryptopilot_mobile/core/errors/api_failure.dart';
import 'package:cryptopilot_mobile/core/http/auth_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

/// Answers 401 to any token but the accepted one.
class TokenGate implements HttpClientAdapter {
  TokenGate(this.accepted);

  String accepted;
  final List<String> seen = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final header = '${options.headers['Authorization']}';
    seen.add(header);
    final ok = header == 'Bearer $accepted';
    return ResponseBody.fromString(
      jsonEncode(
        ok
            ? {'ok': true}
            : {
                'status': 401,
                'code': 'AUTHENTICATION_REQUIRED',
                'messageCode': 'MSG44',
              },
      ),
      ok ? 200 : 401,
      headers: {
        Headers.contentTypeHeader: [
          ok ? 'application/json' : 'application/problem+json',
        ],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late FakeAuthTokenApi tokens;
  late ProviderContainer container;
  late TokenGate gate;
  late Dio dio;

  setUp(() async {
    tokens = FakeAuthTokenApi();
    container = ProviderContainer(
      overrides: baseOverrides(store: MemoryTokenStore(), tokens: tokens),
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
    container.read(sessionControllerProvider);
    await settle();
    await container
        .read(sessionControllerProvider.notifier)
        .signIn(sessionFor('old'));
    gate = TokenGate('access-rotated');
    dio = Dio(BaseOptions(baseUrl: 'http://backend.test/api/v1/'))
      ..httpClientAdapter = gate;
    dio.interceptors.add(
      AuthInterceptor(
        dio: dio,
        session: () => container.read(sessionControllerProvider.notifier),
      ),
    );
  });

  test(
    'a 401 refreshes once and replays the call with the new token',
    () async {
      final response = await dio.get<Object?>('me/profile');

      expect(response.statusCode, 200);
      expect(gate.seen, ['Bearer access-old', 'Bearer access-rotated']);
      expect(tokens.refreshCalls, 1);
    },
  );

  test('two calls failing together share one refresh', () async {
    final responses = await Future.wait([
      dio.get<Object?>('me/profile'),
      dio.get<Object?>('notifications/unread-count'),
    ]);

    expect(responses.map((r) => r.statusCode), [200, 200]);
    expect(tokens.refreshCalls, 1);
  });

  test('a refused refresh surfaces as MSG44 and signs out', () async {
    tokens.onRefresh = (_) async =>
        throw problem(401, 'SESSION_EXPIRED', 'MSG44');

    await expectLater(
      apiCall(() => dio.get<Object?>('me/profile'), (body) => body),
      throwsA(isA<SessionExpiredFailure>()),
    );
    expect(container.read(sessionControllerProvider), isA<SignedOut>());
  });

  test(
    'a call still refused after the refresh is not replayed again',
    () async {
      gate.accepted = 'nobody';

      await expectLater(
        apiCall(() => dio.get<Object?>('me/profile'), (body) => body),
        throwsA(isA<ProblemFailure>()),
      );
      expect(gate.seen, hasLength(2));
    },
  );
}
