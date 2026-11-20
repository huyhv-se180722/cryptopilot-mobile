import 'package:cryptopilot_mobile/core/errors/api_failure.dart';
import 'package:cryptopilot_mobile/core/errors/message_text.dart';
import 'package:cryptopilot_mobile/core/i18n/app_localizations_en.dart';
import 'package:cryptopilot_mobile/core/json/json_read.dart';
import 'package:cryptopilot_mobile/features/ai/data/ai_api.dart';
import 'package:cryptopilot_mobile/features/ai/domain/ai.dart';
import 'package:cryptopilot_mobile/features/market/domain/candle.dart';
import 'package:cryptopilot_mobile/features/market/domain/market.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/http_fakes.dart';

/// Shapes of backend develop 5c2398cb (`ai/dto/response`).
Map<String, Object?> conversationJson({
  String id = 'c1',
  Object? title = 'BTC on 4h',
  Object? topic = 'MARKET',
}) => {
  'id': id,
  'title': title,
  'topic': topic,
  'pairId': topic == 'MY_TRADING' ? null : 'p-btc',
  'createdAt': '2026-11-19T07:00:00Z',
  'updatedAt': '2026-11-19T07:05:00Z',
};

Map<String, Object?> messageJson({
  String id = 'm1',
  Object? role = 'ASSISTANT',
  Object? status = 'COMPLETED',
  Object? sources = const <Object?>[],
}) => {
  'id': id,
  'conversationId': 'c1',
  'role': role,
  'content': 'RSI is near 70 [1].\n\nFor reference only.',
  'status': status,
  'createdAt': '2026-11-19T07:05:00Z',
  'sources': sources,
};

Map<String, Object?> quotaJson({
  Object? limit = 20,
  Object? remaining = 17,
  bool canAsk = true,
  bool performance = false,
}) => {
  'limit': limit,
  'used': 3,
  'remaining': remaining,
  'resetsAt': '2026-11-19T17:00:00Z',
  'canAsk': canAsk,
  'performanceContext': performance,
};

