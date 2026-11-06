import 'package:cryptopilot_mobile/core/auth/session.dart';
import 'package:cryptopilot_mobile/core/errors/api_problem.dart';
import 'package:cryptopilot_mobile/core/json/json_read.dart';
import 'package:cryptopilot_mobile/features/account/domain/profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('problem body (RFC 9457, TD 5.1)', () {
    test('reads code, message, arguments, reference and field codes', () {
      final problem = decodeApiProblem({
        'type': 'about:blank',
        'title': 'Too Many Requests',
        'status': 429,
        'detail': 'locked',
        'code': 'LOGIN_TEMPORARILY_LOCKED',
        'messageCode': 'MSG09',
        'traceId': 'abc',
        'messageArgs': ['15'],
        'errors': {'email': 'MSG02', 'password': 'is required'},
      }, 429)!;

      expect(problem.code, 'LOGIN_TEMPORARILY_LOCKED');
      expect(problem.messageCode, 'MSG09');
      expect(problem.messageArgs, ['15']);
      expect(problem.traceId, 'abc');
      expect(problem.fieldErrors, {'email': 'MSG02', 'password': 'MSG01'});
    });

    test('is null for a body that is not a problem', () {
      expect(decodeApiProblem('<html>', 502), isNull);
      expect(decodeApiProblem({'status': 500}, 500), isNull);
    });
  });

  group('session (fe-guide auth module)', () {
    test('reads the token pair in UTC and the role', () {
      final session = decodeSession({
        'accessToken': 'a',
        'accessTokenExpiresAt': '2026-09-21T10:15:00Z',
        'refreshToken': 'r',
        'refreshTokenExpiresAt': '2026-09-28T10:00:00Z',
        'role': 'ADMIN',
      });

      expect(session.role, UserRole.admin);
      expect(session.accessTokenExpiresAt, DateTime.utc(2026, 9, 21, 10, 15));
      expect(session.refreshTokenExpiresAt.isUtc, isTrue);
    });

    test('refuses an unknown role or a missing token', () {
      expect(
        () => decodeSession({
          'accessToken': 'a',
          'accessTokenExpiresAt': '2026-09-21T10:15:00Z',
          'refreshToken': 'r',
          'refreshTokenExpiresAt': '2026-09-28T10:00:00Z',
          'role': 'GUEST',
        }),
        throwsA(isA<DecodeException>()),
      );
      expect(
        () => decodeSession({'role': 'TRADER'}),
        throwsA(isA<DecodeException>()),
      );
    });
  });

  test('profile keeps the fields of the account screen', () {
    final profile = decodeProfile({
      'email': 'trader.pro@cryptopilot.invalid',
      'displayName': 'Pro Trader',
      'avatarUrl': null,
      'defaultCapital': '1000',
      'defaultRiskPercent': '1.000',
      'tradingStyle': 'SWING',
      'riskProfile': 'CONSERVATIVE',
      'notifyEmail': true,
      'notifyPush': false,
    });

    expect(profile.displayName, 'Pro Trader');
    expect(profile.notifyEmail, isTrue);
    expect(profile.notifyPush, isFalse);
  });
}
