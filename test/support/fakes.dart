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
import 'package:cryptopilot_mobile/features/alerts/data/alert_api.dart';
import 'package:cryptopilot_mobile/features/alerts/domain/alert.dart';
import 'package:cryptopilot_mobile/features/auth/data/auth_api.dart';
import 'package:cryptopilot_mobile/features/market/data/market_api.dart';
import 'package:cryptopilot_mobile/features/market/domain/market.dart';
import 'package:cryptopilot_mobile/features/notifications/data/notification_api.dart';
import 'package:cryptopilot_mobile/features/notifications/domain/notification.dart';
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
  AlertApi? alerts,
  NotificationApi? notifications,
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
  alertApiProvider.overrideWithValue(alerts ?? FakeAlertApi()),
  notificationApiProvider.overrideWithValue(
    notifications ?? FakeNotificationApi(),
  ),
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

  @override
  Future<AlertPage> list({
    AlertStatus? status,
    AlertType? type,
    int page = 1,
    int pageSize = 20,
  }) async {
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

  int get _unread => items.where((n) => !n.read).length;

  @override
  Future<NotificationPage> list({
    bool unreadOnly = false,
    int page = 1,
    int pageSize = 20,
  }) async {
    calls.add('list $unreadOnly $page');
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
