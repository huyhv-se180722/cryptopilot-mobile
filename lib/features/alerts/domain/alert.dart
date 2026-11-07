import 'package:decimal/decimal.dart';

import '../../../core/json/json_read.dart';
import '../../market/domain/market.dart';

/// PRICE compares the last price of the market (BR-18); INDICATOR needs a
/// plan with indicator alerts (BR-62, MSG29 from the server).
enum AlertType {
  price('PRICE'),
  indicator('INDICATOR');

  const AlertType(this.wire);

  final String wire;

  static AlertType decode(String value) => values.firstWhere(
    (type) => type.wire == value,
    orElse: () => throw DecodeException('alert type $value is unknown'),
  );
}

/// The indicators of SRS 3.4.2. The Futures ones run on 1h, set by the
/// server, and take no timeframe (A-40); the two crosses take no threshold.
enum AlertIndicator {
  rsi14('RSI_14'),
  macdCross('MACD_CROSS', signCross: true),
  emaCross('EMA_CROSS', signCross: true),
  openInterestChange('OPEN_INTEREST_CHANGE', futuresOnly: true),
  fundingRate('FUNDING_RATE', futuresOnly: true);

  const AlertIndicator(
    this.wire, {
    this.futuresOnly = false,
    this.signCross = false,
  });

  final String wire;
  final bool futuresOnly;
  final bool signCross;

  static AlertIndicator decode(String value) => values.firstWhere(
    (indicator) => indicator.wire == value,
    orElse: () => throw DecodeException('indicator $value is unknown'),
  );
}

/// BR-20: a cross needs the previous value, a comparison only the current.
enum AlertCondition {
  crossAbove('CROSS_ABOVE'),
  crossBelow('CROSS_BELOW'),
  greaterThan('GREATER_THAN'),
  lessThan('LESS_THAN');

  const AlertCondition(this.wire);

  final String wire;

  bool get isCross => this == crossAbove || this == crossBelow;

  static AlertCondition decode(String value) => values.firstWhere(
    (condition) => condition.wire == value,
    orElse: () => throw DecodeException('condition $value is unknown'),
  );
}

/// BR-19: EVERY_TIME waits for a cooldown of at least one minute.
enum TriggerMode {
  once('ONCE'),
  oncePerBar('ONCE_PER_BAR'),
  everyTime('EVERY_TIME');

  const TriggerMode(this.wire);

  final String wire;

  static TriggerMode decode(String value) => values.firstWhere(
    (mode) => mode.wire == value,
    orElse: () => throw DecodeException('trigger mode $value is unknown'),
  );
}

/// SRS 3.4.3: the Trader pauses and resumes; TRIGGERED and EXPIRED come
/// from the engine, and an edit makes either ACTIVE again.
enum AlertStatus {
  active('ACTIVE'),
  paused('PAUSED'),
  triggered('TRIGGERED'),
  expired('EXPIRED');

  const AlertStatus(this.wire);

  final String wire;

  static AlertStatus decode(String value) => values.firstWhere(
    (status) => status.wire == value,
    orElse: () => throw DecodeException('alert status $value is unknown'),
  );
}

/// The timeframes of the Spot indicators (the server refuses others).
const alertTimeframes = ['15m', '1h', '4h', '1d'];

/// FUNDING_RATE is typed and stored in percent, at most 5 % either side
/// (Q-30, D-93).
final fundingRateMaxPercent = Decimal.fromInt(5);

/// How far ahead an expiry may be (SRS 3.4.2).
const maxExpiry = Duration(days: 90);

/// What an alert watches and how it fires: the body of `POST` / `PUT
/// /alerts` without the pair, and the rule of a stored alert.
class AlertRule {
  const AlertRule({
    required this.market,
    required this.type,
    required this.condition,
    required this.triggerMode,
    this.indicator,
    this.timeframe,
    this.threshold,
    this.cooldownMinutes,
    this.notifyEmail = false,
    this.notifyPush = false,
    this.expiresAt,
  });

  final Market market;
  final AlertType type;

  /// Null for PRICE.
  final AlertIndicator? indicator;

  /// Only for RSI_14, MACD_CROSS and EMA_CROSS.
  final String? timeframe;
  final AlertCondition condition;

  /// A decimal string; null for the two crosses.
  final String? threshold;
  final TriggerMode triggerMode;
  final int? cooldownMinutes;
  final bool notifyEmail;
  final bool notifyPush;
  final DateTime? expiresAt;
}

/// One alert of SCR-13 (`AlertResponse`).
class Alert {
  const Alert({
    required this.id,
    required this.pairId,
    required this.symbol,
    required this.rule,
    required this.status,
    required this.triggerCount,
    required this.createdAt,
    this.lastTriggeredAt,
  });

  final String id;
  final String pairId;
  final String symbol;
  final AlertRule rule;
  final AlertStatus status;
  final int triggerCount;
  final DateTime? lastTriggeredAt;
  final DateTime createdAt;

  Market get market => rule.market;
}

