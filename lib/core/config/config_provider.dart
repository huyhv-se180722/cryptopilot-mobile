import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_config.dart';

/// The build's backend addresses; tests override it.
final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(),
);
