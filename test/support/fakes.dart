import 'package:cryptopilot_mobile/core/auth/auth_token_api.dart';
import 'package:cryptopilot_mobile/core/auth/session.dart';
import 'package:cryptopilot_mobile/core/auth/session_controller.dart';
import 'package:cryptopilot_mobile/core/auth/token_store.dart';
import 'package:cryptopilot_mobile/core/errors/api_failure.dart';
import 'package:cryptopilot_mobile/core/errors/api_problem.dart';
import 'package:cryptopilot_mobile/core/realtime/realtime_hub.dart';
import 'package:cryptopilot_mobile/core/settings/settings.dart';
import 'package:cryptopilot_mobile/core/web/web_links.dart';
import 'package:cryptopilot_mobile/features/account/data/profile_api.dart';
import 'package:cryptopilot_mobile/features/account/domain/profile.dart';
import 'package:cryptopilot_mobile/features/auth/data/auth_api.dart';
import 'package:cryptopilot_mobile/features/market/data/market_api.dart';
import 'package:cryptopilot_mobile/features/market/domain/market.dart';
import 'package:cryptopilot_mobile/features/watchlist/data/watchlist_api.dart';
import 'package:cryptopilot_mobile/features/watchlist/domain/watchlist.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import 'realtime_fakes.dart';

final now = DateTime.utc(2026, 11, 6, 10);

Session sessionFor(
  String token, {
  Duration accessFor = const Duration(minutes: 15),
  UserRole role = UserRole.trader,
}) => Session(
  accessToken: 'access-$token',
  accessTokenExpiresAt: now.add(accessFor),
  refreshToken: 'refresh-$token',
  refreshTokenExpiresAt: now.add(const Duration(days: 30)),
  role: role,
);

StoredSession storedFor(String token, {UserRole role = UserRole.trader}) =>
    StoredSession(
      refreshToken: 'refresh-$token',
      refreshTokenExpiresAt: now.add(const Duration(days: 30)),
      role: role,
    );

ProblemFailure problem(
  int status,
  String code,
  String messageCode, {
  List<String> args = const [],
  Map<String, String> fields = const {},
}) => ProblemFailure(
  ApiProblem(
    status: status,
    code: code,
    messageCode: messageCode,
    messageArgs: args,
    fieldErrors: fields,
  ),
);

class FakeAuthTokenApi implements AuthTokenApi {
  int refreshCalls = 0;
  int logoutCalls = 0;
  final List<String> refreshedWith = [];
  Future<Session> Function(String refreshToken) onRefresh = (token) async =>
      sessionFor('rotated');
  Object? logoutError;

  @override
  Future<Session> refresh(String refreshToken) {
    refreshCalls++;
    refreshedWith.add(refreshToken);
    return onRefresh(refreshToken);
  }

  @override
  Future<void> logout(String refreshToken, {String? fcmToken}) async {
    logoutCalls++;
    if (logoutError != null) throw logoutError!;
  }
}

class FakeAuthApi implements AuthApi {
  Future<Session> Function(String email, String password, bool rememberMe)
  onLogin = (_, _, _) async => sessionFor('login');
  Future<void> Function() onReset = () async {};
  int forgotCalls = 0;
  int resendCalls = 0;

  @override
  Future<Session> login({
    required String email,
    required String password,
    required bool rememberMe,
  }) => onLogin(email, password, rememberMe);

  @override
  Future<void> forgotPassword(String email) async => forgotCalls++;

  @override
  Future<void> resendVerification(String email) async => resendCalls++;

  @override
  Future<void> resetPassword({
    required String token,
    required String newPassword,
    required String confirmPassword,
  }) => onReset();
}

class FakeProfileApi implements ProfileApi {
  Profile current = const Profile(
    email: 'trader@cryptopilot.invalid',
    displayName: 'Pro Trader',
    notifyEmail: true,
    notifyPush: false,
  );
  final List<(bool, bool)> saved = [];
  Object? saveError;

  @override
  Future<Profile> profile() async => current;

  @override
  Future<void> saveNotifications({
    required bool email,
    required bool push,
  }) async {
    saved.add((email, push));
    if (saveError != null) throw saveError!;
  }
}

class FakeWebLinks implements WebLinks {
  final List<String> opened = [];

  @override
  Future<bool> open(String path) async {
    opened.add(path);
    return true;
  }
}

