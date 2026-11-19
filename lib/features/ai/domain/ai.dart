import '../../../core/json/json_read.dart';
import '../../market/domain/candle.dart';
import '../../market/domain/market.dart';

/// What a conversation of SCR-29 is about (backend `ConversationTopic`): one
/// pair's analysis, the Trader's own plan and performance, or a general
/// question that carries no market data (the web's floating chat).
enum ConversationTopic {
  general('GENERAL'),
  market('MARKET'),
  myTrading('MY_TRADING');

  const ConversationTopic(this.wire);

  final String wire;

  static ConversationTopic decode(String value) => values.firstWhere(
    (topic) => topic.wire == value,
    orElse: () => throw DecodeException('topic $value is unknown'),
  );
}

/// PENDING until the answer arrives, then COMPLETED, or FAILED after an error
/// or 60 seconds (SRS 3.9.1, MSG31; a failed question uses no quota).
enum AiMessageStatus {
  pending('PENDING'),
  completed('COMPLETED'),
  failed('FAILED');

  const AiMessageStatus(this.wire);

  final String wire;

  static AiMessageStatus decode(String value) => values.firstWhere(
    (status) => status.wire == value,
    orElse: () => throw DecodeException('message status $value is unknown'),
  );
}

enum AiSenderRole {
  user('USER'),
  assistant('ASSISTANT');

  const AiSenderRole(this.wire);

  final String wire;

  static AiSenderRole decode(String value) => values.firstWhere(
    (role) => role.wire == value,
    orElse: () => throw DecodeException('sender role $value is unknown'),
  );
}

/// One conversation of the list (`ConversationResponse`). [title] is null
/// until the Trader names it.
class AiConversation {
  const AiConversation({
    required this.id,
    required this.topic,
    required this.createdAt,
    required this.updatedAt,
    this.title,
    this.pairId,
  });

  final String id;
  final String? title;
  final ConversationTopic topic;
  final String? pairId;
  final DateTime createdAt;
  final DateTime updatedAt;
}

/// An article an answer cites as `[ref]` (`MessageSourceResponse`, T-074).
/// Only numbers the backend stored become links (BR-51).
class AiSource {
  const AiSource({
    required this.ref,
    required this.origin,
    required this.url,
    this.headline,
    this.outlet,
    this.publishedAt,
  });

  final int ref;
  final String origin;
  final String? headline;
  final String? outlet;
  final DateTime? publishedAt;
  final String url;
}

/// A question or an answer (`MessageResponse`). An answer's [content] already
/// ends with the active disclaimer (backend `AnswerGuard`, BR-51).
class AiMessage {
  const AiMessage({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    required this.status,
    required this.createdAt,
    this.sources = const [],
  });

  final String id;
  final String conversationId;
  final AiSenderRole role;
  final String content;
  final AiMessageStatus status;
  final DateTime createdAt;
  final List<AiSource> sources;

  AiMessage withStatus(AiMessageStatus next) => AiMessage(
    id: id,
    conversationId: conversationId,
    role: role,
    content: content,
    status: next,
    createdAt: createdAt,
    sources: sources,
  );
}

/// One page of a paged endpoint; pages count from 1.
class AiPage<T> {
  const AiPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
  });

  final List<T> items;
  final int page;
  final int pageSize;
  final int total;

  bool get hasMore => page * pageSize < total;
}

/// Today's questions of the Trader (`QuotaResponse`, BR-50): [limit] and
/// [remaining] are null when unlimited, [limit] is 0 when the plan has no AI
/// Assistant (FREE, BR-52). Resets at 00:00 UTC+7.
class AiQuota {
  const AiQuota({
    required this.used,
    required this.resetsAt,
    required this.canAsk,
    required this.performanceContext,
    this.limit,
    this.remaining,
  });

  final int? limit;
  final int used;
  final int? remaining;
  final DateTime resetsAt;
  final bool canAsk;

  /// Whether the plan adds the performance summary (PREMIUM, BR-51).
  final bool performanceContext;

  bool get unlimited => limit == null;

  /// The plan has no AI Assistant: conversations stay readable (BR-52).
  bool get notIncluded => limit == 0;

  /// Today's quota is used up (MSG30).
  bool get exhausted => !canAsk && !notIncluded;
}

/// `202` of a question: the question stored PENDING and the quota with it
/// counted.
class AiAskResult {
  const AiAskResult({required this.question, required this.quota});

  final AiMessage question;
  final AiQuota quota;
}

/// The body of `/user/queue/ai` (`AiAnswerPush`): [answer] is null when the
/// question FAILED.
class AiAnswerPush {
  const AiAnswerPush({
    required this.conversationId,
    required this.questionId,
    required this.status,
    this.answer,
  });

  final String conversationId;
  final String questionId;
  final AiMessageStatus status;
  final AiMessage? answer;
}

