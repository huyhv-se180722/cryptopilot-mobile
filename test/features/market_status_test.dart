import 'dart:async';

import 'package:cryptopilot_mobile/app.dart';
import 'package:cryptopilot_mobile/core/auth/token_store.dart';
import 'package:cryptopilot_mobile/core/errors/message_text.dart';
import 'package:cryptopilot_mobile/core/i18n/app_localizations_en.dart';
import 'package:cryptopilot_mobile/core/router/app_router.dart';
import 'package:cryptopilot_mobile/features/market/data/market_status_repository.dart';
import 'package:cryptopilot_mobile/features/market/domain/market.dart';
import 'package:cryptopilot_mobile/features/market/domain/market_health.dart';
import 'package:cryptopilot_mobile/features/market/presentation/market_status_banner.dart';
import 'package:cryptopilot_mobile/features/plans/data/plan_detail_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/paper_fakes.dart';
import '../support/plans_fakes.dart';
import '../support/realtime_fakes.dart';

/// `MarketHealthResponse` as backend develop e02a7c3b writes it.
Map<String, Object?> healthJson(
  String market, {
  String state = 'LIVE',
  bool tradingOpen = true,
  String? since,
  String? reason,
  String? message,
  String? incidentId,
  String? resumedAt,
  List<String> pausedPairs = const [],
  String? expectedEndAt,
  Map<String, Object?>? recovery,
  String displaySource = 'BINANCE',
  bool dataLost = false,
}) => {
  'market': market,
  'state': state,
  'tradingOpen': tradingOpen,
  'since': since,
  'pausedAt': since,
  'reason': reason,
  'message': message,
  'incidentId': incidentId,
  'resumedAt': resumedAt,
  'pausedPairs': pausedPairs,
  'expectedEndAt': expectedEndAt,
  'retryAt': null,
  'recovery': recovery,
  'displaySource': displaySource,
  'dataLost': dataLost,
};

Map<String, Object?> statusJson({
  Map<String, Object?>? spot,
  Map<String, Object?>? futures,
}) => {
  'markets': [spot ?? healthJson('SPOT'), futures ?? healthJson('FUTURES')],
};

final spotPaused = healthJson(
  'SPOT',
  state: 'PAUSED',
  tradingOpen: false,
  since: '2026-11-26T02:00:00Z',
  reason: 'STREAM_LOST',
  incidentId: 'inc-1',
  displaySource: 'OKX',
  dataLost: true,
);

final l = AppLocalizationsEn();

