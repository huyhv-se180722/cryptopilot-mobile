import 'package:cryptopilot_mobile/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defaults to the local backend as the Android emulator sees it', () {
    final config = AppConfig.fromEnvironment();
    expect(config.apiBaseUrl, 'http://10.0.2.2:8080/api/v1');
    expect(config.wsUrl, 'ws://10.0.2.2:8080/ws');
    expect(config.webBaseUrl, 'http://10.0.2.2:5173');
  });
}