/// A page of `GET /alerts` (CR-04: 20 per page).
class AlertPage {
  const AlertPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
  });

  final List<Alert> items;
  final int page;
  final int pageSize;
  final int total;

  bool get hasMore => page * pageSize < total;
}

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

/// Decimals arrive as JSON numbers or strings; both are kept as text.
String? _optionalDecimal(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  final text = value is String ? value : (value is num ? '$value' : null);
  if (text == null || Decimal.tryParse(text) == null) {
    throw DecodeException('$key is not a decimal');
  }
  return text;
}

Alert decodeAlert(Object? body) {
  final json = asJsonObject(body, 'alert');
  final indicator = readOptionalString(json, 'indicator');
  return Alert(
    id: readString(json, 'id'),
    pairId: readString(json, 'pairId'),
    symbol: readString(json, 'symbol'),
    rule: AlertRule(
      market: Market.decode(readString(json, 'market')),
      type: AlertType.decode(readString(json, 'type')),
      indicator: indicator == null ? null : AlertIndicator.decode(indicator),
      timeframe: readOptionalString(json, 'timeframe'),
      condition: AlertCondition.decode(readString(json, 'condition')),
      threshold: _optionalDecimal(json, 'threshold'),
      triggerMode: TriggerMode.decode(readString(json, 'triggerMode')),
      cooldownMinutes: _optionalInt(json, 'cooldownMinutes'),
      notifyEmail: readBool(json, 'notifyEmail'),
      notifyPush: readBool(json, 'notifyPush'),
      expiresAt: _optionalInstant(json, 'expiresAt'),
    ),
    status: AlertStatus.decode(readString(json, 'status')),
    triggerCount: _int(json, 'triggerCount'),
    lastTriggeredAt: _optionalInstant(json, 'lastTriggeredAt'),
    createdAt: readInstant(json, 'createdAt'),
  );
}

AlertPage decodeAlertPage(Object? body) {
  final json = asJsonObject(body, 'alert page');
  final items = json['items'];
  if (items is! List) throw const DecodeException('items is not a list');
  final total = json['total'];
  return AlertPage(
    items: [for (final item in items) decodeAlert(item)],
    page: _int(json, 'page'),
    pageSize: _int(json, 'pageSize'),
    total: total is int ? total : throw const DecodeException('total'),
  );
}

/// What the type and the indicator ask the form for.
class RuleShape {
  const RuleShape._(this.indicator);

  factory RuleShape.of(AlertType type, AlertIndicator indicator) =>
      RuleShape._(type == AlertType.indicator ? indicator : null);

  final AlertIndicator? indicator;

  bool get takesTimeframe => indicator != null && !indicator!.futuresOnly;
  bool get takesThreshold => indicator == null || !indicator!.signCross;
  bool get crossesOnly => indicator?.signCross ?? false;
  bool get futuresOnly => indicator?.futuresOnly ?? false;
}

/// A field of the rule a check refuses; the keys are the server's field names.
enum RuleField { market, condition, threshold, cooldownMinutes, expiresAt }

sealed class RuleError {
  const RuleError();
}

class RequiredValue extends RuleError {
  const RequiredValue();
}

class NotANumber extends RuleError {
  const NotANumber();
}

class NotPositive extends RuleError {
  const NotPositive();
}

class OutOfRange extends RuleError {
  const OutOfRange(this.min, this.max);

  final String min;
  final String max;
}

class CooldownTooShort extends RuleError {
  const CooldownTooShort();
}

class ExpiryOutOfWindow extends RuleError {
  const ExpiryOutOfWindow();
}

/// The form as typed.
class AlertDraft {
  const AlertDraft({
    required this.market,
    this.type = AlertType.price,
    this.indicator = AlertIndicator.rsi14,
    this.timeframe = '1h',
    this.condition = AlertCondition.crossAbove,
    this.threshold = '',
    this.triggerMode = TriggerMode.once,
    this.cooldown = '',
    this.notifyEmail = false,
    this.notifyPush = false,
    this.expiresAt,
  });

  /// The form of a stored alert, thresholds without their scale padding.
  factory AlertDraft.of(AlertRule rule) => AlertDraft(
    market: rule.market,
    type: rule.type,
    indicator: rule.indicator ?? AlertIndicator.rsi14,
    timeframe: rule.timeframe ?? '1h',
    condition: rule.condition,
    threshold: rule.threshold == null
        ? ''
        : Decimal.parse(rule.threshold!).toString(),
    triggerMode: rule.triggerMode,
    cooldown: rule.cooldownMinutes?.toString() ?? '',
    notifyEmail: rule.notifyEmail,
    notifyPush: rule.notifyPush,
    expiresAt: rule.expiresAt,
  );

  final Market market;
  final AlertType type;
  final AlertIndicator indicator;
  final String timeframe;
  final AlertCondition condition;
  final String threshold;
  final TriggerMode triggerMode;
  final String cooldown;
  final bool notifyEmail;
  final bool notifyPush;
  final DateTime? expiresAt;

