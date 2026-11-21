import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/poll_gate.dart';
import 'realtime_hub.dart';

extension ReloadOnReconnect on Ref {
  /// Reads [reload] again when pushes may have been missed, once per gap
  /// (T-138):
  /// - on every new connection, except the app's first one when it comes
  ///   within [fallbackAfter] of this screen's own first read, which it
  ///   would only repeat;
  /// - on resume only when the socket does not come back within
  ///   [fallbackAfter], since a socket still open in its background grace
  ///   missed nothing and a reconnected one already reads on its new
  ///   generation.
  void reloadOnReconnect(
    void Function() reload, {
    Duration fallbackAfter = const Duration(seconds: 10),
  }) {
    Timer? fallback;
    // A timer, not the wall clock, so a changed device clock cannot matter.
    var young = true;
    final grown = Timer(fallbackAfter, () => young = false);
    final lifecycle = AppLifecycleListener(
      onResume: () {
        if (read(realtimeHubProvider).connected) return;
        fallback?.cancel();
        fallback = Timer(fallbackAfter, () {
          fallback = null;
          if (!mounted || read(realtimeHubProvider).connected) return;
          // Not on its own clock inside a 429 window either (ADR-014).
          if (read(pollGateProvider).open) reload();
        });
      },
    );
    listen(realtimeHubProvider.select((s) => s.generation), (before, now) {
      if (before == null || now == before) return;
      if (before == 0 && young) return;
      fallback?.cancel();
      fallback = null;
      reload();
    });
    onDispose(() {
      grown.cancel();
      fallback?.cancel();
      lifecycle.dispose();
    });
  }
}
