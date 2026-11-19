import 'package:cryptopilot_mobile/core/auth/token_store.dart';
import 'package:cryptopilot_mobile/core/errors/api_failure.dart';
import 'package:cryptopilot_mobile/features/ai/application/ai_chat_controller.dart';
import 'package:cryptopilot_mobile/features/ai/application/ai_context.dart';
import 'package:cryptopilot_mobile/features/ai/application/ai_conversations_controller.dart';
import 'package:cryptopilot_mobile/features/ai/application/ai_quota.dart';
import 'package:cryptopilot_mobile/features/ai/data/ai_api.dart';
import 'package:cryptopilot_mobile/features/ai/domain/ai.dart';
import 'package:cryptopilot_mobile/features/market/domain/candle.dart';
import 'package:cryptopilot_mobile/features/market/domain/market.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ai_fakes.dart';
import '../support/fakes.dart';
import '../support/realtime_fakes.dart';

void main() {
  late FakeTransport transport;
  late FakeAiApi api;
  late ProviderContainer container;

  Future<void> pump(
    WidgetTester tester,
    List<ProviderListenable<Object?>> watched,
  ) async {
    transport = FakeTransport();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...baseOverrides(
            store: MemoryTokenStore(storedFor('saved')),
            tokens: FakeAuthTokenApi(),
            transport: transport,
          ),
          aiApiProvider.overrideWithValue(api),
        ],
        retry: (_, _) => null,
        child: Consumer(
          builder: (context, ref, _) {
            for (final provider in watched) {
              ref.watch(provider);
            }
            return const SizedBox();
          },
        ),
      ),
    );
    container = ProviderScope.containerOf(
      tester.element(find.byType(Consumer)),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }
    // The list alone opens no realtime connection.
    if (transport.connections.isNotEmpty) transport.last.onConnected();
    await tester.pump();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 31));
  }

  setUp(() => api = FakeAiApi());

  group('conversation list (BR-52: readable on every plan)', () {
    testWidgets('every topic, then one topic; rename and delete in place', (
      tester,
    ) async {
      await pump(tester, [aiConversationsControllerProvider]);
      AiConversationsState read() =>
          container.read(aiConversationsControllerProvider);
      final list = container.read(aiConversationsControllerProvider.notifier);
      expect(read().items!.map((c) => c.id), ['c1', 'c2']);

      await list.show(ConversationTopic.myTrading);
      expect(read().items!.map((c) => c.id), ['c2']);
      expect(api.calls, contains('conversations MY_TRADING 1'));

      await list.rename('c2', 'Plan review');
      expect(read().items!.single.title, 'Plan review');
      await list.delete('c2');
      expect(read().items, isEmpty);
      expect(read().total, 0);
      await unmount(tester);
    });

    testWidgets('a failed read keeps the failure for the retry state', (
      tester,
    ) async {
      api.failNext['conversations'] = const NetworkFailure();
      await pump(tester, [aiConversationsControllerProvider]);
      final state = container.read(aiConversationsControllerProvider);
      expect(state.items, isNull);
      expect(state.failure, isA<NetworkFailure>());
      await container.read(aiConversationsControllerProvider.notifier).load();
      expect(
        container.read(aiConversationsControllerProvider).items,
        hasLength(2),
      );
      await unmount(tester);
    });

    testWidgets('load more appends the next page once', (tester) async {
      api.conversationList = [
        for (var i = 0; i < 25; i++) conversationOf('c$i'),
      ];
      await pump(tester, [aiConversationsControllerProvider]);
      final list = container.read(aiConversationsControllerProvider.notifier);
      expect(container.read(aiConversationsControllerProvider).hasMore, isTrue);
      await list.loadMore();
      final state = container.read(aiConversationsControllerProvider);
      expect(state.items, hasLength(25));
      expect(state.hasMore, isFalse);
      await unmount(tester);
    });
  });

  group('chat (UC-30)', () {
    final existing = AiChatArgs.existing(conversationOf('c1'));
    const fresh = AiChatArgs.fresh(
      AiContext(
        topic: ConversationTopic.market,
        pairId: 'BTCUSDT-FUT',
        symbol: 'BTCUSDT',
        market: Market.futures,
        timeframe: Timeframe.h4,
      ),
    );

    testWidgets('an existing chat shows its messages oldest first and its '
        'pair as the context', (tester) async {
      final provider = aiChatControllerProvider(existing);
      await pump(tester, [provider]);
      final state = container.read(provider);
      expect(state.messages!.map((m) => m.id), ['q0', 'a0']);
      expect(state.context.topic, ConversationTopic.market);
      expect(state.context.pairId, 'BTCUSDT-SPOT');
      expect(state.waiting, isFalse);
      await unmount(tester);
    });

    testWidgets('the first question creates the conversation, sends only the '
        'pair data, waits, and the pushed answer ends the wait', (
      tester,
    ) async {
      final provider = aiChatControllerProvider(fresh);
      await pump(tester, [provider, aiQuotaProvider]);
      final chat = container.read(provider.notifier);

      expect(await chat.send('  How is BTC on 4h?  '), isTrue);
      expect(
        api.calls,
        containsAllInOrder(['start MARKET BTCUSDT-FUT', 'ask new1']),
      );
      expect(api.asked.single.toJson(), {
        'question': 'How is BTC on 4h?',
        'pairId': 'BTCUSDT-FUT',
        'market': 'FUTURES',
        'timeframe': '4h',
      });
      var state = container.read(provider);
      expect(state.conversation?.id, 'new1');
      expect(state.waiting, isTrue);
      expect(container.read(aiQuotaProvider).quota?.remaining, 16);

      // While it waits, the newest page is read every 3 s.
      final reads = api.calls.where((c) => c.startsWith('messages')).length;
      await tester.pump(AiChatController.pollEvery);
      await tester.pump();
      expect(
        api.calls.where((c) => c.startsWith('messages')).length,
        reads + 1,
      );

      final question = state.messages!.last;
      final answer = api.answer('new1', question.id);
      transport.last.push(aiQueue, {
        'conversationId': 'new1',
        'questionId': question.id,
        'status': 'COMPLETED',
        'answer': messageJsonOf(answer),
      });
      await tester.pump();
      state = container.read(provider);
      expect(state.waiting, isFalse);
      expect(state.messages!.last.id, answer.id);
      expect(
        state.messages!.firstWhere((m) => m.id == question.id).status,
        AiMessageStatus.completed,
      );
      expect(api.calls.last, 'quota');

      // No more reads once nothing waits.
      final after = api.calls.length;
      await tester.pump(AiChatController.pollEvery * 2);
      expect(api.calls.length, after);
      await unmount(tester);
    });

    testWidgets('a FAILED push marks the question (MSG31); Try again asks the '
        'same text once more', (tester) async {
      final provider = aiChatControllerProvider(existing);
      await pump(tester, [provider]);
      final chat = container.read(provider.notifier)
        ..setContext(
          container
              .read(provider)
              .context
              .withPair('BTCUSDT-SPOT', 'BTCUSDT', Market.spot),
        );
      await chat.send('Where is resistance?');
      final question = container.read(provider).messages!.last;
      transport.last.push(aiQueue, {
        'conversationId': 'c1',
        'questionId': question.id,
        'status': 'FAILED',
        'answer': null,
      });
      await tester.pump();
      final failed = container.read(provider).messages!.last;
      expect(failed.status, AiMessageStatus.failed);
      expect(container.read(provider).waiting, isFalse);

      expect(await chat.retry(failed), isTrue);
      expect(api.asked.map((q) => q.text), [
        'Where is resistance?',
        'Where is resistance?',
      ]);
      await unmount(tester);
    });

    testWidgets('a push of another conversation changes nothing', (
      tester,
    ) async {
      final provider = aiChatControllerProvider(existing);
      await pump(tester, [provider]);
      final before = container.read(provider).messages;
      transport.last.push(aiQueue, {
        'conversationId': 'other',
        'questionId': 'q0',
        'status': 'FAILED',
        'answer': null,
      });
      await tester.pump();
      expect(container.read(provider).messages, same(before));
      await unmount(tester);
    });

    testWidgets('429 MSG30 and 403 MSG29 are kept for the screen and the '
        'quota is read again', (tester) async {
      final provider = aiChatControllerProvider(fresh);
      await pump(tester, [provider, aiQuotaProvider]);
      final chat = container.read(provider.notifier);
      api.failNext['ask'] = problem(
        429,
        'AI_DAILY_QUOTA_EXHAUSTED',
        'MSG30',
        args: ['20'],
      );
      final quotaReads = api.calls.where((c) => c == 'quota').length;
      expect(await chat.send('Hi'), isFalse);
      await tester.pump();
      var state = container.read(provider);
      expect(
        (state.sendFailure! as ProblemFailure).problem.messageCode,
        'MSG30',
      );
      expect(state.sending, isFalse);
      expect(api.calls.where((c) => c == 'quota').length, quotaReads + 1);

      api.failNext['ask'] = problem(
        403,
        'PLAN_FEATURE_NOT_INCLUDED',
        'MSG29',
        args: ['PRO'],
      );
      expect(await chat.send('Hi again'), isFalse);
      state = container.read(provider);
      expect(
        (state.sendFailure! as ProblemFailure).problem.messageCode,
        'MSG29',
      );
      await unmount(tester);
    });

    testWidgets('nothing is sent without the data the topic needs, or past '
        '1,000 characters', (tester) async {
      const noPair = AiChatArgs.fresh(
        AiContext(topic: ConversationTopic.market),
      );
      final provider = aiChatControllerProvider(noPair);
      await pump(tester, [provider]);
      final chat = container.read(provider.notifier);
      expect(container.read(provider).context.ready, isFalse);
      expect(await chat.send('How is it?'), isFalse);
      chat.setContext(
        container
            .read(provider)
            .context
            .withPair('ETHUSDT-SPOT', 'ETHUSDT', Market.spot),
      );
      expect(await chat.send('x' * 1001), isFalse);
      expect(api.calls.where((c) => c.startsWith('start')), isEmpty);
      await unmount(tester);
    });

    testWidgets('My plan & performance sends the plan and the performance, '
        'never a pair', (tester) async {
      const mine = AiChatArgs.fresh(
        AiContext(topic: ConversationTopic.myTrading),
      );
      final provider = aiChatControllerProvider(mine);
      await pump(tester, [provider]);
      final chat = container.read(provider.notifier);
      expect(container.read(provider).context.ready, isFalse);
      chat.setContext(
        container
            .read(provider)
            .context
            .withPlan(planOf('plan-1'))
            .withPerformance(include: true),
      );
      expect(await chat.send('Risks?'), isTrue);
      expect(api.calls.first, startsWith('start MY_TRADING null'));
      expect(api.asked.single.toJson(), {
        'question': 'Risks?',
        'planId': 'plan-1',
        'includePerformance': true,
      });
      await unmount(tester);
    });

    testWidgets('a General question carries no data', (tester) async {
      const general = AiChatArgs.fresh(
        AiContext(topic: ConversationTopic.general),
      );
      final provider = aiChatControllerProvider(general);
      await pump(tester, [provider]);
      expect(
        await container.read(provider.notifier).send('What is DCA?'),
        isTrue,
      );
      expect(api.asked.single.toJson(), {'question': 'What is DCA?'});
      await unmount(tester);
    });

    testWidgets('a reconnection reads the newest page again', (tester) async {
      final provider = aiChatControllerProvider(existing);
      await pump(tester, [provider]);
      final reads = api.calls.where((c) => c == 'messages c1 1').length;
      transport.last.drop();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      transport.last.onConnected();
      await tester.pump();
      await tester.pump();
      expect(api.calls.where((c) => c == 'messages c1 1').length, reads + 1);
      await unmount(tester);
    });

    testWidgets('older pages stay when the newest page is read again', (
      tester,
    ) async {
      api.messagesOf['c1'] = [
        for (var i = 0; i < 60; i++)
          messageOf('m$i', at: aiNow.add(Duration(seconds: i))),
      ];
      final provider = aiChatControllerProvider(existing);
      await pump(tester, [provider]);
      final chat = container.read(provider.notifier);
      expect(container.read(provider).messages, hasLength(50));
      expect(container.read(provider).hasOlder, isTrue);
      await chat.loadOlder();
      expect(container.read(provider).messages, hasLength(60));
      expect(container.read(provider).messages!.first.id, 'm0');
      await chat.refresh();
      final ids = container.read(provider).messages!.map((m) => m.id);
      expect(ids, hasLength(60));
      expect(ids.first, 'm0');
      expect(ids.last, 'm59');
      await unmount(tester);
    });

    testWidgets('rename and delete reach the list', (tester) async {
      final provider = aiChatControllerProvider(existing);
      await pump(tester, [provider, aiConversationsControllerProvider]);
      final chat = container.read(provider.notifier);
      await chat.rename('Support levels');
      expect(container.read(provider).conversation?.title, 'Support levels');
      expect(
        container.read(aiConversationsControllerProvider).items!.first.title,
        'Support levels',
      );
      await chat.delete();
      expect(
        container
            .read(aiConversationsControllerProvider)
            .items!
            .map((c) => c.id),
        ['c2'],
      );
      await unmount(tester);
    });
  });
}
