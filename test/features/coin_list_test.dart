import 'package:cryptopilot_mobile/core/json/json_read.dart';
import 'package:cryptopilot_mobile/features/market/domain/coin_market.dart';
import 'package:cryptopilot_mobile/features/market/domain/market.dart';
import 'package:flutter_test/flutter_test.dart';

/// T-137 (A-67): the coin list of `GET /market/coins` with live prices.
Map<String, Object?> coinJson({String symbol = 'BTC', int? rank = 1}) => {
  'symbol': symbol,
  'name': 'Bitcoin',
  'logoUrl': 'https://static.coinpaprika.com/coin/btc-bitcoin/logo.png',
  'rank': rank,
  'spotSymbol': '${symbol}USDT',
  'futuresSymbol': '${symbol}USDT',
  'quote': 'USDT',
  'circulatingSupply': '19800000',
  'price1hAgo': '76000',
  'price7dAgo': '80000',
  'sparkline7d': ['80000', '79000.5', '76100'],
};

Ticker ticker(String? price, {String? change = '-1.50'}) => Ticker(
  symbol: 'BTCUSDT',
  lastPrice: price,
  changePercent24h: change,
  quoteVolume24h: '2000000000',
);

void main() {
  test('a coin row; a figure not known is absent', () {
    final c = decodeCoinRow(coinJson());
    expect((c.symbol, c.rank, c.spotSymbol), ('BTC', 1, 'BTCUSDT'));
    expect(c.sparkline7d, [80000, 79000.5, 76100]);
    final partial = decodeCoinRow({'symbol': 'XYZ', 'name': 'Xyz'});
    expect(partial.rank, isNull);
    expect(partial.circulatingSupply, isNull);
    expect(partial.sparkline7d, isEmpty);
  });

  test('a figure of the wrong kind is refused', () {
    expect(
      () => decodeCoinRow({...coinJson(), 'circulatingSupply': 19800000}),
      throwsA(isA<DecodeException>()),
    );
    expect(
      () => decodeCoinRow({
        ...coinJson(),
        'sparkline7d': ['x'],
      }),
      throwsA(isA<DecodeException>()),
    );
  });

  test('the overview carries its coins', () {
    final o = decodeMarketOverview({
      'asOf': '2026-11-20T03:00:00Z',
      'coins': [coinJson(), coinJson(symbol: 'ETH', rank: 2)],
    });
    expect(o.coins.map((c) => c.symbol), ['BTC', 'ETH']);
  });

  test('the live price moves the cap and the 1 h and 7 d changes', () {
    final c = decodeCoinRow(coinJson());
    final f = coinFigures(c, ticker('76760'));
    expect(f.price, '76760');
    expect(f.change1h, '1.00');
    expect(f.change7d, '-4.05');
    expect(f.change24h, '-1.50');
    expect(f.marketCap, '1519848000000');
    expect(f.volume24h, '2000000000');
  });

  test('no live price yet: only what the ticker knows', () {
    final c = decodeCoinRow(coinJson());
    final none = coinFigures(c, null);
    expect(none.price, isNull);
    expect(none.marketCap, isNull);
    final noPrice = coinFigures(c, ticker(null, change: '2.00'));
    expect(noPrice.change24h, '2.00');
    expect(noPrice.change1h, isNull);
  });
}
