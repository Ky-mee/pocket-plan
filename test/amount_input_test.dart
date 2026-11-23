import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_plan/core/utils/amount_input.dart';

TextEditingValue _edit(String oldText, String newText) {
  const formatter = AmountInputFormatter();
  return formatter.formatEditUpdate(
    TextEditingValue(
      text: oldText,
      selection: TextSelection.collapsed(offset: oldText.length),
    ),
    TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    ),
  );
}

void main() {
  group('parseCents', () {
    test('parses whole, decimal, comma, and empty inputs accurately', () {
      expect(parseCents('12.5'), 1250);
      expect(parseCents('0.07'), 7);
      expect(parseCents('12,34'), 1234);
      expect(parseCents('100'), 10000);
      expect(parseCents(''), 0);
      expect(parseCents('.'), 0);
      expect(parseCents('  9.99  '), 999);
    });
  });

  group('AmountInputFormatter', () {
    test('accepts valid decimals and normalizes commas to dots', () {
      expect(_edit('', '12.34').text, '12.34');
      expect(_edit('12', '12,5').text, '12.5');
      expect(_edit('', '.5').text, '.5');
    });

    test('rejects invalid characters, extra decimals, and digit overflow', () {
      expect(_edit('12.34', '12.345').text, '12.34');
      expect(_edit('12.3', '12.3.4').text, '12.3');
      expect(_edit('12', '12a').text, '12');
      expect(_edit('1234567', '12345678').text, '1234567');
    });
  });
}
