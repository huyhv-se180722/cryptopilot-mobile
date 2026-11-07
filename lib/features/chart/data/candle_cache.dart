import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/json/json_read.dart';
import '../../../core/settings/settings.dart';
import '../../market/domain/candle.dart';
import '../../market/domain/market.dart';

/// The last closed candles of a pair and timeframe, kept on the device so
/// the chart draws at once and the fresh ones replace them (ADR-012 item 5).
/// Market data only; nothing personal.
class CandleCache {
  const CandleCache(this._store);

  /// SRS 3.3.2 shows the latest 500 closed candles.
  static const keep = 500;

  final SettingsStore _store;

  static String _key(Market market, String symbol, Timeframe tf) =>
      'chart.candles.${market.wire}.$symbol.${tf.wire}';

  /// Null when nothing is kept or what is kept no longer decodes.
  Future<List<Candle>?> read(Market market, String symbol, Timeframe tf) async {
    final text = await _store.read(_key(market, symbol, tf));
    if (text == null) return null;
    try {
      final list = jsonDecode(text);
      if (list is! List) return null;
      return [for (final item in list) decodeCandle(item)];
    } on FormatException {
      return null;
    } on DecodeException {
      return null;
    }
  }

  Future<void> write(
    Market market,
    String symbol,
    Timeframe tf,
    List<Candle> candles,
  ) {
    final closed = [
      for (final c in candles)
        if (c.closed) c,
    ];
    final tail = closed.length > keep
        ? closed.sublist(closed.length - keep)
        : closed;
    return _store.write(
      _key(market, symbol, tf),
      jsonEncode([for (final c in tail) c.toJson()]),
    );
  }
}

final candleCacheProvider = Provider<CandleCache>(
  (ref) => CandleCache(ref.watch(settingsStoreProvider)),
);
