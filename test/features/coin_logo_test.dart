import 'package:cryptopilot_mobile/core/theme/app_theme.dart';
import 'package:cryptopilot_mobile/features/market/domain/market.dart';
import 'package:cryptopilot_mobile/features/market/presentation/market_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// T-132: the coin's logo from `logoUrl` of the pair, or its first two
/// letters, as the web's CoinLogo.
void main() {
  Map<String, Object?> pairJson(Object? logo) => {
    'pairId': '01a18804-7883-752f-86a8-6efe55cebd85',
    'symbol': 'BTCUSDT',
    'market': 'SPOT',
    'baseAsset': 'BTC',
    'quoteAsset': 'USDT',
    'baseAssetName': 'Bitcoin',
    'logoUrl': logo,
    'tickSize': '0.01',
    'stepSize': '0.00001',
    'minNotional': '5',
    'displayOrder': 1,
  };

  test('the pair keeps an https logo; none or another scheme is no logo', () {
    const url = 'https://static.coinpaprika.com/coin/btc-bitcoin/logo.png';
    expect(decodePair(pairJson(url)).logoUrl, url);
    expect(decodePair(pairJson(null)).logoUrl, isNull);
    expect(
      decodePair(pairJson('http://example.invalid/btc.png')).logoUrl,
      null,
    );
    final missing = pairJson(null)..remove('logoUrl');
    expect(decodePair(missing).logoUrl, isNull);
  });

  Future<void> show(
    WidgetTester tester,
    Widget child, {
    Brightness brightness = Brightness.light,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: appTheme(brightness),
      home: Scaffold(body: Center(child: child)),
    ),
  );

  testWidgets('no logo: the first two letters', (tester) async {
    await show(tester, const CoinLogo(symbol: 'ETH'));
    expect(find.text('ET'), findsOneWidget);
    expect(find.byKey(const Key('coin-image')), findsNothing);
  });

  testWidgets('a logo that fails to load falls back to the letters', (
    tester,
  ) async {
    await show(
      tester,
      const CoinLogo(
        symbol: 'SOL',
        url: 'https://static.coinpaprika.com/coin/sol-solana/logo.png',
      ),
    );
    expect(find.byKey(const Key('coin-image')), findsOneWidget);
    // Loading: the letters hold the place.
    expect(find.text('SO'), findsOneWidget);
    // The test HTTP client answers 400: the letters stay.
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(find.text('SO'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    testWidgets('${brightness.name}: decorative, sized as asked', (
      tester,
    ) async {
      await show(
        tester,
        const CoinLogo(symbol: 'BNB', size: 24),
        brightness: brightness,
      );
      expect(tester.getSize(find.byType(CoinLogo)), const Size(24, 24));
      expect(
        find.descendant(
          of: find.byType(CoinLogo),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );
    });
  }

  testWidgets('a logo sits on the raised tint with a ring, so a dark logo '
      'shows on the dark theme', (tester) async {
    await show(
      tester,
      const CoinLogo(
        symbol: 'XRP',
        url: 'https://static.coinpaprika.com/coin/xrp-xrp/logo.png',
      ),
      brightness: Brightness.dark,
    );
    final frame = tester.widget<DecoratedBox>(
      find.byKey(const Key('coin-frame')),
    );
    final decoration = frame.decoration as BoxDecoration;
    expect(decoration.color, isNotNull);
    expect(decoration.border, isNotNull);
  });
}
