import 'package:cryptopilot_mobile/core/http/rate_limit_interceptor.dart';
import 'package:cryptopilot_mobile/core/state/poll_gate.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/http_fakes.dart';

void main() {
  testWidgets('the background closes the gate and the foreground opens it', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(pollGateProvider).open, isTrue);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    expect(container.read(pollGateProvider).open, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(container.read(pollGateProvider).foreground, isFalse);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(container.read(pollGateProvider).open, isTrue);
  });

  testWidgets('a 429 holds the gate until its window ends', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final gate = container.read(pollGateProvider.notifier);

    gate.rateLimited(const Duration(seconds: 30));
    expect(gate.open, isFalse);
    await tester.pump(const Duration(seconds: 29));
    expect(gate.open, isFalse);
    // A later 429 starts the window again.
    gate.rateLimited(const Duration(seconds: 10));
    await tester.pump(const Duration(seconds: 2));
    expect(gate.open, isFalse);
    await tester.pump(const Duration(seconds: 9));
    expect(gate.open, isTrue);
  });

  group('RateLimitInterceptor', () {
    Response<Object?> response({Object? data, String? retryAfter}) => Response(
      requestOptions: RequestOptions(),
      statusCode: 429,
      data: data,
      headers: Headers.fromMap({
        if (retryAfter != null) 'retry-after': [retryAfter],
      }),
    );

    test('reads Retry-After, then MSG50 seconds, then one minute', () {
      expect(
        RateLimitInterceptor.retryAfter(response(retryAfter: '17')),
        const Duration(seconds: 17),
      );
      expect(
        RateLimitInterceptor.retryAfter(
          response(
            data: {
              'messageCode': 'MSG50',
              'messageArgs': ['42'],
            },
          ),
        ),
        const Duration(seconds: 42),
      );
      expect(
        RateLimitInterceptor.retryAfter(response()),
        const Duration(seconds: 60),
      );
      expect(
        RateLimitInterceptor.retryAfter(response(retryAfter: '86400')),
        const Duration(minutes: 5),
      );
    });

    test('reports a 429 and lets the error go on', () async {
      final adapter = RecordingAdapter()
        ..answers.addAll([
          (
            429,
            {
              'status': 429,
              'code': 'RATE_LIMITED',
              'messageCode': 'MSG50',
              'messageArgs': ['30'],
            },
          ),
          (500, {'status': 500, 'code': 'X', 'messageCode': 'MSG43'}),
        ]);
      final limited = <Duration>[];
      final dio = dioOn(adapter)
        ..interceptors.add(RateLimitInterceptor(limited.add));

      await expectLater(
        dio.get<Object?>('plans'),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'status',
            429,
          ),
        ),
      );
      await expectLater(dio.get<Object?>('plans'), throwsA(anything));
      expect(limited, [const Duration(seconds: 30)]);
    });
  });
}
