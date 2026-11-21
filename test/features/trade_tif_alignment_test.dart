// T-148 (D-163): the time in force (GTC) lines up with the order type.
//
// The shift shows only with a real font, so this file loads the Roboto that
// ships with the Flutter SDK (its own file: the font stays out of the other
// tests).
import 'dart:io';

import 'package:cryptopilot_mobile/app.dart';
import 'package:cryptopilot_mobile/core/auth/token_store.dart';
import 'package:cryptopilot_mobile/core/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/realtime_fakes.dart';

Future<void> loadRoboto() async {
  final dir = Directory(
    '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts',
  );
  final roboto = FontLoader('Roboto');
  for (final file in dir.listSync().whereType<File>()) {
    final name = file.uri.pathSegments.last;
    if (name.startsWith('roboto-') && name.endsWith('.ttf')) {
      roboto.addFont(
        Future.value(ByteData.sublistView(file.readAsBytesSync())),
      );
    }
  }
  await roboto.load();
}

void main() {
  setUpAll(loadRoboto);

  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> open(WidgetTester tester, String location) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.reset);
    final transport = FakeTransport();
    await tester.pumpWidget(
      ProviderScope(
        overrides: baseOverrides(
          store: MemoryTokenStore(storedFor('saved')),
          tokens: FakeAuthTokenApi(),
          transport: transport,
        ),
        retry: (_, _) => null,
        child: const CryptoPilotApp(),
      ),
    );
    await frames(tester);
    transport.last.onConnected();
    ProviderScope.containerOf(
      tester.element(find.byType(CryptoPilotApp)),
    ).read(appRouterProvider).go(location);
    await frames(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 31));
  }

  /// The top of the drawn text: a paragraph stretched to the dropdown's
  /// height keeps its centre on the line but draws its text at its top.
  double topY(WidgetTester tester, String dropdown, String text) => tester
      .getTopLeft(
        find.descendant(
          of: find.byKey(Key(dropdown)),
          matching: find.text(text),
        ),
      )
      .dy;

  for (final (market, kind, tif) in [
    ('spot', 'trade-kind', 'trade-tif'),
    ('futures', 'futures-kind', 'futures-tif'),
  ]) {
    testWidgets('$market: GTC on the line of Limit', (tester) async {
      await open(tester, '/trade?market=$market');
      expect(
        (topY(tester, tif, 'GTC') - topY(tester, kind, 'Limit')).abs(),
        lessThanOrEqualTo(1),
      );
      await unmount(tester);
    });
  }
}
