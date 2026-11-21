import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether background REST reads (polling) may run now.
@immutable
class PollGateState {
  const PollGateState({this.foreground = true, this.rateLimited = false});

  /// The app is shown; a hidden or paused app reads nothing on a timer.
  final bool foreground;

  /// The server answered 429 (ADR-014) and its window has not ended yet.
  final bool rateLimited;

  bool get open => foreground && !rateLimited;
}

final pollGateProvider = NotifierProvider<PollGate, PollGateState>(
  PollGate.new,
);

/// The one place every poller asks before a timed REST read (T-138): no
/// polling while the app is in the background, where the realtime hub closes
/// its socket on purpose, and none until a 429's `Retry-After` has passed.
/// What the user asks for (retry, pull to refresh, an order) is never held.
class PollGate extends Notifier<PollGateState> {
  Timer? _limit;

  @override
  PollGateState build() {
    final lifecycle = AppLifecycleListener(
      onPause: () => _setForeground(false),
      onHide: () => _setForeground(false),
      onResume: () => _setForeground(true),
      onShow: () => _setForeground(true),
    );
    ref.onDispose(() {
      lifecycle.dispose();
      _limit?.cancel();
    });
    return const PollGateState();
  }

  bool get open => state.open;

  /// Holds every poller for [retryAfter]; a later 429 restarts the window.
  void rateLimited(Duration retryAfter) {
    _limit?.cancel();
    _limit = Timer(retryAfter, () {
      if (ref.mounted) state = PollGateState(foreground: state.foreground);
    });
    state = PollGateState(foreground: state.foreground, rateLimited: true);
  }

  void _setForeground(bool foreground) {
    if (state.foreground == foreground) return;
    state = PollGateState(
      foreground: foreground,
      rateLimited: state.rateLimited,
    );
  }
}