void main() {
  group('decoders (MarketStatusResponse, FallbackPricesResponse)', () {
    test('a paused market with its incident', () {
      final status = decodeMarketStatus(statusJson(spot: spotPaused));
      final spot = status.of(Market.spot);
      expect(spot.state, MarketHealthState.paused);
      expect(spot.tradingOpen, isFalse);
      expect(spot.reason, IncidentReason.streamLost);
      expect(spot.since, DateTime.utc(2026, 11, 26, 2));
      expect(spot.displaySource, DisplaySource.okx);
      expect(spot.dataLost, isTrue);
      expect(spot.noteworthy, isTrue);
      expect(status.of(Market.futures).noteworthy, isFalse);
    });

    test('recovery progress, paused pairs and an unknown state', () {
      final health = decodeMarketHealth(
        healthJson(
          'FUTURES',
          state: 'SOMETHING_NEW',
          pausedPairs: ['ethusdt'],
          recovery: {'pairsDone': 3, 'pairsTotal': 9},
        ),
      );
      expect(health.state, MarketHealthState.unknown);
      // What may be done is the server's flag, not the state.
      expect(health.tradingOpen, isTrue);
      expect(health.pausedPairs, ['ETHUSDT']);
      expect(health.pairsDone, 3);
      expect(health.pairsTotal, 9);
      expect(health.canTrade('BTCUSDT'), isTrue);
      expect(health.canTrade('ethusdt'), isFalse);
    });

    test('reference prices by symbol; a pair without a last price is left '
        'out', () {
      final prices = decodeFallbackPrices({
        'market': 'SPOT',
        'source': 'OKX',
        'asOf': '2026-11-26T02:05:00Z',
        'prices': [
          {
            'symbol': 'BTCUSDT',
            'lastPrice': '75900.10',
            'changePercent24h': '-1.2',
            'high24h': null,
            'low24h': null,
            'volume24h': null,
            'asOf': '2026-11-26T02:05:00Z',
            'diverged': true,
          },
          {'symbol': 'XYZUSDT', 'lastPrice': null, 'diverged': false},
        ],
      });
      expect(prices.source, DisplaySource.okx);
      expect(prices.prices.keys, ['BTCUSDT']);
      expect(prices.prices['BTCUSDT']!.lastPrice, '75900.10');
      expect(prices.prices['BTCUSDT']!.diverged, isTrue);
    });
  });

  test('the trading block: the market closed, then only one pair', () {
    final closed = decodeMarketHealth(spotPaused);
    expect(
      tradingBlockText(l, closed, 'BTCUSDT'),
      'Spot trading is paused: orders cannot be placed, changed or cancelled '
      'now.',
    );
    final pair = decodeMarketHealth(
      healthJson('FUTURES', pausedPairs: ['ETHUSDT']),
    );
    expect(
      tradingBlockText(l, pair, 'ethusdt'),
      'Data for ETHUSDT is unavailable: trading this pair is paused.',
    );
    expect(tradingBlockText(l, pair, 'BTCUSDT'), isNull);
    expect(tradingBlockText(l, pair, null), isNull);
  });

  test('MSG57 has its own words, no longer MSG43', () {
    expect(
      failureText(l, problem(503, 'TRADING_PAUSED', 'MSG57')),
      'Trading on this market is paused while exchange data is unavailable. '
      'Please try again once it reopens.',
    );
  });

  group('the Trade tab while Spot is paused (T-146)', () {
    late FakeTransport transport;
    late FakeMarketStatusApi status;
    late FakePaperApi paper;

    Future<void> frames(WidgetTester tester) async {
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    Future<void> open(WidgetTester tester, String location) async {
      transport = FakeTransport();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...baseOverrides(
              store: MemoryTokenStore(storedFor('saved')),
              tokens: FakeAuthTokenApi(),
              transport: transport,
              paper: paper,
              marketStatus: status,
            ),
            planDetailApiProvider.overrideWithValue(FakePlanDetailApi()),
          ],
          retry: (_, _) => null,
          child: const CryptoPilotApp(),
        ),
      );
      await frames(tester);
      transport.last.onConnected();
      final router = ProviderScope.containerOf(
        tester.element(find.byType(CryptoPilotApp)),
      ).read(appRouterProvider);
      if (location == '/trade') {
        router.go(location);
      } else {
        unawaited(router.push(location));
      }
      await frames(tester);
    }

    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 31));
    }

    setUp(() {
      status = FakeMarketStatusApi();
      paper = FakePaperApi();
    });

    testWidgets('the banner, the locked form, the paused book and the OKX '
        'reference price', (tester) async {
      status
        ..current = decodeMarketStatus(statusJson(spot: spotPaused))
        ..prices[Market.spot] = decodeFallbackPrices({
          'market': 'SPOT',
          'source': 'OKX',
          'asOf': '2026-11-26T02:05:00Z',
          'prices': [
            {
              'symbol': 'BTCUSDT',
              'lastPrice': '75900.10',
              'asOf': '2026-11-26T02:05:00Z',
              'diverged': false,
            },
          ],
        });
      await open(tester, '/trade');

      expect(find.byKey(const Key('market-status-SPOT')), findsOneWidget);
      expect(find.textContaining('Spot trading is paused'), findsWidgets);
      expect(
        find.textContaining('The exchange stream sends nothing.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('trading-block')), findsOneWidget);
      final submit = tester.widget<FilledButton>(
        find.byKey(const Key('trade-submit')),
      );
      expect(submit.onPressed, isNull);
      expect(find.byKey(const Key('book-paused')), findsOneWidget);
      expect(find.text('Reference price 75,900.10'), findsOneWidget);
      expect(status.calls, contains('fallback SPOT'));
      await unmount(tester);
    });

    testWidgets('360 dp: the paused banner, the block and the reference '
        'price fit on Spot and Futures', (tester) async {
      tester.view
        ..physicalSize = const Size(360 * 3, 760 * 3)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      status.current = decodeMarketStatus(
        statusJson(
          spot: spotPaused,
          futures: healthJson(
            'FUTURES',
            state: 'PAUSED',
            tradingOpen: false,
            since: '2026-11-25T23:00:00Z',
            reason: 'IP_BANNED',
            incidentId: 'inc-9',
            displaySource: 'NONE',
            dataLost: true,
          ),
        ),
      );
      await open(tester, '/trade');
      expect(tester.takeException(), isNull);
      expect(find.text('No reference price for this pair.'), findsOneWidget);
      await tester.tap(find.text('Futures').first);
      await frames(tester);
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('market-status-FUTURES')), findsOneWidget);
      expect(
        find.textContaining('No reference price is available.'),
        findsOneWidget,
      );
      await unmount(tester);
    });

    testWidgets('pushes of /topic/market.status: paused, then reopened '
        'until dismissed', (tester) async {
      await open(tester, '/trade');
      expect(find.byKey(const Key('market-status-SPOT')), findsNothing);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('trade-submit')))
            .onPressed,
        isNotNull,
      );

      transport.last.push(marketStatusTopic, statusJson(spot: spotPaused));
      await frames(tester);
      expect(find.byKey(const Key('market-status-SPOT')), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('trade-submit')))
            .onPressed,
        isNull,
      );

      transport.last.push(
        marketStatusTopic,
        statusJson(
          spot: healthJson(
            'SPOT',
            since: '2026-11-26T02:00:00Z',
            incidentId: 'inc-1',
            resumedAt: '2026-11-26T02:20:00Z',
          ),
        ),
      );
      await frames(tester);
      expect(find.textContaining('Spot trading has reopened'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('trade-submit')))
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.byKey(const Key('market-status-dismiss-SPOT')));
      await frames(tester);
      expect(find.byKey(const Key('market-status-SPOT')), findsNothing);
      await unmount(tester);
    });

    testWidgets('the status is read again every 15 s without pushes', (
      tester,
    ) async {
      await open(tester, '/trade');
      final first = status.calls.where((c) => c == 'status').length;
      expect(first, greaterThanOrEqualTo(1));
      status.current = decodeMarketStatus(
        statusJson(
          spot: healthJson(
            'SPOT',
            state: 'MAINTENANCE',
            tradingOpen: false,
            reason: 'MAINTENANCE',
            message: 'Upgrade until 03:00 UTC.',
            incidentId: 'inc-2',
          ),
        ),
      );
      await tester.pump(marketStatusPollEvery);
      await frames(tester);
      expect(
        status.calls.where((c) => c == 'status').length,
        greaterThan(first),
      );
      expect(find.textContaining('Spot is under maintenance'), findsOneWidget);
      expect(find.textContaining('Upgrade until 03:00 UTC.'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('SCR-18: a draft of a closed market is not activated, still '
        'cancelled', (tester) async {
      // planDetailOf drafts are Futures plans.
      status.current = decodeMarketStatus(
        statusJson(
          futures: healthJson(
            'FUTURES',
            state: 'RECOVERING',
            tradingOpen: false,
            incidentId: 'inc-3',
            recovery: {'pairsDone': 2, 'pairsTotal': 5},
            dataLost: true,
          ),
        ),
      );
      await open(tester, '/plan/d1');
      expect(find.byKey(const Key('market-status-FUTURES')), findsOneWidget);
      expect(find.textContaining('2 of 5 pairs caught up'), findsOneWidget);
      expect(find.byKey(const Key('plan-trading-block')), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('plan-activate')))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('plan-cancel')))
            .onPressed,
        isNotNull,
      );
      await unmount(tester);
    });
  });
}
