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
    fontFamily: 'Inter', // remove/adjust if you're not using a custom font
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
      thumbColor: MaterialStateProperty.resolveWith(
        (states) => states.contains(MaterialState.selected)
            ? palette.accent
            : palette.textTertiary,
      ),
      trackColor: MaterialStateProperty.resolveWith(
        (states) => states.contains(MaterialState.selected)
            ? palette.accent.withOpacity(0.3)
            : palette.border,
      ),
    ),
    extensions: [palette],
  );
}

// Backward-compatible constant for any code still referencing
// lightTheme directly (uses the default brand accent).
final ThemeData lightTheme = buildLightTheme();
