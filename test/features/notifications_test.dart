import 'dart:async';

import 'package:cryptopilot_mobile/core/auth/token_store.dart';
import 'package:cryptopilot_mobile/core/i18n/app_localizations.dart';
import 'package:cryptopilot_mobile/core/i18n/app_localizations_en.dart';
import 'package:cryptopilot_mobile/core/json/json_read.dart';
import 'package:cryptopilot_mobile/core/theme/app_theme.dart';
import 'package:cryptopilot_mobile/features/market/presentation/market_widgets.dart';
import 'package:cryptopilot_mobile/features/notifications/application/notifications_controller.dart';
import 'package:cryptopilot_mobile/features/notifications/domain/notification.dart';
import 'package:cryptopilot_mobile/features/notifications/presentation/notification_bell.dart';
import 'package:cryptopilot_mobile/features/notifications/presentation/notification_format.dart';
import 'package:cryptopilot_mobile/features/notifications/presentation/notifications_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../support/fakes.dart';
import '../support/realtime_fakes.dart';

/// `NotificationResponse` as backend develop 25ba960 writes it.
const payload = {
  'id': '01a18807-0000-7000-8000-000000000001',
  'type': 'FUTURES',
  'title': 'Margin call',
  'content': 'Your BTCUSDT position is near liquidation.',
  'referenceType': 'FUTURES_POSITION',
  'referenceId': '01a18807-0000-7000-8000-0000000000ff',
  'read': false,
  'readAt': null,
  'createdAt': '2026-11-07T02:15:00.123456Z',
};

final l = AppLocalizationsEn();

