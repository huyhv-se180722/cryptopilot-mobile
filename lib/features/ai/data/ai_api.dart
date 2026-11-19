import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/http/http_providers.dart';
import '../domain/ai.dart';

/// The Trader's queue an answer, or FAILED, is pushed to.
const aiQueue = '/user/queue/ai';

/// `/ai` of SCR-29 (UC-30; checked on backend develop 5c2398cb). Reading is
/// open on every plan (BR-52); starting and asking refuse 403 MSG29 on a plan
/// without the AI Assistant, and asking refuses 429 MSG30 once today's quota
/// is used up.
abstract interface class AiApi {
  /// Last asked first; every topic when [topic] is null.
  Future<AiPage<AiConversation>> conversations({
    ConversationTopic? topic,
    int page = 1,
    int pageSize = 20,
  });

  /// 403 MSG29, 404 MSG41 (pair), 400 MSG01 (a MY_TRADING pair).
  Future<AiConversation> start({
    required ConversationTopic topic,
    String? pairId,
    String? title,
  });

  /// 400 MSG01, 404 MSG41.
  Future<AiConversation> rename(String id, String title);

  /// 404 MSG41. Today's questions of it still count (BR-50).
  Future<void> delete(String id);

  /// Newest first.
  Future<AiPage<AiMessage>> messages(
    String conversationId, {
    int page = 1,
    int pageSize = 50,
  });

  /// 202 with the PENDING question; the outcome arrives on [aiQueue].
  /// 400 MSG01, 403 MSG29, 404 MSG41, 429 MSG30.
  Future<AiAskResult> ask(String conversationId, AiQuestion question);

  Future<AiQuota> quota();
}

class DioAiApi implements AiApi {
  const DioAiApi(this._dio);

  final Dio _dio;

  @override
  Future<AiPage<AiConversation>> conversations({
    ConversationTopic? topic,
    int page = 1,
    int pageSize = 20,
  }) => apiCall(
    () => _dio.get<Object?>(
      'ai/conversations',
      queryParameters: {
        'topic': ?topic?.wire,
        'page': page,
        'pageSize': pageSize,
      },
    ),
    decodeConversationPage,
  );

  @override
  Future<AiConversation> start({
    required ConversationTopic topic,
    String? pairId,
    String? title,
  }) => apiCall(
    () => _dio.post<Object?>(
      'ai/conversations',
      data: {'topic': topic.wire, 'pairId': ?pairId, 'title': ?title},
    ),
    decodeConversation,
  );

  @override
  Future<AiConversation> rename(String id, String title) => apiCall(
    () => _dio.patch<Object?>(
      'ai/conversations/${Uri.encodeComponent(id)}',
      data: {'title': title},
    ),
    decodeConversation,
  );

  @override
  Future<void> delete(String id) => apiCall(
    () => _dio.delete<Object?>('ai/conversations/${Uri.encodeComponent(id)}'),
    (_) {},
  );

  @override
  Future<AiPage<AiMessage>> messages(
    String conversationId, {
    int page = 1,
    int pageSize = 50,
  }) => apiCall(
    () => _dio.get<Object?>(
      'ai/conversations/${Uri.encodeComponent(conversationId)}/messages',
      queryParameters: {'page': page, 'pageSize': pageSize},
    ),
    decodeMessagePage,
  );

  @override
  Future<AiAskResult> ask(String conversationId, AiQuestion question) =>
      apiCall(
        () => _dio.post<Object?>(
          'ai/conversations/${Uri.encodeComponent(conversationId)}/messages',
          data: question.toJson(),
        ),
        decodeAskResult,
      );

  @override
  Future<AiQuota> quota() =>
      apiCall(() => _dio.get<Object?>('ai/quota'), decodeQuota);
}

final aiApiProvider = Provider<AiApi>(
  (ref) => DioAiApi(ref.watch(apiDioProvider)),
);
