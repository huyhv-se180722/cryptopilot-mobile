import 'package:cryptopilot_mobile/features/ai/data/ai_api.dart';
import 'package:cryptopilot_mobile/features/ai/domain/ai.dart';

final aiNow = DateTime.utc(2026, 11, 19, 7);

AiConversation conversationOf(
  String id, {
  ConversationTopic topic = ConversationTopic.market,
  String? title = 'BTC on 4h',
  String? pairId = 'BTCUSDT-SPOT',
  DateTime? updatedAt,
}) => AiConversation(
  id: id,
  title: title,
  topic: topic,
  pairId: topic == ConversationTopic.market ? pairId : null,
  createdAt: aiNow,
  updatedAt: updatedAt ?? aiNow,
);

AiMessage messageOf(
  String id, {
  String conversationId = 'c1',
  AiSenderRole role = AiSenderRole.assistant,
  AiMessageStatus status = AiMessageStatus.completed,
  String content = 'RSI near 70 means the price rose fast.',
  DateTime? at,
  List<AiSource> sources = const [],
}) => AiMessage(
  id: id,
  conversationId: conversationId,
  role: role,
  content: content,
  status: status,
  createdAt: at ?? aiNow,
  sources: sources,
);

AiQuota quotaOf({
  int? limit = 20,
  int used = 3,
  int? remaining = 17,
  bool canAsk = true,
  bool performance = false,
}) => AiQuota(
  limit: limit,
  used: used,
  remaining: remaining,
  resetsAt: DateTime.utc(2026, 11, 19, 17),
  canAsk: canAsk,
  performanceContext: performance,
);

/// An in-memory `/ai`: conversations, their messages newest last, the quota
/// and one queued failure per method name.
class FakeAiApi implements AiApi {
  List<AiConversation> conversationList = [
    conversationOf('c1'),
    conversationOf(
      'c2',
      topic: ConversationTopic.myTrading,
      title: 'Risk of my ETH plan',
    ),
  ];
  final Map<String, List<AiMessage>> messagesOf = {
    'c1': [
      messageOf(
        'q0',
        role: AiSenderRole.user,
        content: 'Where is support?',
        at: aiNow.subtract(const Duration(minutes: 2)),
      ),
      messageOf('a0', at: aiNow.subtract(const Duration(minutes: 1))),
    ],
  };
  AiQuota quotaValue = quotaOf();
  final List<String> calls = [];
  final List<AiQuestion> asked = [];

  /// Thrown once by the method of that name ('ask', 'start', 'messages' …).
  final Map<String, Object> failNext = {};
  int _ids = 0;

  void _fail(String method) {
    final error = failNext.remove(method);
    if (error != null) throw error;
  }

  @override
  Future<AiPage<AiConversation>> conversations({
    ConversationTopic? topic,
    int page = 1,
    int pageSize = 20,
  }) async {
    calls.add('conversations ${topic?.wire} $page');
    _fail('conversations');
    final rows = [
      for (final c in conversationList)
        if (topic == null || c.topic == topic) c,
    ];
    return AiPage(
      items: rows.skip((page - 1) * pageSize).take(pageSize).toList(),
      page: page,
      pageSize: pageSize,
      total: rows.length,
    );
  }

  @override
  Future<AiConversation> start({
    required ConversationTopic topic,
    String? pairId,
    String? title,
  }) async {
    calls.add('start ${topic.wire} $pairId');
    _fail('start');
    final created = conversationOf(
      'new${++_ids}',
      topic: topic,
      title: null,
      pairId: pairId,
    );
    conversationList = [created, ...conversationList];
    return created;
  }

  @override
  Future<AiConversation> rename(String id, String title) async {
    calls.add('rename $id $title');
    _fail('rename');
    final old = conversationList.firstWhere((c) => c.id == id);
    final renamed = conversationOf(
      id,
      topic: old.topic,
      title: title,
      pairId: old.pairId,
    );
    conversationList = [
      for (final c in conversationList) c.id == id ? renamed : c,
    ];
    return renamed;
  }

  @override
  Future<void> delete(String id) async {
    calls.add('delete $id');
    _fail('delete');
    conversationList = [
      for (final c in conversationList)
        if (c.id != id) c,
    ];
  }

  @override
  Future<AiPage<AiMessage>> messages(
    String conversationId, {
    int page = 1,
    int pageSize = 50,
  }) async {
    calls.add('messages $conversationId $page');
    _fail('messages');
    final newestFirst = (messagesOf[conversationId] ?? []).reversed.toList();
    return AiPage(
      items: newestFirst.skip((page - 1) * pageSize).take(pageSize).toList(),
      page: page,
      pageSize: pageSize,
      total: newestFirst.length,
    );
  }

  @override
  Future<AiAskResult> ask(String conversationId, AiQuestion question) async {
    calls.add('ask $conversationId');
    _fail('ask');
    asked.add(question);
    final pending = messageOf(
      'q${++_ids}',
      conversationId: conversationId,
      role: AiSenderRole.user,
      status: AiMessageStatus.pending,
      content: question.text,
      at: aiNow.add(Duration(minutes: _ids)),
    );
    (messagesOf[conversationId] ??= []).add(pending);
    quotaValue = quotaOf(
      used: quotaValue.used + 1,
      remaining: quotaValue.remaining == null
          ? null
          : quotaValue.remaining! - 1,
      limit: quotaValue.limit,
      performance: quotaValue.performanceContext,
    );
    return AiAskResult(question: pending, quota: quotaValue);
  }

  /// The server's side of an answer: the question COMPLETED and the answer
  /// stored after it.
  AiMessage answer(String conversationId, String questionId) {
    final list = messagesOf[conversationId]!;
    final index = list.indexWhere((m) => m.id == questionId);
    list[index] = list[index].withStatus(AiMessageStatus.completed);
    final answer = messageOf(
      'a-$questionId',
      conversationId: conversationId,
      at: list[index].createdAt.add(const Duration(seconds: 5)),
    );
    list.add(answer);
    return answer;
  }

  @override
  Future<AiQuota> quota() async {
    calls.add('quota');
    _fail('quota');
    return quotaValue;
  }
}

/// The JSON of [message] as `/user/queue/ai` carries it.
Map<String, Object?> messageJsonOf(AiMessage message) => {
  'id': message.id,
  'conversationId': message.conversationId,
  'role': message.role.wire,
  'content': message.content,
  'status': message.status.wire,
  'createdAt': message.createdAt.toIso8601String(),
  'sources': const <Object?>[],
};
