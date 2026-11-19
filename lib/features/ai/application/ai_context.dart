import 'package:flutter/foundation.dart';

import '../../market/domain/candle.dart';
import '../../market/domain/market.dart';
import '../../plans/domain/plan.dart';
import '../domain/ai.dart';

/// What the next question is asked about (SRS 3.9.1 context selector). Each
/// topic sends only its own data, as the backend requires (MSG01 otherwise):
/// MARKET a pair on one market and timeframe; MY_TRADING one plan and/or the
/// performance summary (PREMIUM); GENERAL nothing.
@immutable
class AiContext {
  const AiContext({
    required this.topic,
    this.pairId,
    this.symbol,
    this.market = Market.spot,
    this.timeframe = Timeframe.h1,
    this.plan,
    this.includePerformance = false,
  });

  /// The context of a conversation the Trader opens again: its topic and,
  /// for MARKET, its pair (the market and timeframe start at the defaults).
  factory AiContext.of(AiConversation conversation) => AiContext(
    topic: conversation.topic,
    pairId: conversation.topic == ConversationTopic.market
        ? conversation.pairId
        : null,
  );

  /// The seed of `/ai/new?…` (Ask AI from SCR-10/11); unknown values fall
  /// back to the defaults, a missing topic to MARKET.
  factory AiContext.fromQuery(Map<String, String> query) {
    final topic =
        ConversationTopic.values
            .where((t) => t.wire == query['topic'])
            .firstOrNull ??
        ConversationTopic.market;
    final pairId = topic == ConversationTopic.market ? query['pair'] : null;
    return AiContext(
      topic: topic,
      pairId: pairId,
      symbol: pairId == null ? null : query['symbol'],
      market: query['market'] == Market.futures.wire
          ? Market.futures
          : Market.spot,
      timeframe: Timeframe.fromWire(query['tf']) ?? Timeframe.h1,
    );
  }

  final ConversationTopic topic;
  final String? pairId;

  /// For the chip; null until the pair list names [pairId].
  final String? symbol;
  final Market market;
  final Timeframe timeframe;
  final PlanSummary? plan;
  final bool includePerformance;

  /// Whether a question can be sent: MARKET needs a pair, MY_TRADING a plan
  /// or the performance summary.
  bool get ready => switch (topic) {
    ConversationTopic.market => pairId != null,
    ConversationTopic.myTrading => plan != null || includePerformance,
    ConversationTopic.general => true,
  };

  AiQuestion question(String text) => switch (topic) {
    ConversationTopic.market => AiQuestion(
      text: text,
      pairId: pairId,
      market: pairId == null ? null : market,
      timeframe: pairId == null ? null : timeframe,
    ),
    ConversationTopic.myTrading => AiQuestion(
      text: text,
      planId: plan?.id,
      includePerformance: includePerformance,
    ),
    ConversationTopic.general => AiQuestion(text: text),
  };

  /// The query of `/ai/new` that [AiContext.fromQuery] reads back.
  Map<String, String> toQuery() => {
    'topic': topic.wire,
    'pair': ?pairId,
    if (pairId != null && symbol != null) 'symbol': symbol!,
    if (pairId != null) 'market': market.wire,
    if (pairId != null) 'tf': timeframe.wire,
  };

  /// A pair of [pairMarket]; choosing a pair also chooses its market.
  AiContext withPair(String id, String name, Market pairMarket) => AiContext(
    topic: topic,
    pairId: id,
    symbol: name,
    market: pairMarket,
    timeframe: timeframe,
    plan: plan,
    includePerformance: includePerformance,
  );

  AiContext withTimeframe(Timeframe next) => AiContext(
    topic: topic,
    pairId: pairId,
    symbol: symbol,
    market: market,
    timeframe: next,
    plan: plan,
    includePerformance: includePerformance,
  );

  /// [next] null clears the plan.
  AiContext withPlan(PlanSummary? next) => AiContext(
    topic: topic,
    pairId: pairId,
    symbol: symbol,
    market: market,
    timeframe: timeframe,
    plan: next,
    includePerformance: includePerformance,
  );

  AiContext withPerformance({required bool include}) => AiContext(
    topic: topic,
    pairId: pairId,
    symbol: symbol,
    market: market,
    timeframe: timeframe,
    plan: plan,
    includePerformance: include,
  );

  @override
  bool operator ==(Object other) =>
      other is AiContext &&
      other.topic == topic &&
      other.pairId == pairId &&
      other.symbol == symbol &&
      other.market == market &&
      other.timeframe == timeframe &&
      other.plan?.id == plan?.id &&
      other.includePerformance == includePerformance;

  @override
  int get hashCode => Object.hash(
    topic,
    pairId,
    symbol,
    market,
    timeframe,
    plan?.id,
    includePerformance,
  );
}
