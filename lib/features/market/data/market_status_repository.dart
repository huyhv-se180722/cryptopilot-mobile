import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/http/http_providers.dart';
import '../../../core/json/json_read.dart';
import '../../../core/realtime/realtime_hub.dart';
import '../../../core/realtime/reload_on_reconnect.dart';
import '../../../core/state/load_after_build.dart';
import '../../../core/state/poll_gate.dart';
import '../domain/market.dart';
import '../domain/market_health.dart';

const marketStatusTopic = '/topic/market.status';
String fallbackTopic(Market market) => '/topic/market.fallback.${market.wire}';

/// The markets' data health and their reference prices (D-159; public, as
/// the market data is).
abstract interface class MarketStatusApi {
  /// `GET /market/status`: Spot, then Futures.
  Future<MarketStatus> status();

  /// `GET /market/fallback?market=`: the display-only prices while the
  /// market's exchange data is lost; none while it is live.
  Future<FallbackPrices> fallback(Market market);
}

class DioMarketStatusApi implements MarketStatusApi {
  const DioMarketStatusApi(this._dio);

  final Dio _dio;

  @override
  Future<MarketStatus> status() =>
      apiCall(() => _dio.get<Object?>('market/status'), decodeMarketStatus);

  @override
  Future<FallbackPrices> fallback(Market market) => apiCall(
    () => _dio.get<Object?>(
      'market/fallback',
      queryParameters: {'market': market.wire},
    ),
    decodeFallbackPrices,
  );
}

final marketStatusApiProvider = Provider<MarketStatusApi>(
  (ref) => DioMarketStatusApi(ref.watch(apiDioProvider)),
);

/// How often the status is read again whatever the pushes do, as on the web
/// (`STATUS_POLL_MS`): a missed push costs at most this long. The backend
/// refuses every trading request while a market is closed, so a late banner
/// never lets a wrong order through.
const marketStatusPollEvery = Duration(seconds: 15);

final marketStatusProvider =
    NotifierProvider.autoDispose<MarketStatusRepository, MarketStatus>(
      MarketStatusRepository.new,
    );

/// Both markets' data health (D-159, T-146): read once, kept current by
/// `/topic/market.status` (pushed on every change and every 5 s while a
/// market recovers), read again on reconnection and every
/// [marketStatusPollEvery]. Until the first answer, and while none can be
/// read, every market counts as live.
class MarketStatusRepository extends Notifier<MarketStatus> {
  bool _loading = false;

  @override
  MarketStatus build() {
    final pushes = ref
        .read(realtimeHubProvider.notifier)
        .watch(marketStatusTopic)
        .listen(_onPush);
    final poll = ref.pollEvery(marketStatusPollEvery, () => unawaited(load()));
    ref
      ..reloadOnReconnect(() => unawaited(load()))
      ..onDispose(() {
        poll.cancel();
        unawaited(pushes.cancel());
      });
    ref.loadAfterBuild(load);
    return MarketStatus.allLive;
  }

  Future<void> load() async {
    if (!ref.mounted || _loading) return;
    _loading = true;
    try {
      final status = await ref.read(marketStatusApiProvider).status();
      if (ref.mounted) state = status;
    } on ApiFailure {
      // The last status stands; the server still refuses with MSG57.
    } finally {
      _loading = false;
    }
  }

  void _onPush(Object? body) {
    try {
      state = decodeMarketStatus(body);
    } on DecodeException {
      // Not readable: the next poll catches up.
    }
  }
}

final fallbackPricesProvider = NotifierProvider.autoDispose
    .family<FallbackPricesRepository, FallbackPrices?, Market>(
      FallbackPricesRepository.new,
    );

/// The reference prices of a market while its exchange data is lost
/// (D-159): null while it is not, with no subscription then; otherwise read,
/// kept by `/topic/market.fallback.<MARKET>` and read again every
/// [marketStatusPollEvery].
class FallbackPricesRepository extends Notifier<FallbackPrices?> {
  FallbackPricesRepository(this.market);

  final Market market;

  @override
  FallbackPrices? build() {
    final lost = ref.watch(
      marketStatusProvider.select((status) => status.of(market).dataLost),
    );
    if (!lost) return null;
    final pushes = ref
        .read(realtimeHubProvider.notifier)
        .watch(fallbackTopic(market))
        .listen(_onPush);
    final poll = ref.pollEvery(marketStatusPollEvery, () => unawaited(load()));
    ref.onDispose(() {
      poll.cancel();
      unawaited(pushes.cancel());
    });
    ref.loadAfterBuild(load);
    return null;
  }

  Future<void> load() async {
    if (!ref.mounted) return;
    try {
      final prices = await ref.read(marketStatusApiProvider).fallback(market);
      if (ref.mounted) state = prices;
    } on ApiFailure {
      // The last prices stand.
    }
  }

  void _onPush(Object? body) {
    try {
      final prices = decodeFallbackPrices(body);
      if (prices.market == market) state = prices;
    } on DecodeException {
      // Not readable: the next poll catches up.
    }
  }
}
