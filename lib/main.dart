import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  runApp(
    // Failed calls are retried by the user ("Try again"), never silently.
    ProviderScope(retry: (_, _) => null, child: const CryptoPilotApp()),
  );
}