  RuleShape get shape => RuleShape.of(type, indicator);

  AlertDraft copyWith({
    Market? market,
    AlertType? type,
    AlertIndicator? indicator,
    String? timeframe,
    AlertCondition? condition,
    String? threshold,
    TriggerMode? triggerMode,
    String? cooldown,
    bool? notifyEmail,
    bool? notifyPush,
    DateTime? expiresAt,
    bool clearExpiry = false,
  }) => AlertDraft(
    market: market ?? this.market,
    type: type ?? this.type,
    indicator: indicator ?? this.indicator,
    timeframe: timeframe ?? this.timeframe,
    condition: condition ?? this.condition,
    threshold: threshold ?? this.threshold,
    triggerMode: triggerMode ?? this.triggerMode,
    cooldown: cooldown ?? this.cooldown,
    notifyEmail: notifyEmail ?? this.notifyEmail,
    notifyPush: notifyPush ?? this.notifyPush,
    expiresAt: clearExpiry ? null : expiresAt ?? this.expiresAt,
  );
}

final _decimalText = RegExp(r'^-?\d{1,16}(\.\d{1,12})?$');

/// The checks of the server's rule validator, so most mistakes show before
/// a request; the server checks again and its field errors use the same
/// fields. Returns the rule to send, with null for every field the
/// combination does not take, or the refused fields.
({AlertRule? rule, Map<RuleField, RuleError> errors}) checkDraft(
  AlertDraft draft,
  DateTime now,
) {
  final shape = draft.shape;
  final errors = <RuleField, RuleError>{};
  final threshold = draft.threshold.trim();
  if (shape.takesThreshold) {
    final value = _decimalText.hasMatch(threshold)
        ? Decimal.parse(threshold)
        : null;
    if (threshold.isEmpty) {
      errors[RuleField.threshold] = const RequiredValue();
    } else if (value == null) {
      errors[RuleField.threshold] = const NotANumber();
    } else if (shape.indicator == null && value <= Decimal.zero) {
      errors[RuleField.threshold] = const NotPositive();
    } else if (shape.indicator == AlertIndicator.fundingRate &&
        value.abs() > fundingRateMaxPercent) {
      errors[RuleField.threshold] = thresholdRange(shape)!;
    } else if (shape.indicator == AlertIndicator.rsi14 &&
        (value < Decimal.zero || value > Decimal.fromInt(100))) {
      errors[RuleField.threshold] = thresholdRange(shape)!;
    }
  }
  if (shape.futuresOnly && draft.market != Market.futures) {
    errors[RuleField.market] = const RequiredValue();
  }
  if (shape.crossesOnly && !draft.condition.isCross) {
    errors[RuleField.condition] = const RequiredValue();
  }
  int? cooldown;
  if (draft.triggerMode == TriggerMode.everyTime) {
    final raw = draft.cooldown.trim();
    final minutes = int.tryParse(raw);
    if (raw.isEmpty) {
      errors[RuleField.cooldownMinutes] = const RequiredValue();
    } else if (minutes == null || minutes < 1) {
      errors[RuleField.cooldownMinutes] = const CooldownTooShort();
    } else {
      cooldown = minutes;
    }
  }
  final expiresAt = draft.expiresAt;
  if (expiresAt != null &&
      (!expiresAt.isAfter(now) || expiresAt.isAfter(now.add(maxExpiry)))) {
    errors[RuleField.expiresAt] = const ExpiryOutOfWindow();
  }
  if (errors.isNotEmpty) return (rule: null, errors: errors);
  return (
    rule: AlertRule(
      market: draft.market,
      type: draft.type,
      indicator: shape.indicator,
      timeframe: shape.takesTimeframe ? draft.timeframe : null,
      condition: draft.condition,
      threshold: shape.takesThreshold ? threshold : null,
      triggerMode: draft.triggerMode,
      cooldownMinutes: cooldown,
      notifyEmail: draft.notifyEmail,
      notifyPush: draft.notifyPush,
      expiresAt: expiresAt?.toUtc(),
    ),
    errors: errors,
  );
}

/// The range a threshold must lie in, for MSG15 (M-11: the client fills it).
OutOfRange? thresholdRange(RuleShape shape) => switch (shape.indicator) {
  AlertIndicator.rsi14 => const OutOfRange('0', '100'),
  AlertIndicator.fundingRate => OutOfRange(
    '-$fundingRateMaxPercent',
    '$fundingRateMaxPercent',
  ),
  _ => null,
};

/// A server field error worded as the client would: MSG01 is a missing or
/// inapplicable value, MSG15 the field's own range.
RuleError? serverRuleError(RuleShape shape, RuleField field, String code) {
  if (code != 'MSG15') return const RequiredValue();
  return switch (field) {
    RuleField.expiresAt => const ExpiryOutOfWindow(),
    RuleField.cooldownMinutes => const CooldownTooShort(),
    RuleField.threshold => thresholdRange(shape) ?? const NotPositive(),
    _ => const RequiredValue(),
  };
}
