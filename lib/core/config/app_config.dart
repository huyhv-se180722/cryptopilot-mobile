/// Where the app finds the backend and the website, read once from
/// `--dart-define` at build time.
///
/// Defaults suit a debug build on the Android emulator, where the host machine
/// is `10.0.2.2`. Release builds must pass HTTPS and WSS addresses.
class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.wsUrl,
    required this.webBaseUrl,
  });

  factory AppConfig.fromEnvironment() => const AppConfig(
    apiBaseUrl: String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://10.0.2.2:8080/api/v1',
    ),
    wsUrl: String.fromEnvironment(
      'WS_URL',
      defaultValue: 'ws://10.0.2.2:8080/ws',
    ),
    webBaseUrl: String.fromEnvironment(
      'WEB_BASE_URL',
      defaultValue: 'http://10.0.2.2:5173',
    ),
  );

  /// REST root, ending in `/api/v1`, without a trailing slash.
  final String apiBaseUrl;

  /// STOMP endpoint.
  final String wsUrl;

  /// The web client, for the screens that exist only there (SRS 3.1.1).
  final String webBaseUrl;
}
