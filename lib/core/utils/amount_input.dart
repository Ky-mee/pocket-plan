import 'package:flutter/services.dart';

/// Allows only a money amount while typing: digits, one decimal point,
/// at most 2 decimals, at most [maxIntDigits] whole digits.
/// A comma (some keyboards) is converted to a dot.
class AmountInputFormatter extends TextInputFormatter {
  final int maxIntDigits;
  const AmountInputFormatter({this.maxIntDigits = 7});

  static final _pattern = RegExp(r'^\d*\.?\d{0,2}$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(',', '.');
    if (!_pattern.hasMatch(text)) return oldValue;
    if (text.split('.').first.length > maxIntDigits) return oldValue;
    if (text == newValue.text) return newValue;
    return newValue.copyWith(
      text: text,
      selection: TextSelection.collapsed(
        offset: newValue.selection.end.clamp(0, text.length).toInt(),
      ),
    );
  }
}

/// "12.5" -> 1250, "0.07" -> 7, "" -> 0. Integer maths, no float rounding.
int parseCents(String text) {
  final t = text.trim().replaceAll(',', '.');
  if (t.isEmpty || t == '.') return 0;
  final parts = t.split('.');
  final whole = int.tryParse(parts[0].isEmpty ? '0' : parts[0]) ?? 0;
  final frac = (parts.length > 1 ? parts[1] : '').padRight(2, '0').substring(0, 2);
  return whole * 100 + (int.tryParse(frac) ?? 0);
}
