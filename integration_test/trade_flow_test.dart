// The paper trading flows end to end against a running backend (not part of
// `flutter test`): every order is placed through the screens as a Trader
// does, then the server's own records are read back and the money checked to
// the last decimal.
//
//   flutter test integration_test/trade_flow_test.dart -d emulator-5554 \
//     --dart-define=LOGIN_EMAIL=... --dart-define=LOGIN_PASSWORD=...
//
// The rules checked are the backend's (`origin/develop` `c1803226`): a Spot
// order that takes liquidity walks the book level by level (`BookSweep`), its
// commission is 0.1 % of each fill taken in the coin the fill brings in
// (`PaperOrderProperties`); Futures commission is zero until configured
// (`FuturesCommissionPolicy`), so a position closes for (exit − entry) × size.
// Prices come from the live book, so the checks are the invariants, never a
// guessed price. Each line is printed as `CHECK:` for the report.
import 'dart:async';

import 'package:cryptopilot_mobile/app.dart';
import 'package:cryptopilot_mobile/core/auth/token_store.dart';
import 'package:cryptopilot_mobile/core/router/app_router.dart';
import 'package:cryptopilot_mobile/core/web/web_links.dart';
import 'package:cryptopilot_mobile/features/market/data/market_repository.dart';
import 'package:cryptopilot_mobile/features/market/domain/market.dart';
import 'package:cryptopilot_mobile/features/paper/application/trade_controller.dart';
import 'package:cryptopilot_mobile/features/paper/data/futures_api.dart';
import 'package:cryptopilot_mobile/features/paper/data/paper_api.dart';
import 'package:cryptopilot_mobile/features/paper/domain/paper.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const email = String.fromEnvironment('LOGIN_EMAIL');
const password = String.fromEnvironment('LOGIN_PASSWORD');

class NoBrowser implements WebLinks {
  @override
  Future<bool> open(String path) async => true;

  @override
  Future<bool> openAddress(String address) async => true;
}

Decimal d(String? value) => Decimal.parse((value ?? '0').trim());

Decimal sum(Iterable<Decimal> values) =>
    values.fold(Decimal.zero, (a, b) => a + b);

