import 'package:decimal/decimal.dart';

import '../../../core/json/json_read.dart';
import '../../market/domain/market.dart';
import 'plan.dart';

/// How a plan's simulated position ended (backend `CloseReason`).
enum CloseReason {
  takeProfit('TAKE_PROFIT'),
  stopLoss('STOP_LOSS'),
  manual('MANUAL'),
  liquidation('LIQUIDATION');

  const CloseReason(this.wire);

  final String wire;

  static CloseReason decode(String value) => values.firstWhere(
    (reason) => reason.wire == value,
    orElse: () => throw DecodeException('close reason $value is unknown'),
  );
}

/// Why an ACTIVE plan was invalidated before it filled.
enum InvalidationReason {
  takeProfitReached('TAKE_PROFIT_REACHED'),
  stopLossReached('STOP_LOSS_REACHED'),
  invalidationPrice('INVALIDATION_PRICE');

  const InvalidationReason(this.wire);

  final String wire;

  static InvalidationReason decode(String value) => values.firstWhere(
    (reason) => reason.wire == value,
    orElse: () =>
        throw DecodeException('invalidation reason $value is unknown'),
  );
}

enum WarningSeverity {
  info('INFO'),
  warning('WARNING'),
  blocking('BLOCKING');

  const WarningSeverity(this.wire);

  final String wire;

  static WarningSeverity decode(String value) => values.firstWhere(
    (severity) => severity.wire == value,
    orElse: () => throw DecodeException('warning severity $value is unknown'),
  );
}

/// A warning of the calculation or of a level change (MSG17); [message] is
/// the server's sentence, [type] its stable code.
class PlanWarning {
  const PlanWarning({
    required this.type,
    required this.severity,
    required this.message,
  });

  final String type;
  final WarningSeverity severity;
  final String message;
}

/// The calculation stored when the plan was activated (BR-31). Every figure
/// is a decimal text, null on a plan saved before it existed (D-116).
class PlanSnapshot {
  const PlanSnapshot({
    this.positionQuantity,
    this.notionalValue,
    this.initialMargin,
    this.riskAmount,
    this.rewardAmount,
    this.riskRewardRatio,
    this.estimatedLiquidationPrice,
    this.estimatedEntryFee,
    this.lossAtStopLoss,
    this.netRiskReward,
  });

  final String? positionQuantity;
  final String? notionalValue;
  final String? initialMargin;
  final String? riskAmount;
  final String? rewardAmount;
  final String? riskRewardRatio;
  final String? estimatedLiquidationPrice;
  final String? estimatedEntryFee;
  final String? lossAtStopLoss;
  final String? netRiskReward;
}

class PlanStatusChange {
  const PlanStatusChange({required this.status, required this.at});

  final PlanStatus status;
  final DateTime at;
}

/// One change of an open position's stop loss or take profit.
class LevelChange {
  const LevelChange({
    required this.changedAt,
    this.oldStopLoss,
    this.oldTakeProfit,
    this.newStopLoss,
    this.newTakeProfit,
  });

  final DateTime changedAt;
  final String? oldStopLoss;
  final String? oldTakeProfit;
  final String? newStopLoss;
  final String? newTakeProfit;
}

/// The simulated position of an EXECUTED plan (`PositionResponse`, BR-34…
/// BR-38). Every figure is the server one: while OPEN [currentPrice] and
/// [unrealizedPnl] (no fees, no funding); once CLOSED the exit, the realized
/// P/L, fees, funding and [netPnl], [provisional] while a funding settlement
/// is missing (D-97).
class PlanPosition {
  const PlanPosition({
    required this.status,
    required this.fillPrice,
    required this.quantity,
    required this.entryTime,
    this.entryFee,
    this.liquidationPrice,
    this.currentPrice,
    this.unrealizedPnl,
    this.exitPrice,
    this.exitTime,
    this.closeReason,
    this.realizedPnl,
    this.feeAmount,
    this.fundingFeeAmount,
    this.netPnl,
    this.provisional = false,
    this.stopLoss,
    this.takeProfit,
    this.originalStopLoss,
    this.originalTakeProfit,
    this.stopWidened = false,
    this.levelChanges = const [],
    this.breakevenPrice,
    this.levelWarnings = const [],
  });

  final PositionState status;
  final String fillPrice;
  final String quantity;
  final DateTime entryTime;
  final String? entryFee;
  final String? liquidationPrice;
  final String? currentPrice;
  final String? unrealizedPnl;
  final String? exitPrice;
  final DateTime? exitTime;
  final CloseReason? closeReason;
  final String? realizedPnl;
  final String? feeAmount;
  final String? fundingFeeAmount;
  final String? netPnl;
  final bool provisional;
  final String? stopLoss;
  final String? takeProfit;
  final String? originalStopLoss;
  final String? originalTakeProfit;
  final bool stopWidened;
  final List<LevelChange> levelChanges;
  final String? breakevenPrice;
  final List<PlanWarning> levelWarnings;

  bool get open => status == PositionState.open;
}

