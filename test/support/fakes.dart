import 'package:cryptopilot_mobile/core/auth/auth_token_api.dart';
import 'package:cryptopilot_mobile/core/auth/session.dart';
import 'package:cryptopilot_mobile/core/auth/session_controller.dart';
import 'package:cryptopilot_mobile/core/auth/token_store.dart';
import 'package:cryptopilot_mobile/core/errors/api_failure.dart';
import 'package:cryptopilot_mobile/core/errors/api_problem.dart';
import 'package:cryptopilot_mobile/core/realtime/realtime_hub.dart';
import 'package:cryptopilot_mobile/core/settings/settings.dart';
import 'package:cryptopilot_mobile/core/web/web_links.dart';
import 'package:cryptopilot_mobile/features/community/data/community_api.dart';
import 'package:cryptopilot_mobile/features/academy/data/academy_api.dart';
import 'package:cryptopilot_mobile/features/account/data/profile_api.dart';
import 'package:cryptopilot_mobile/features/account/domain/profile.dart';
import 'package:cryptopilot_mobile/features/alerts/data/alert_api.dart';
import 'package:cryptopilot_mobile/features/analysis/data/analysis_api.dart';
import 'package:cryptopilot_mobile/features/analysis/domain/analysis.dart'
    show Analysis, FuturesMetrics, decodeAnalysis, decodeFuturesMetrics;