final spotFee = Decimal.parse('0.001');
final dust = Decimal.parse('0.00000001');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('paper trading: buy, sell, a resting order and a Futures '
      'position, checked against the server', (tester) async {
    expect(email, isNotEmpty, reason: 'pass --dart-define=LOGIN_EMAIL');
    final failures = <String>[];
    void check(String name, bool ok, String detail) {
      // ignore: avoid_print
      print('CHECK:${ok ? 'OK' : 'FAIL'} $name — $detail');
      if (!ok) failures.add('$name — $detail');
    }

    bool near(Decimal a, Decimal b) => (a - b).abs() <= dust;

    await SecureTokenStore().clear();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [webLinksProvider.overrideWithValue(NoBrowser())],
        retry: (_, _) => null,
        child: const CryptoPilotApp(),
      ),
    );

    Future<bool> waitFor(Finder finder, {int seconds = 30}) async {
      for (var i = 0; i < seconds * 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (finder.evaluate().isNotEmpty) return true;
      }
      return false;
    }

    Future<void> settle([int ms = 1500]) async {
      for (var i = 0; i < ms ~/ 100; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    /// Runs [work] while the frames keep coming, so the app's own requests
    /// and pushes go on meanwhile.
    Future<T> io<T>(Future<T> work) async {
      var done = false;
      T? value;
      Object? error;
      unawaited(
        work
            .then((v) => value = v, onError: (Object e) => error = e)
            .whenComplete(() => done = true),
      );
      for (var i = 0; i < 300 && !done; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      if (error != null) throw error!;
      if (!done) throw TimeoutException('server call');
      return value as T;
    }

    Future<void> tapKey(String key) async {
      final f = find.byKey(Key(key));
      expect(await waitFor(f), isTrue, reason: '$key never showed');
      await tester.ensureVisible(f.first);
      await settle(300);
      await tester.tap(f.first);
      await settle(800);
    }

    Future<void> typeInto(String key, String text) async {
      final field = find.descendant(
        of: find.byKey(Key(key)),
        matching: find.byType(TextField),
      );
      expect(await waitFor(field), isTrue, reason: '$key never showed');
      await tester.ensureVisible(field.first);
      await settle(300);
      await tester.enterText(field.first, text);
      await settle(500);
    }

    Future<void> chooseKind(String key, String label) async {
      await tapKey(key);
      await tester.tap(find.text(label).last);
      await settle(800);
    }

    // Sign in.
    await waitFor(find.byKey(const Key('login-submit')));
    await tester.enterText(find.byKey(const Key('login-email')), email);
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('login-password')),
        matching: find.byType(TextField),
      ),
      password,
    );
    await tester.tap(find.byKey(const Key('login-submit')));
    expect(await waitFor(find.byType(NavigationBar)), isTrue);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(CryptoPilotApp)),
    );
    final paper = container.read(paperApiProvider);
    final futures = container.read(futuresApiProvider);
    final router = container.read(appRouterProvider);
    // The confirmation sheet stays on: the flow is the one a Trader sees.
    await container.read(confirmOrdersProvider.notifier).set(true);

    router.go('/trade?market=spot');
    expect(await waitFor(find.byKey(const Key('trade-submit'))), isTrue);
    await settle(3000);

    final spotPairs =
        container.read(marketRepositoryProvider(Market.spot)).pairs ?? [];
    final btc = spotPairs.firstWhere((p) => p.symbol == 'BTCUSDT');
    if (!find
        .descendant(
          of: find.byKey(const Key('trade-pair')),
          matching: find.textContaining('BTC'),
        )
        .evaluate()
        .isNotEmpty) {
      await tapKey('trade-pair');
      await tapKey('trade-pick-BTCUSDT');
    }

    Future<Map<String, Balance>> spotWallet() async {
      final w = await io(paper.wallet(PaperWallet.spot));
      return {for (final b in w.balances) b.asset: b};
    }

    Decimal total(Map<String, Balance> w, String asset) => d(w[asset]?.total);

    Future<Set<String>> orderIds() async {
      final page = await io(paper.orders(pairId: btc.pairId, pageSize: 50));
      return {for (final o in page.items) o.orderId};
    }

    Future<PaperOrder> newOrder(Set<String> before) async {
      for (var i = 0; i < 30; i++) {
        final page = await io(paper.orders(pairId: btc.pairId, pageSize: 50));
        final fresh = page.items.where((o) => !before.contains(o.orderId));
        if (fresh.isNotEmpty) return fresh.first;
        await settle(500);
      }
      throw StateError('the order never reached the server');
    }

    Future<PaperOrder> finalOrder(String id) async {
      PaperOrder? last;
      for (var i = 0; i < 30; i++) {
        final page = await io(paper.orders(pairId: btc.pairId, pageSize: 50));
        last = page.items.firstWhere((o) => o.orderId == id);
        if (last.status == OrderStatus.filled ||
            last.status == OrderStatus.canceled ||
            last.status == OrderStatus.expired) {
          return last;
        }
        await settle(500);
      }
      return last!;
    }

    Future<List<PaperFill>> fillsOf(String orderId) async {
      final page = await io(paper.fills(pairId: btc.pairId, pageSize: 100));
      return page.items.where((f) => f.orderId == orderId).toList();
    }

    Future<Set<String>> fillIds() async {
      final page = await io(paper.fills(pageSize: 100));
      return {for (final f in page.items) f.fillId};
    }

    /// Fills of other orders in the window would move the same balances;
    /// they make a balance check void, not failed.
    Future<bool> othersFilled(Set<String> before, Set<String> ours) async {
      final page = await io(paper.fills(pageSize: 100));
      return page.items.any(
        (f) => !before.contains(f.fillId) && !ours.contains(f.orderId),
      );
    }

    // ---- 1. Spot MARKET BUY 0.001 BTC --------------------------------------
    {
      const qty = '0.001';
      final w0 = await spotWallet();
      final ids = await orderIds();
      final fills0 = await fillIds();
      await chooseKind('trade-kind', 'Market');
      await tapKey('trade-side-BUY');
      await typeInto('trade-field-amount', qty);
      await tapKey('trade-submit');
      await tapKey('trade-confirm');
      final order = await finalOrder((await newOrder(ids)).orderId);
      final fills = await fillsOf(order.orderId);
      final w1 = await spotWallet();
      final filledQty = sum(fills.map((f) => d(f.quantity)));
      final quote = sum(fills.map((f) => d(f.quoteAmount)));
      final fees = sum(fills.map((f) => d(f.fee)));
      check(
        'spot buy filled',
        order.status == OrderStatus.filled,
        'status ${order.status.name}, ${fills.length} fill(s)',
      );
      check(
        'spot buy quantity',
        filledQty == d(qty) && d(order.executedQuantity) == d(qty),
        'fills $filledQty, order ${order.executedQuantity}, asked $qty',
      );
      check(
        'spot buy each fill = price × qty',
        fills.every((f) => near(d(f.price) * d(f.quantity), d(f.quoteAmount))),
        [
          for (final f in fills) '${f.price}×${f.quantity}=${f.quoteAmount}',
        ].join('; '),
      );
      final vwap = (quote / filledQty).toDecimal(scaleOnInfinitePrecision: 8);
      check(
        'spot buy average = VWAP',
        near(d(order.avgPrice).round(scale: 8), vwap.round(scale: 8)) ||
            (d(order.avgPrice) - vwap).abs() < Decimal.parse('0.01'),
        'avg ${order.avgPrice}, VWAP $vwap',
      );
      check(
        'spot buy fee 0.1 % in BTC',
        fills.every(
          (f) =>
              f.feeAsset == 'BTC' &&
              (d(f.fee) - d(f.quantity) * spotFee).abs() <= dust,
        ),
        [for (final f in fills) '${f.fee} ${f.feeAsset}'].join('; '),
      );
      if (await othersFilled(fills0, {order.orderId})) {
        check('spot buy balances', true, 'skipped: another order filled');
      } else {
        final dUsdt = total(w1, 'USDT') - total(w0, 'USDT');
        final dBtc = total(w1, 'BTC') - total(w0, 'BTC');
        check(
          'spot buy USDT − cost',
          dUsdt == -quote,
          'ΔUSDT $dUsdt, cost $quote',
        );
        check(
          'spot buy BTC + qty − fee',
          dBtc == filledQty - fees,
          'ΔBTC $dBtc, expected ${filledQty - fees}',
        );
      }
    }

    // ---- 2. Spot MARKET SELL 0.0005 BTC ------------------------------------
    {
      const qty = '0.0005';
      final w0 = await spotWallet();
      final ids = await orderIds();
      final fills0 = await fillIds();
      await tapKey('trade-side-SELL');
      await typeInto('trade-field-amount', qty);
      await tapKey('trade-submit');
      await tapKey('trade-confirm');
      final order = await finalOrder((await newOrder(ids)).orderId);
      final fills = await fillsOf(order.orderId);
      final w1 = await spotWallet();
      final filledQty = sum(fills.map((f) => d(f.quantity)));
      final quote = sum(fills.map((f) => d(f.quoteAmount)));
      final fees = sum(fills.map((f) => d(f.fee)));
      check(
        'spot sell filled',
        order.status == OrderStatus.filled && filledQty == d(qty),
        'status ${order.status.name}, qty $filledQty',
      );
      check(
        'spot sell fee 0.1 % in USDT',
        fills.every(
          (f) =>
              f.feeAsset == 'USDT' &&
              (d(f.fee) - d(f.quoteAmount) * spotFee).abs() <= dust,
        ),
        [
          for (final f in fills) '${f.fee} ${f.feeAsset} of ${f.quoteAmount}',
        ].join('; '),
      );
      if (await othersFilled(fills0, {order.orderId})) {
        check('spot sell balances', true, 'skipped: another order filled');
      } else {
        final dUsdt = total(w1, 'USDT') - total(w0, 'USDT');
        final dBtc = total(w1, 'BTC') - total(w0, 'BTC');
        check(
          'spot sell BTC − qty',
          dBtc == -filledQty,
          'ΔBTC $dBtc, sold $filledQty',
        );
        check(
          'spot sell USDT + proceeds − fee',
          dUsdt == quote - fees,
          'ΔUSDT $dUsdt, expected ${quote - fees}',
        );
      }
    }

    // ---- 3. Spot LIMIT BUY far below: rests, locks, cancels ----------------
    {
      const qty = '0.001';
      final last = d(
        container
            .read(marketRepositoryProvider(Market.spot))
            .tickers['BTCUSDT']
            ?.lastPrice,
      );
      // Half the last price on the 0.01 tick: it never fills in the test.
      final price = (last * Decimal.parse('0.5')).floor(scale: 2);
      final w0 = await spotWallet();
      final ids = await orderIds();
      await chooseKind('trade-kind', 'Limit');
      await tapKey('trade-side-BUY');
      await typeInto('trade-field-price', price.toString());
      await typeInto('trade-field-amount', qty);
      await tapKey('trade-submit');
      await tapKey('trade-confirm');
      final order = await newOrder(ids);
      await settle(1500);
      final w1 = await spotWallet();
      final lockedUp = d(w1['USDT']?.locked) - d(w0['USDT']?.locked);
      check(
        'limit buy rests',
        order.status == OrderStatus.newOrder,
        'status ${order.status.name} at $price',
      );
      check(
        'limit buy locks price × qty',
        lockedUp == price * d(qty),
        'locked +$lockedUp, expected ${price * d(qty)}',
      );
      final row = find.byKey(Key('open-order-${order.orderId}'));
      check(
        'limit buy listed in Open orders',
        await waitFor(row, seconds: 10),
        order.orderId,
      );
      await tapKey('cancel-${order.orderId}');
      final done = await finalOrder(order.orderId);
      final w2 = await spotWallet();
      check(
        'limit buy cancelled',
        done.status == OrderStatus.canceled,
        'status ${done.status.name}',
      );
      check(
        'cancel releases the lock',
        d(w2['USDT']?.locked) == d(w0['USDT']?.locked),
        'locked ${w2['USDT']?.locked} vs ${w0['USDT']?.locked}',
      );
    }

    // ---- 4. Futures MARKET long, then market close --------------------------
    {
      final open = await io(futures.positions());
      final taken = {
        for (final p in open)
          if (d(p.amount) != Decimal.zero) p.symbol,
      };
      final (symbol, qty) = [
        ('BTCUSDT', '0.002'),
        ('ETHUSDT', '0.05'),
        ('SOLUSDT', '1'),
      ].firstWhere((c) => !taken.contains(c.$1));
      router.go('/trade?market=futures');
      expect(await waitFor(find.byKey(const Key('futures-pair'))), isTrue);
      await settle(3000);
      if (find
          .descendant(
            of: find.byKey(const Key('futures-pair')),
            matching: find.textContaining(symbol.replaceAll('USDT', '')),
          )
          .evaluate()
          .isEmpty) {
        await tapKey('futures-pair');
        await tapKey('futures-pick-$symbol');
        await settle(2000);
      }
      final a0 = await io(futures.account());
      final t0 = {
        for (final t in await io(futures.userTrades(symbol, limit: 100))) t.id,
      };
      await chooseKind('futures-kind', 'Market');
      await tapKey('futures-size-coin');
      await typeInto('futures-field-size', qty);
      await settle(1000);
      await tapKey('futures-BUY');
      await tapKey('futures-confirm');
      await settle(2000);
      final positions = await io(futures.positions(symbol: symbol));
      final position = positions.where((p) => d(p.amount) != Decimal.zero);
      final opens = (await io(
        futures.userTrades(symbol, limit: 100),
      )).where((t) => !t0.contains(t.id)).toList();
      final openQty = sum(opens.map((t) => d(t.qty)));
      final openQuote = sum(opens.map((t) => d(t.quoteQty)));
      check(
        'futures long opened',
        position.length == 1 && d(position.first.amount) == d(qty),
        '${position.map((p) => '${p.side.wire} ${p.amount}').join(', ')}, '
            'asked $qty',
      );
      final entryVwap = openQty == Decimal.zero
          ? Decimal.zero
          : (openQuote / openQty).toDecimal(scaleOnInfinitePrecision: 8);
      final entry = position.isEmpty
          ? Decimal.zero
          : d(position.first.entryPrice);
      check(
        'futures entry = VWAP of its fills',
        (entry - entryVwap).abs() <= Decimal.parse('0.01'),
        'entry $entry, VWAP $entryVwap of ${opens.length} fill(s)',
      );
      check(
        'futures commission zero',
        opens.every((t) => d(t.commission) == Decimal.zero),
        [for (final t in opens) t.commission].join(', '),
      );
      final screenCard = find.byKey(Key('position-$symbol-BOTH'));
      check(
        'position card on screen',
        await waitFor(screenCard, seconds: 10),
        'position-$symbol-BOTH',
      );

      final t1 = {
        for (final t in await io(futures.userTrades(symbol, limit: 100))) t.id,
      };
      await tapKey('market-close-$symbol-BOTH');
      await tapKey('futures-ask-yes');
      await settle(2500);
      final closes = (await io(
        futures.userTrades(symbol, limit: 100),
      )).where((t) => !t1.contains(t.id)).toList();
      final closeQty = sum(closes.map((t) => d(t.qty)));
      final closeQuote = sum(closes.map((t) => d(t.quoteQty)));
      final realized = sum(closes.map((t) => d(t.realizedPnl)));
      final expected = closeQuote - entry * closeQty;
      final after = (await io(
        futures.positions(symbol: symbol),
      )).where((p) => d(p.amount) != Decimal.zero);
      check(
        'futures position closed',
        after.isEmpty && closeQty == d(qty),
        'left ${after.map((p) => p.amount).join(', ')}, closed $closeQty',
      );
      check(
        'realised PnL = (exit − entry) × size',
        (realized - expected).abs() <= Decimal.parse('0.0001'),
        'realised $realized, expected $expected '
            '(exit ${closeQty == Decimal.zero ? '-' : (closeQuote / closeQty).toDecimal(scaleOnInfinitePrecision: 8)}, entry $entry)',
      );
      final a1 = await io(futures.account());
      final dWallet = d(a1.walletBalance) - d(a0.walletBalance);
      check(
        'futures wallet moves by the realised PnL',
        (dWallet - realized).abs() <= Decimal.parse('0.0001'),
        'Δwallet $dWallet, realised $realized',
      );
    }

    // ignore: avoid_print
    print('CHECKS-FAILED:${failures.length}');
    await SecureTokenStore().clear();
    expect(failures, isEmpty);
  });
}
