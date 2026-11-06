import 'dart:convert';

import 'package:cryptopilot_mobile/core/realtime/realtime_transport.dart';

class FakeConnection implements RealtimeConnection {
  FakeConnection(this.headers, this.onConnected, this.onClosed);

  final Map<String, String> headers;
  final void Function() onConnected;
  final void Function() onClosed;
  final Map<String, void Function(String?)> subscriptions = {};
  bool closed = false;

  void push(String destination, Object body) =>
      subscriptions[destination]?.call(jsonEncode(body));

  void drop() {
    closed = true;
    onClosed();
  }

  @override
  void Function() subscribe(
    String destination,
    void Function(String? body) onMessage,
  ) {
    subscriptions[destination] = onMessage;
    return () => subscriptions.remove(destination);
  }

  @override
  void close() {
    closed = true;
    onClosed();
  }
}

class FakeTransport implements RealtimeTransport {
  final List<FakeConnection> connections = [];

  FakeConnection get last => connections.last;

  @override
  RealtimeConnection connect({
    required String url,
    required Map<String, String> headers,
    required void Function() onConnected,
    required void Function() onClosed,
  }) {
    final connection = FakeConnection(headers, onConnected, onClosed);
    connections.add(connection);
    return connection;
  }
}
