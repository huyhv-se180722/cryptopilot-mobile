import 'package:stomp_dart_client/stomp_dart_client.dart';

/// One STOMP connection (TD 9, fe-guide realtime chapter): plain WebSocket at
/// `/ws`, optional `Authorization: Bearer` on CONNECT, SUBSCRIBE only.
abstract interface class RealtimeConnection {
  /// Returns the function that unsubscribes.
  void Function() subscribe(
    String destination,
    void Function(String? body) onMessage,
  );

  void close();
}

abstract interface class RealtimeTransport {
  /// Opens a connection. [onConnected] runs once the CONNECTED frame arrives;
  /// [onClosed] once when it ends for any reason (refused subscription, server
  /// restart, network). The library's own reconnect is off: the hub reconnects
  /// with a fresh access token each time.
  RealtimeConnection connect({
    required String url,
    required Map<String, String> headers,
    required void Function() onConnected,
    required void Function() onClosed,
  });
}

class StompTransport implements RealtimeTransport {
  const StompTransport();

  @override
  RealtimeConnection connect({
    required String url,
    required Map<String, String> headers,
    required void Function() onConnected,
    required void Function() onClosed,
  }) {
    var closed = false;
    void closeOnce() {
      if (closed) return;
      closed = true;
      onClosed();
    }

    final client = StompClient(
      config: StompConfig(
        url: url,
        stompConnectHeaders: headers,
        reconnectDelay: Duration.zero,
        heartbeatIncoming: const Duration(seconds: 20),
        heartbeatOutgoing: const Duration(seconds: 20),
        connectionTimeout: const Duration(seconds: 10),
        onConnect: (_) => onConnected(),
        onStompError: (_) => closeOnce(),
        onWebSocketError: (_) => closeOnce(),
        onWebSocketDone: closeOnce,
        onDisconnect: (_) => closeOnce(),
      ),
    )..activate();
    return _StompConnection(client, closeOnce);
  }
}

class _StompConnection implements RealtimeConnection {
  _StompConnection(this._client, this._closed);

  final StompClient _client;
  final void Function() _closed;

  @override
  void Function() subscribe(
    String destination,
    void Function(String? body) onMessage,
  ) {
    final unsubscribe = _client.subscribe(
      destination: destination,
      callback: (frame) => onMessage(frame.body),
    );
    return () {
      if (_client.connected) unsubscribe();
    };
  }

  @override
  void close() {
    _client.deactivate();
    _closed();
  }
}
