import 'package:flutter/material.dart';

import 'cp_colors.dart';

ThemeData appTheme(Brightness brightness) {
  final cp = brightness == Brightness.dark ? CpColors.dark : CpColors.light;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: cp.primary,
        brightness: brightness,
      ).copyWith(
        primary: cp.primary,
        onPrimary: Colors.white,
        surface: cp.surface,
        onSurface: cp.text,
        onSurfaceVariant: cp.muted,
        error: cp.negative,
        outline: cp.border,
        outlineVariant: cp.border,
      );
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: cp.border),
  );
  return ThemeData(
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: cp.bg,
    extensions: [cp],
    appBarTheme: AppBarTheme(
      backgroundColor: cp.bg,
      foregroundColor: cp.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: cp.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cp.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cp.surface,
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: BorderSide(color: cp.primary, width: 1.5),
      ),
      errorBorder: border.copyWith(borderSide: BorderSide(color: cp.negative)),
      focusedErrorBorder: border.copyWith(
        borderSide: BorderSide(color: cp.negative, width: 1.5),
      ),
      errorMaxLines: 3,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 48),
        side: BorderSide(color: cp.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: cp.surface,
      indicatorColor: cp.primary.withValues(alpha: 0.15),
    ),
    dividerTheme: DividerThemeData(color: cp.border, space: 1),
  );
}
