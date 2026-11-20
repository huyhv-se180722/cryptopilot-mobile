import 'package:cryptopilot_mobile/core/theme/app_theme.dart';
import 'package:cryptopilot_mobile/features/academy/presentation/academy_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Device check: a lesson cover shows the tint and its icon while the
/// photo loads, not an empty gap.
void main() {
  testWidgets('the tint holds the place while the photo loads', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: const Scaffold(
          body: SizedBox(
            width: 80,
            height: 60,
            child: LessonCover(url: 'https://images.example.invalid/c.jpg'),
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.school_outlined), findsOneWidget);
  });
}