/// SCR-18: one plan in full (`TradingPlanResponse`).
class PlanDetail {
  const PlanDetail({
    required this.id,
    required this.pairId,
    required this.market,
    required this.direction,
    required this.entryType,
    required this.status,
    required this.editable,
    required this.blocksActivation,
    this.entryPrice,
    this.expectedFillPrice,
    this.stopLoss,
    this.takeProfit,
    this.capital,
    this.riskPercent,
    this.leverage,
    this.expiresAt,
    this.note,
    this.analysisTimeframe,
    this.invalidationReason,
    this.snapshot,
    this.warnings = const [],
    this.statusHistory = const [],
    this.position,
  });

  final String id;
  final String pairId;
  final Market market;
  final PlanDirection direction;

  /// LIMIT, MARKET or STOP, shown as sent.
  final String entryType;
  final String? entryPrice;
  final String? expectedFillPrice;
  final String? stopLoss;
  final String? takeProfit;
  final String? capital;
  final String? riskPercent;
  final int? leverage;
  final DateTime? expiresAt;
  final String? note;
  final String? analysisTimeframe;
  final PlanStatus status;
  final InvalidationReason? invalidationReason;

  /// Whether it can still be edited (on the web, SCR-17).
  final bool editable;
  final PlanSnapshot? snapshot;
  final List<PlanWarning> warnings;

  /// A BLOCKING warning stops Activate (MSG18).
  final bool blocksActivation;
  final List<PlanStatusChange> statusHistory;
  final PlanPosition? position;

  bool get hasOpenPosition => position?.open ?? false;

  /// The row this plan has in `GET /plans`, for the screens that take one
  /// (the AI plan picker); created when its first status was.
  PlanSummary get summary => PlanSummary(
    id: id,
    pairId: pairId,
    market: market,
    direction: direction,
    entryType: entryType,
    status: status,
    createdAt: statusHistory.isEmpty
        ? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)
        : statusHistory.first.at,
    entryPrice: entryPrice,
    stopLoss: stopLoss,
    takeProfit: takeProfit,
    leverage: leverage,
    positionState: position?.status,
  );
}

/// SCR-19: what closing now would give (`CloseEstimateResponse`).
class CloseEstimate {
  const CloseEstimate({
    required this.currentPrice,
    required this.estimatedExitPrice,
    required this.priceResult,
    required this.entryFee,
    required this.estimatedExitFee,
    required this.estimatedNetPnl,
    required this.at,
    this.fundingSoFar,
    this.fundingProvisional = false,
  });

  final String currentPrice;
  final String estimatedExitPrice;
  final String priceResult;
  final String entryFee;
  final String estimatedExitFee;

  /// Null on Spot.
  final String? fundingSoFar;
  final bool fundingProvisional;
  final String estimatedNetPnl;
  final DateTime at;
}

/// The body of `/user/queue/positions`: the plan whose position changed.
class PositionUpdate {
  const PositionUpdate({required this.planId, required this.status});

