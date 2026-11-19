import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/candle_repository.dart';

export '../data/candle_repository.dart'
    show CandleChange, CandleKey, CandlesState;

final candlesControllerProvider = NotifierProvider.autoDispose
    .family<CandlesController, CandlesState, CandleKey>(CandlesController.new);

/// The chart's view of [CandleRepository]: what [ChartView] draws and the
/// two things it asks for, Try again and the older candles at the left edge.
/// Chart-only state (price lines, the paper orders of T-128) goes here, not
/// in the repository that every chart shares.
class CandlesController extends Notifier<CandlesState> {
  CandlesController(this.key);

  final CandleKey key;

  /// Every change of the repository, at once and one by one: the chart page
  /// must get the cached list and then the fresh one, not only the last.
  @override
  CandlesState build() {
    final repository = candleRepositoryProvider(key);
    ref.listen(repository, (_, next) => state = next);
    return ref.read(repository);
  }

  Future<void> load() =>
      ref.read(candleRepositoryProvider(key).notifier).load();

  Future<void> loadOlder() =>
      ref.read(candleRepositoryProvider(key).notifier).loadOlder();
}
