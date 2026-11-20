import 'dart:async';

import 'package:cryptopilot_mobile/app.dart';
import 'package:cryptopilot_mobile/core/auth/token_store.dart';
import 'package:cryptopilot_mobile/core/router/app_router.dart';
import 'package:cryptopilot_mobile/core/settings/settings.dart';
import 'package:cryptopilot_mobile/features/market/data/market_repository.dart';
import 'package:cryptopilot_mobile/features/market/domain/market.dart';
import 'package:cryptopilot_mobile/features/paper/application/spot_form_controller.dart';
import 'package:cryptopilot_mobile/features/paper/data/paper_repository.dart';
import 'package:cryptopilot_mobile/features/paper/domain/paper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/paper_fakes.dart';
import '../support/realtime_fakes.dart';

/// T-123: the second-version Spot orders (plan 9.4): time in force,
/// post-only, trailing stops and OTO.
void main() {
  late FakeTransport transport;
  late FakePaperApi api;
  late ProviderContainer container;
  final form = spotFormProvider('BTCUSDT');

  Future<SpotFormController> pump(WidgetTester tester) async {
    transport = FakeTransport();
    await tester.pumpWidget(
      ProviderScope(
        overrides: baseOverrides(
          store: MemoryTokenStore(storedFor('saved')),
          tokens: FakeAuthTokenApi(),
          transport: transport,
          paper: api,
        ),
        retry: (_, _) => null,
        child: Consumer(
          builder: (context, ref, _) {
            ref
              ..watch(form)
              ..watch(marketRepositoryProvider(Market.spot))
              ..watch(openOrdersProvider);
            return const SizedBox();
          },
        ),
      ),
    );
    container = ProviderScope.containerOf(
      tester.element(find.byType(Consumer)),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump();
    }
    transport.last.onConnected();
    transport.last.push('/topic/overview.SPOT', {
      'market': 'SPOT',
      'serverTime': '2026-11-19T02:00:00Z',
      'tickers': [
        {
          'market': 'SPOT',
          'symbol': 'BTCUSDT',
          'sourceTime': '2026-11-19T02:00:00Z',
          'lastPrice': '76000.00',
          'changePercent24h': '1',
          'quoteVolume24h': '1',
          'markPrice': null,
        },
      ],
    });
    await tester.pump();
    return container.read(form.notifier);
  }

  SpotFormState state() => container.read(form);

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 31));
  }

  setUp(() => api = FakePaperApi());

  testWidgets('a Limit goes IOC when chosen; post-only is LIMIT_MAKER '
      'without a time in force', (tester) async {
    final c = await pump(tester);
    c
      ..setTimeInForce(SpotTimeInForce.ioc)
      ..edit(SpotField.price, '75000.00')
      ..edit(SpotField.amount, '0.01');
    expect(await c.submit(), isTrue);
    expect(api.placed.last.toJson()['timeInForce'], 'IOC');

    c
      ..selectKind(SpotKind.postOnly)
      ..edit(SpotField.price, '75000.00')
      ..edit(SpotField.amount, '0.01');
    expect(await c.submit(), isTrue);
    final json = api.placed.last.toJson();
    expect(json['type'], 'LIMIT_MAKER');
    expect(json.containsKey('timeInForce'), isFalse);
    await unmount(tester);
  });

  testWidgets('a trailing stop sends its percent as basis points; more than '
      'two decimals is refused on the phone; empty, none is sent', (
    tester,
  ) async {
    final c = await pump(tester);
    c
      ..selectSide(OrderSide.sell)
      ..selectKind(SpotKind.stopMarket)
      ..edit(SpotField.stop, '74000.00')
      ..edit(SpotField.amount, '0.01')
      ..edit(SpotField.trailing, '1.234');
    expect(await c.submit(), isFalse);
    expect(state().errors[SpotField.trailing]?.issue, InputIssue.offStep);

    c.edit(SpotField.trailing, '1.5');
    expect(await c.submit(), isTrue);
    expect(api.placed.last.toJson()['trailingDelta'], 150);

    // After an order only the price stays: the stop is typed again.
    c
      ..edit(SpotField.stop, '74000.00')
      ..edit(SpotField.amount, '0.01')
      ..edit(SpotField.trailing, '');
    expect(await c.submit(), isTrue);
    expect(api.placed.last.toJson().containsKey('trailingDelta'), isFalse);
    await unmount(tester);
  });

  testWidgets('OTO: a Limit Buy now, a Limit Sell of the same amount at its '
      'own price once it filled, one key for both', (tester) async {
    final c = await pump(tester);
    c.selectKind(SpotKind.oto);
    expect(await c.submit(), isFalse);
    expect(state().errors.keys, contains(SpotField.pendingPrice));
    c
      ..edit(SpotField.price, '75000.00')
      ..edit(SpotField.amount, '0.01')
      ..edit(SpotField.pendingPrice, '78000.00');
    expect(await c.submit(), isTrue);
    final json = api.placedOtos.single.toJson();
    expect(json['type'], 'OTO');
    expect(json['working'], {
      'side': 'BUY',
      'type': 'LIMIT',
      'price': '75000.00',
      'quantity': '0.01',
    });
    expect(json['pending'], {
      'side': 'SELL',
      'type': 'LIMIT',
      'price': '78000.00',
      'quantity': '0.01',
    });
    expect(json['listClientOrderId'], hasLength(36));
    await unmount(tester);
  });

  for (final brightness in Brightness.values) {
    testWidgets('360 dp, ${brightness.name}: the time in force beside the '
        'kind; OTO and a trailing stop fit', (tester) async {
      tester.view
        ..physicalSize = const Size(360 * 3, 760 * 3)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      transport = FakeTransport();
      await tester.pumpWidget(
        ProviderScope(
          overrides: baseOverrides(
            store: MemoryTokenStore(storedFor('saved')),
            tokens: FakeAuthTokenApi(),
            transport: transport,
            paper: api,
            settings: MemorySettingsStore(),
          ),
          retry: (_, _) => null,
          child: const CryptoPilotApp(),
        ),
      );
      Future<void> frames() async {
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
      }

      await frames();
      transport.last.onConnected();
      final c = ProviderScope.containerOf(
        tester.element(find.byType(CryptoPilotApp)),
      );
      if (brightness == Brightness.dark) {
        unawaited(c.read(themeModeProvider.notifier).select(ThemeMode.dark));
      }
      c.read(appRouterProvider).go('/trade');
      await frames();
      expect(find.byKey(const Key('trade-tif')), findsOneWidget);
      expect(find.text('GTC'), findsOneWidget);
      expect(tester.takeException(), isNull);
      c.read(form.notifier).selectKind(SpotKind.oto);
      await frames();
      expect(find.byKey(const Key('trade-tif')), findsNothing);
      expect(find.byKey(const Key('trade-field-pendingPrice')), findsOneWidget);
      expect(tester.takeException(), isNull);
      c.read(form.notifier).selectKind(SpotKind.stopLimit);
      await frames();
      expect(find.byKey(const Key('trade-field-trailing')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 31));
    });
  }
}
