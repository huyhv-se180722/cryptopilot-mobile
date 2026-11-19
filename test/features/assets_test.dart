import 'dart:async';

import 'package:cryptopilot_mobile/app.dart';
import 'package:cryptopilot_mobile/core/auth/token_store.dart';
import 'package:cryptopilot_mobile/core/errors/api_failure.dart';
import 'package:cryptopilot_mobile/core/router/app_router.dart';
import 'package:cryptopilot_mobile/core/settings/settings.dart';
import 'package:cryptopilot_mobile/features/paper/application/assets_controller.dart';
import 'package:cryptopilot_mobile/features/paper/domain/paper.dart';
import 'package:cryptopilot_mobile/features/paper/presentation/trade_screen.dart';
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
    WidgetTester tester,
    String location, {
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
    container.read(appRouterProvider).go(location);
    await frames(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 31));
  }

  setUp(() {
    paper = FakePaperApi()
      ..spot = const Wallet(
        wallet: PaperWallet.spot,
        balances: [
          Balance(
            asset: 'USDT',
            free: '9000.00000000',
            locked: '1000.00000000',
            total: '10000.00000000',
            usdtValue: '10000.00000000',
          ),
          Balance(
            asset: 'BTC',
            free: '0.10000000',
            locked: '0',
            total: '0.10000000',
            usdtValue: '7600.00000000',
          ),
          Balance(
            asset: 'DUST',
            free: '3',
            locked: '0',
            total: '3',
            usdtValue: '0.30000000',
          ),
          Balance(asset: 'XYZ', free: '1', locked: '0', total: '1'),
        ],
        estimatedUsdt: '17600.30000000',
        complete: false,
      );
    settings = MemorySettingsStore();
  });

  group('Assets', () {
    testWidgets('the demo banner, the total, the Spot coins and the Futures '
        'USDT; a coin without a price is said to be left out', (tester) async {
      await open(tester, '/assets');
      expect(find.byKey(const Key('paper-demo-banner')), findsOneWidget);
      expect(find.text('17,600.30 USDT'), findsWidgets);
      expect(find.byKey(const Key('assets-incomplete')), findsOneWidget);
      for (final coin in ['USDT', 'BTC', 'DUST', 'XYZ']) {
        await tester.scrollUntilVisible(
          find.byKey(Key('coin-$coin')),
          100,
          scrollable: find.byType(Scrollable).last,
        );
      }
      expect(find.textContaining('In orders'), findsWidgets);
      await tester.scrollUntilVisible(
        find.byKey(const Key('futures-usdt')),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('futures-usdt')),
          matching: find.text('5,000.00'),
        ),
        findsOneWidget,
      );
      await unmount(tester);
    });

    testWidgets('the eye masks every amount and is remembered; small coins '
        'can be hidden, an unvalued one stays', (tester) async {
      await open(tester, '/assets');
      await tester.tap(find.byKey(const Key('assets-eye')));
      await frames(tester);
      expect(find.text('17,600.30 USDT'), findsNothing);
      expect(settings.values[AssetsController.hideBalancesKey], 'true');

      await tester.tap(find.byKey(const Key('assets-hide-small')));
      await frames(tester);
      expect(find.byKey(const Key('coin-DUST')), findsNothing);
      await tester.scrollUntilVisible(
        find.byKey(const Key('coin-XYZ')),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      expect(settings.values[AssetsController.hideSmallKey], 'true');
      await unmount(tester);
    });

    testWidgets('Trade (demo) on a coin opens the Trade tab on its pair', (
      tester,
    ) async {
      await open(tester, '/assets');
      await tester.tap(find.byKey(const Key('trade-BTC')));
      await frames(tester);
      expect(find.byType(TradeScreen), findsOneWidget);
      expect(find.text('BTC/USDT'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('Transfer', () {
    Future<void> openSheet(WidgetTester tester) async {
      await open(tester, '/assets');
      await tester.tap(find.byKey(const Key('assets-transfer')));
      await frames(tester);
    }

    testWidgets('more than the Spot wallet holds free is refused; a valid '
        'amount moves and the wallets are read again', (tester) async {
      await openSheet(tester);
      await tester.enterText(find.byKey(const Key('transfer-amount')), '9500');
      await tester.tap(find.byKey(const Key('transfer-send')));
      await frames(tester);
      expect(find.text('More than the wallet holds.'), findsOneWidget);
      expect(paper.transferKeys, isEmpty);

      await tester.enterText(find.byKey(const Key('transfer-amount')), '100');
      await tester.tap(find.byKey(const Key('transfer-send')));
      await frames(tester);
      expect(paper.calls, contains('transfer SPOT 100'));
      expect(find.byKey(const Key('transfer-sheet')), findsNothing);
      expect(find.text('Transferred.'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('Futures to Spot after a swap; a network failure keeps the '
        'key for the retry', (tester) async {
      await openSheet(tester);
      await tester.tap(find.byKey(const Key('transfer-swap')));
      await frames(tester);
      expect(find.textContaining('From Futures wallet'), findsOneWidget);
      paper.transferError = const NetworkFailure(timeout: true);
      await tester.enterText(find.byKey(const Key('transfer-amount')), '50');
      await tester.tap(find.byKey(const Key('transfer-send')));
      await frames(tester);
      expect(find.byKey(const Key('transfer-sheet')), findsOneWidget);
      paper.transferError = null;
      await tester.tap(find.byKey(const Key('transfer-send')));
      await frames(tester);
      expect(paper.calls, contains('transfer FUTURES 50'));
      expect(paper.transferKeys, hasLength(2));
      expect(paper.transferKeys[0], paper.transferKeys[1]);
      await unmount(tester);
    });
  });

  group('History', () {
    testWidgets('orders with a period and a status; the ledger by type; '
        'transfers have no range', (tester) async {
      paper
        ..history = [paperOrderOf('h-1', status: OrderStatus.filled)]
        ..ledgerEntries = [
          LedgerEntry(
            entryId: 'e-1',
            wallet: PaperWallet.spot,
            asset: 'USDT',
            type: LedgerType.fee,
            amount: '-0.76',
            balanceAfter: '9999.24',
            createdAt: DateTime.utc(2026, 11, 19, 3),
          ),
        ];
      await open(tester, '/assets');
      await tester.tap(find.byKey(const Key('assets-history')));
      await frames(tester);
      expect(find.byKey(const Key('history-order-h-1')), findsOneWidget);
      await tester.tap(find.byKey(const Key('period-orders-week')));
      await frames(tester);
      expect(paper.calls.where((c) => c == 'orders page=1'), hasLength(2));

      await tester.tap(find.text('Ledger'));
      await frames(tester);
      expect(find.byKey(const Key('history-ledger-e-1')), findsOneWidget);
      expect(find.text('-0.76 USDT'), findsOneWidget);
      await tester.tap(find.byKey(const Key('history-type')));
      await frames(tester);
      await tester.tap(find.text('TRANSFER').last);
      await frames(tester);
      expect(paper.calls.last, 'ledger page=1 type=TRANSFER');
      expect(find.byKey(const Key('history-empty-ledger')), findsOneWidget);

      await tester.tap(find.text('Transfers'));
      await frames(tester);
      expect(find.byKey(const Key('period-transfers-all')), findsNothing);
      await unmount(tester);
    });
  });

  test('shown coins: held ones, USDT first then by value; under 1 USDT left '
      'out when asked, an unvalued coin kept', () {
    final wallet = FakePaperApi().spot;
    final rich = Wallet(
      wallet: PaperWallet.spot,
      balances: [
        ...wallet.balances,
        const Balance(
          asset: 'DUST',
          free: '3',
          locked: '0',
          total: '3',
          usdtValue: '0.3',
        ),
        const Balance(
          asset: 'ETH',
          free: '1',
          locked: '0',
          total: '1',
          usdtValue: '3000',
        ),
        const Balance(
          asset: 'NONE',
          free: '0',
          locked: '0',
          total: '0',
          usdtValue: '0',
        ),
        const Balance(asset: 'XYZ', free: '1', locked: '0', total: '1'),
      ],
      estimatedUsdt: '1',
      complete: false,
    );
    expect(
      [for (final b in shownCoins(rich, hideSmall: false)) b.asset],
      ['USDT', 'ETH', 'DUST', 'BTC', 'XYZ'],
    );
    expect(
      [for (final b in shownCoins(rich, hideSmall: true)) b.asset],
      ['USDT', 'ETH', 'BTC', 'XYZ'],
    );
  });

  for (final brightness in Brightness.values) {
    testWidgets('360 dp, ${brightness.name}: Assets, the transfer sheet and '
        'the history fit', (tester) async {
      tester.view
        ..physicalSize = const Size(360 * 3, 760 * 3)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await open(tester, '/assets', brightness: brightness);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('assets-transfer')));
      await frames(tester);
      expect(tester.takeException(), isNull);
      Navigator.of(
        tester.element(find.byKey(const Key('transfer-sheet'))),
      ).pop();
      await frames(tester);
      unawaited(
        containerOf(tester).read(appRouterProvider).push('/assets/history'),
      );
      await frames(tester);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  }
}
