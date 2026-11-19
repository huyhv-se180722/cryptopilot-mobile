import 'dart:async';

import 'package:cryptopilot_mobile/app.dart';
import 'package:cryptopilot_mobile/core/auth/token_store.dart';
import 'package:cryptopilot_mobile/core/router/app_router.dart';
import 'package:cryptopilot_mobile/core/settings/settings.dart';
import 'package:cryptopilot_mobile/features/paper/domain/paper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/paper_fakes.dart';
import '../support/realtime_fakes.dart';

void main() {
  late FakeTransport transport;
  late FakePaperApi paper;
  late MemorySettingsStore settings;

  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(CryptoPilotApp)));

  Future<void> open(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
  }) async {
    transport = FakeTransport();
    await tester.pumpWidget(
      ProviderScope(
        overrides: baseOverrides(
          store: MemoryTokenStore(storedFor('saved')),
          tokens: FakeAuthTokenApi(),
          transport: transport,
          paper: paper,
          settings: settings,
        ),
        retry: (_, _) => null,
        child: const CryptoPilotApp(),
      ),
    );
    await frames(tester);
    transport.last.onConnected();
    final container = containerOf(tester);
    if (brightness == Brightness.dark) {
      unawaited(
        container.read(themeModeProvider.notifier).select(ThemeMode.dark),
      );
    }
    container.read(appRouterProvider).go('/trade');
    await frames(tester);
    transport.last.push('/topic/overview.SPOT', {
      'market': 'SPOT',
      'serverTime': '2026-11-19T02:00:00Z',
      'tickers': [
        {
          'market': 'SPOT',
          'symbol': 'BTCUSDT',
          'sourceTime': '2026-11-19T02:00:00Z',
          'lastPrice': '76000.00',
          'changePercent24h': '1.5',
          'quoteVolume24h': '1',
          'markPrice': null,
        },
      ],
    });
    await frames(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 31));
  }

  Finder scrollable() => find
      .descendant(
        of: find.byKey(const Key('trade-spot')),
        matching: find.byType(Scrollable),
      )
      .first;

  setUp(() {
    paper = FakePaperApi();
    settings = MemorySettingsStore();
  });

  testWidgets('the demo banner, the pair, the book and the funds; the demo '
      'account is opened on first entry', (tester) async {
    await open(tester);
    expect(find.byKey(const Key('paper-demo-banner')), findsOneWidget);
    expect(find.text('BTC/USDT'), findsOneWidget);
    expect(find.byKey(const Key('trade-book')), findsOneWidget);
    expect(find.text('Avbl 10,000.00 USDT'), findsOneWidget);
    // Home reads the demo worth first (never opening the account); entering
    // Trade opens it, then reads the wallet.
    expect(
      paper.calls.indexOf('open'),
      lessThan(paper.calls.indexOf('wallet SPOT')),
    );
    expect(paper.calls.first, 'equity');
    await unmount(tester);
  });

  testWidgets('a Limit Buy: a level fills the price, the sheet confirms, the '
      'order is listed and can be cancelled', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('book-76000')).first);
    await tester.pump();
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: find.byKey(const Key('trade-field-price')),
              matching: find.byType(TextField),
            ),
          )
          .controller!
          .text,
      '76000',
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('trade-field-amount')),
        matching: find.byType(TextField),
      ),
      '0.01',
    );
    await tester.tap(find.byKey(const Key('trade-submit')));
    await frames(tester);
    expect(find.byKey(const Key('trade-confirm-sheet')), findsOneWidget);
    await tester.tap(find.byKey(const Key('trade-confirm')));
    await frames(tester);
    expect(paper.placed.single.type, SpotOrderType.limit);
    expect(find.text('Demo order placed.'), findsOneWidget);

    ScaffoldMessenger.of(
      tester.element(find.byKey(const Key('trade-spot'))),
    ).removeCurrentSnackBar();
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const Key('open-order-o-1')),
      200,
      scrollable: scrollable(),
    );
    await tester.tap(find.byKey(const Key('cancel-o-1')));
    await frames(tester);
    expect(paper.calls, contains('cancel o-1'));
    expect(find.byKey(const Key('open-order-o-1')), findsNothing);
    await unmount(tester);
  });

  testWidgets('with confirmation off the order goes at once; a refusal is '
      'told under its field', (tester) async {
    settings.values['paper.confirmOrders'] = 'false';
    paper.placeError = problem(
      400,
      'PAPER_PRICE_FILTER',
      'MSG15',
      args: ['price', '90000.00', '80000', 'MAX'],
    );
    await open(tester);
    for (final (field, value) in [('price', '90000.00'), ('amount', '0.01')]) {
      await tester.enterText(
        find.descendant(
          of: find.byKey(Key('trade-field-$field')),
          matching: find.byType(TextField),
        ),
        value,
      );
    }
    await tester.tap(find.byKey(const Key('trade-submit')));
    await frames(tester);
    expect(find.byKey(const Key('trade-confirm-sheet')), findsNothing);
    expect(find.text('Enter at most 80,000.'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('another pair from the sheet; Futures says it comes next', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('trade-pair')));
    await frames(tester);
    await tester.tap(find.byKey(const Key('trade-pick-ETHUSDT')));
    await frames(tester);
    expect(find.text('ETH/USDT'), findsOneWidget);

    await tester.tap(find.text('Futures'));
    await frames(tester);
    expect(find.byKey(const Key('trade-futures-soon')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('leaving the tab stops the book and the trades; coming back '
      'starts them again', (tester) async {
    await open(tester);
    Set<String> topics() => transport.last.subscriptions.keys.toSet();
    expect(topics(), contains('/topic/depth.SPOT.BTCUSDT'));
    containerOf(tester).read(appRouterProvider).go('/home');
    await frames(tester);
    expect(topics(), isNot(contains('/topic/depth.SPOT.BTCUSDT')));
    expect(topics(), isNot(contains('/topic/trades.SPOT.BTCUSDT')));
    containerOf(tester).read(appRouterProvider).go('/trade');
    await frames(tester);
    expect(topics(), contains('/topic/depth.SPOT.BTCUSDT'));
    await unmount(tester);
  });

  testWidgets('each fill pushed is told once, even two alike', (tester) async {
    await open(tester);
    Map<String, Object?> fill(String id) => {
      'fillId': id,
      'orderId': 'o-1',
      'pairId': 'pair-BTC',
      'symbol': 'BTCUSDT',
      'market': 'SPOT',
      'side': 'BUY',
      'price': '76000.00',
      'quantity': '0.01',
      'quoteAmount': '760',
      'fee': '0.76',
      'feeAsset': 'USDT',
      'liquidity': 'TAKER',
      'source': 'LIVE',
      'tradedAt': '2026-11-19T02:00:00Z',
    };
    expect(transport.last.subscriptions.keys, contains('/user/queue/fills'));
    transport.last.push('/user/queue/fills', fill('f-1'));
    await frames(tester);
    expect(
      find.text('Demo fill: Buy 0.01 BTCUSDT at 76,000.00'),
      findsOneWidget,
    );
    ScaffoldMessenger.of(
      tester.element(find.byKey(const Key('trade-spot'))),
    ).removeCurrentSnackBar();
    await frames(tester);
    transport.last.push('/user/queue/fills', fill('f-1'));
    await frames(tester);
    expect(
      find.text('Demo fill: Buy 0.01 BTCUSDT at 76,000.00'),
      findsOneWidget,
    );
    await unmount(tester);
  });

  for (final brightness in Brightness.values) {
    testWidgets('360 dp, ${brightness.name}: the form and the book fit side '
        'by side', (tester) async {
      tester.view
        ..physicalSize = const Size(360 * 3, 760 * 3)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      paper.open = [paperOrderOf('o-9', price: '123456.78')];
      await open(tester, brightness: brightness);
      expect(tester.takeException(), isNull);
      for (final kind in ['OCO', 'Limit TP/SL']) {
        await tester.tap(find.byKey(const Key('trade-kind')));
        await frames(tester);
        await tester.tap(find.text(kind).last);
        await frames(tester);
        expect(tester.takeException(), isNull, reason: kind);
      }
      await tester.drag(scrollable(), const Offset(0, -800));
      await frames(tester);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  }
}
