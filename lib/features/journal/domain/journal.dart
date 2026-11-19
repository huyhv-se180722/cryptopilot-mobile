import 'package:decimal/decimal.dart';

import '../../../core/json/json_read.dart';
import '../../market/domain/market.dart';
import '../../plans/domain/plan.dart';
import '../../plans/domain/plan_detail.dart';

/// Where a trade comes from (BR-41): a plan's simulated position, or one
/// recorded by hand (SCR-22, on the web).
enum TradeSource {
  simulated('SIMULATED'),
  manual('MANUAL');

  const TradeSource(this.wire);

  final String wire;

  static TradeSource decode(String value) => values.firstWhere(
    (source) => source.wire == value,
    orElse: () => throw DecodeException('trade source $value is unknown'),
  );
}

/// BR-42, as the backend decides it: by the sign of the net P/L of a closed
/// trade.
enum TradeResult {
  win('WIN'),
  loss('LOSS'),
  breakeven('BREAKEVEN');

  const TradeResult(this.wire);

  final String wire;
}

/// One trade of SCR-20 (`JournalEntryResponse`). Amounts are decimal texts;
/// the closing figures are null while it is OPEN.
class JournalEntry {
  const JournalEntry({
    required this.id,
    required this.pairId,
    required this.market,
    required this.direction,
    required this.source,
    required this.status,
    required this.entryPrice,
    required this.quantity,
    required this.entryTime,
    this.planId,
    this.strategyId,
    this.strategyName,
    this.leverage,
    this.entryFee,
    this.stopLoss,
    this.takeProfit,
    this.exitPrice,
    this.exitTime,
    this.closeReason,
    this.realizedPnl,
    this.feeAmount,
    this.fundingFeeAmount,
    this.netPnl,
    this.provisional = false,
  });

  final String id;

  /// The plan of a SIMULATED trade (SCR-18).
  final String? planId;
  final String? strategyId;
  final String? strategyName;
  final String pairId;
  final Market market;
  final PlanDirection direction;
  final TradeSource source;
  final PositionState status;
  final int? leverage;
  final String entryPrice;
  final String quantity;
  final DateTime entryTime;
  final String? entryFee;
  final String? stopLoss;
  final String? takeProfit;
  final String? exitPrice;
  final DateTime? exitTime;
  final CloseReason? closeReason;
  final String? realizedPnl;
  final String? feeAmount;
  final String? fundingFeeAmount;
  final String? netPnl;
  final bool provisional;

  /// Null while OPEN.
  TradeResult? get result {
    final net = netPnl;
    if (status != PositionState.closed || net == null) return null;
    final sign = Decimal.parse(net).compareTo(Decimal.zero);
    return sign > 0
        ? TradeResult.win
        : sign < 0
        ? TradeResult.loss
        : TradeResult.breakeven;
  }
}

/// SCR-21 (`JournalEntryDetailResponse`): the trade and its review.
class JournalDetail {
  const JournalDetail({
    required this.entry,
    this.setupDescription,
    this.lessonsLearned,
    this.mistakes,
    this.chartImageUrl,
  });

  final JournalEntry entry;
  final String? setupDescription;
  final String? lessonsLearned;
  final String? mistakes;
  final String? chartImageUrl;
}

class JournalPage {
  const JournalPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
  });

  final List<JournalEntry> items;
  final int page;
  final int pageSize;
  final int total;
}

/// A strategy the Trader can tag a review with (`GET /strategies`).
class Strategy {
  const Strategy({required this.id, required this.name});

  final String id;
  final String name;
}

/// The longest review text (SRS 3.6.1, MSG15 past it).
const reviewMaxLength = 4000;

/// The filters of SCR-20, as `GET /journal` takes them; null is "all".
class JournalFilter {
  const JournalFilter({
    this.days = 30,
    this.market,
    this.source,
    this.result,
    this.status,
    this.strategyId,
  });

  /// The last [days] days; null for no period.
  final int? days;
  final Market? market;
  final TradeSource? source;
  final TradeResult? result;
  final PositionState? status;
  final String? strategyId;

