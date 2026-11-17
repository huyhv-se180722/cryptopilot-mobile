import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/settings.dart';
import '../domain/chart_indicators.dart';

/// The device's offset from UTC when the app started: one fixed offset for
/// every chart (BR-08; see `chartOffset`).
final chartZoneProvider = Provider<Duration>(
  (ref) => DateTime.now().timeZoneOffset,
);

final chartIndicatorsProvider =
    NotifierProvider<ChartIndicatorChoice, Set<ChartIndicator>>(
      ChartIndicatorChoice.new,
    );

/// The overlays and panels the Trader switched on, remembered on the device
/// (SRS 3.3.2) and shared by every chart of the app.
class ChartIndicatorChoice extends Notifier<Set<ChartIndicator>> {
  static const storageKey = 'chart_indicators';

  bool _changed = false;

  @override
  Set<ChartIndicator> build() {
    unawaited(_load());
    return ChartIndicator.defaults;
  }

  Future<void> _load() async {
    final saved = await ref.read(settingsStoreProvider).read(storageKey);
    // A toggle made before the stored choice was read wins.
    if (saved == null || _changed || !ref.mounted) return;
    state = ChartIndicator.parse(saved);
  }

  Future<void> toggle(ChartIndicator indicator) async {
    _changed = true;
    state = state.contains(indicator)
        ? ({...state}..remove(indicator))
        : {...state, indicator};
    await ref
        .read(settingsStoreProvider)
        .write(storageKey, ChartIndicator.format(state));
  }
}
