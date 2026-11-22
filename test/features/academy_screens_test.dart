import 'dart:async';

import 'package:cryptopilot_mobile/app.dart';
import 'package:cryptopilot_mobile/core/auth/token_store.dart';
import 'package:cryptopilot_mobile/core/router/app_router.dart';
import 'package:cryptopilot_mobile/core/settings/settings.dart';
import 'package:cryptopilot_mobile/features/academy/presentation/academy_links.dart';
import 'package:cryptopilot_mobile/features/academy/presentation/academy_screen.dart';
import 'package:cryptopilot_mobile/features/academy/presentation/academy_widgets.dart';
import 'package:cryptopilot_mobile/features/academy/presentation/lesson_screen.dart';
import 'package:cryptopilot_mobile/features/home/presentation/home_screen.dart';
import 'package:cryptopilot_mobile/features/market/presentation/markets_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/academy_fakes.dart';
import '../support/fakes.dart';
import '../support/realtime_fakes.dart';

/// A lesson body with every block the seed uses and a table wider than the
/// phone.
const richBody = '''
## Khác gì tiền trong ngân hàng?

Tiền mã hóa được ghi trên **sổ cái công khai** và *không* do ngân hàng giữ.

| | Tiền pháp định (VND, USD) | Tiền mã hóa | Ghi chú rất dài để bảng rộng hơn màn hình |
|---|---|---|---|
| Ai giữ sổ | Ngân hàng | Mạng lưới | Mỗi máy trong mạng giữ một bản sao của sổ cái |

> Lãi = Giá × Đòn bẩy

1. Mở ví
2. Mua coin

- `seed phrase`
- [Đọc thêm](/plans/new)

---
''';

