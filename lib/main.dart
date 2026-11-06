import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'features/market/presentation/pair_sheet.dart';
import 'features/watchlist/presentation/watchlist_view.dart';

void main() {
  runApp(
    // Failed calls are retried by the user ("Try again"), never silently.
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        // Composition root: features meet here, not inside each other.
        pairActionsProvider.overrideWithValue(
          (_, pair) => WatchToggle(pair: pair),
        ),
      ],
      child: const CryptoPilotApp(),
    ),
  );
}