void main() {
  group('decoders (NotificationResponse of backend develop 25ba960)', () {
    test('a notification with its reference', () {
      final n = decodeNotification(payload);
      expect(n.type, NotificationType.futures);
      expect(n.referenceType, NotificationReference.futuresPosition);
      expect(n.read, isFalse);
      expect(n.createdAt, DateTime.utc(2026, 11, 7, 2, 15, 0, 123, 456));
    });

    test('every type the backend sends is known; others are refused', () {
      for (final wire in [
        'ALERT',
        'PLAN',
        'MODERATION',
        'SUBSCRIPTION',
        'COMMENT',
        'SYSTEM',
        'FOLLOW',
        'MENTION',
        'FUTURES',
      ]) {
        expect(decodeNotification({...payload, 'type': wire}).type.wire, wire);
      }
      expect(
        () => decodeNotification({...payload, 'type': 'PROMO'}),
        throwsA(isA<DecodeException>()),
      );
    });

    test('a page and the unread count', () {
      final page = decodeNotificationPage({
        'items': [payload],
        'page': 1,
        'pageSize': 20,
        'total': 1,
      });
      expect(page.items.single.title, 'Margin call');
      expect(decodeUnreadCount({'unread': 4}), 4);
    });
  });

  group('where opening one goes', () {
    NotificationTarget? of(NotificationReference? reference, [String? id]) =>
        targetOf(
          notificationOf('x', reference: reference, referenceId: id ?? 'r 1'),
        );

    test('every reference', () {
      expect(
        (of(NotificationReference.alert)! as AppScreen).location,
        '/alerts',
      );
      expect((of(NotificationReference.plan)! as WebPage).path, '/plans/r%201');
      expect(
        (of(NotificationReference.post)! as WebPage).path,
        '/community/r%201',
      );
      expect(
        (of(NotificationReference.member)! as WebPage).path,
        '/community/members/r%201',
      );
      expect(
        (of(NotificationReference.subscription)! as WebPage).path,
        '/subscription',
      );
      expect(
        (of(NotificationReference.futuresPosition)! as WebPage).path,
        '/trade/futures',
      );
      expect(of(NotificationReference.newsSource), isNull);
      expect(of(null), isNull);
    });
  });

  test('age and badge as the web words them', () {
    DateTime ago(Duration d) => now.subtract(d);
    expect(notificationAge(l, ago(const Duration(seconds: 20)), now), 'now');
    expect(notificationAge(l, ago(const Duration(minutes: 5)), now), '5m ago');
    expect(notificationAge(l, ago(const Duration(hours: 3)), now), '3h ago');
    expect(notificationAge(l, ago(const Duration(days: 2)), now), '2d ago');
    expect(
      notificationAge(l, DateTime.utc(2026, 10, 20, 12), now),
      '20 Oct 2026',
    );
    expect(badgeText(7), '7');
    expect(badgeText(120), '99+');
  });

  group('SCR-15 and the bell', () {
    late FakeTransport transport;
    late FakeNotificationApi api;
    late FakeWebLinks web;
    late List<String> hooked;

    Future<void> pump(
      WidgetTester tester, {
      List<AppNotification>? items,
      Brightness brightness = Brightness.light,
      String start = '/',
    }) async {
      transport = FakeTransport();
      api = FakeNotificationApi();
      web = FakeWebLinks();
      hooked = [];
      if (items != null) api.items = items;
      final router = GoRouter(
        initialLocation: start,
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => NotificationBanner(
              child: Scaffold(
                appBar: AppBar(actions: const [NotificationBell()]),
                body: const Text('HOME'),
              ),
            ),
          ),
          GoRoute(
            path: '/notifications',
            builder: (_, _) => const NotificationsScreen(),
          ),
          GoRoute(
            path: '/alerts',
            builder: (_, _) => const Scaffold(body: Text('ALERTS PAGE')),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...baseOverrides(
              store: MemoryTokenStore(storedFor('saved')),
              tokens: FakeAuthTokenApi(),
              transport: transport,
              notifications: api,
              web: web,
            ),
            notificationHooksProvider.overrideWithValue([
              (_, arrived) => hooked.add(arrived.id),
            ]),
          ],
          retry: (_, _) => null,
          child: MaterialApp.router(
            routerConfig: router,
            theme: appTheme(brightness),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      for (var i = 0; i < 8; i++) {
        await tester.pump();
      }
    }

    Future<void> connect(WidgetTester tester) async {
      transport.last.onConnected();
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }
    }

    Future<void> openList(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('open-notifications')));
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 400));
    }

    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 31));
    }

    Finder badge(String text) => find.descendant(
      of: find.byKey(const Key('notification-badge')),
      matching: find.text(text),
    );

    testWidgets('the bell shows the unread count from the server', (
      tester,
    ) async {
      await pump(tester);
      expect(api.calls, contains('count'));
      expect(badge('2'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('a push adds one, shows a banner and runs the hooks', (
      tester,
    ) async {
      await pump(tester);
      await connect(tester);
      transport.last.push(
        notificationQueue,
        notificationJson(notificationOf('n9', title: 'Margin call')),
      );
      await tester.pump();
      await tester.pump();

      expect(badge('3'), findsOneWidget);
      expect(find.text('Margin call'), findsOneWidget);
      expect(hooked, ['n9']);

      // Let the snackbar slide in before it takes a tap.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('View'));
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 400));
      expect(api.calls, contains('read n9'));
      expect(find.text('ALERTS PAGE'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('the banner goes away by itself', (tester) async {
      await pump(tester);
      await connect(tester);
      transport.last.push(
        notificationQueue,
        notificationJson(notificationOf('n9', title: 'Margin call')),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Margin call'), findsOneWidget);
      // In, shown for its duration, then out.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(bannerDuration);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Margin call'), findsNothing);
      await unmount(tester);
    });

    testWidgets('lists title, text, age and the unread dot', (tester) async {
      await pump(tester);
      await openList(tester);
      expect(find.text('Alert triggered'), findsOneWidget);
      expect(find.text('Entry filled'), findsOneWidget);
      expect(find.text('5m ago'), findsOneWidget);
      expect(find.text('1h ago'), findsOneWidget);
      expect(find.byKey(const Key('unread-dot-n1')), findsOneWidget);
      expect(find.byKey(const Key('unread-dot-n3')), findsNothing);
      await unmount(tester);
    });

    testWidgets('Unread asks the server for unread ones only', (tester) async {
      await pump(tester);
      await openList(tester);
      await tester.tap(find.text('Unread'));
      await tester.pump();
      await tester.pump();
      expect(api.calls.last, 'list true 1');
      expect(find.text('Welcome'), findsNothing);
      expect(find.text('Alert triggered'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('opening one marks it read, lowers the bell, opens the page', (
      tester,
    ) async {
      await pump(tester);
      await openList(tester);
      await tester.tap(find.byKey(const Key('notification-n2')));
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }
      expect(api.calls, contains('read n2'));
      expect(web.opened, ['/plans/plan-7']);
      expect(find.byKey(const Key('unread-dot-n2')), findsNothing);

      await tester.tap(find.byKey(const Key('notification-n1')));
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('ALERTS PAGE'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('a failed mark still opens and says why', (tester) async {
      await pump(tester);
      await openList(tester);
      api.readError = problem(404, 'RESOURCE_NOT_FOUND', 'MSG41');
      await tester.tap(find.byKey(const Key('notification-n2')));
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }
      expect(web.opened, ['/plans/plan-7']);
      expect(find.text('No results found.'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('mark all as read empties the bell and the dots', (
      tester,
    ) async {
      await pump(tester);
      await openList(tester);
      await tester.tap(find.byKey(const Key('mark-all-read')));
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }
      expect(api.calls, contains('read-all'));
      expect(find.byKey(const Key('unread-dot-n1')), findsNothing);
      expect(find.byKey(const Key('mark-all-read')), findsNothing);
      expect(find.text('All notifications marked as read.'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('the next page loads as the list scrolls', (tester) async {
      await pump(
        tester,
        items: [
          for (var i = 0; i < 25; i++) notificationOf('m$i', minutesAgo: i),
        ],
      );
      await openList(tester);
      await tester.drag(find.byType(ListView).last, const Offset(0, -4000));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(api.calls, contains('list false 2'));
      await unmount(tester);
    });

    testWidgets('the first read of the list shows the skeleton', (
      tester,
    ) async {
      final gate = Completer<void>();
      await pump(tester);
      api.hold = gate.future;
      await openList(tester);
      expect(find.byType(ListSkeleton), findsOneWidget);

      api.hold = null;
      gate.complete();
      await tester.pump();
      await tester.pump();
      expect(find.byType(ListSkeleton), findsNothing);
      expect(find.text('Alert triggered'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('empty lists say so; a failure offers to try again', (
      tester,
    ) async {
      await pump(tester, items: []);
      await openList(tester);
      expect(find.text('No notifications yet.'), findsOneWidget);
      await tester.tap(find.text('Unread'));
      await tester.pump();
      await tester.pump();
      expect(find.text("You're all caught up."), findsOneWidget);
      await unmount(tester);

      await pump(tester);
      api.listError = networkDown;
      await openList(tester);
      expect(
        find.text(
          'Unable to reach the server. Check your connection and try again.',
        ),
        findsOneWidget,
      );
      api.listError = null;
      await tester.tap(find.text('Try again'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Alert triggered'), findsOneWidget);
      await unmount(tester);
    });

    for (final brightness in Brightness.values) {
      testWidgets('fits 360 dp in the ${brightness.name} theme', (
        tester,
      ) async {
        tester.view
          ..physicalSize = const Size(360 * 3, 760 * 3)
          ..devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        await pump(
          tester,
          brightness: brightness,
          items: [
            notificationOf(
              'long',
              title: 'Your report was reviewed by the moderators of the forum',
              content:
                  'The post you reported in Trading ideas was hidden after review; thank you for keeping the community useful.',
            ),
            ...FakeNotificationApi().items,
          ],
        );
        await openList(tester);
        expect(tester.takeException(), isNull);
        await unmount(tester);
      });
    }
  });
}
