import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session_controller.dart';
import '../config/config_provider.dart';
import 'realtime_transport.dart';

/// What screens know about the push channel.
@immutable
class RealtimeState {
  const RealtimeState({required this.connected, required this.generation});

  final bool connected;

  /// Grows by one at every (re)connection: a screen re-reads its REST snapshot
  /// when it changes, since pushes missed while away are not replayed.
  final int generation;
}

final realtimeTransportProvider = Provider<RealtimeTransport>(
  (ref) => const StompTransport(),
);

final realtimeHubProvider = NotifierProvider<RealtimeHub, RealtimeState>(
  RealtimeHub.new,
);

/// One STOMP connection for the whole app (TD 9):
/// - opened while something listens and the app is in the foreground, closed
///   30 s after the app goes to the background;
/// - a fresh access token on every CONNECT, user queues only when signed in
///   (a refused SUBSCRIBE closes the whole connection);
/// - reconnect after 1, 2, 4 … 30 s, then every destination is subscribed
///   again.
class RealtimeHub extends Notifier<RealtimeState> {
  static const backgroundGrace = Duration(seconds: 30);
  static const maxBackoff = Duration(seconds: 30);

  final Map<String, _Destination> _destinations = {};
  RealtimeConnection? _connection;
  bool _connecting = false;
  bool _authenticated = false;
  bool _foreground = true;
  int _attempt = 0;
  Timer? _retry;
  Timer? _backgroundClose;
  bool _disposed = false;

  @override
  RealtimeState build() {
    final lifecycle = AppLifecycleListener(
      onPause: _onBackground,
      onHide: _onBackground,
      onResume: _onForeground,
      onShow: _onForeground,
    );
    ref
      ..listen(sessionControllerProvider, (previous, next) {
        final wasIn = previous is SignedIn;
        final isIn = next is SignedIn;
        if (wasIn != isIn) _restart();
      })
      ..onDispose(() {
        _disposed = true;
        lifecycle.dispose();
        _retry?.cancel();
        _backgroundClose?.cancel();
        _connection?.close();
        for (final destination in _destinations.values) {
          unawaited(destination.controller.close());
        }
      });
    return const RealtimeState(connected: false, generation: 0);
  }

  /// Decoded JSON bodies pushed to [destination] while listened to.
  Stream<Object?> watch(String destination) {
    final existing = _destinations[destination];
    if (existing != null) return existing.controller.stream;
    late final _Destination entry;
    entry = _Destination(
      StreamController<Object?>.broadcast(
        onListen: () {
          _subscribe(destination, entry);
          _ensureConnected();
        },
        onCancel: () {
          if (_disposed) return;
          entry.unsubscribe?.call();
          entry.unsubscribe = null;
          _destinations.remove(destination);
          if (_destinations.isEmpty) _scheduleIdleClose();
        },
      ),
    );
    _destinations[destination] = entry;
    return entry.controller.stream;
  }

  void _subscribe(String destination, _Destination entry) {
    if (_disposed) return;
    final connection = _connection;
    if (connection == null || !state.connected) return;
    if (destination.startsWith('/user/') && !_authenticated) return;
    entry.unsubscribe ??= connection.subscribe(destination, (body) {
      if (body == null || entry.controller.isClosed) return;
      try {
        entry.controller.add(jsonDecode(body));
      } on FormatException {
        // A body that is not JSON is not ours to show.
      }
    });
  }

  Future<void> _ensureConnected() async {
    if (_disposed) return;
    if (_connection != null || _connecting || !_foreground) return;
    if (_destinations.isEmpty) return;
    _connecting = true;
    _retry?.cancel();
    final headers = <String, String>{};
    _authenticated = false;
    if (ref.read(sessionControllerProvider) is SignedIn) {
      try {
        final token = await ref
            .read(sessionControllerProvider.notifier)
            .accessToken();
        headers['Authorization'] = 'Bearer $token';
        _authenticated = true;
      } on Exception {
        // Public topics still work without a token.
      }
    }
    if (!ref.mounted) return;
    if (!_foreground || _destinations.isEmpty) {
      _connecting = false;
      return;
    }
    late final RealtimeConnection connection;
    connection = ref
        .read(realtimeTransportProvider)
        .connect(
          url: ref.read(appConfigProvider).wsUrl,
          headers: headers,
          onConnected: () {
            if (!ref.mounted || _connection != connection) return;
            _attempt = 0;
            state = RealtimeState(
              connected: true,
              generation: state.generation + 1,
            );
            for (final MapEntry(:key, :value) in _destinations.entries) {
              _subscribe(key, value);
            }
          },
          onClosed: () {
            if (!ref.mounted || _connection != connection) return;
            _dropConnection();
            _scheduleRetry();
          },
        );
    _connection = connection;
    _connecting = false;
  }

  void _dropConnection() {
    if (_disposed) return;
    _connection = null;
    for (final destination in _destinations.values) {
      destination.unsubscribe = null;
    }
    if (state.connected) {
      state = RealtimeState(connected: false, generation: state.generation);
    }
  }

  void _scheduleRetry() {
    if (_disposed) return;
    if (!_foreground || _destinations.isEmpty) return;
    final seconds = 1 << _attempt.clamp(0, 5);
    _attempt++;
    final delay = Duration(seconds: seconds) > maxBackoff
        ? maxBackoff
        : Duration(seconds: seconds);
    _retry?.cancel();
    _retry = Timer(delay, _ensureConnected);
  }

  void _close() {
    if (_disposed) return;
    _retry?.cancel();
    final connection = _connection;
    _dropConnection();
    connection?.close();
  }

  /// New credentials: drop the connection and open one with the new session.
  void _restart() {
    _close();
    _attempt = 0;
    unawaited(_ensureConnected());
  }

  void _scheduleIdleClose() {
    if (_disposed) return;
    _backgroundClose?.cancel();
    _backgroundClose = Timer(backgroundGrace, () {
      if (_destinations.isEmpty) _close();
    });
  }

  void _onBackground() {
    _foreground = false;
    _backgroundClose?.cancel();
    _backgroundClose = Timer(backgroundGrace, _close);
  }

  void _onForeground() {
    _foreground = true;
    _backgroundClose?.cancel();
    _attempt = 0;
    unawaited(_ensureConnected());
  }
}

class _Destination {
  _Destination(this.controller);

  final StreamController<Object?> controller;
  void Function()? unsubscribe;
}
