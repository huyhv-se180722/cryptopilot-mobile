import 'package:decimal/decimal.dart';

import '../../../core/json/json_read.dart';
import '../../market/domain/market.dart';

/// The tabs of SCR-16, the `tab` filter of `GET /plans`.
enum PlanTab {
  draft('DRAFT'),
  active('ACTIVE'),
  executed('EXECUTED'),
  cancelledExpired('CANCELLED_EXPIRED');

  const PlanTab(this.wire);

  final String wire;
}

enum PlanStatus {
  draft('DRAFT'),
  active('ACTIVE'),
  executed('EXECUTED'),
  cancelled('CANCELLED'),
  expired('EXPIRED'),
  invalidated('INVALIDATED');

  const PlanStatus(this.wire);

  final String wire;

  static PlanStatus decode(String value) => values.firstWhere(
    (status) => status.wire == value,
    orElse: () => throw DecodeException('plan status $value is unknown'),
  );
}

enum PlanDirection {
  long('LONG'),
  short('SHORT');

  const PlanDirection(this.wire);

  final String wire;

  static PlanDirection decode(String value) => values.firstWhere(
    (direction) => direction.wire == value,
    orElse: () => throw DecodeException('direction $value is unknown'),
  );
}

/// An executed plan's position (the Executed tab).
enum PositionState {
  open('OPEN'),
  closed('CLOSED');

  const PositionState(this.wire);

  final String wire;

  static PositionState decode(String value) => values.firstWhere(
    (state) => state.wire == value,
    orElse: () => throw DecodeException('position status $value is unknown'),
  );
}

/// One row of `GET /plans` (`TradingPlanSummaryResponse`); the pair is named
/// by id only, so screens read its symbol from the market boards.
class PlanSummary {
  const PlanSummary({
    required this.id,
    required this.pairId,
    required this.market,
    required this.direction,
    required this.entryType,
    required this.status,
    required this.createdAt,
    this.entryPrice,
    this.stopLoss,
    this.takeProfit,
    this.leverage,
    this.positionState,
  });

  final String id;
  final String pairId;
  final Market market;
  final PlanDirection direction;

  /// LIMIT, MARKET or STOP, shown as sent.
  final String entryType;
  final String? entryPrice;
  final String? stopLoss;
  final String? takeProfit;

  /// Null on Spot.
  final int? leverage;
  final PlanStatus status;

  /// EXECUTED plans only.
  final PositionState? positionState;
  final DateTime createdAt;
}

class PlanPage {
  const PlanPage({required this.items, required this.total});

  final List<PlanSummary> items;
  final int total;
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

PlanSummary decodePlanSummary(Object? body) {
  final json = asJsonObject(body, 'plan');
  final leverage = json['leverage'];
  final position = readOptionalString(json, 'positionStatus');
  return PlanSummary(
    id: readString(json, 'id'),
    pairId: readString(json, 'pairId'),
    market: Market.decode(readString(json, 'market')),
    direction: PlanDirection.decode(readString(json, 'direction')),
    entryType: readString(json, 'entryType'),
    entryPrice: _decimal(json, 'entryPrice'),
    stopLoss: _decimal(json, 'stopLoss'),
    takeProfit: _decimal(json, 'takeProfit'),
    leverage: leverage is int ? leverage : null,
    status: PlanStatus.decode(readString(json, 'status')),
    positionState: position == null ? null : PositionState.decode(position),
    createdAt: readInstant(json, 'createdAt'),
  );
}

PlanPage decodePlanPage(Object? body) {
  final json = asJsonObject(body, 'plan page');
  final items = json['items'];
  final total = json['total'];
  if (items is! List) throw const DecodeException('items is not a list');
  if (total is! int) throw const DecodeException('total is not a number');
  return PlanPage(
    items: [for (final item in items) decodePlanSummary(item)],
    total: total,
  );
}
