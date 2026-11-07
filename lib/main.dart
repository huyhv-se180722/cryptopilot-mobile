import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'features/alerts/presentation/alert_sheet.dart';
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
          (_, pair) => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              WatchToggle(pair: pair),
              CreateAlertButton(pair: pair),
            ],
          ),
        ),
        watchRowActionsProvider.overrideWithValue(
          (l) => [
            WatchRowAction(
              id: 'create-alert',
              label: l.alertCreate,
              run: (context, pair) => openAlertSheetFor(context, pair),
            ),
          ],
        ),
      ],
      child: const CryptoPilotApp(),
    ),
  );
}
