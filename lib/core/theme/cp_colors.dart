import 'package:flutter/material.dart';

/// The web client's `--cp-*` tokens, so both clients look like one product.
@immutable
class CpColors extends ThemeExtension<CpColors> {
  const CpColors({
    required this.bg,
    required this.surface,
    required this.raised,
    required this.border,
    required this.text,
    required this.muted,
    required this.primary,
    required this.positive,
    required this.negative,
    required this.onPositive,
    required this.onNegative,
    required this.warning,
    required this.accent,
  });

  static const light = CpColors(
    bg: Color(0xFFF5F7FA),
    surface: Color(0xFFFFFFFF),
    raised: Color(0xFFEDF1F7),
    border: Color(0xFFD9E0EA),
    text: Color(0xFF17212F),
    muted: Color(0xFF526175),
    primary: Color(0xFF2563EB),
    positive: Color(0xFF087F5B),
    negative: Color(0xFFC52D3A),
    onPositive: Color(0xFFFFFFFF),
    onNegative: Color(0xFFFFFFFF),
    warning: Color(0xFF925400),
    accent: Color(0xFF0891B2),
  );

  static const dark = CpColors(
    bg: Color(0xFF030712),
    surface: Color(0xFF0D1424),
    raised: Color(0xFF131F35),
    border: Color(0x14FFFFFF),
    text: Color(0xFFF9FAFB),
    muted: Color(0xFF9CA3AF),
    primary: Color(0xFF3B82F6),
    positive: Color(0xFF10B981),
    negative: Color(0xFFF43F5E),
    onPositive: Color(0xFF030712),
    onNegative: Color(0xFF030712),
    warning: Color(0xFFFFBB33),
    accent: Color(0xFF06B6D4),
  );

  final Color bg;
  final Color surface;
  final Color raised;
  final Color border;
  final Color text;
  final Color muted;
  final Color primary;

  /// Up, gains (shown with a sign as well, never by colour alone).
  final Color positive;

  /// Down, losses, errors.
  final Color negative;

  /// Text and icons on a [positive] or [negative] fill (buttons, change
  /// pills): white on the deeper light-theme colours, near-black on the
  /// brighter dark-theme ones, each at least 4.5:1 (T-148).
  final Color onPositive;
  final Color onNegative;
  final Color warning;
  final Color accent;

  @override
  CpColors copyWith({
    Color? bg,
    Color? surface,
    Color? raised,
    Color? border,
    Color? text,
    Color? muted,
    Color? primary,
    Color? positive,
    Color? negative,
    Color? onPositive,
    Color? onNegative,
    Color? warning,
    Color? accent,
  }) => CpColors(
    bg: bg ?? this.bg,
    surface: surface ?? this.surface,
    raised: raised ?? this.raised,
    border: border ?? this.border,
    text: text ?? this.text,
    muted: muted ?? this.muted,
    primary: primary ?? this.primary,
    positive: positive ?? this.positive,
    negative: negative ?? this.negative,
    onPositive: onPositive ?? this.onPositive,
    onNegative: onNegative ?? this.onNegative,
    warning: warning ?? this.warning,
    accent: accent ?? this.accent,
  );

  @override
  CpColors lerp(ThemeExtension<CpColors>? other, double t) {
    if (other is! CpColors) return this;
    return CpColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      raised: Color.lerp(raised, other.raised, t)!,
      border: Color.lerp(border, other.border, t)!,
      text: Color.lerp(text, other.text, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      positive: Color.lerp(positive, other.positive, t)!,
      negative: Color.lerp(negative, other.negative, t)!,
      onPositive: Color.lerp(onPositive, other.onPositive, t)!,
      onNegative: Color.lerp(onNegative, other.onNegative, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
    );
  }
}

extension CpColorsOf on BuildContext {
  /// The app theme carries the tokens; a bare theme falls back to them.
  CpColors get cp {
    final theme = Theme.of(this);
    return theme.extension<CpColors>() ??
        (theme.brightness == Brightness.dark ? CpColors.dark : CpColors.light);
  }
}
