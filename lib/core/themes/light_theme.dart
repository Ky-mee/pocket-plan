import 'package:flutter/material.dart';
import 'package:pocket_plan/core/themes/app_colors.dart';

// Builds the light ThemeData with a given accent color.
// Falls back to AppColors.light.accent if none is passed.
ThemeData buildLightTheme([Color? accent]) {
  final palette = AppColors.light.copyWith(
    accent: accent ?? AppColors.light.accent,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: palette.background,
    colorScheme: ColorScheme.light(
      primary: palette.accent,
      secondary: palette.info,
      error: palette.danger,
      surface: palette.surface,
    ),
    cardColor: palette.surface,
    dividerColor: palette.border,
    appBarTheme: AppBarTheme(
      backgroundColor: palette.background,
      elevation: 0,
      iconTheme: IconThemeData(color: palette.textPrimary),
      titleTextStyle: TextStyle(
        color: palette.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
    textTheme: TextTheme(
      bodyLarge: TextStyle(color: palette.textPrimary),
      bodyMedium: TextStyle(color: palette.textPrimary),
      bodySmall: TextStyle(color: palette.textSecondary),
    ),
    iconTheme: IconThemeData(color: palette.textPrimary),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? palette.accent
            : palette.textTertiary,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? palette.accent.withValues(alpha: 0.3)
            : palette.border,
      ),
    ),
    extensions: [palette],
  );
}

// Backward-compatible constant for any code still referencing
// lightTheme directly (uses the default brand accent).
final ThemeData lightTheme = buildLightTheme();
