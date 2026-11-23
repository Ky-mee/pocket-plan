import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_plan/core/utils/currency_formatter.dart';

void main() {
  group('CurrencyFormatter', () {
    test('formats supported currencies with expected symbols and decimals', () {
      expect(CurrencyFormatter.format(125.5, code: 'MYR'), 'RM 125.50');
      expect(CurrencyFormatter.format(42, code: 'USD'), '\$ 42.00');
      expect(CurrencyFormatter.format(1500, code: 'JPY'), '¥ 1500');
      expect(CurrencyFormatter.format(50000, code: 'IDR'), 'Rp 50000');
    });

    test('handles negative amounts and unknown codes safely', () {
      expect(CurrencyFormatter.format(-25.3, code: 'EUR'), '-€ 25.30');
      expect(CurrencyFormatter.of('xyz').code, 'MYR');
      expect(CurrencyFormatter.format(10, code: 'unknown'), 'RM 10.00');
    });

    test('formats signed expense and income strings', () {
      expect(
        CurrencyFormatter.signed(88.4, isExpense: true, code: 'SGD'),
        '-S\$ 88.40',
      );
      expect(
        CurrencyFormatter.signed(2500, isExpense: false, code: 'GBP'),
        '+£ 2500.00',
      );
    });
  });
}
