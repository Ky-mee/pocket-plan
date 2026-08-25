import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────
// ACCENT COLOR PROVIDER
// Lets the user pick a custom accent color from
// Settings. Persisted the same way themeProvider is.
// ─────────────────────────────────────────
final accentColorProvider = StateNotifierProvider<AccentColorNotifier, Color>((
  ref,
) {
  return AccentColorNotifier();
});

class AccentColorNotifier extends StateNotifier<Color> {
  static const Color defaultAccent = Color(0xFF6C63FF);

  AccentColorNotifier() : super(defaultAccent) {
    _loadAccent();
  }

  Future<void> _loadAccent() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getInt('accentColor');
    if (stored != null) {
      state = Color(stored);
    }
  }

  Future<void> setAccent(Color color) async {
    final prefs = await SharedPreferences.getInstance();
    state = color;
    await prefs.setInt('accentColor', color.value);
  }

  Future<void> resetToDefault() async {
    final prefs = await SharedPreferences.getInstance();
    state = defaultAccent;
    await prefs.remove('accentColor');
  }
}

// ── Preset swatches shown in the picker ──
const List<Color> accentColorPresets = [
  Color(0xFF6C63FF), // brand purple (default)
  Color(0xFF00D4AA), // teal
  Color(0xFFFF6B6B), // coral red
  Color(0xFFFFB347), // amber
  Color(0xFF4FC3F7), // sky blue
  Color(0xFFCE93D8), // orchid
  Color(0xFF80CBC4), // seafoam
  Color(0xFFE57373), // rose
];
