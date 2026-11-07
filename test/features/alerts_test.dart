import 'package:cryptopilot_mobile/core/auth/token_store.dart';
import 'package:cryptopilot_mobile/core/i18n/app_localizations.dart';
import 'package:cryptopilot_mobile/core/i18n/app_localizations_en.dart';
import 'package:cryptopilot_mobile/core/json/json_read.dart';
import 'package:cryptopilot_mobile/core/theme/app_theme.dart';
import 'package:cryptopilot_mobile/features/alerts/data/alert_api.dart';
import 'package:cryptopilot_mobile/features/alerts/domain/alert.dart';
import 'package:cryptopilot_mobile/features/alerts/presentation/alert_format.dart';
import 'package:cryptopilot_mobile/features/alerts/presentation/alert_sheet.dart';
import 'package:cryptopilot_mobile/features/alerts/presentation/alerts_screen.dart';
import 'package:cryptopilot_mobile/features/market/domain/market.dart';
import 'package:cryptopilot_mobile/features/market/presentation/markets_screen.dart';
import 'package:cryptopilot_mobile/features/market/presentation/pair_sheet.dart';
import 'package:cryptopilot_mobile/features/watchlist/domain/watchlist.dart';
import 'package:cryptopilot_mobile/features/watchlist/presentation/watchlist_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/realtime_fakes.dart';

/// `AlertResponse` as backend develop 25ba960 writes it (decimals as text,
/// instants ISO 8601).
const payload = {
  'id': '01a1b2c3-0000-7000-8000-000000000001',
  'watchlistId': '01a1b2c3-0000-7000-8000-0000000000aa',
  'pairId': '01a18804-7883-752f-86a8-6efe55cebd85',
  'symbol': 'BTCUSDT',
  'market': 'FUTURES',
  'type': 'INDICATOR',
  'indicator': 'FUNDING_RATE',
  'timeframe': '1h',
  'condition': 'GREATER_THAN',
  'threshold': '0.050000000000',
  'triggerMode': 'EVERY_TIME',
  'cooldownMinutes': 30,
  'notifyInApp': true,
  'notifyEmail': false,
  'notifyPush': true,
  'status': 'TRIGGERED',
  'triggerCount': 3,
  'lastTriggeredAt': '2026-11-07T02:15:00Z',
  'expiresAt': null,
  'createdAt': '2026-11-06T10:00:00.123456Z',
};

final l = AppLocalizationsEn();