/// Overrides that keep tests off the platform channels and the network.
List<Override> baseOverrides({
  required TokenStore store,
  required AuthTokenApi tokens,
  AuthApi? auth,
  ProfileApi? profile,
  WebLinks? web,
  FakeTransport? transport,
  MarketApi? market,
  WatchlistApi? watchlist,
}) => [
  tokenStoreProvider.overrideWithValue(store),
  authTokenApiProvider.overrideWithValue(tokens),
  clockProvider.overrideWithValue(() => now),
  settingsStoreProvider.overrideWithValue(MemorySettingsStore()),
  authApiProvider.overrideWithValue(auth ?? FakeAuthApi()),
  profileApiProvider.overrideWithValue(profile ?? FakeProfileApi()),
  webLinksProvider.overrideWithValue(web ?? FakeWebLinks()),
  realtimeTransportProvider.overrideWithValue(transport ?? FakeTransport()),
  marketApiProvider.overrideWithValue(market ?? FakeMarketApi()),
  watchlistApiProvider.overrideWithValue(watchlist ?? FakeWatchlistApi()),
];

class FakeWatchlistApi implements WatchlistApi {
  List<WatchItem> items = [
    watchOf('BTC', label: 'Core', alerts: 2),
    watchOf('ETH', label: 'Core'),
    watchOf('SOL'),
  ];
  int? limit = 5;
  final List<String> removeCalls = [];
  final List<String> added = [];
  Object? addError;

  @override
  Future<Watchlist> list() async => Watchlist(items: [...items], limit: limit);

  @override
  Future<WatchItem> add(String pairId) async {
    if (addError != null) throw addError!;
    added.add(pairId);
    final item = watchOf(pairId.replaceFirst('pair-', ''));
    items = [...items, item];
    return item;
  }

  @override
  Future<WatchItem> update(String id, {String? label, String? note}) async =>
      items.firstWhere((item) => item.id == id);

  @override
  Future<void> remove(
    String id, {
    bool confirm = false,
    int? expectedAlertCount,
  }) async {
    removeCalls.add('$id confirm=$confirm n=$expectedAlertCount');
    final item = items.firstWhere((item) => item.id == id);
    if (item.activeAlerts > 0 && !confirm) {
      throw problem(
        400,
        'WATCHLIST_REMOVAL_CONFIRMATION_REQUIRED',
        'MSG26',
        args: [item.symbol, '${item.activeAlerts}'],
      );
    }
    items = [
      for (final i in items)
        if (i.id != id) i,
    ];
  }

  @override
  Future<SetupScore?> score(String symbol) async => SetupScore(
    score: symbol == 'BTCUSDT' ? 72 : null,
    preset: 'SWING',
    presetVersion: 'v1',
    timeframe: '4h',
  );
}

WatchItem watchOf(String base, {String? label, int alerts = 0}) => WatchItem(
  id: 'watch-$base',
  pairId: 'pair-$base',
  symbol: '${base}USDT',
  spotListed: true,
  futuresListed: true,
  label: label,
  sortOrder: 0,
  activeAlerts: alerts,
);

class FakeMarketApi implements MarketApi {
  final Map<Market, List<MarketPair>> pairsBy = {
    Market.spot: [pairOf('BTC', 1), pairOf('ETH', 2), pairOf('SOL', 3)],
    Market.futures: [
      pairOf('BTC', 1, market: Market.futures),
      pairOf('ETH', 2, market: Market.futures),
    ],
  };
  final List<String> statsCalls = [];
  Object? pairsError;

  @override
  Future<List<MarketPair>> pairs(Market market) async {
    if (pairsError != null) throw pairsError!;
    return pairsBy[market]!;
  }

  @override
  Future<Ticker> stats(Market market, String symbol) async {
    statsCalls.add(symbol);
    return Ticker(symbol: symbol, lastPrice: '100.5', changePercent24h: '1');
  }
}

MarketPair pairOf(String base, int order, {Market market = Market.spot}) =>
    MarketPair(
      pairId: 'pair-$base',
      symbol: '${base}USDT',
      market: market,
      baseAsset: base,
      quoteAsset: 'USDT',
      baseAssetName: base == 'BTC' ? 'Bitcoin' : base,
      tickSize: '0.010000000000',
      stepSize: '0.000010000000',
      displayOrder: order,
    );

/// Lets scheduled microtasks and chained futures run.
Future<void> settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

const networkDown = NetworkFailure();
