import 'package:flutter/material.dart';
import 'package:pocket_plan/core/themes/app_colors.dart';

// Builds the dark ThemeData with a given accent color.
// Falls back to AppColors.dark.accent if none is passed.
ThemeData buildDarkTheme([Color? accent]) {
  final palette = AppColors.dark.copyWith(
    accent: accent ?? AppColors.dark.accent,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: palette.background,
    colorScheme: ColorScheme.dark(
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
// darkTheme directly (uses the default brand accent).
final ThemeData darkTheme = buildDarkTheme();
