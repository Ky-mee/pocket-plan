import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────
// THEME PROVIDER
// ─────────────────────────────────────────
final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier();
});

class ThemeNotifier extends StateNotifier<ThemeMode> {
  static const String _modeKey = 'themeMode';
  static const String _legacyDarkKey = 'darkMode';

  ThemeNotifier() : super(ThemeMode.system) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final storedMode = prefs.getString(_modeKey);
    if (storedMode != null) {
      state = switch (storedMode) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
      return;
    }

    if (prefs.containsKey(_legacyDarkKey)) {
      final isDark = prefs.getBool(_legacyDarkKey) ?? true;
      state = isDark ? ThemeMode.dark : ThemeMode.light;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    final modeStr = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await prefs.setString(_modeKey, modeStr);
    if (mode != ThemeMode.system) {
      await prefs.setBool(_legacyDarkKey, mode == ThemeMode.dark);
    }
  }

  Future<void> toggleTheme() async {
    await setThemeMode(
      state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
    );
  }

  bool get isDark => state == ThemeMode.dark;
}
