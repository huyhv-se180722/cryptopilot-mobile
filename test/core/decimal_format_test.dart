import 'package:cryptopilot_mobile/core/format/decimal_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tick size gives the fraction digits', () {
    expect(decimalPlaces('0.01000000'), 2);
    expect(decimalPlaces('0.00001000'), 5);
    expect(decimalPlaces('1.00000000'), 0);
    expect(decimalPlaces(null), 0);
  });

  test('prices round half away from zero at the tick and group thousands', () {
    expect(formatPrice('67210.505', '0.01'), '67,210.51');
    expect(formatPrice('0.123456', '0.0001'), '0.1235');
    expect(formatPrice('1234567', '1'), '1,234,567');
    expect(formatPrice('-1234.5', '0.1'), '-1,234.5');
    expect(formatPrice(null, '0.01'), '--');
    expect(formatPrice('abc', '0.01'), '--');
  });

  test('changes always carry a sign (never colour alone)', () {
    expect(formatSignedPercent('1.2345'), '+1.23%');
    expect(formatSignedPercent('-0.8'), '−0.80%');
    expect(formatSignedPercent('0.001'), '0.00%');
    expect(directionOf('-0.8'), Direction.down);
    expect(directionOf('0'), Direction.flat);
    expect(directionOf('2'), Direction.up);
  });

  test('the funding rate is a fraction shown as a percent', () {
    expect(formatFractionAsPercent('0.0001'), '+0.0100%');
    expect(formatFractionAsPercent('-0.00025'), '−0.0250%');
  });

  test('volumes are compact as on the web', () {
    expect(formatCompact('1139455120.42'), '1.14B');
    expect(formatCompact('25000000'), '25.00M');
    expect(formatCompact('1500'), '1.50K');
    expect(formatCompact('999.5'), '999.50');
    expect(formatCompact('12345678901234'), '12.35T');
  });

  test('decimals compare exactly', () {
    expect(compareDecimal('0.30', '0.3'), 0);
    expect(
      compareDecimal('100000000000000000.01', '100000000000000000.02'),
      -1,
    );
    expect(compareDecimal(null, '1'), lessThan(0));
  });
}
