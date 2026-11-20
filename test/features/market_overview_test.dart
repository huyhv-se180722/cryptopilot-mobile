import 'package:cryptopilot_mobile/core/json/json_read.dart';
import 'package:cryptopilot_mobile/features/market/data/market_api.dart';
import 'package:cryptopilot_mobile/features/market/domain/coin_market.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/http_fakes.dart';

/// T-134 (A-65): the whole market's figures of `GET /market/coins`.
Map<String, Object?> coinsJson() => {
  'asOf': '2026-11-20T03:00:00Z',
  'global': {
    'marketCapUsd': '2614000000000',
    'marketCapChange24hPercent': '-1.84',
    'volume24hUsd': '98400000000',
    'bitcoinDominancePercent': '58.21',
    'asOf': '2026-11-20T02:55:00Z',
  },
  'fearGreed': {
    'value': 22,
    'classification': 'Extreme Fear',
    'asOf': '2026-11-20T00:00:00Z',
  },
  'altcoinSeason': {'index': 31, 'altcoins': 9, 'days': 90},
  'openInterest': {
    'valueUsd': '41200000000',
    'change24hPercent': '3.10',
    'lastDay': [
      {'at': '2026-11-19T03:00:00Z', 'valueUsd': '40000000000'},
    ],
  },
  'coins': [
    {'symbol': 'BTC', 'name': 'Bitcoin'},
  ],
};

void main() {
  test('every figure of the whole market', () {
    final o = decodeMarketOverview(coinsJson());
    expect(o.asOf, DateTime.utc(2026, 11, 20, 3));
    expect(o.global!.marketCapUsd, '2614000000000');
    expect(o.global!.marketCapChange24hPercent, '-1.84');
    expect(o.global!.bitcoinDominancePercent, '58.21');
    expect(o.fearGreed!.value, 22);
    expect(o.altcoinSeason!.index, 31);
    expect(o.openInterest!.change24hPercent, '3.10');
  });

  test('a figure not known is absent, never zero', () {
    final o = decodeMarketOverview({
      'asOf': '2026-11-20T03:00:00Z',
      'global': {'marketCapUsd': '2614000000000'},
      'coins': const <Object?>[],
    });
    expect(o.global!.volume24hUsd, isNull);
    expect(o.global!.marketCapChange24hPercent, isNull);
    expect(o.fearGreed, isNull);
    expect(o.altcoinSeason, isNull);
    expect(o.openInterest, isNull);
  });

  test('a figure of the wrong kind is refused', () {
    expect(
      () => decodeMarketOverview({
        ...coinsJson(),
        'global': {'marketCapUsd': 2614000000000},
      }),
      throwsA(isA<DecodeException>()),
    );
    expect(
      () => decodeMarketOverview({
        ...coinsJson(),
        'fearGreed': {'value': '22', 'classification': 'Fear'},
      }),
      throwsA(isA<DecodeException>()),
    );
  });

  test('read from market/coins', () async {
    final adapter = RecordingAdapter()..answers.add((200, coinsJson()));
    await DioMarketApi(dioOn(adapter)).overview();
    expect(adapter.requests.single.path, 'market/coins');
  });
}
