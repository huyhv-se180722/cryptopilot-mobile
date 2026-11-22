import 'package:cryptopilot_mobile/core/theme/app_theme.dart';
import 'package:cryptopilot_mobile/core/theme/cp_colors.dart';
import 'package:cryptopilot_mobile/features/market/presentation/market_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// T-151 (D-163): the list style of Markets and Home.
void main() {
  group('ChangeText', () {
    Future<void> show(WidgetTester tester, Brightness brightness) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(brightness),
          home: const Scaffold(
            body: Column(
              children: [
                ChangeText(percent: '2.41'),
                ChangeText(percent: '-1.27'),
                ChangeText(percent: '0.001'),
                ChangeText(percent: null),
              ],
            ),
          ),
        ),
      );
    }

    for (final brightness in Brightness.values) {
      testWidgets('${brightness.name}: sign, colour and arrow agree', (
        tester,
      ) async {
        final cp = brightness == Brightness.dark
            ? CpColors.dark
            : CpColors.light;
        await show(tester, brightness);
        expect(
          tester.widget<Text>(find.text('+2.41%')).style!.color,
          cp.positive,
        );
        // The formatter writes the minus sign U+2212.
        expect(
          tester.widget<Text>(find.text('−1.27%')).style!.color,
          cp.negative,
        );
        expect(find.byIcon(Icons.arrow_drop_up), findsOneWidget);
        expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget);
        // Rounded to zero: no sign, no arrow, muted.
        expect(tester.widget<Text>(find.text('0.00%')).style!.color, cp.muted);
        expect(find.text('--'), findsOneWidget);
      });
    }
  });
}