void main() {
  late FakeAcademyApi api;
  late FakeWebLinks web;
  late FakeTransport transport;

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
          web: web,
          academy: api,
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
    unawaited(container.read(appRouterProvider).push(location));
    await frames(tester);
  }

  /// Scrolls the Academy list until [finder] is built and on screen.
  Future<void> scrollTo(
    WidgetTester tester,
    Finder finder, {
    double delta = 300,
  }) async {
    await tester.scrollUntilVisible(
      finder,
      delta,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('academy-list')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pump();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 31));
  }

  setUp(() {
    api = FakeAcademyApi();
    web = FakeWebLinks();
  });

  group('Academy screen', () {
    testWidgets('progress, the beginner path, topics, levels and the lessons '
        'with the learned mark; the notice', (tester) async {
      await open(tester, '/academy');
      expect(find.text('Học viện Crypto'), findsOneWidget);
      expect(find.text('Đã học 1/3 bài của lộ trình'), findsOneWidget);
      expect(find.text('Bạn đã đọc 1/35 bài'), findsOneWidget);
      expect(find.byKey(const Key('path-lesson-2')), findsOneWidget);
      expect(find.byKey(const Key('topic-risk')), findsOneWidget);
      expect(find.byKey(const Key('level-ADVANCED')), findsOneWidget);
      await scrollTo(tester, find.byKey(const Key('lesson-lesson-1')));
      expect(find.byKey(const Key('learned-lesson-1')), findsOneWidget);
      expect(find.byKey(const Key('learned-lesson-2')), findsNothing);
      await tester.scrollUntilVisible(
        find.byKey(const Key('academy-disclaimer')),
        400,
        scrollable: find.descendant(
          of: find.byKey(const Key('academy-list')),
          matching: find.byType(Scrollable),
        ),
      );
      expect(
        find.text(
          'Nội dung chỉ nhằm mục đích giáo dục, không phải lời khuyên đầu tư.',
        ),
        findsOneWidget,
      );
      await unmount(tester);
    });

    testWidgets('scrolling to the end reads the next page', (tester) async {
      await open(tester, '/academy');
      await scrollTo(tester, find.byKey(const Key('lesson-lesson-25')));
      await frames(tester);
      expect(api.calls.where((c) => c.startsWith('lessons')), [
        'lessons page=1',
        'lessons page=2',
      ]);
      await unmount(tester);
    });

    testWidgets('a topic narrows the list; a search with no match says so', (
      tester,
    ) async {
      await open(tester, '/academy');
      await tester.tap(find.byKey(const Key('topic-risk')));
      await frames(tester);
      await scrollTo(tester, find.byKey(const Key('lesson-risk-1')));
      expect(find.byKey(const Key('lesson-lesson-1')), findsNothing);
      await scrollTo(
        tester,
        find.byKey(const Key('academy-search')),
        delta: -300,
      );
      expect(find.byKey(const Key('lesson-lesson-1')), findsNothing);

      await tester.enterText(find.byKey(const Key('academy-search')), 'zzz');
      await tester.pump(const Duration(milliseconds: 400));
      await frames(tester);
      expect(
        find.text('Không có bài học nào khớp với bộ lọc.'),
        findsOneWidget,
      );
      await unmount(tester);
    });

    testWidgets('lessons that cannot be read: the failure and Thử lại', (
      tester,
    ) async {
      api.lessonsError = problem(503, 'UNAVAILABLE', 'MSG43');
      await open(tester, '/academy');
      await scrollTo(tester, find.text('Thử lại'));
      api.lessonsError = null;
      await tester.tap(find.text('Thử lại'));
      await frames(tester);
      await scrollTo(tester, find.byKey(const Key('lesson-lesson-1')));
      await unmount(tester);
    });
  });

  group('Lesson page', () {
    testWidgets('summary, the body with its table, quote and lists, the '
        'neighbours and related lessons', (tester) async {
      api.bodies['lesson-2'] = richBody;
      await open(tester, lessonLocation('lesson-2'));
      expect(find.text('Title lesson-2'), findsOneWidget);
      expect(find.text('Tóm tắt nhanh'), findsOneWidget);
      expect(find.text('Cập nhật 25/10/2026'), findsOneWidget);
      expect(find.text('Khác gì tiền trong ngân hàng?'), findsOneWidget);
      expect(find.byKey(const Key('lesson-table')), findsOneWidget);
      expect(find.textContaining('Lãi = Giá × Đòn bẩy'), findsOneWidget);
      expect(find.text('1.'), findsOneWidget);
      final page = find
          .descendant(
            of: find.byKey(const Key('lesson-page')),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.byKey(const Key('lesson-next')),
        300,
        scrollable: page,
      );
      expect(find.byKey(const Key('lesson-previous')), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('academy-disclaimer')),
        300,
        scrollable: page,
      );
      expect(find.text('Bài liên quan'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('Mark as learned waits for the server, then shows Learned '
        'and how to unmark; the path card follows', (tester) async {
      await open(tester, lessonLocation('lesson-2'));
      await tester.scrollUntilVisible(
        find.byKey(const Key('lesson-mark')),
        300,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('lesson-page')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('Đánh dấu đã học'), findsOneWidget);
      await tester.tap(find.byKey(const Key('lesson-mark')));
      await frames(tester);
      expect(api.calls, contains('mark lesson-2'));
      expect(find.text('Đã học'), findsWidgets);
      expect(find.text('Bấm lần nữa để bỏ đánh dấu.'), findsOneWidget);

      await tester.pageBack();
      await frames(tester);
      unawaited(containerOf(tester).read(appRouterProvider).push('/academy'));
      await frames(tester);
      expect(find.text('Đã học 2/3 bài của lộ trình'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('a refused mark says why under the button', (tester) async {
      api.markError = problem(404, 'NOT_FOUND', 'MSG41');
      await open(tester, lessonLocation('lesson-2'));
      await tester.scrollUntilVisible(
        find.byKey(const Key('lesson-mark')),
        300,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('lesson-page')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.byKey(const Key('lesson-mark')));
      await frames(tester);
      expect(find.byKey(const Key('lesson-mark-failure')), findsOneWidget);
      expect(find.text('Đánh dấu đã học'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('a lesson no longer published says so and leads back', (
      tester,
    ) async {
      api.lessonError = problem(404, 'NOT_FOUND', 'MSG41');
      await open(tester, lessonLocation('gone'));
      expect(
        find.text('Bài học không tồn tại hoặc chưa được xuất bản.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Quay lại Học viện'));
      await frames(tester);
      expect(find.byType(LessonScreen), findsNothing);
      await unmount(tester);
    });

    testWidgets('"Try it in the app" opens the Markets tab; a web-only screen '
        'and a link in the body open the web', (tester) async {
      api.bodies['lesson-2'] = richBody;
      api.appLinks['lesson-3'] = '/plans/new';
      await open(tester, lessonLocation('lesson-2'));
      final page = find
          .descendant(
            of: find.byKey(const Key('lesson-page')),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text('Đọc thêm', findRichText: true),
        200,
        scrollable: page,
      );
      await tester.ensureVisible(find.text('Đọc thêm', findRichText: true));
      await tester.pump();
      await tester.tapOnText(find.textRange.ofSubstring('Đọc thêm'));
      expect(web.opened, ['/plans/new']);

      await tester.scrollUntilVisible(
        find.byKey(const Key('lesson-try')),
        200,
        scrollable: page,
      );
      await tester.tap(find.byKey(const Key('lesson-try')));
      await frames(tester);
      expect(find.byType(MarketsScreen), findsOneWidget);

      unawaited(
        containerOf(
          tester,
        ).read(appRouterProvider).push(lessonLocation('lesson-3')),
      );
      await frames(tester);
      await tester.scrollUntilVisible(
        find.byKey(const Key('lesson-try')),
        200,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('lesson-page')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.byKey(const Key('lesson-try')));
      expect(web.opened, ['/plans/new', '/plans/new']);
      await unmount(tester);
    });
  });

  group('Glossary', () {
    testWidgets('terms under their letter; a letter filters; Đọc bài học '
        'opens the lesson', (tester) async {
      await open(tester, '/academy/glossary');
      expect(find.text('Thuật ngữ'), findsOneWidget);
      expect(find.byKey(const Key('term-altcoin')), findsOneWidget);
      expect(find.byKey(const Key('term-bitcoin')), findsOneWidget);

      await tester.tap(find.byKey(const Key('letter-B')));
      await frames(tester);
      expect(api.calls.last, 'terms letter=B');
      expect(find.byKey(const Key('term-altcoin')), findsNothing);

      await tester.tap(find.byKey(const Key('letter-all')));
      await frames(tester);
      await tester.tap(find.byKey(const Key('term-lesson-altcoin')));
      await frames(tester);
      expect(find.byType(LessonScreen), findsOneWidget);
      expect(find.text('Title lesson-2'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('no term matches: says so', (tester) async {
      await open(tester, '/academy/glossary');
      await tester.enterText(find.byKey(const Key('glossary-search')), 'zzz');
      await tester.pump(const Duration(milliseconds: 400));
      await frames(tester);
      expect(find.text('Không có thuật ngữ nào khớp.'), findsOneWidget);
      await unmount(tester);
    });
  });

  for (final brightness in Brightness.values) {
    testWidgets('360 dp, ${brightness.name}: the three screens do not '
        'overflow, the table scrolls on its own', (tester) async {
      tester.view
        ..physicalSize = const Size(360 * 3, 760 * 3)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      api.bodies['lesson-2'] = richBody;
      await open(tester, '/academy', brightness: brightness);
      expect(tester.takeException(), isNull);
      expect(
        Theme.of(tester.element(find.byType(AcademyScreen))).brightness,
        brightness,
      );
      await tester.drag(
        find.byKey(const Key('academy-list')),
        const Offset(0, -1500),
      );
      await frames(tester);
      expect(tester.takeException(), isNull);

      unawaited(
        containerOf(
          tester,
        ).read(appRouterProvider).push(lessonLocation('lesson-2')),
      );
      await frames(tester);
      expect(tester.takeException(), isNull);
      await tester.drag(
        find.byKey(const Key('lesson-page')),
        const Offset(0, -500),
      );
      await frames(tester);
      expect(tester.takeException(), isNull);
      final table = find.byKey(const Key('lesson-table'));
      expect(table, findsOneWidget);
      expect(tester.getSize(table).width, lessThanOrEqualTo(360));

      unawaited(
        containerOf(tester).read(appRouterProvider).push('/academy/glossary'),
      );
      await frames(tester);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  }

  group('ways in', () {
    Future<void> home(WidgetTester tester) async {
      transport = FakeTransport();
      await tester.pumpWidget(
        ProviderScope(
          overrides: baseOverrides(
            store: MemoryTokenStore(storedFor('saved')),
            tokens: FakeAuthTokenApi(),
            transport: transport,
            web: web,
            academy: api,
          ),
          retry: (_, _) => null,
          child: const CryptoPilotApp(),
        ),
      );
      await frames(tester);
      transport.last.onConnected();
      await frames(tester);
    }

    Finder homeList() => find
        .descendant(
          of: find.byType(HomeScreen),
          matching: find.byType(Scrollable),
        )
        .first;

    testWidgets('the Home card shows the path progress, opens the Academy and '
        'follows a mark made there', (tester) async {
      await home(tester);
      await tester.scrollUntilVisible(
        find.byKey(const Key('home-academy')),
        300,
        scrollable: homeList(),
      );
      expect(find.text('Beginner path 1/3'), findsOneWidget);
      await tester.tap(find.byKey(const Key('home-academy')));
      await frames(tester);
      expect(find.byType(AcademyScreen), findsOneWidget);

      unawaited(
        containerOf(
          tester,
        ).read(appRouterProvider).push(lessonLocation('lesson-3')),
      );
      await frames(tester);
      await tester.scrollUntilVisible(
        find.byKey(const Key('lesson-mark')),
        300,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('lesson-page')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.byKey(const Key('lesson-mark')));
      await frames(tester);
      // Both pages leave; Home was kept under them.
      await tester.pageBack();
      await frames(tester);
      await tester.pageBack();
      await frames(tester);
      expect(find.text('Beginner path 2/3'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('the account screen opens the Academy', (tester) async {
      await home(tester);
      await tester.tap(find.byKey(const Key('open-account')));
      await frames(tester);
      await tester.scrollUntilVisible(
        find.byKey(const Key('open-academy')),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.byKey(const Key('open-academy')));
      await frames(tester);
      expect(find.byType(AcademyScreen), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('T-151: the account groups demo trading and learning under '
        'their own headings', (tester) async {
      await home(tester);
      await tester.tap(find.byKey(const Key('open-account')));
      await frames(tester);
      await tester.scrollUntilVisible(
        find.text('LEARN AND SHARE'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('DEMO TRADING'), findsOneWidget);
      expect(find.text('LEARN AND SHARE'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('progress that cannot be read leaves the card without it', (
      tester,
    ) async {
      api.progressError = problem(503, 'UNAVAILABLE', 'MSG43');
      await home(tester);
      await tester.scrollUntilVisible(
        find.byKey(const Key('home-academy')),
        300,
        scrollable: homeList(),
      );
      expect(find.text('Learn crypto step by step'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('links and dates', () {
    test('lesson paths map to the app screens it has; the rest to the web', () {
      expect(academyLinkTarget('/markets'), isA<AppScreen>());
      expect((academyLinkTarget('/markets') as AppScreen).tab, isTrue);
      expect((academyLinkTarget('/alerts') as AppScreen).tab, isFalse);
      // FE owner 2026-11-19 (T-131): `/trade/spot` opens the Trade tab now
      // that the app has it; it was a web path until then.
      expect(academyLinkTarget('/trade/spot'), isA<TradeTab>());
      // The journal is in the app since T-091 (it opened the web before).
      final journal = academyLinkTarget('/journal');
      expect(journal, isA<AppScreen>());
      expect((journal as AppScreen).location, '/plans?tab=journal');
      for (final path in ['/plans/new', '/x']) {
        expect(academyLinkTarget(path), isA<WebPath>(), reason: path);
      }
      expect(academyLinkTarget('https://a.test'), isA<WebAddress>());
    });

    test('dates read dd/MM/yyyy whatever the device language', () {
      expect(academyDate(DateTime(2026, 3, 7, 12)), '07/03/2026');
    });
  });
}