  @override
  bool operator ==(Object other) =>
      other is JournalFilter &&
      other.days == days &&
      other.market == market &&
      other.source == source &&
      other.result == result &&
      other.status == status &&
      other.strategyId == strategyId;

  @override
  int get hashCode =>
      Object.hash(days, market, source, result, status, strategyId);
}

String? _decimal(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  final text = value is String ? value : (value is num ? '$value' : null);
  if (text == null || Decimal.tryParse(text) == null) {
    throw DecodeException('$key is not a decimal');
  }
  return text;
}

String _requiredDecimal(Map<String, Object?> json, String key) =>
    _decimal(json, key) ?? (throw DecodeException('$key is missing'));

int _int(Map<String, Object?> json, String key) => switch (json[key]) {
  final int value => value,
  _ => throw DecodeException('$key is not a whole number'),
};

JournalEntry decodeJournalEntry(Object? body) {
  final json = asJsonObject(body, 'journal entry');
  final reason = readOptionalString(json, 'closeReason');
  final leverage = switch (json['leverage']) {
    null => null,
    final int value => value,
    _ => throw const DecodeException('leverage is not a whole number'),
  };
  final provisional = json['provisional'];
  return JournalEntry(
    id: readString(json, 'id'),
    planId: readOptionalString(json, 'planId'),
    strategyId: readOptionalString(json, 'strategyId'),
    strategyName: readOptionalString(json, 'strategyName'),
    pairId: readString(json, 'pairId'),
    market: Market.decode(readString(json, 'market')),
    direction: PlanDirection.decode(readString(json, 'direction')),
    source: TradeSource.decode(readString(json, 'source')),
    status: PositionState.decode(readString(json, 'status')),
    leverage: leverage,
    entryPrice: _requiredDecimal(json, 'entryPrice'),
    quantity: _requiredDecimal(json, 'quantity'),
    entryTime: readInstant(json, 'entryTime'),
    entryFee: _decimal(json, 'entryFee'),
    stopLoss: _decimal(json, 'stopLoss'),
    takeProfit: _decimal(json, 'takeProfit'),
    exitPrice: _decimal(json, 'exitPrice'),
    exitTime: json['exitTime'] == null ? null : readInstant(json, 'exitTime'),
    closeReason: reason == null ? null : CloseReason.decode(reason),
    realizedPnl: _decimal(json, 'realizedPnl'),
    feeAmount: _decimal(json, 'feeAmount'),
    fundingFeeAmount: _decimal(json, 'fundingFeeAmount'),
    netPnl: _decimal(json, 'netPnl'),
    provisional: provisional is bool && provisional,
  );
}

JournalDetail decodeJournalDetail(Object? body) {
  final json = asJsonObject(body, 'journal entry');
  return JournalDetail(
    entry: decodeJournalEntry(json),
    setupDescription: readOptionalString(json, 'setupDescription'),
    lessonsLearned: readOptionalString(json, 'lessonsLearned'),
    mistakes: readOptionalString(json, 'mistakes'),
    chartImageUrl: readOptionalString(json, 'chartImageUrl'),
  );
}

JournalPage decodeJournalPage(Object? body) {
  final json = asJsonObject(body, 'journal page');
  final items = switch (json['items']) {
    final List<Object?> list => list,
    _ => throw const DecodeException('items is not a list'),
  };
  return JournalPage(
    items: [for (final item in items) decodeJournalEntry(item)],
    page: _int(json, 'page'),
    pageSize: _int(json, 'pageSize'),
    total: _int(json, 'total'),
  );
}

List<Strategy> decodeStrategies(Object? body) {
  final items = switch (body) {
    final List<Object?> list => list,
    _ => throw const DecodeException('strategies is not a list'),
  };
  return [for (final item in items) _decodeStrategy(item)];
}

Strategy _decodeStrategy(Object? body) {
  final json = asJsonObject(body, 'strategy');
  return Strategy(id: readString(json, 'id'), name: readString(json, 'name'));
}
