import 'dart:async';

import 'package:cryptopilot_mobile/app.dart';
import 'package:cryptopilot_mobile/core/auth/token_store.dart';
import 'package:cryptopilot_mobile/core/router/app_router.dart';
import 'package:cryptopilot_mobile/core/settings/settings.dart';
import 'package:cryptopilot_mobile/core/media/media_picker.dart';
import 'package:cryptopilot_mobile/features/community/presentation/post_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/community_fakes.dart';
import '../support/fakes.dart';
import '../support/realtime_fakes.dart';

/// T-135: SCR-26 in the app (A-66).
void main() {
  late FakeCommunityApi api;
  late FakeMediaPicker picker;

  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> open(
    WidgetTester tester,
    String location, {
    Brightness brightness = Brightness.light,
  }) async {
    final transport = FakeTransport();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...baseOverrides(
            store: MemoryTokenStore(storedFor('saved')),
            tokens: FakeAuthTokenApi(),
            transport: transport,
            settings: MemorySettingsStore(),
            clock: () => communityNow,
            community: api,
          ),
          mediaPickerProvider.overrideWithValue(picker),
        ],
        retry: (_, _) => null,
        child: const CryptoPilotApp(),
      ),
    );
    await frames(tester);
    transport.last.onConnected();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(CryptoPilotApp)),
    );
    if (brightness == Brightness.dark) {
      unawaited(
        container.read(themeModeProvider.notifier).select(ThemeMode.dark),
      );
    }
    unawaited(container.read(appRouterProvider).push(location));
    await frames(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 31));
  }

  bool publishEnabled(WidgetTester tester) =>
      tester
          .widget<FilledButton>(find.byKey(const Key('composer-publish')))
          .onPressed !=
      null;

  /// Brings [key] fully into view: the list is lazy and a button only
  /// peeking at the edge would miss the tap.
  Future<void> scrollTo(WidgetTester tester, String key) async {
    await tester.scrollUntilVisible(
      find.byKey(Key(key)),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('composer')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.pump();
  }

  setUp(() {
    api = FakeCommunityApi();
    picker = FakeMediaPicker();
  });

  testWidgets('a new post with a coin, a market, a stance and two images; '
      'MSG33, then the post opens', (tester) async {
    await open(tester, '/community/new');
    expect(find.text('New post'), findsOneWidget);
    expect(publishEnabled(tester), isFalse);
    await tester.enterText(
      find.byKey(const Key('composer-title')),
      'BTC holds 76k',
    );
    await tester.enterText(
      find.byKey(const Key('composer-content')),
      'Support held twice.',
    );
    await tester.pump();
    expect(publishEnabled(tester), isTrue);

    await tester.tap(find.byKey(const Key('composer-add-coin')));
    await frames(tester);
    await tester.tap(find.byKey(const Key('composer-coin-ETH')));
    await frames(tester);
    expect(find.byKey(const Key('composer-coin-chip-ETH')), findsOneWidget);
    await tester.tap(find.byKey(const Key('composer-market-SPOT')));
    await tester.tap(find.byKey(const Key('composer-stance-BULLISH')));
    await tester.pump();

    await scrollTo(tester, 'composer-add-images');
    await tester.tap(find.byKey(const Key('composer-add-images')));
    await frames(tester);
    await scrollTo(tester, 'composer-media-1');
    expect(find.byKey(const Key('composer-media-0')), findsOneWidget);
    expect(find.byKey(const Key('composer-media-1')), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('composer-add-video')))
          .onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const Key('composer-publish')));
    await frames(tester);
    expect(api.calls, contains('create "BTC holds 76k" media=2'));
    final draft = api.drafts.single.toJson();
    expect(draft['coins'], ['ETH']);
    expect(draft['marketType'], 'SPOT');
    expect(draft['sentiment'], 'BULLISH');
    expect(find.text('Your post has been published.'), findsOneWidget);
    expect(find.byType(PostScreen), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('a file too large shows MSG32 and holds the post until '
      'removed', (tester) async {
    picker.nextImages = const [
      PickedFile(path: '/tmp/big.png', name: 'big.png', size: 20 * 1024 * 1024),
    ];
    await open(tester, '/community/new');
    await tester.enterText(find.byKey(const Key('composer-title')), 'Title ok');
    await tester.enterText(find.byKey(const Key('composer-content')), 'Body');
    await scrollTo(tester, 'composer-add-images');
    await tester.tap(find.byKey(const Key('composer-add-images')));
    await frames(tester);
    await scrollTo(tester, 'composer-error-0');
    expect(
      find.text('File type or size is not supported (maximum 10 MB).'),
      findsOneWidget,
    );
    expect(publishEnabled(tester), isFalse);
    await tester.tap(find.byKey(const Key('composer-remove-0')));
    await tester.pump();
    expect(publishEnabled(tester), isTrue);
    await unmount(tester);
  });

  testWidgets('a video on a plan without video posting shows MSG29', (
    tester,
  ) async {
    api.failNext['form'] = problem(
      403,
      'PLAN_FEATURE_NOT_INCLUDED',
      'MSG29',
      args: ['PREMIUM'],
    );
    await open(tester, '/community/new');
    await scrollTo(tester, 'composer-add-video');
    await tester.tap(find.byKey(const Key('composer-add-video')));
    await frames(tester);
    await scrollTo(tester, 'composer-error-0');
    expect(find.textContaining('PREMIUM'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('editing an own post starts from it and saves', (tester) async {
    api.posts['p1'] = postOf('p1', title: 'Old title', mine: true);
    await open(tester, '/community/p1/edit');
    expect(find.text('Edit post'), findsOneWidget);
    expect(find.text('Old title'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('composer-title')),
      'New title here',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('composer-publish')));
    await frames(tester);
    expect(api.calls, contains('update p1 "New title here" media=0'));
    expect(find.text('Your changes are saved.'), findsOneWidget);
    await unmount(tester);
  });

  for (final brightness in Brightness.values) {
    testWidgets('360 dp, ${brightness.name}: the composer with files fits', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(360 * 3, 760 * 3)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      picker.nextImages = const [
        PickedFile(path: '/tmp/a.png', name: 'a.png', size: 1000),
        PickedFile(path: '/tmp/big.png', name: 'big.png', size: 50000000),
      ];
      await open(tester, '/community/new', brightness: brightness);
      await tester.tap(find.byKey(const Key('composer-add-coin')));
      await frames(tester);
      await tester.tap(find.byKey(const Key('composer-coin-BTC')));
      await frames(tester);
      await scrollTo(tester, 'composer-add-images');
      await tester.tap(find.byKey(const Key('composer-add-images')));
      await frames(tester);
      await scrollTo(tester, 'composer-error-1');
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  }
}