  final String planId;
  final PositionState status;
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

bool _flag(Map<String, Object?> json, String key) => switch (json[key]) {
  null => false,
  final bool value => value,
  _ => throw DecodeException('$key is not a boolean'),
};

int? _optionalInt(Map<String, Object?> json, String key) => switch (json[key]) {
  null => null,
  final int value => value,
  _ => throw DecodeException('$key is not a whole number'),
};

DateTime? _optionalInstant(Map<String, Object?> json, String key) =>
    json[key] == null ? null : readInstant(json, key);

List<Object?> _listOf(Map<String, Object?> json, String key) =>
    switch (json[key]) {
      null => const [],
      final List<Object?> list => list,
      _ => throw DecodeException('$key is not a list'),
    };

PlanWarning decodePlanWarning(Object? body) {
  final json = asJsonObject(body, 'warning');
  return PlanWarning(
    type: readString(json, 'type'),
    severity: WarningSeverity.decode(readString(json, 'severity')),
    message: readString(json, 'message'),
  );
}

PlanSnapshot decodePlanSnapshot(Object? body) {
  final json = asJsonObject(body, 'snapshot');
  return PlanSnapshot(
    positionQuantity: _decimal(json, 'positionQuantity'),
    notionalValue: _decimal(json, 'notionalValue'),
    initialMargin: _decimal(json, 'initialMargin'),
    riskAmount: _decimal(json, 'riskAmount'),
    rewardAmount: _decimal(json, 'rewardAmount'),
    riskRewardRatio: _decimal(json, 'riskRewardRatio'),
    estimatedLiquidationPrice: _decimal(json, 'estimatedLiquidationPrice'),
    estimatedEntryFee: _decimal(json, 'estimatedEntryFee'),
    lossAtStopLoss: _decimal(json, 'lossAtStopLoss'),
    netRiskReward: _decimal(json, 'netRiskReward'),
  );
}

LevelChange _decodeLevelChange(Object? body) {
  final json = asJsonObject(body, 'level change');
  return LevelChange(
    changedAt: readInstant(json, 'changedAt'),
    oldStopLoss: _decimal(json, 'oldStopLoss'),
    oldTakeProfit: _decimal(json, 'oldTakeProfit'),
    newStopLoss: _decimal(json, 'newStopLoss'),
    newTakeProfit: _decimal(json, 'newTakeProfit'),
  );
}

PlanStatusChange _decodeStatusChange(Object? body) {
  final json = asJsonObject(body, 'status change');
  return PlanStatusChange(
    status: PlanStatus.decode(readString(json, 'status')),
    at: readInstant(json, 'at'),
  );
}

PlanPosition decodePlanPosition(Object? body) {
  final json = asJsonObject(body, 'position');
  final reason = readOptionalString(json, 'closeReason');
  return PlanPosition(
    status: PositionState.decode(readString(json, 'status')),
    fillPrice: _requiredDecimal(json, 'fillPrice'),
    quantity: _requiredDecimal(json, 'quantity'),
    entryTime: readInstant(json, 'entryTime'),
    entryFee: _decimal(json, 'entryFee'),
    liquidationPrice: _decimal(json, 'liquidationPrice'),
    currentPrice: _decimal(json, 'currentPrice'),
    unrealizedPnl: _decimal(json, 'unrealizedPnl'),
    exitPrice: _decimal(json, 'exitPrice'),
    exitTime: _optionalInstant(json, 'exitTime'),
    closeReason: reason == null ? null : CloseReason.decode(reason),
    realizedPnl: _decimal(json, 'realizedPnl'),
    feeAmount: _decimal(json, 'feeAmount'),
    fundingFeeAmount: _decimal(json, 'fundingFeeAmount'),
    netPnl: _decimal(json, 'netPnl'),
    provisional: _flag(json, 'provisional'),
    stopLoss: _decimal(json, 'stopLoss'),
    takeProfit: _decimal(json, 'takeProfit'),
    originalStopLoss: _decimal(json, 'originalStopLoss'),
    originalTakeProfit: _decimal(json, 'originalTakeProfit'),
    stopWidened: _flag(json, 'stopWidened'),
    levelChanges: [
      for (final change in _listOf(json, 'levelChanges'))
        _decodeLevelChange(change),
    ],
    breakevenPrice: _decimal(json, 'breakevenPrice'),
    levelWarnings: [
      for (final warning in _listOf(json, 'levelWarnings'))
        decodePlanWarning(warning),
    ],
  );
}

PlanDetail decodePlanDetail(Object? body) {
  final json = asJsonObject(body, 'plan');
  final reason = readOptionalString(json, 'invalidationReason');
  return PlanDetail(
    id: readString(json, 'id'),
    pairId: readString(json, 'pairId'),
    market: Market.decode(readString(json, 'market')),
    direction: PlanDirection.decode(readString(json, 'direction')),
    entryType: readString(json, 'entryType'),
    entryPrice: _decimal(json, 'entryPrice'),
    expectedFillPrice: _decimal(json, 'expectedFillPrice'),
    stopLoss: _decimal(json, 'stopLoss'),
    takeProfit: _decimal(json, 'takeProfit'),
    capital: _decimal(json, 'capital'),
    riskPercent: _decimal(json, 'riskPercent'),
    leverage: _optionalInt(json, 'leverage'),
    expiresAt: _optionalInstant(json, 'expiresAt'),
    note: readOptionalString(json, 'note'),
    analysisTimeframe: readOptionalString(json, 'analysisTimeframe'),
    status: PlanStatus.decode(readString(json, 'status')),
    invalidationReason: reason == null
        ? null
        : InvalidationReason.decode(reason),
    editable: readBool(json, 'editable'),
    snapshot: json['snapshot'] == null
        ? null
        : decodePlanSnapshot(json['snapshot']),
    warnings: [
      for (final warning in _listOf(json, 'warnings'))
        decodePlanWarning(warning),
    ],
    blocksActivation: readBool(json, 'blocksActivation'),
    statusHistory: [
      for (final change in _listOf(json, 'statusHistory'))
        _decodeStatusChange(change),
    ],
    position: json['position'] == null
        ? null
        : decodePlanPosition(json['position']),
  );
}

CloseEstimate decodeCloseEstimate(Object? body) {
  final json = asJsonObject(body, 'close estimate');
  return CloseEstimate(
    currentPrice: _requiredDecimal(json, 'currentPrice'),
    estimatedExitPrice: _requiredDecimal(json, 'estimatedExitPrice'),
    priceResult: _requiredDecimal(json, 'priceResult'),
    entryFee: _requiredDecimal(json, 'entryFee'),
    estimatedExitFee: _requiredDecimal(json, 'estimatedExitFee'),
    fundingSoFar: _decimal(json, 'fundingSoFar'),
    fundingProvisional: _flag(json, 'fundingProvisional'),
    estimatedNetPnl: _requiredDecimal(json, 'estimatedNetPnl'),
    at: readInstant(json, 'at'),
  );
}

PositionUpdate decodePositionUpdate(Object? body) {
  final json = asJsonObject(body, 'position update');
  return PositionUpdate(
    planId: readString(json, 'planId'),
    status: PositionState.decode(readString(json, 'status')),
  );
}
