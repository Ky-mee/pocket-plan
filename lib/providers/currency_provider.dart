import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocket_plan/core/utils/currency_formatter.dart';
import 'package:shared_preferences/shared_preferences.dart';

final currencyProvider = StateNotifierProvider<CurrencyNotifier, String>((ref) {
  return CurrencyNotifier();
});

class CurrencyNotifier extends StateNotifier<String> {
  static const String _prefKey = 'currency';

  CurrencyNotifier() : super('MYR') {
    _loadCurrency();
  }

  Future<void> _loadCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefKey);
    if (stored != null && stored.isNotEmpty) {
      state = CurrencyFormatter.of(stored).code;
    }
  }

  Future<void> setCurrency(String code) async {
    final normalized = CurrencyFormatter.of(code).code;
    state = normalized;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, normalized);
  }

  Future<void> syncFromProfile(String? code) async {
    if (code == null || code.trim().isEmpty) return;
    final normalized = CurrencyFormatter.of(code).code;
    if (normalized == state) return;
    await setCurrency(normalized);
  }
}