void main() {
  group('decoders (AlertResponse of backend develop 25ba960)', () {
    test('an alert with every field', () {
      final alert = decodeAlert(payload);
      expect(alert.rule.market, Market.futures);
      expect(alert.rule.indicator, AlertIndicator.fundingRate);
      expect(alert.rule.threshold, '0.050000000000');
      expect(alert.rule.cooldownMinutes, 30);
      expect(alert.status, AlertStatus.triggered);
      expect(alert.lastTriggeredAt, DateTime.utc(2026, 11, 7, 2, 15));
      expect(alert.rule.expiresAt, isNull);
    });

    test('a page carries its total', () {
      final page = decodeAlertPage({
        'items': [payload],
        'page': 1,
        'pageSize': 20,
        'total': 21,
      });
      expect(page.items, hasLength(1));
      expect(page.hasMore, isTrue);
    });

    test(
      'an unknown status or a threshold that is not a number is refused',
      () {
        expect(
          () => decodeAlert({...payload, 'status': 'SNOOZED'}),
          throwsA(isA<DecodeException>()),
        );
        expect(
          () => decodeAlert({...payload, 'threshold': 'high'}),
          throwsA(isA<DecodeException>()),
        );
      },
    );

    test('the request body names every field, null when not taken', () {
      final body = encodeRule(
        AlertRule(
          market: Market.spot,
          type: AlertType.price,
          condition: AlertCondition.crossAbove,
          threshold: '68000',
          triggerMode: TriggerMode.once,
          expiresAt: DateTime.utc(2026, 11, 14, 10),
        ),
      );
      expect(body, {
        'market': 'SPOT',
        'type': 'PRICE',
        'indicator': null,
        'timeframe': null,
        'condition': 'CROSS_ABOVE',
        'threshold': '68000',
        'triggerMode': 'ONCE',
        'cooldownMinutes': null,
        'notifyEmail': false,
        'notifyPush': false,
        'expiresAt': '2026-11-14T10:00:00.000Z',
      });
    });
  });

  group('client checks mirror the server validator', () {
    RuleError? errorOf(AlertDraft draft, RuleField field) =>
        checkDraft(draft, now).errors[field];

    const spot = AlertDraft(market: Market.spot);
    const futures = AlertDraft(market: Market.futures);

    test('a price target is required and above zero', () {
      expect(errorOf(spot, RuleField.threshold), isA<RequiredValue>());
      expect(
        errorOf(spot.copyWith(threshold: '0'), RuleField.threshold),
        isA<NotPositive>(),
      );
      expect(
        errorOf(spot.copyWith(threshold: '1.2.3'), RuleField.threshold),
        isA<NotANumber>(),
      );
      final ok = checkDraft(spot.copyWith(threshold: '68000.5'), now).rule!;
      expect(ok.indicator, isNull);
      expect(ok.timeframe, isNull);
      expect(ok.threshold, '68000.5');
    });

    test('RSI lies between 0 and 100 and takes a timeframe', () {
      final rsi = spot.copyWith(type: AlertType.indicator, threshold: '101');
      final error = errorOf(rsi, RuleField.threshold);
      expect(error, isA<OutOfRange>());
      expect((error! as OutOfRange).max, '100');
      final ok = checkDraft(rsi.copyWith(threshold: '70'), now).rule!;
      expect(ok.timeframe, '1h');
    });

    test('the two crosses take a cross and no threshold', () {
      final macd = spot.copyWith(
        type: AlertType.indicator,
        indicator: AlertIndicator.macdCross,
        condition: AlertCondition.greaterThan,
        threshold: '5',
      );
      expect(errorOf(macd, RuleField.condition), isA<RequiredValue>());
      final ok = checkDraft(
        macd.copyWith(condition: AlertCondition.crossBelow),
        now,
      ).rule!;
      expect(ok.threshold, isNull);
      expect(ok.timeframe, '1h');
    });

    test(
      'funding is Futures only, in percent within ±5, without timeframe',
      () {
        final funding = futures.copyWith(
          type: AlertType.indicator,
          indicator: AlertIndicator.fundingRate,
          threshold: '-6',
        );
        expect(errorOf(funding, RuleField.threshold), isA<OutOfRange>());
        expect(
          errorOf(funding.copyWith(market: Market.spot), RuleField.market),
          isA<RequiredValue>(),
        );
        final ok = checkDraft(funding.copyWith(threshold: '0.05'), now).rule!;
        expect(ok.timeframe, isNull);
        expect(ok.threshold, '0.05');
      },
    );

    test('every time needs a cooldown of at least one minute', () {
      final every = spot.copyWith(
        threshold: '1',
        triggerMode: TriggerMode.everyTime,
      );
      expect(errorOf(every, RuleField.cooldownMinutes), isA<RequiredValue>());
      expect(
        errorOf(every.copyWith(cooldown: '0'), RuleField.cooldownMinutes),
        isA<CooldownTooShort>(),
      );
      expect(
        checkDraft(every.copyWith(cooldown: '15'), now).rule!.cooldownMinutes,
        15,
      );
    });

    test('an expiry lies in the next 90 days', () {
      final draft = spot.copyWith(threshold: '1');
      expect(
        errorOf(
          draft.copyWith(expiresAt: now.add(const Duration(days: 91))),
          RuleField.expiresAt,
        ),
        isA<ExpiryOutOfWindow>(),
      );
      expect(
        errorOf(
          draft.copyWith(expiresAt: now.subtract(const Duration(minutes: 1))),
          RuleField.expiresAt,
        ),
        isA<ExpiryOutOfWindow>(),
      );
      expect(
        checkDraft(
          draft.copyWith(expiresAt: now.add(const Duration(days: 90))),
          now,
        ).rule,
        isNotNull,
      );
    });

    test('a server MSG15 is worded with the field’s own range', () {
      final rsi = RuleShape.of(AlertType.indicator, AlertIndicator.rsi14);
      final price = RuleShape.of(AlertType.price, AlertIndicator.rsi14);
      expect(
        ruleErrorText(
          l,
          serverRuleError(rsi, RuleField.threshold, 'MSG15')!,
          'RSI level',
        ),
        'RSI level must be between 0 and 100.',
      );
      expect(
        ruleErrorText(
          l,
          serverRuleError(price, RuleField.threshold, 'MSG15')!,
          'Target price',
        ),
        'Target price must be greater than 0.',
      );
      expect(
        ruleErrorText(
          l,
          serverRuleError(price, RuleField.threshold, 'MSG01')!,
          'Target price',
        ),
        'The Target price field is required.',
      );
    });
  });

  group('the rule in words', () {
    AlertRule rule({
      AlertType type = AlertType.indicator,
      AlertIndicator? indicator,
      String? timeframe,
      AlertCondition condition = AlertCondition.greaterThan,
      String? threshold,
    }) => AlertRule(
      market: Market.futures,
      type: type,
      indicator: indicator,
      timeframe: timeframe,
      condition: condition,
      threshold: threshold,
      triggerMode: TriggerMode.once,
    );

    test('every type and indicator', () {
      expect(
        conditionText(
          l,
          rule(
            type: AlertType.price,
            condition: AlertCondition.crossAbove,
            threshold: '68000.000000000000',
          ),
        ),
        'Crosses above 68,000.00',
      );
      expect(
        conditionText(
          l,
          rule(
            indicator: AlertIndicator.rsi14,
            timeframe: '4h',
            condition: AlertCondition.lessThan,
            threshold: '30.000000000000',
          ),
        ),
        'RSI (14) 4h · Less than 30',
      );
      expect(
        conditionText(
          l,
          rule(
            indicator: AlertIndicator.macdCross,
            timeframe: '1h',
            condition: AlertCondition.crossBelow,
          ),
        ),
        'MACD crosses below signal · 1h',
      );
      expect(
        conditionText(
          l,
          rule(
            indicator: AlertIndicator.emaCross,
            timeframe: '1d',
            condition: AlertCondition.crossAbove,
          ),
        ),
        'EMA 20 crosses above EMA 50 · 1d',
      );
      expect(
        conditionText(
          l,
          rule(
            indicator: AlertIndicator.fundingRate,
            threshold: '0.050000000000',
          ),
        ),
        'Funding rate · Greater than 0.05%',
      );
      expect(
        conditionText(
          l,
          rule(
            indicator: AlertIndicator.openInterestChange,
            condition: AlertCondition.lessThan,
            threshold: '-5.5',
          ),
        ),
        'Open interest change (1h) · Less than -5.5%',
      );
      expect(
        conditionText(
          l,
          rule(
            type: AlertType.price,
            condition: AlertCondition.lessThan,
            threshold: '0.123400000000',
          ),
        ),
        'Less than 0.1234',
      );
    });
  });

  group('SCR-13', () {
    late FakeTransport transport;
    late FakeAlertApi api;
    late FakeWatchlistApi watchlist;

    Future<void> pump(
      WidgetTester tester, {
      List<Alert>? alerts,
      List<WatchItem>? watched,
      Brightness brightness = Brightness.light,
    }) async {
      transport = FakeTransport();
      api = FakeAlertApi();
      watchlist = FakeWatchlistApi();
      if (alerts != null) api.alerts = alerts;
      if (watched != null) watchlist.items = watched;
      await tester.pumpWidget(
        ProviderScope(
          overrides: baseOverrides(
            store: MemoryTokenStore(storedFor('saved')),
            tokens: FakeAuthTokenApi(),
            transport: transport,
            watchlist: watchlist,
            alerts: api,
          ),
          retry: (_, _) => null,
          child: MaterialApp(
            theme: appTheme(brightness),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const AlertsScreen(),
          ),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump();
      }
    }

    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 31));
    }

    Future<void> menu(WidgetTester tester, String id, String action) async {
      await tester.tap(find.byKey(Key('alert-menu-$id')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text(action).last);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('lists the rule, market, status and trigger count', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text('Crosses above 68,000.00'), findsOneWidget);
      expect(find.text('RSI (14) 4h · Less than 30'), findsOneWidget);
      expect(find.text('Paused'), findsWidgets);
      expect(find.textContaining('Triggered 2×'), findsOneWidget);
      expect(find.textContaining('Never triggered'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('a status chip filters on the server', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const Key('alert-filter-PAUSED')));
      await tester.pump();
      await tester.pump();

      expect(api.calls.last, 'list PAUSED null 1');
      expect(find.text('Crosses above 68,000.00'), findsNothing);
      expect(find.text('RSI (14) 4h · Less than 30'), findsOneWidget);

      await tester.tap(find.byKey(const Key('alert-filter-EXPIRED')));
      await tester.pump();
      await tester.pump();
      expect(find.text('No alerts match these filters.'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('the next page loads as the list scrolls', (tester) async {
      await pump(tester, alerts: [for (var i = 0; i < 25; i++) alertOf('x$i')]);
      expect(api.calls, ['list null null 1']);
      await tester.drag(find.byType(ListView).last, const Offset(0, -3000));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(api.calls, contains('list null null 2'));
      await tester.drag(find.byType(ListView).last, const Offset(0, -3000));
      await tester.pump();
      expect(find.byKey(const Key('alert-row-x24')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('pause and resume from the row menu', (tester) async {
      await pump(tester);
      await menu(tester, 'a1', 'Pause');
      expect(api.calls, contains('pause a1'));
      expect(find.text('Alert paused.'), findsOneWidget);

      await menu(tester, 'a2', 'Resume');
      expect(api.calls, contains('resume a2'));
      expect(find.text('Alert resumed.'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('a resume over the plan limit shows MSG27', (tester) async {
      await pump(tester);
      api.resumeError = problem(
        409,
        'PLAN_LIMIT_REACHED',
        'MSG27',
        args: ['3', 'active alerts', 'FREE'],
      );
      await menu(tester, 'a2', 'Resume');
      expect(
        find.text(
          'You have reached the limit of 3 active alerts of the FREE plan. Upgrade to increase the limit?',
        ),
        findsOneWidget,
      );
      await unmount(tester);
    });

    testWidgets('delete asks first, then removes the row', (tester) async {
      await pump(tester);
      await menu(tester, 'a1', 'Delete');
      expect(
        find.text(
          'Delete the Crosses above 68,000.00 alert on BTCUSDT? This cannot be undone.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('confirm-delete-alert')));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(api.calls, contains('delete a1'));
      expect(find.byKey(const Key('alert-row-a1')), findsNothing);
      expect(find.text('Alert deleted.'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('an edit sends the whole rule again with MSG14', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.byKey(const Key('alert-row-a1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Edit alert · BTCUSDT'), findsOneWidget);
      // The boards tell the pair's markets: Futures can be chosen too.
      final futures = tester.widget<SegmentedButton<Market>>(
        find.byKey(const Key('alert-market')),
      );
      expect(
        futures.segments.firstWhere((s) => s.value == Market.futures).enabled,
        isTrue,
      );
      expect(find.widgetWithText(TextField, '68000'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('alert-threshold')), '70000');
      await tester.tap(find.byKey(const Key('alert-save')));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final (id, rule) = api.updated.single;
      expect(id, 'a1');
      expect(rule.threshold, '70000');
      expect(rule.type, AlertType.price);
      expect(find.text('Saved successfully.'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('New alert picks any pair; an unwatched one is added', (
      tester,
    ) async {
      await pump(tester, watched: [watchOf('BTC')]);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byKey(const Key('new-alert')));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.enterText(find.byKey(const Key('alert-pair-search')), 'sol');
      await tester.pump();
      await tester.tap(find.byKey(const Key('alert-pick-SOLUSDT')));
      await tester.pump();
      expect(
        find.text('This pair is added to your watchlist with the alert.'),
        findsOneWidget,
      );
      await tester.enterText(find.byKey(const Key('alert-threshold')), '150');
      await tester.tap(find.byKey(const Key('alert-save')));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(api.created.single.$1, 'pair-SOL');
      expect(find.text('Crosses above 150.00'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('nothing yet offers to create one', (tester) async {
      await pump(tester, alerts: []);
      expect(find.text('No alerts yet.'), findsOneWidget);
      expect(find.text('New alert'), findsOneWidget);
      await unmount(tester);
    });

    for (final brightness in Brightness.values) {
      testWidgets('fits 360 dp in the ${brightness.name} theme', (
        tester,
      ) async {
        tester.view
          ..physicalSize = const Size(360 * 3, 760 * 3)
          ..devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        await pump(
          tester,
          brightness: brightness,
          alerts: [
            alertOf(
              'long',
              base: 'ONEPOINTFIVE',
              market: Market.futures,
              type: AlertType.indicator,
              indicator: AlertIndicator.openInterestChange,
              condition: AlertCondition.greaterThan,
              threshold: '12.5',
              status: AlertStatus.triggered,
              triggers: 12,
              expiresAt: now.add(const Duration(days: 30)),
            ),
            ...FakeAlertApi().alerts,
          ],
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const Key('alert-row-a1')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
        await unmount(tester);
      });
    }
  });

  group('SCR-14 from the pair sheet', () {
    late FakeTransport transport;
    late FakeAlertApi api;

    Future<void> openSheet(WidgetTester tester) async {
      transport = FakeTransport();
      api = FakeAlertApi();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...baseOverrides(
              store: MemoryTokenStore(storedFor('saved')),
              tokens: FakeAuthTokenApi(),
              transport: transport,
              alerts: api,
            ),
            pairActionsProvider.overrideWithValue(
              (_, pair) => Wrap(
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
                  run: openAlertSheetFor,
                ),
              ],
            ),
          ],
          retry: (_, _) => null,
          child: MaterialApp(
            theme: appTheme(Brightness.light),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const MarketsScreen(watchlist: WatchlistView()),
          ),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump();
      }
      transport.last.onConnected();
      transport.last.push('/topic/overview.SPOT', {
        'market': 'SPOT',
        'serverTime': '2026-11-06T01:48:10Z',
        'tickers': [
          {
            'market': 'SPOT',
            'symbol': 'BTCUSDT',
            'lastPrice': '76166.01',
            'changePercent24h': '-5.66',
          },
        ],
      });
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byKey(const Key('row-spot-BTCUSDT')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byKey(const Key('create-alert')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    Future<void> save(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('alert-save')));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 31));
    }

    testWidgets('a price alert from the live price, saved with MSG14', (
      tester,
    ) async {
      await openSheet(tester);
      expect(find.text('Create alert · BTCUSDT'), findsOneWidget);
      expect(find.text('Last 76,166.01'), findsOneWidget);
      // Opened from Spot, yet the Futures board says BTC is listed there too.
      final market = tester.widget<SegmentedButton<Market>>(
        find.byKey(const Key('alert-market')),
      );
      expect(
        market.segments.firstWhere((s) => s.value == Market.futures).enabled,
        isTrue,
      );

      await tester.tap(find.byKey(const Key('alert-step-5')));
      await tester.pump();
      expect(find.widgetWithText(TextField, '79974.31'), findsOneWidget);
      await save(tester);

      final (pairId, rule) = api.created.single;
      expect(pairId, 'pair-BTC');
      expect(rule.market, Market.spot);
      expect(rule.type, AlertType.price);
      expect(rule.threshold, '79974.31');
      expect(rule.triggerMode, TriggerMode.once);
      expect(find.text('Saved successfully.'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('the watchlist row menu opens the same sheet', (tester) async {
      await openSheet(tester);
      // Back to the list, then to the Watchlist segment.
      await tester.tapAt(const Offset(20, 20));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tapAt(const Offset(20, 20));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Watchlist'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      for (var i = 0; i < 6; i++) {
        await tester.pump();
      }
      await tester.tap(find.byKey(const Key('watch-menu-BTCUSDT')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Create alert').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Create alert · BTCUSDT'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('an empty target stays in the form with MSG01', (tester) async {
      await openSheet(tester);
      await save(tester);
      expect(find.text('The Target price field is required.'), findsOneWidget);
      expect(api.created, isEmpty);
      await unmount(tester);
    });

    testWidgets('a server field error shows under its field', (tester) async {
      await openSheet(tester);
      api.createError = problem(
        400,
        'VALIDATION_FAILED',
        'MSG01',
        fields: {'threshold': 'MSG15'},
      );
      await tester.enterText(find.byKey(const Key('alert-threshold')), '0.001');
      await save(tester);
      expect(find.text('Target price must be greater than 0.'), findsOneWidget);
      expect(find.byKey(const Key('alert-error')), findsNothing);
      await unmount(tester);
    });

    testWidgets('a feature outside the plan opens MSG29 with the web plans', (
      tester,
    ) async {
      await openSheet(tester);
      api.createError = problem(
        403,
        'PLAN_FEATURE_NOT_INCLUDED',
        'MSG29',
        args: ['PRO'],
      );
      await tester.tap(find.text('Indicator'));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('alert-threshold')), '70');
      await save(tester);
      expect(
        find.text(
          'This feature is available on the PRO plan or higher. View plans?',
        ),
        findsWidgets,
      );
      expect(find.byKey(const Key('upgrade-open-web')), findsOneWidget);
      await tester.tap(find.byKey(const Key('upgrade-open-web')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await unmount(tester);
    });

    testWidgets('the active alert limit MSG27 stays in the sheet', (
      tester,
    ) async {
      await openSheet(tester);
      api.createError = problem(
        409,
        'PLAN_LIMIT_REACHED',
        'MSG27',
        args: ['3', 'active alerts', 'FREE'],
      );
      await tester.enterText(find.byKey(const Key('alert-threshold')), '70000');
      await save(tester);
      expect(
        find.text(
          'You have reached the limit of 3 active alerts of the FREE plan. Upgrade to increase the limit?',
        ),
        findsOneWidget,
      );
      expect(find.text('Create alert · BTCUSDT'), findsOneWidget);
      await unmount(tester);
    });
  });
}