/// A question with the data of its conversation's topic only (the backend
/// refuses data outside the topic with MSG01): a pair on one market and
/// timeframe for MARKET; a plan and/or the performance summary for
/// MY_TRADING; nothing for GENERAL.
class AiQuestion {
  const AiQuestion({
    required this.text,
    this.pairId,
    this.market,
    this.timeframe,
    this.planId,
    this.includePerformance = false,
  });

  final String text;
  final String? pairId;
  final Market? market;
  final Timeframe? timeframe;
  final String? planId;
  final bool includePerformance;

  Map<String, Object?> toJson() => {
    'question': text,
    if (pairId != null) 'pairId': pairId,
    if (market != null) 'market': market!.wire,
    if (timeframe != null) 'timeframe': timeframe!.wire,
    if (planId != null) 'planId': planId,
    if (includePerformance) 'includePerformance': true,
  };
}

/// The longest question the backend takes (SRS 3.9.1: 1-1,000 characters).
const aiQuestionMaxLength = 1000;

/// The longest conversation title (`RenameConversationRequest`).
const aiTitleMaxLength = 100;

int _int(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw DecodeException('$key is not a whole number');
}

int? _optionalInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null || value is int) return value as int?;
  throw DecodeException('$key is not a whole number');
}

DateTime? _optionalInstant(Map<String, Object?> json, String key) =>
    json[key] == null ? null : readInstant(json, key);

List<Object?> _list(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is List) return value;
  throw DecodeException('$key is not a list');
}

AiConversation decodeConversation(Object? body) {
  final json = asJsonObject(body, 'conversation');
  return AiConversation(
    id: readString(json, 'id'),
    title: readOptionalString(json, 'title'),
    topic: ConversationTopic.decode(readString(json, 'topic')),
    pairId: readOptionalString(json, 'pairId'),
    createdAt: readInstant(json, 'createdAt'),
    updatedAt: readInstant(json, 'updatedAt'),
  );
}

AiSource decodeSource(Object? body) {
  final json = asJsonObject(body, 'source');
  return AiSource(
    ref: _int(json, 'ref'),
    origin: readString(json, 'origin'),
    headline: readOptionalString(json, 'headline'),
    outlet: readOptionalString(json, 'outlet'),
    publishedAt: _optionalInstant(json, 'publishedAt'),
    url: readString(json, 'url'),
  );
}

AiMessage decodeMessage(Object? body) {
  final json = asJsonObject(body, 'message');
  final sources = json['sources'];
  if (sources != null && sources is! List) {
    throw const DecodeException('sources is not a list');
  }
  return AiMessage(
    id: readString(json, 'id'),
    conversationId: readString(json, 'conversationId'),
    role: AiSenderRole.decode(readString(json, 'role')),
    content: readString(json, 'content'),
    status: AiMessageStatus.decode(readString(json, 'status')),
    createdAt: readInstant(json, 'createdAt'),
    sources: [
      for (final source in (sources as List?) ?? []) decodeSource(source),
    ],
  );
}

AiPage<T> _page<T>(Object? body, String what, T Function(Object?) item) {
  final json = asJsonObject(body, what);
  return AiPage(
    items: [for (final entry in _list(json, 'items')) item(entry)],
    page: _int(json, 'page'),
    pageSize: _int(json, 'pageSize'),
    total: _int(json, 'total'),
  );
}

AiPage<AiConversation> decodeConversationPage(Object? body) =>
    _page(body, 'conversation page', decodeConversation);

AiPage<AiMessage> decodeMessagePage(Object? body) =>
    _page(body, 'message page', decodeMessage);

AiQuota decodeQuota(Object? body) {
  final json = asJsonObject(body, 'quota');
  return AiQuota(
    limit: _optionalInt(json, 'limit'),
    used: _int(json, 'used'),
    remaining: _optionalInt(json, 'remaining'),
    resetsAt: readInstant(json, 'resetsAt'),
    canAsk: readBool(json, 'canAsk'),
    performanceContext: readBool(json, 'performanceContext'),
  );
}

AiAskResult decodeAskResult(Object? body) {
  final json = asJsonObject(body, 'ask result');
  return AiAskResult(
    question: decodeMessage(json['question']),
    quota: decodeQuota(json['quota']),
  );
}

AiAnswerPush decodeAnswerPush(Object? body) {
  final json = asJsonObject(body, 'AI answer push');
  final status = AiMessageStatus.decode(readString(json, 'status'));
  if (status == AiMessageStatus.pending) {
    throw const DecodeException('an AI push is never PENDING');
  }
  final answer = json['answer'];
  if (status == AiMessageStatus.completed && answer == null) {
    throw const DecodeException('a COMPLETED push carries its answer');
  }
  return AiAnswerPush(
    conversationId: readString(json, 'conversationId'),
    questionId: readString(json, 'questionId'),
    status: status,
    answer: answer == null ? null : decodeMessage(answer),
  );
}