import 'package:cryptopilot_mobile/features/alerts/domain/alert.dart';
import 'package:cryptopilot_mobile/features/auth/data/auth_api.dart';
import 'package:cryptopilot_mobile/features/journal/data/performance_api.dart';
import 'package:cryptopilot_mobile/features/journal/domain/performance.dart';
import 'package:cryptopilot_mobile/features/market/data/market_api.dart';
import 'package:cryptopilot_mobile/features/market/domain/coin_market.dart';
import 'package:cryptopilot_mobile/features/market/domain/candle.dart';
import 'package:cryptopilot_mobile/features/market/domain/market.dart';
import 'package:cryptopilot_mobile/features/market/domain/order_book.dart';
import 'package:cryptopilot_mobile/features/chart/application/chart_prefs.dart';
import 'package:cryptopilot_mobile/features/chart/presentation/chart_surface.dart';
import 'package:cryptopilot_mobile/features/chart/presentation/metric_surface.dart';
import 'package:cryptopilot_mobile/features/news/data/news_api.dart';
import 'package:cryptopilot_mobile/features/paper/data/futures_api.dart';
import 'package:cryptopilot_mobile/features/paper/data/paper_api.dart';
import 'package:cryptopilot_mobile/features/news/domain/news.dart';
import 'package:cryptopilot_mobile/features/notifications/data/notification_api.dart';
import 'package:cryptopilot_mobile/features/notifications/domain/notification.dart';
import 'package:cryptopilot_mobile/features/plans/data/plan_api.dart';
import 'package:cryptopilot_mobile/features/plans/domain/plan.dart';
import 'package:cryptopilot_mobile/features/watchlist/data/watchlist_api.dart';
import 'package:cryptopilot_mobile/features/watchlist/domain/watchlist.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import 'academy_fakes.dart';
import 'chart_fakes.dart';
import 'community_fakes.dart';
import 'futures_fakes.dart';
import 'paper_fakes.dart';
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

  /// The address of every forgot password and resend call, as sent.
  final List<String> emails = [];
  Object? forgotError;
  Object? resendError;

  @override
  Future<Session> login({
    required String email,
    required String password,
    required bool rememberMe,
  }) => onLogin(email, password, rememberMe);

  @override
  Future<void> forgotPassword(String email) async {
    forgotCalls++;
    emails.add(email);
    if (forgotError case final error?) throw error;
  }

  @override
  Future<void> resendVerification(String email) async {
    resendCalls++;
    emails.add(email);
    if (resendError case final error?) throw error;
  }

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
    tradingStyle: TradingStyle.swing,
    riskProfile: RiskProfile.balanced,
  );
  final List<(bool, bool)> saved = [];
  Object? saveError;
  Object? loadError;

  @override
  Future<Profile> profile() async {
    if (loadError case final error?) throw error;
    return current;
  }

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

  @override
  Future<bool> openAddress(String address) async {
    opened.add(address);
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
  AlertApi? alerts,
  NotificationApi? notifications,
  PlanApi? plans,
  NewsApi? news,
  PerformanceApi? performance,
  FakeChartSurface? chart,
  FakeMetricSurface? metricChart,
  SettingsStore? settings,
  AnalysisApi? analysis,
  AcademyApi? academy,
  PaperApi? paper,
  FuturesApi? futures,
  CommunityApi? community,
  Duration zone = Duration.zero,
  DateTime Function()? clock,
  double Function()? jitter,
}) => [
  tokenStoreProvider.overrideWithValue(store),
  authTokenApiProvider.overrideWithValue(tokens),
  clockProvider.overrideWithValue(clock ?? () => now),
  settingsStoreProvider.overrideWithValue(settings ?? MemorySettingsStore()),
  authApiProvider.overrideWithValue(auth ?? FakeAuthApi()),
  profileApiProvider.overrideWithValue(profile ?? FakeProfileApi()),
  webLinksProvider.overrideWithValue(web ?? FakeWebLinks()),
  realtimeTransportProvider.overrideWithValue(transport ?? FakeTransport()),
  // The whole step by default, so reconnect times stay exact in tests.
  realtimeJitterProvider.overrideWithValue(jitter ?? () => 1.0),
  marketApiProvider.overrideWithValue(market ?? FakeMarketApi()),
  watchlistApiProvider.overrideWithValue(watchlist ?? FakeWatchlistApi()),
  alertApiProvider.overrideWithValue(alerts ?? FakeAlertApi()),
  notificationApiProvider.overrideWithValue(
    notifications ?? FakeNotificationApi(),
  ),
  planApiProvider.overrideWithValue(plans ?? FakePlanApi()),
  newsApiProvider.overrideWithValue(news ?? FakeNewsApi()),
  communityApiProvider.overrideWithValue(community ?? FakeCommunityApi()),
  performanceApiProvider.overrideWithValue(performance ?? FakePerformanceApi()),
  chartSurfaceProvider.overrideWithValue(chart ?? FakeChartSurface()),
  metricSurfaceProvider.overrideWithValue(metricChart ?? FakeMetricSurface()),
  // Never the zone of the machine that runs the tests.
  chartZoneProvider.overrideWithValue(zone),
  analysisApiProvider.overrideWithValue(analysis ?? FakeAnalysisApi()),
  academyApiProvider.overrideWithValue(academy ?? FakeAcademyApi()),
  paperApiProvider.overrideWithValue(paper ?? FakePaperApi()),
  futuresApiProvider.overrideWithValue(futures ?? FakeFuturesApi()),
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

  /// Every PATCH, e.g. `watch-SOL sortOrder=0` or `watch-BTC label=A note=`.
  final List<String> updates = [];
  Object? updateError;

  /// Next `list()` throws this once (then reads normally).
  Object? listError;

  /// While set, `list()` waits for it (the loading state).
  Future<void>? hold;

  /// As the backend: by `sortOrder`, rows on the same position in the order
  /// they were added ([items] keeps that order).
  @override
  Future<Watchlist> list() async {
    if (hold case final gate?) await gate;
    if (listError case final error?) {
      listError = null;
      throw error;
    }
    final indexed = [for (var i = 0; i < items.length; i++) (i, items[i])]
      ..sort((a, b) {
        final bySort = a.$2.sortOrder.compareTo(b.$2.sortOrder);
        return bySort != 0 ? bySort : a.$1.compareTo(b.$1);
      });
    return Watchlist(
      items: [for (final (_, item) in indexed) item],
      limit: limit,
    );
  }

  @override
  Future<WatchItem> add(String pairId) async {
    if (addError != null) throw addError!;
    added.add(pairId);
    final item = watchOf(pairId.replaceFirst('pair-', ''));
    items = [...items, item];
    return item;
  }

  /// Changes only the row it names, as the backend's `moveTo`.
  @override
  Future<WatchItem> update(
    String id, {
    String? label,
    String? note,
    int? sortOrder,
  }) async {
    updates.add(
      [
        id,
        if (label != null) 'label=$label',
        if (note != null) 'note=$note',
        if (sortOrder != null) 'sortOrder=$sortOrder',
      ].join(' '),
    );
    if (updateError case final error?) throw error;
    late WatchItem changed;
    items = [
      for (final item in items)
        if (item.id == id)
          changed = WatchItem(
            id: item.id,
            pairId: item.pairId,
            symbol: item.symbol,
            spotListed: item.spotListed,
            futuresListed: item.futuresListed,
            label: label == null ? item.label : (label.isEmpty ? null : label),
            note: note == null ? item.note : (note.isEmpty ? null : note),
            sortOrder: sortOrder ?? item.sortOrder,
            activeAlerts: item.activeAlerts,
          )
        else
          item,
    ];
    return changed;
  }

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

  /// While set, `pairs()` waits for it (the loading state).
  Future<void>? hold;

  @override
  Future<MarketOverview> overview() async {
    overviewCalls++;
    if (overviewError case final error?) throw error;
    return overviewValue;
  }

  int overviewCalls = 0;
  Object? overviewError;
  MarketOverview overviewValue = MarketOverview(
    asOf: DateTime.utc(2026, 11, 20),
    global: const GlobalMarket(
      marketCapUsd: '2614000000000',
      marketCapChange24hPercent: '-1.84',
      volume24hUsd: '98400000000',
      bitcoinDominancePercent: '58.21',
    ),
    fearGreed: const FearGreed(value: 22, classification: 'Extreme Fear'),
    altcoinSeason: const AltcoinSeason(index: 31, altcoins: 9, days: 90),
    openInterest: const OpenInterest(
      valueUsd: '41200000000',
      change24hPercent: '3.10',
    ),
  );

  @override
  Future<List<MarketPair>> pairs(Market market) async {
    if (hold case final gate?) await gate;
    if (pairsError != null) throw pairsError!;
    return pairsBy[market]!;
  }

  @override
  Future<Ticker> stats(Market market, String symbol) async {
    statsCalls.add(symbol);
    // The Futures stats carry mark, index and funding only (Q-91).
    return market == Market.futures
        ? Ticker(symbol: symbol, markPrice: '100.4', indexPrice: '100.3')
        : Ticker(symbol: symbol, lastPrice: '100.5', changePercent24h: '1');
  }

  /// Closed candles by `MARKET SYMBOL tf`; older pages by `… before`.
  final Map<String, List<Candle>> candlesBy = {};
  final List<String> candleCalls = [];
  Object? candlesError;

  /// While set, `candles()` waits for it.
  Future<void>? candlesHold;

  @override
  Future<List<Candle>> candles(
    Market market,
    String symbol,
    Timeframe tf, {
    int limit = 500,
    DateTime? to,
  }) async {
    candleCalls.add(
      '${market.wire} $symbol ${tf.wire} $limit${to == null ? '' : ' to'}',
    );
    if (candlesHold case final gate?) await gate;
    if (candlesError case final error?) throw error;
    final all = candlesBy['${market.wire} $symbol ${tf.wire}'] ?? const [];
    final before = [
      for (final c in all)
        if (to == null || c.openTime.isBefore(to)) c,
    ];
    return before.length > limit
        ? before.sublist(before.length - limit)
        : before;
  }

  DepthSnapshot depthAnswer = const DepthSnapshot(
    bids: [BookLevel('76000.00', '1.5'), BookLevel('75999.50', '0.5')],
    asks: [BookLevel('76000.50', '2'), BookLevel('76001.00', '1')],
  );
  List<MarketTrade> tradesAnswer = [];
  Object? depthError;
  final List<String> bookCalls = [];

  @override
  Future<DepthSnapshot> depth(Market market, String symbol) async {
    bookCalls.add('depth ${market.wire} $symbol');
    if (depthError case final error?) throw error;
    return depthAnswer;
  }

  @override
  Future<List<MarketTrade>> trades(
    Market market,
    String symbol, {
    int limit = 50,
  }) async {
    bookCalls.add('trades ${market.wire} $symbol');
    return tradesAnswer;
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

/// An alert as the backend stores it (thresholds with their scale padding).
Alert alertOf(
  String id, {
  String base = 'BTC',
  Market market = Market.spot,
  AlertType type = AlertType.price,
  AlertIndicator? indicator,
  String? timeframe,
  AlertCondition condition = AlertCondition.crossAbove,
  String? threshold = '68000.000000000000',
  AlertStatus status = AlertStatus.active,
  int triggers = 0,
  DateTime? expiresAt,
}) => Alert(
  id: id,
  pairId: 'pair-$base',
  symbol: '${base}USDT',
  rule: AlertRule(
    market: market,
    type: type,
    indicator: indicator,
    timeframe: timeframe,
    condition: condition,
    threshold: threshold,
    triggerMode: TriggerMode.once,
    expiresAt: expiresAt,
  ),
  status: status,
  triggerCount: triggers,
  lastTriggeredAt: triggers > 0 ? now : null,
  createdAt: now,
);

class FakeAlertApi implements AlertApi {
  List<Alert> alerts = [
    alertOf('a1', triggers: 2),
    alertOf(
      'a2',
      base: 'ETH',
      type: AlertType.indicator,
      indicator: AlertIndicator.rsi14,
      timeframe: '4h',
      condition: AlertCondition.lessThan,
      threshold: '30.000000000000',
      status: AlertStatus.paused,
    ),
  ];
  final List<String> calls = [];
  final List<(String, AlertRule)> created = [];
  final List<(String, AlertRule)> updated = [];
  Object? createError;
  Object? resumeError;

  /// While set, `list()` waits for it (the loading state).
  Future<void>? hold;

  @override
  Future<AlertPage> list({
    AlertStatus? status,
    AlertType? type,
    int page = 1,
    int pageSize = 20,
  }) async {
    if (hold case final gate?) await gate;
    calls.add('list ${status?.wire} ${type?.wire} $page');
    final matching = [
      for (final alert in alerts)
        if ((status == null || alert.status == status) &&
            (type == null || alert.rule.type == type))
          alert,
    ];
    final start = (page - 1) * pageSize;
    return AlertPage(
      items: matching.skip(start).take(pageSize).toList(),
      page: page,
      pageSize: pageSize,
      total: matching.length,
    );
  }

  @override
  Future<Alert> create(String pairId, AlertRule rule) async {
    if (createError != null) throw createError!;
    created.add((pairId, rule));
    final alert = Alert(
      id: 'new-${created.length}',
      pairId: pairId,
      symbol: '${pairId.replaceFirst('pair-', '')}USDT',
      rule: rule,
      status: AlertStatus.active,
      triggerCount: 0,
      createdAt: now,
    );
    alerts = [alert, ...alerts];
    return alert;
  }

  @override
  Future<Alert> update(String id, AlertRule rule) async {
    updated.add((id, rule));
    return alerts.firstWhere((alert) => alert.id == id);
  }

  @override
  Future<void> delete(String id) async {
    calls.add('delete $id');
    alerts = [
      for (final alert in alerts)
        if (alert.id != id) alert,
    ];
  }

  Alert _with(String id, AlertStatus status) {
    final old = alerts.firstWhere((alert) => alert.id == id);
    final next = Alert(
      id: old.id,
      pairId: old.pairId,
      symbol: old.symbol,
      rule: old.rule,
      status: status,
      triggerCount: old.triggerCount,
      createdAt: old.createdAt,
    );
    alerts = [for (final alert in alerts) alert.id == id ? next : alert];
    return next;
  }

  @override
  Future<Alert> pause(String id) async {
    calls.add('pause $id');
    return _with(id, AlertStatus.paused);
  }

  @override
  Future<Alert> resume(String id) async {
    calls.add('resume $id');
    if (resumeError != null) throw resumeError!;
    return _with(id, AlertStatus.active);
  }
}

/// A notification as the backend writes it; [minutesAgo] before [now].
AppNotification notificationOf(
  String id, {
  NotificationType type = NotificationType.alert,
  NotificationReference? reference = NotificationReference.alert,
  String? referenceId = 'alert-1',
  bool read = false,
  int minutesAgo = 5,
  String title = 'Alert triggered',
  String content = 'BTCUSDT: Greater than 72,162.67 (75,958.20)',
}) => AppNotification(
  id: id,
  type: type,
  title: title,
  content: content,
  referenceType: reference,
  referenceId: referenceId,
  read: read,
  createdAt: now.subtract(Duration(minutes: minutesAgo)),
);

/// The JSON of [notification], as pushed on `/user/queue/notifications`.
Map<String, Object?> notificationJson(AppNotification notification) => {
  'id': notification.id,
  'type': notification.type.wire,
  'title': notification.title,
  'content': notification.content,
  'referenceType': notification.referenceType?.wire,
  'referenceId': notification.referenceId,
  'read': notification.read,
  'readAt': null,
  'createdAt': notification.createdAt.toIso8601String(),
};

class FakeNotificationApi implements NotificationApi {
  List<AppNotification> items = [
    notificationOf('n1'),
    notificationOf(
      'n2',
      type: NotificationType.plan,
      reference: NotificationReference.plan,
      referenceId: 'plan-7',
      title: 'Entry filled',
      content: 'Your plan on ETHUSDT entered at 2,243.00.',
      minutesAgo: 90,
    ),
    notificationOf(
      'n3',
      type: NotificationType.system,
      reference: null,
      referenceId: null,
      title: 'Welcome',
      content: 'Your account is ready.',
      read: true,
      minutesAgo: 60 * 24 * 10,
    ),
  ];
  final List<String> calls = [];
  Object? listError;
  Object? readError;

  /// While set, `list()` waits for it (the loading state).
  Future<void>? hold;

  int get _unread => items.where((n) => !n.read).length;

  @override
  Future<NotificationPage> list({
    bool unreadOnly = false,
    int page = 1,
    int pageSize = 20,
  }) async {
    calls.add('list $unreadOnly $page');
    if (hold case final gate?) await gate;
    if (listError != null) throw listError!;
    final matching = [
      for (final n in items)
        if (!unreadOnly || !n.read) n,
    ];
    return NotificationPage(
      items: matching.skip((page - 1) * pageSize).take(pageSize).toList(),
      page: page,
      pageSize: pageSize,
      total: matching.length,
    );
  }

  @override
  Future<int> unreadCount() async {
    calls.add('count');
    return _unread;
  }

  @override
  Future<AppNotification> markRead(String id) async {
    calls.add('read $id');
    if (readError != null) throw readError!;
    final read = items.firstWhere((n) => n.id == id).asRead(now);
    items = [for (final n in items) n.id == id ? read : n];
    return read;
  }

  @override
  Future<int> markAllRead() async {
    calls.add('read-all');
    items = [for (final n in items) n.asRead(now)];
    return 0;
  }
}

PlanSummary planOf(
  String id, {
  String base = 'BTC',
  Market market = Market.spot,
  PlanDirection direction = PlanDirection.long,
  PlanStatus status = PlanStatus.active,
  PositionState? position,
  int? leverage,
}) => PlanSummary(
  id: id,
  pairId: 'pair-$base',
  market: market,
  direction: direction,
  entryType: 'LIMIT',
  entryPrice: '74000.000000000000',
  stopLoss: '72000.000000000000',
  takeProfit: '80000.000000000000',
  leverage: leverage,
  status: status,
  positionState: position,
  createdAt: now,
);

class FakePlanApi implements PlanApi {
  List<PlanSummary> active = [planOf('p1')];
  List<PlanSummary> executed = [
    planOf(
      'p2',
      base: 'ETH',
      status: PlanStatus.executed,
      position: PositionState.open,
    ),
    planOf('p3', status: PlanStatus.executed, position: PositionState.closed),
  ];
  final List<String> calls = [];
  Object? error;

  /// While set, `list()` waits for it (the loading state).
  Future<void>? hold;

  @override
  Future<PlanPage> list({PlanTab? tab, int page = 1, int pageSize = 20}) async {
    calls.add('${tab?.wire} $pageSize');
    if (hold case final gate?) await gate;
    if (error != null) throw error!;
    final rows = tab == PlanTab.executed ? executed : active;
    return PlanPage(items: rows.take(pageSize).toList(), total: rows.length);
  }
}

class FakeNewsApi implements NewsApi {
  List<NewsArticle> articles = [
    NewsArticle(
      id: 'a1',
      title: 'Bitcoin holds above 75,000 as funding cools',
      source: 'CoinDesk',
      publishedAt: now.subtract(const Duration(hours: 2)),
      sentiment: NewsSentiment.bullish,
      coins: const ['BTC'],
    ),
  ];
  Object? error;

  /// The `coin` of every read (null: every coin).
  final List<String?> coinCalls = [];

  @override
  Future<List<NewsArticle>> latest({int pageSize = 3, String? coin}) async {
    coinCalls.add(coin);
    if (error != null) throw error!;
    return articles
        .where((article) => coin == null || article.coins.contains(coin))
        .take(pageSize)
        .toList();
  }
}

class FakePerformanceApi implements PerformanceApi {
  PerformanceSummary summaryValue = const PerformanceSummary(
    trades: 8,
    wins: 5,
    losses: 3,
    winRate: '0.625000',
    totalNetPnl: '-304.12000000',
  );
  Object? error;

  @override
  Future<PerformanceSummary> summary() async {
    if (error != null) throw error!;
    return summaryValue;
  }
}

/// `GET /analysis/{m}/{s}` as backend develop answers it (T-107:
/// `componentsLocked`; D-126 push without score). [capReason] and
/// [scoredSide] are the optional fields of setup score v2 (9090dc07); a
/// [short] history has no EMA 200 yet.
Map<String, Object?> analysisJson({
  String market = 'SPOT',
  String symbol = 'BTCUSDT',
  bool locked = false,
  int? score = 56,
  String support = '75790.0000000000',
  String? capReason,
  String? scoredSide,
  bool short = false,
}) => {
  'symbol': symbol,
  'market': market,
  'timeframe': '1h',
  'openTime': '2026-11-07T08:00:00Z',
  'calculatedAt': '2026-11-07T09:00:01.339409Z',
  'indicators': {
    'sma20': '75926.1660000001',
    'ema20': '76039.2154406578',
    'ema50': '76577.2345805825',
    'ema200': short ? null : '77867.9229098132',
    'rsi14': '51.8182579316',
    'macdLine': '-106.1115449333',
    'macdSignal': '-199.4043185456',
    'macdHistogram': '93.2927736123',
    'bbUpper': '76195.7288915412',
    'bbMiddle': '75926.1660000001',
    'bbLower': '75656.6031084590',
    'volumeSma20': '584.8379235000',
  },
  'nearestSupport': support,
  'nearestResistance': '76208.2500000000',
  'componentsLocked': locked,
  'components': locked
      ? null
      : {
          'formulaVersion': 'v1',
          'trend': '25.00',
          'momentum': '100.00',
          'volume': '0.00',
          'level': '1.09',
          if (market == 'FUTURES') 'derivatives': '75.43',
        },
  'setupScore': {
    'score': score,
    'preset': 'SCALPING',
    'presetVersion': 'v1',
    'timeframe': '15m',
    'openTime': '2026-11-07T09:15:00Z',
    'components': locked
        ? null
        : {
            'formulaVersion': 'v1',
            'trend': '50.00',
            'momentum': '80.00',
            'volume': '25.54',
            'level': '49.48',
            if (market == 'FUTURES') 'derivatives': '50.07',
          },
    if (market == 'FUTURES') 'dominantSide': 'LONG',
    'capReason': ?capReason,
    'scoredSide': ?scoredSide,
  },
};

class FakeAnalysisApi implements AnalysisApi {
  /// By `MARKET SYMBOL tf`; missing → the default spot answer.
  final Map<String, Object?> answers = {};
  final List<String> calls = [];
  final List<String> metricCalls = [];
  Object? error;
  Object? metricsError;

  /// The metrics body; missing → `metricsJson` of the asked range.
  Map<String, Object?>? metricsAnswer;

  /// While set, `metrics()` waits for it (the loading state).
  Future<void>? metricsHold;

  /// While set, `analysis()` waits for it (the loading state).
  Future<void>? hold;

  @override
  Future<Analysis> analysis(Market market, String symbol, Timeframe tf) async {
    final key = '${market.wire} $symbol ${tf.wire}';
    calls.add(key);
    if (hold case final gate?) await gate;
    if (error case final e?) throw e;
    return decodeAnalysis(
      answers[key] ?? analysisJson(market: market.wire, symbol: symbol),
    );
  }

  @override
  Future<FuturesMetrics> metrics(String symbol, DateTime from) async {
    metricCalls.add('$symbol ${from.toIso8601String()}');
    if (metricsHold case final gate?) await gate;
    if (metricsError case final e?) throw e;
    return decodeFuturesMetrics(
      metricsAnswer ?? metricsJson(symbol: symbol, from: from),
    );
  }
}

/// `GET /market/futures/{s}/metrics` as backend develop answers it
/// (9090dc07): sparse points, oldest first, and the first stored instant of
/// each series.
Map<String, Object?> metricsJson({
  String symbol = 'BTCUSDT',
  DateTime? from,
  List<Object?>? openInterest,
  List<Object?>? longShortRatio,
  String? since = '2026-11-05T00:00:00Z',
}) => {
  'symbol': symbol,
  'from': (from ?? now.subtract(const Duration(days: 1))).toIso8601String(),
  'to': now.toIso8601String(),
  'openInterest':
      openInterest ??
      [
        {
          'time': '2026-11-06T09:30:00Z',
          'openInterest': '95410.118000000000',
          'openInterestValue': '7264410223.10220000',
        },
        {
          'time': '2026-11-06T09:35:00Z',
          'openInterest': '95532.229000000000',
          'openInterestValue': '7273680617.71650000',
        },
      ],
  'longShortRatio':
      longShortRatio ??
      [
        {
          'time': '2026-11-06T09:30:00Z',
          'longShortRatio': '3.19870000',
          'longAccountRatio': '0.76180000',
          'shortAccountRatio': '0.23820000',
        },
        {
          'time': '2026-11-06T09:35:00Z',
          'longShortRatio': '3.23010000',
          'longAccountRatio': '0.76360000',
          'shortAccountRatio': '0.23640000',
        },
      ],
  'fundingSettlements': <Object?>[],
  'availableFrom': {
    'openInterest': since,
    'longShortRatio': since,
    'fundingSettlements': null,
  },
};
