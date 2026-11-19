import 'dart:async';

import 'package:cryptopilot_mobile/app.dart';
import 'package:cryptopilot_mobile/core/auth/token_store.dart';
import 'package:cryptopilot_mobile/core/router/app_router.dart';
import 'package:cryptopilot_mobile/core/settings/settings.dart';
import 'package:cryptopilot_mobile/features/ai/data/ai_api.dart';
import 'package:cryptopilot_mobile/features/ai/domain/ai.dart';
import 'package:cryptopilot_mobile/features/ai/presentation/ai_answer.dart';
import 'package:cryptopilot_mobile/features/ai/presentation/ai_chat_screen.dart';
import 'package:cryptopilot_mobile/features/ai/presentation/ai_conversations_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ai_fakes.dart';
import '../support/fakes.dart';
import '../support/realtime_fakes.dart';

void main() {
  late FakeAiApi api;
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
    Object? extra,
    Brightness brightness = Brightness.light,
  }) async {
    transport = FakeTransport();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...baseOverrides(
            store: MemoryTokenStore(storedFor('saved')),
            tokens: FakeAuthTokenApi(),
            transport: transport,
            web: web,
          ),
          aiApiProvider.overrideWithValue(api),
        ],
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
    unawaited(container.read(appRouterProvider).push(location, extra: extra));
    await frames(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 31));
  }

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const Key('ai-input')), text);
    await tester.pump();
  }

  bool sendEnabled(WidgetTester tester) =>
      tester.widget<IconButton>(find.byKey(const Key('ai-send'))).onPressed !=
      null;

  setUp(() {
    api = FakeAiApi()
      ..conversationList = [
        conversationOf('c1', pairId: 'pair-BTC'),
        conversationOf(
          'c2',
          topic: ConversationTopic.myTrading,
          title: 'Risk of my ETH plan',
          updatedAt: aiNow.subtract(const Duration(days: 1)),
        ),
      ];
    web = FakeWebLinks();
  });

  group('answer text', () {
    test('paragraphs, bullet and numbered lists', () {
      final blocks = answerBlocks(
        'RSI is high.\nIt rose fast.\n\n- Support 90k\n- Resistance 95k\n'
        '1. Wait\n2. Review\n\nFor reference only.',
      );
      expect(blocks, hasLength(3));
      expect((blocks[0] as AnswerParagraph).text, 'RSI is high. It rose fast.');
      expect((blocks[1] as AnswerList).items, [
        'Support 90k',
        'Resistance 95k',
        'Wait',
        'Review',
      ]);
      expect((blocks[2] as AnswerParagraph).text, 'For reference only.');
    });

    test('bold, and citations only for stored sources (BR-51)', () {
      const source = AiSource(
        ref: 1,
        origin: 'NEWS',
        url: 'https://news.example/1',
      );
      final spans = answerSpans('A **strong** move [1], not [2].', {1: source});
      expect(spans[1], isA<PlainSpan>().having((s) => s.bold, 'bold', true));
      expect(
        spans.whereType<CitationSpan>().single.sources.single.url,
        source.url,
      );
      expect(
        spans.whereType<PlainSpan>().map((s) => s.text).join(),
        contains('[2]'),
      );
    });
  });

  group('SCR-29 list', () {
    testWidgets('grouped by day, filtered by topic, quota beside the title', (
      tester,
    ) async {
      await open(tester, '/ai');
      expect(find.byType(AiConversationsScreen), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Yesterday'), findsOneWidget);
      expect(find.text('BTC on 4h'), findsOneWidget);
      expect(find.text('17/20 today'), findsOneWidget);

      // The chips scroll sideways on a narrow screen.
      await tester.ensureVisible(find.byKey(const Key('ai-filter-MY_TRADING')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('ai-filter-MY_TRADING')));
      await frames(tester);
      expect(find.text('BTC on 4h'), findsNothing);
      expect(find.text('Risk of my ETH plan'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('empty list invites a first question', (tester) async {
      api.conversationList = [];
      await open(tester, '/ai');
      expect(find.byKey(const Key('ai-empty')), findsOneWidget);
      expect(find.text('No conversations yet.'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('swipe, confirm and the conversation is deleted', (
      tester,
    ) async {
      await open(tester, '/ai');
      await tester.drag(
        find.byKey(const Key('ai-conversation-c1')),
        const Offset(-600, 0),
      );
      await frames(tester);
      expect(find.text('Delete this conversation?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('ai-delete-confirm')));
      await frames(tester);
      expect(api.calls, contains('delete c1'));
      expect(find.text('BTC on 4h'), findsNothing);
      expect(find.text('Conversation deleted.'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('SCR-29 chat', () {
    testWidgets('New → Market analysis: a coin is needed, then the question '
        'waits and the pushed answer shows with its disclaimer', (
      tester,
    ) async {
      await open(tester, '/ai');
      await tester.tap(find.byKey(const Key('ai-new')));
      await frames(tester);
      await tester.tap(find.byKey(const Key('ai-mode-MARKET')));
      await frames(tester);
      expect(find.byType(AiChatScreen), findsOneWidget);
      expect(find.byKey(const Key('ai-chat-empty')), findsOneWidget);
      expect(
        find.text('Pick a coin for the assistant to analyse.'),
        findsOneWidget,
      );
      await type(tester, 'How is it doing?');
      expect(sendEnabled(tester), isFalse);

      await tester.tap(find.byKey(const Key('ai-context-pair')));
      await frames(tester);
      await tester.tap(find.byKey(const Key('ai-pair-market')).last);
      await tester.tap(find.text('Futures').last);
      await frames(tester);
      await tester.tap(find.byKey(const Key('ai-pair-BTCUSDT-FUTURES')));
      await frames(tester);
      expect(find.text('BTCUSDT · Futures'), findsOneWidget);
      expect(sendEnabled(tester), isTrue);

      await tester.tap(find.byKey(const Key('ai-send')));
      await frames(tester);
      expect(api.asked.single.toJson(), {
        'question': 'How is it doing?',
        'pairId': 'pair-BTC',
        'market': 'FUTURES',
        'timeframe': '1h',
      });
      expect(find.byKey(const Key('ai-typing')), findsOneWidget);
      expect(find.text('16/20 today'), findsOneWidget);
      expect(sendEnabled(tester), isFalse);

      final question = api.messagesOf['new1']!.last;
      final answer = api.answer('new1', question.id);
      transport.last.push(aiQueue, {
        'conversationId': 'new1',
        'questionId': question.id,
        'status': 'COMPLETED',
        'answer': messageJsonOf(answer),
      });
      await frames(tester);
      expect(find.byKey(const Key('ai-typing')), findsNothing);
      expect(find.byKey(Key('ai-answer-${answer.id}')), findsOneWidget);
      expect(find.byKey(Key('ai-disclaimer-${answer.id}')), findsOneWidget);
      expect(
        find.text('For reference only, not investment advice.'),
        findsOneWidget,
      );
      await unmount(tester);
    });

    testWidgets('Ask AI from SCR-10/11 opens a chat on that pair', (
      tester,
    ) async {
      await open(
        tester,
        '/ai/new?topic=MARKET&pair=pair-ETH&symbol=ETHUSDT&market=SPOT&tf=4h',
      );
      expect(find.text('ETHUSDT · Spot'), findsOneWidget);
      expect(find.text('4h ▾'), findsOneWidget);
      await type(tester, 'Where is support?');
      expect(sendEnabled(tester), isTrue);
      await unmount(tester);
    });

    testWidgets('an answer with sources: citations and Sources open the '
        'article; Copy copies', (tester) async {
      api.messagesOf['c1'] = [
        messageOf('q0', role: AiSenderRole.user, content: 'News?'),
        messageOf(
          'a0',
          content: 'Bitcoin **held** 90k [1].\n\n- ETF inflows\n- Low funding',
          sources: [
            AiSource(
              ref: 1,
              origin: 'NEWS',
              headline: 'Bitcoin holds 90k',
              outlet: 'Example News',
              publishedAt: aiNow,
              url: 'https://news.example/btc',
            ),
          ],
        ),
      ];
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await open(tester, '/ai/c/c1', extra: api.conversationList.first);
      expect(find.text('Sources'), findsOneWidget);
      expect(find.textContaining('ETF inflows'), findsOneWidget);
      await tester.tap(find.byKey(const Key('ai-source-a0-1')));
      await tester.pump();
      expect(web.opened, contains('https://news.example/btc'));
      await tester.tap(find.byKey(const Key('ai-copy-a0')));
      await frames(tester);
      expect(find.text('Answer copied.'), findsOneWidget);
      expect(copied, startsWith('Bitcoin **held** 90k [1].'));
      await unmount(tester);
    });

    testWidgets('a FAILED answer shows MSG31 and Try again asks again', (
      tester,
    ) async {
      api.messagesOf['c1'] = [
        messageOf(
          'q9',
          role: AiSenderRole.user,
          status: AiMessageStatus.failed,
          content: 'Where is resistance?',
        ),
      ];
      await open(tester, '/ai/c/c1', extra: api.conversationList.first);
      expect(
        find.text(
          'The AI Assistant is temporarily unavailable. Please try again.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('ai-retry-q9')));
      await frames(tester);
      expect(api.asked.single.text, 'Where is resistance?');
      expect(api.asked.single.pairId, 'pair-BTC');
      await unmount(tester);
    });

    testWidgets('FREE (BR-52): old conversations read, the input gives way to '
        'the upgrade card', (tester) async {
      api.quotaValue = quotaOf(limit: 0, remaining: 0, used: 0, canAsk: false);
      await open(tester, '/ai/c/c1', extra: api.conversationList.first);
      expect(find.byKey(const Key('ai-answer-a0')), findsOneWidget);
      expect(find.byKey(const Key('ai-input')), findsNothing);
      expect(
        find.text('The AI assistant is on PRO and PREMIUM'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('ai-quota')), findsNothing);
      await tester.tap(find.byKey(const Key('ai-upgrade-open')));
      await tester.pump();
      expect(web.opened, ['/subscription']);
      await unmount(tester);
    });

    testWidgets("today's quota used up: MSG30 and no input (BR-50)", (
      tester,
    ) async {
      api.quotaValue = quotaOf(remaining: 0, used: 20, canAsk: false);
      await open(tester, '/ai/c/c1', extra: api.conversationList.first);
      expect(
        find.text("You have used today's 20 questions. Quota resets at 00:00."),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(find.byKey(const Key('ai-input'))).enabled,
        isFalse,
      );
      await unmount(tester);
    });

    testWidgets('a 429 MSG30 refusal shows its words in line', (tester) async {
      api.failNext['ask'] = problem(
        429,
        'AI_DAILY_QUOTA_EXHAUSTED',
        'MSG30',
        args: ['20'],
      );
      await open(tester, '/ai/c/c1', extra: api.conversationList.first);
      await type(tester, 'One more?');
      await tester.tap(find.byKey(const Key('ai-send')));
      await frames(tester);
      expect(find.byKey(const Key('ai-notice')), findsOneWidget);
      expect(find.textContaining("today's 20 questions"), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('a 403 MSG29 refusal is a dialog that opens the plans', (
      tester,
    ) async {
      api.failNext['ask'] = problem(
        403,
        'PLAN_FEATURE_NOT_INCLUDED',
        'MSG29',
        args: ['PREMIUM'],
      );
      await open(tester, '/ai/c/c1', extra: api.conversationList.first);
      await type(tester, 'And my performance?');
      await tester.tap(find.byKey(const Key('ai-send')));
      await frames(tester);
      expect(find.byKey(const Key('ai-msg29')), findsOneWidget);
      expect(
        find.text(
          'This feature is available on the PREMIUM plan or higher. '
          'View plans?',
        ),
        findsWidgets,
      );
      await tester.tap(find.byKey(const Key('ai-msg29-open')));
      await frames(tester);
      expect(web.opened, ['/subscription']);
      await unmount(tester);
    });

    testWidgets('My plan & performance: a plan from the picker; performance '
        'locked below PREMIUM', (tester) async {
      await open(tester, aiNewLocationFor(ConversationTopic.myTrading));
      expect(find.text('Trading performance: PREMIUM only'), findsOneWidget);
      expect(
        tester
            .widget<FilterChip>(find.byKey(const Key('ai-context-performance')))
            .onSelected,
        isNull,
      );
      expect(
        find.text('Your email, name and capital are never sent.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('ai-context-plan')));
      await frames(tester);
      await tester.tap(find.byKey(const Key('ai-plan-p1')));
      await frames(tester);
      expect(find.text('Plan BTCUSDT Long'), findsOneWidget);
      await type(tester, 'Risks?');
      await tester.tap(find.byKey(const Key('ai-send')));
      await frames(tester);
      expect(api.asked.single.toJson(), {'question': 'Risks?', 'planId': 'p1'});
      await unmount(tester);
    });

    testWidgets('rename and delete from the chat menu', (tester) async {
      await open(tester, '/ai/c/c1', extra: api.conversationList.first);
      await tester.tap(find.byKey(const Key('ai-chat-menu')));
      await frames(tester);
      await tester.tap(find.byKey(const Key('ai-chat-rename')));
      await frames(tester);
      await tester.enterText(
        find.byKey(const Key('ai-rename-field')),
        'Support levels',
      );
      await tester.tap(find.byKey(const Key('ai-rename-save')));
      await frames(tester);
      expect(find.text('Support levels'), findsOneWidget);

      await tester.tap(find.byKey(const Key('ai-chat-menu')));
      await frames(tester);
      await tester.tap(find.byKey(const Key('ai-chat-delete')));
      await frames(tester);
      await tester.tap(find.byKey(const Key('ai-delete-confirm')));
      await frames(tester);
      expect(api.calls, contains('delete c1'));
      expect(find.byType(AiChatScreen), findsNothing);
      await unmount(tester);
    });

    testWidgets('a chat opened without its conversation is found in the list, '
        'or MSG41', (tester) async {
      await open(tester, '/ai/c/c2');
      expect(find.byType(AiChatScreen), findsOneWidget);
      expect(find.text('Risk of my ETH plan'), findsOneWidget);
      await unmount(tester);

      await open(tester, '/ai/c/gone');
      expect(find.byKey(const Key('ai-chat-missing')), findsOneWidget);
      expect(find.text('No results found.'), findsOneWidget);
      await unmount(tester);
    });
  });

  for (final brightness in Brightness.values) {
    testWidgets('360 dp, ${brightness.name}: list and chat do not overflow', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(360 * 3, 760 * 3)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      api.conversationList = [
        conversationOf(
          'c1',
          pairId: 'pair-BTC',
          title: 'A very long conversation title that does not fit on one line',
        ),
      ];
      api.messagesOf['c1'] = [
        messageOf('q0', role: AiSenderRole.user, content: 'Why? ' * 40),
        messageOf('a0', content: 'Because. ' * 80),
      ];
      await open(tester, '/ai', brightness: brightness);
      expect(tester.takeException(), isNull);
      expect(
        Theme.of(tester.element(find.byType(AiConversationsScreen))).brightness,
        brightness,
      );
      await tester.tap(find.byKey(const Key('ai-conversation-c1')));
      await frames(tester);
      expect(find.byType(AiChatScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await type(tester, 'x' * 300);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  }
}

String aiNewLocationFor(ConversationTopic topic) =>
    '/ai/new?topic=${topic.wire}';
