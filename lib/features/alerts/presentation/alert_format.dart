import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';

import '../../../core/format/decimal_format.dart';
import '../../../core/i18n/app_localizations.dart';
import '../domain/alert.dart';

String statusLabel(AppLocalizations l, AlertStatus status) => switch (status) {
  AlertStatus.active => l.alertStatusACTIVE,
  AlertStatus.paused => l.alertStatusPAUSED,
  AlertStatus.triggered => l.alertStatusTRIGGERED,
  AlertStatus.expired => l.alertStatusEXPIRED,
};

String typeLabel(AppLocalizations l, AlertType type) => switch (type) {
  AlertType.price => l.alertTypePRICE,
  AlertType.indicator => l.alertTypeINDICATOR,
};

String indicatorLabel(AppLocalizations l, AlertIndicator indicator) =>
    switch (indicator) {
      AlertIndicator.rsi14 => l.alertIndicatorRSI_14,
      AlertIndicator.macdCross => l.alertIndicatorMACD_CROSS,
      AlertIndicator.emaCross => l.alertIndicatorEMA_CROSS,
      AlertIndicator.fundingRate => l.alertIndicatorFUNDING_RATE,
      AlertIndicator.openInterestChange => l.alertIndicatorOPEN_INTEREST_CHANGE,
    };

String conditionLabel(AppLocalizations l, AlertCondition condition) =>
    switch (condition) {
      AlertCondition.crossAbove => l.alertConditionCROSS_ABOVE,
      AlertCondition.crossBelow => l.alertConditionCROSS_BELOW,
      AlertCondition.greaterThan => l.alertConditionGREATER_THAN,
      AlertCondition.lessThan => l.alertConditionLESS_THAN,
    };

String modeLabel(AppLocalizations l, TriggerMode mode) => switch (mode) {
  TriggerMode.once => l.alertModeONCE,
  TriggerMode.oncePerBar => l.alertModeONCE_PER_BAR,
  TriggerMode.everyTime => l.alertModeEVERY_TIME,
};

/// A stored threshold without its scale padding, grouped; prices keep at
/// least two decimals ("68000.000000000000" → "68,000.00").
String thresholdText(String value, {required bool price}) {
  final parsed = Decimal.tryParse(value);
  if (parsed == null) return value;
  final text = parsed.toString();
  final places = text.contains('.') ? text.split('.').last.length : 0;
  return groupThousands(
    parsed.toStringAsFixed(price && places < 2 ? 2 : places),
  );
}

/// The rule in words for SCR-13 and the delete confirmation, as the web
/// words it: "Crosses above 68,000.00", "RSI (14) 4h · Less than 30",
/// "EMA 20 crosses above EMA 50 · 1h", "Funding rate · Greater than 0.05%".
String conditionText(AppLocalizations l, AlertRule rule) {
  final condition = conditionLabel(l, rule.condition);
  final value = rule.threshold == null
      ? ''
      : thresholdText(rule.threshold!, price: rule.type == AlertType.price);
  final indicator = rule.indicator;
  if (rule.type == AlertType.price || indicator == null) {
    return '$condition $value';
  }
  final below = rule.condition == AlertCondition.crossBelow;
  final frame = rule.timeframe == null ? '' : ' · ${rule.timeframe}';
  return switch (indicator) {
    AlertIndicator.macdCross =>
      '${below ? l.alertCrossMACD_BELOW : l.alertCrossMACD_ABOVE}$frame',
    AlertIndicator.emaCross =>
      '${below ? l.alertCrossEMA_BELOW : l.alertCrossEMA_ABOVE}$frame',
    AlertIndicator.fundingRate || AlertIndicator.openInterestChange =>
      '${indicatorLabel(l, indicator)} · $condition $value%',
    AlertIndicator.rsi14 =>
      '${indicatorLabel(l, indicator)} ${rule.timeframe ?? ''} · '
          '$condition $value',
  };
}

/// "7 Nov 14:05" in the device's time zone.
String shortTime(DateTime instant) =>
    DateFormat('d MMM HH:mm', 'en').format(instant.toLocal());

/// "7 Nov 2026" in the device's time zone.
String shortDate(DateTime instant) =>
    DateFormat('d MMM yyyy', 'en').format(instant.toLocal());

/// The words of a refused field, with the field's own label.
String ruleErrorText(AppLocalizations l, RuleError error, String field) =>
    switch (error) {
      RequiredValue() => l.msg01(field),
      NotANumber() => l.alertErrNumber(field),
      NotPositive() => l.alertErrPositive(field),
      OutOfRange(:final min, :final max) => l.msg15(field, min, max),
      CooldownTooShort() => l.alertErrCooldown(field),
      ExpiryOutOfWindow() => l.alertErrExpiry,
    };
