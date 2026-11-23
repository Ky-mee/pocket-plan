class CurrencyInfo {
  final String code;
  final String symbol;
  final String name;
  final int decimals;

  const CurrencyInfo({
    required this.code,
    required this.symbol,
    required this.name,
    this.decimals = 2,
  });
}

const List<CurrencyInfo> kSupportedCurrencies = [
  CurrencyInfo(code: 'MYR', symbol: 'RM', name: 'Malaysian Ringgit'),
  CurrencyInfo(code: 'USD', symbol: '\$', name: 'US Dollar'),
  CurrencyInfo(code: 'SGD', symbol: 'S\$', name: 'Singapore Dollar'),
  CurrencyInfo(code: 'GBP', symbol: '£', name: 'British Pound'),
  CurrencyInfo(code: 'EUR', symbol: '€', name: 'Euro'),
  CurrencyInfo(code: 'AUD', symbol: 'A\$', name: 'Australian Dollar'),
  CurrencyInfo(
    code: 'IDR',
    symbol: 'Rp',
    name: 'Indonesian Rupiah',
    decimals: 0,
  ),
  CurrencyInfo(code: 'THB', symbol: '฿', name: 'Thai Baht'),
  CurrencyInfo(code: 'PHP', symbol: '₱', name: 'Philippine Peso'),
  CurrencyInfo(code: 'JPY', symbol: '¥', name: 'Japanese Yen', decimals: 0),
];

class CurrencyFormatter {
  static CurrencyInfo of(String? code) {
    final normalized = (code ?? '').trim().toUpperCase();
    for (final c in kSupportedCurrencies) {
      if (c.code == normalized) return c;
    }
    return kSupportedCurrencies.first;
  }

  static String symbol(String? code) => of(code).symbol;

  static String format(double amount, {String? code, int? decimals}) {
    final info = of(code);
    final d = decimals ?? info.decimals;
    final sign = amount < 0 ? '-' : '';
    return '$sign${info.symbol} ${amount.abs().toStringAsFixed(d)}';
  }

  static String signed(
    double amount, {
    required bool isExpense,
    String? code,
  }) {
    final prefix = isExpense ? '-' : '+';
    return '$prefix${format(amount.abs(), code: code)}';
  }
}
