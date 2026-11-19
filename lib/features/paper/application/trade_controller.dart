import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/settings.dart';
import '../../market/domain/market.dart';

/// The Spot pair the Trade tab shows: chosen there, or handed over by a
/// "Trade (demo)" entry; the first listed pair until then.
final tradePairProvider = NotifierProvider<TradePair, String?>(TradePair.new);

class TradePair extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String symbol) => state = symbol;
}

/// The pair to show: the chosen one when it is still listed, else the
/// first Spot pair.
MarketPair? tradePairOf(String? chosen, List<MarketPair>? pairs) {
  if (pairs == null || pairs.isEmpty) return null;
  return pairs.where((p) => p.symbol == chosen).firstOrNull ?? pairs.first;
}

/// Whether a demo order is confirmed in a sheet before it goes (plan 9.4);
/// on by default, switched in the account screen, kept on the device.
final confirmOrdersProvider = NotifierProvider<ConfirmOrders, bool>(
  ConfirmOrders.new,
);

class ConfirmOrders extends Notifier<bool> {
  static const key = 'paper.confirmOrders';

  late Future<void> _loaded;

  @override
  bool build() {
    _loaded = _read();
    unawaited(_loaded);
    return true;
  }

  Future<void> _read() async {
    final stored = await ref.read(settingsStoreProvider).read(key);
    if (stored != null && ref.mounted) state = stored != 'false';
  }

  /// The stored choice, once read: the first order after a start must not
  /// ask when the Trader switched the question off.
  Future<bool> current() async {
    await _loaded;
    return state;
  }

  Future<void> set(bool value) async {
    state = value;
    await ref.read(settingsStoreProvider).write(key, '$value');
  }
}
