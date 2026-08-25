import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════
// APP COLORS — custom ThemeExtension
// Lets every screen read semantic colors (background, card,
// text tiers, accent, success/danger) that automatically
// swap between light and dark palettes.
// ═══════════════════════════════════════════════════════════
@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color background;
  final Color surface; // card background
  final Color surfaceAlt; // slightly elevated / secondary card
  final Color border;

  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  final Color accent; // brand purple
  final Color success;
  final Color danger;
  final Color warning;
  final Color info;

  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.accent,
    required this.success,
    required this.danger,
    required this.warning,
    required this.info,
  });

  // ── DARK PALETTE (your existing look) ──
  static const dark = AppColors(
    background: Color(0xFF0F0F1A),
    surface: Color(0xFF1A1A2E),
    surfaceAlt: Color(0xFF22223A),
    border: Colors.white12,
    textPrimary: Colors.white,
    textSecondary: Color(0xFF9E9FBF),
    textTertiary: Color(0xFF4A4A6A),
    accent: Color(0xFF6C63FF),
    success: Color(0xFF00D4AA),
    danger: Color(0xFFFF6B6B),
    warning: Color(0xFFFFB347),
    info: Color(0xFF4FC3F7),
  );

  // ── LIGHT PALETTE ──
  static const light = AppColors(
    background: Color(0xFFF6F6FB),
    surface: Colors.white,
    surfaceAlt: Color(0xFFF0F0F8),
    border: Color(0xFFE4E4EF),
    textPrimary: Color(0xFF1C1C28),
    textSecondary: Color(0xFF6B6B85),
    textTertiary: Color(0xFF9B9BB0),
    accent: Color(0xFF6C63FF),
    success: Color(0xFF00A88A),
    danger: Color(0xFFE94E4E),
    warning: Color(0xFFE0961F),
    info: Color(0xFF1D9BD8),
  );

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? accent,
    Color? success,
    Color? danger,
    Color? warning,
    Color? info,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      accent: accent ?? this.accent,
      success: success ?? this.success,
      danger: danger ?? this.danger,
      warning: warning ?? this.warning,
      info: info ?? this.info,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      success: Color.lerp(success, other.success, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      info: Color.lerp(info, other.info, t)!,
    );
  }
}

// ─────────────────────────────────────────
// Convenience accessor: context.colors.xxx
// ─────────────────────────────────────────
extension AppColorsX on BuildContext {
  AppColors get colors =>
      Theme.of(this).extension<AppColors>() ?? AppColors.dark;
}
