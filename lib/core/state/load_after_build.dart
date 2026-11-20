import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The first read of a notifier, started once its build has returned.
extension LoadAfterBuild on Ref {
  /// Runs [load] in the next microtask unless the provider is gone by then
  /// (read once with no listener, its widget removed in the frame it was
  /// built, or invalidated): a disposed Ref must not be used (T-125).
  void loadAfterBuild(FutureOr<void> Function() load) => unawaited(
    Future.microtask(() {
      if (mounted) return load();
    }),
  );
}
