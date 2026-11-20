import 'package:decimal/decimal.dart';

/// Display formatting of the API's decimal strings (CR-02, CR-03), the same
/// rules as the web client: never through `double`, rounding half away from
/// zero, thousands grouped with commas.

/// Significant fraction digits of a step such as a tick size
/// ("0.01000000" → 2, "1" → 0, null → 0).
int decimalPlaces(String? step) {
  if (step == null) return 0;
  final point = step.indexOf('.');
  if (point < 0) return 0;
  return step.substring(point + 1).replaceFirst(RegExp(r'0+$'), '').length;
}

/// "1234567.5" → "1,234,567.5": groups the integer part only.
String groupThousands(String value) {
  final negative = value.startsWith('-');
  final unsigned = negative || value.startsWith('+')
      ? value.substring(1)
      : value;
  final point = unsigned.indexOf('.');
  final whole = point < 0 ? unsigned : unsigned.substring(0, point);
  final fraction = point < 0 ? '' : unsigned.substring(point);
  final grouped = whole.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return '${negative ? '-' : ''}$grouped$fraction';
}

/// A price or amount at [places] fraction digits, grouped; `--` when absent.
String formatDecimal(String? value, int places) {
  final parsed = value == null ? null : Decimal.tryParse(value.trim());
  if (parsed == null) return '--';
  return groupThousands(parsed.toStringAsFixed(places));
}

/// A price at the pair's tick precision (CR-02).
/// A backend decimal without its trailing zeros, grouped
/// ("73852.320000000000" → "73,852.32", "0.002000000000" → "0.002");
/// [keep] decimals stay for an amount of money ("-0.500000000000" →
/// "-0.50" with 2). `--` when it is not a number.
String formatTrimmed(String? value, {int keep = 0}) {
  final text = value?.trim();
  if (text == null || Decimal.tryParse(text) == null) return '--';
  var out = text;
  final point = out.indexOf('.');
  if (point >= 0) {
    var end = out.length;
    while (end > point + 1 + keep && out[end - 1] == '0') {
      end--;
    }
    out = out.substring(0, end);
    if (out.endsWith('.')) out = out.substring(0, out.length - 1);
  }
  return groupThousands(out);
}

/// A cost or a price without its pair: two decimals from 1 up, six below
/// ("79361.667533661822" → "79,361.67", "0.0123456789" → "0.012346").
String formatCost(String? value) {
  final parsed = value == null ? null : Decimal.tryParse(value.trim());
  if (parsed == null) return '--';
  final places = parsed.abs() >= Decimal.one ? 2 : 6;
  return formatTrimmed(parsed.toStringAsFixed(places));
}

String formatPrice(String? value, String? tickSize) =>
    formatDecimal(value, decimalPlaces(tickSize));

enum Direction { up, down, flat }

Direction directionOf(String? value) {
  final parsed = value == null ? null : Decimal.tryParse(value.trim());
  if (parsed == null || parsed == Decimal.zero) return Direction.flat;
  return parsed > Decimal.zero ? Direction.up : Direction.down;
}

/// A percent that is already in percent units ("1.2345" → "+1.23%"); the
/// sign is always shown, so the change never relies on colour alone.
String formatSignedPercent(String? value, {int places = 2}) {
  final parsed = value == null ? null : Decimal.tryParse(value.trim());
  if (parsed == null) return '--';
  final text = parsed.abs().toStringAsFixed(places);
  final zero = Decimal.parse(text) == Decimal.zero;
  final sign = zero ? '' : (parsed > Decimal.zero ? '+' : '−');
  return '$sign$text%';
}

/// A fraction shown as a percent: the funding rate "0.0001" → "+0.0100%".
String formatFractionAsPercent(String? value, {int places = 4}) {
  final parsed = value == null ? null : Decimal.tryParse(value.trim());
  if (parsed == null) return '--';
  return formatSignedPercent(parsed.shift(2).toString(), places: places);
}

const _units = [(13, 'T'), (10, 'B'), (7, 'M'), (4, 'K')];

/// A volume in K / M / B / T with two decimals ("1139455120.42" → "1.14B").
String formatCompact(String? value) {
  final parsed = value == null ? null : Decimal.tryParse(value.trim());
  if (parsed == null) return '--';
  final digits = parsed.abs().truncate().toBigInt().toString().length;
  for (final (minDigits, suffix) in _units) {
    if (parsed.abs() >= Decimal.one && digits >= minDigits) {
      final scaled = parsed.shift(-(minDigits - 1));
      return '${scaled.toStringAsFixed(2)}$suffix';
    }
  }
  return groupThousands(parsed.toStringAsFixed(2));
}

/// Orders two decimal strings exactly; unreadable values sort first.
int compareDecimal(String? a, String? b) {
  final x = a == null ? null : Decimal.tryParse(a);
  final y = b == null ? null : Decimal.tryParse(b);
  if (x == null || y == null) {
    return (x == null ? 0 : 1) - (y == null ? 0 : 1);
  }
  return x.compareTo(y);
}

/// An amount with its sign always shown ("+12.4" → "+12.40", "-7.0095" →
/// "−7.01"), so a gain or a loss never relies on colour alone.
String formatSignedDecimal(String? value, {int places = 2}) {
  final parsed = value == null ? null : Decimal.tryParse(value.trim());
  if (parsed == null) return '--';
  final text = groupThousands(parsed.abs().toStringAsFixed(places));
  final zero =
      Decimal.parse(parsed.abs().toStringAsFixed(places)) == Decimal.zero;
  if (zero) return text;
  return '${parsed > Decimal.zero ? '+' : '−'}$text';
}

/// A fraction from 0 to 1 as a percent without sign ("0.625" → "62.5%").
String formatRatioAsPercent(String? value, {int places = 1}) {
  final parsed = value == null ? null : Decimal.tryParse(value.trim());
  if (parsed == null) return '--';
  return '${parsed.shift(2).toStringAsFixed(places)}%';
}

/// `a − b` exactly, as a decimal string (the spread: ask − bid); null when
/// either side is absent or unreadable.
String? subtractDecimal(String? a, String? b) {
  final x = a == null ? null : Decimal.tryParse(a.trim());
  final y = b == null ? null : Decimal.tryParse(b.trim());
  if (x == null || y == null) return null;
  return (x - y).toString();
}