void main() {
  group('AI decoders (backend develop 5c2398cb)', () {
    test('a page of conversations; an untitled one has a null title', () {
      final page = decodeConversationPage({
        'items': [
          conversationJson(),
          conversationJson(id: 'c2', title: null, topic: 'MY_TRADING'),
        ],
        'page': 1,
        'pageSize': 20,
        'total': 21,
      });
      expect(page.items.first.topic, ConversationTopic.market);
      expect(page.items.first.pairId, 'p-btc');
      expect(page.items.last.title, isNull);
      expect(page.items.last.topic, ConversationTopic.myTrading);
      expect(page.hasMore, isTrue);
      expect(page.items.first.updatedAt.isUtc, isTrue);
    });

    test('a message with the articles it cites', () {
      final message = decodeMessage(
        messageJson(
          sources: [
            {
              'ref': 1,
              'origin': 'NEWS',
              'headline': 'Bitcoin holds 90k',
              'outlet': 'Example News',
              'publishedAt': '2026-11-19T06:00:00Z',
              'url': 'https://news.example/btc',
            },
          ],
        ),
      );
      expect(message.role, AiSenderRole.assistant);
      expect(message.status, AiMessageStatus.completed);
      expect(message.sources.single.ref, 1);
      expect(message.sources.single.headline, 'Bitcoin holds 90k');
    });

    test('a question without sources (null or missing) has none', () {
      expect(
        decodeMessage(messageJson(role: 'USER', sources: null)).sources,
        isEmpty,
      );
      final json = messageJson()..remove('sources');
      expect(decodeMessage(json).sources, isEmpty);
    });

    test('quota: limited, unlimited, not included (FREE) and used up', () {
      final pro = decodeQuota(quotaJson());
      expect((pro.limit, pro.remaining, pro.canAsk), (20, 17, true));
      expect(pro.unlimited || pro.notIncluded || pro.exhausted, isFalse);

      final premium = decodeQuota(
        quotaJson(limit: null, remaining: null, performance: true),
      );
      expect(premium.unlimited, isTrue);
      expect(premium.performanceContext, isTrue);

      final free = decodeQuota(
        quotaJson(limit: 0, remaining: 0, canAsk: false),
      );
      expect(free.notIncluded, isTrue);
      expect(free.exhausted, isFalse);

      final usedUp = decodeQuota(quotaJson(remaining: 0, canAsk: false));
      expect(usedUp.exhausted, isTrue);
      expect(usedUp.notIncluded, isFalse);
    });

    test('the 202 of a question carries it PENDING with the quota', () {
      final result = decodeAskResult({
        'question': messageJson(role: 'USER', status: 'PENDING'),
        'quota': quotaJson(remaining: 16),
      });
      expect(result.question.status, AiMessageStatus.pending);
      expect(result.quota.remaining, 16);
    });

    test('a push is COMPLETED with its answer or FAILED without one', () {
      final done = decodeAnswerPush({
        'conversationId': 'c1',
        'questionId': 'q1',
        'status': 'COMPLETED',
        'answer': messageJson(),
      });
      expect(done.answer?.id, 'm1');
      final failed = decodeAnswerPush({
        'conversationId': 'c1',
        'questionId': 'q1',
        'status': 'FAILED',
        'answer': null,
      });
      expect(failed.status, AiMessageStatus.failed);
      expect(failed.answer, isNull);
    });

    test('bad shapes and unknown values are refused, never guessed', () {
      void refuses(void Function() decode) =>
          expect(decode, throwsA(isA<DecodeException>()));

      refuses(() => decodeConversation(conversationJson(topic: 'NEWS')));
      refuses(() => decodeMessage(messageJson(status: 'QUEUED')));
      refuses(() => decodeMessage(messageJson(role: 'SYSTEM')));
      refuses(() => decodeMessage(messageJson(sources: 'none')));
      refuses(() => decodeQuota(quotaJson(limit: '20')));
      refuses(() => decodeConversationPage({'items': null}));
      refuses(
        () => decodeAnswerPush({
          'conversationId': 'c1',
          'questionId': 'q1',
          'status': 'PENDING',
        }),
      );
      refuses(
        () => decodeAnswerPush({
          'conversationId': 'c1',
          'questionId': 'q1',
          'status': 'COMPLETED',
          'answer': null,
        }),
      );
    });
  });

  group('AiQuestion sends only the data it carries', () {
    test('a pair question names the pair, market and timeframe', () {
      const question = AiQuestion(
        text: 'How is BTC on 4h?',
        pairId: 'p-btc',
        market: Market.futures,
        timeframe: Timeframe.h4,
      );
      expect(question.toJson(), {
        'question': 'How is BTC on 4h?',
        'pairId': 'p-btc',
        'market': 'FUTURES',
        'timeframe': '4h',
      });
    });

    test('a plan question carries the plan and, if asked, performance', () {
      const question = AiQuestion(
        text: 'Risks?',
        planId: 'plan-1',
        includePerformance: true,
      );
      expect(question.toJson(), {
        'question': 'Risks?',
        'planId': 'plan-1',
        'includePerformance': true,
      });
    });

    test('a general question carries the text only', () {
      expect(const AiQuestion(text: 'What is DCA?').toJson(), {
        'question': 'What is DCA?',
      });
    });
  });

  group('DioAiApi', () {
    late RecordingAdapter adapter;
    late AiApi api;

    setUp(() {
      adapter = RecordingAdapter();
      api = DioAiApi(
        Dio(BaseOptions(baseUrl: 'http://backend.test/api/v1/'))
          ..httpClientAdapter = adapter,
      );
    });

    test('lists one topic, or every topic without the filter', () async {
      final page = {
        'items': [conversationJson()],
        'page': 1,
        'pageSize': 20,
        'total': 1,
      };
      adapter.answers.addAll([(200, page), (200, page)]);
      await api.conversations(topic: ConversationTopic.myTrading);
      await api.conversations(page: 2);
      expect(adapter.requests[0].path, 'ai/conversations');
      expect(adapter.requests[0].queryParameters, {
        'topic': 'MY_TRADING',
        'page': 1,
        'pageSize': 20,
      });
      expect(adapter.requests[1].queryParameters, {'page': 2, 'pageSize': 20});
    });

    test('starts, renames and deletes a conversation', () async {
      adapter.answers.addAll([
        (201, conversationJson()),
        (200, conversationJson(title: 'Renamed')),
        (204, null),
      ]);
      await api.start(topic: ConversationTopic.market, pairId: 'p-btc');
      final renamed = await api.rename('c1', 'Renamed');
      await api.delete('c1');
      expect(adapter.requests[0].method, 'POST');
      expect(adapter.requests[0].data, {'topic': 'MARKET', 'pairId': 'p-btc'});
      expect(adapter.requests[1].method, 'PATCH');
      expect(adapter.requests[1].path, 'ai/conversations/c1');
      expect(adapter.requests[1].data, {'title': 'Renamed'});
      expect(renamed.title, 'Renamed');
      expect(adapter.requests[2].method, 'DELETE');
    });

    test('asks with the question body and reads messages', () async {
      adapter.answers.addAll([
        (
          202,
          {
            'question': messageJson(role: 'USER', status: 'PENDING'),
            'quota': quotaJson(),
          },
        ),
        (
          200,
          {
            'items': [messageJson()],
            'page': 1,
            'pageSize': 50,
            'total': 1,
          },
        ),
      ]);
      await api.ask('c1', const AiQuestion(text: 'What is DCA?'));
      final page = await api.messages('c1');
      expect(adapter.requests[0].path, 'ai/conversations/c1/messages');
      expect(adapter.requests[0].data, {'question': 'What is DCA?'});
      expect(adapter.requests[1].queryParameters, {'page': 1, 'pageSize': 50});
      expect(page.items.single.status, AiMessageStatus.completed);
    });

    test('403 MSG29 and 429 MSG30 reach the screen with their words', () async {
      adapter.answers.addAll([
        (
          403,
          {
            'status': 403,
            'code': 'PLAN_FEATURE_NOT_INCLUDED',
            'messageCode': 'MSG29',
            'messageArgs': ['PRO'],
          },
        ),
        (
          429,
          {
            'status': 429,
            'code': 'AI_DAILY_QUOTA_EXHAUSTED',
            'messageCode': 'MSG30',
            'messageArgs': ['20'],
          },
        ),
      ]);
      final l = AppLocalizationsEn();
      Future<ProblemFailure> failure(Future<Object?> call) async {
        try {
          await call;
        } on ProblemFailure catch (error) {
          return error;
        }
        fail('expected a ProblemFailure');
      }

      final notIncluded = await failure(
        api.ask('c1', const AiQuestion(text: 'Hi')),
      );
      expect(notIncluded.code, 'PLAN_FEATURE_NOT_INCLUDED');
      expect(
        failureText(l, notIncluded),
        'This feature is available on the PRO plan or higher. View plans?',
      );
      final usedUp = await failure(api.ask('c1', const AiQuestion(text: 'Hi')));
      expect(usedUp.code, 'AI_DAILY_QUOTA_EXHAUSTED');
      expect(
        failureText(l, usedUp),
        "You have used today's 20 questions. Quota resets at 00:00.",
      );
    });

    test('MSG31 has its words for a FAILED answer', () {
      expect(
        messageText(AppLocalizationsEn(), 'MSG31'),
        'The AI Assistant is temporarily unavailable. Please try again.',
      );
    });
  });
}
