import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_plan/core/services/fuzzy_spending_predictor.dart';
import 'package:pocket_plan/models/transaction_model.dart';

TransactionModel _expense(
  DateTime date,
  double amount, {
  BudgetCategory bucket = BudgetCategory.spending,
}) {
  return TransactionModel(
    id: '${date.toIso8601String()}-$amount',
    userId: 'user-1',
    type: TransactionType.expense,
    budgetCategory: bucket,
    amount: amount,
    category: 'Food & Drinks',
    date: date,
    createdAt: date,
  );
}

void main() {
  final refNow = DateTime(2026, 11, 30); // end of Nov so Nov is complete

  group('FuzzySpendingPredictor.predictNextMonth', () {
    test('returns insufficient data on empty transactions', () {
      final res = FuzzySpendingPredictor.predictNextMonth(
        transactions: const [],
        currentMonthLimit: 1000,
        now: refNow,
      );

      expect(res.predictedAmount, 0);
      expect(res.confidenceScore, 0);
      expect(res.trendLabel, 'Insufficient data');
    });

    test('steady zero-volatility spending produces non-zero rules and realistic confidence', () {
      final txs = [
        _expense(DateTime(2026, 8, 10), 500),
        _expense(DateTime(2026, 9, 10), 500),
        _expense(DateTime(2026, 10, 10), 500),
      ];

      final res = FuzzySpendingPredictor.predictNextMonth(
        transactions: txs,
        currentMonthLimit: 1000,
        now: refNow,
      );

      expect(res.trendLabel, 'Stable');
      expect(res.volatilityLabel, 'Low');
      expect(res.confidenceScore, greaterThanOrEqualTo(50));
      expect(res.confidenceScore, lessThanOrEqualTo(95));
      expect(res.predictedAmount, closeTo(500, 1));
    });

    test('handles zero utilization edge without collapsing confidence', () {
      final txs = [
        _expense(DateTime(2026, 9, 5), 100),
        _expense(DateTime(2026, 10, 5), 100),
      ];

      final res = FuzzySpendingPredictor.predictNextMonth(
        transactions: txs,
        currentMonthLimit: 0,
        now: refNow,
      );

      expect(res.utilizationLabel, 'Low');
      expect(res.confidenceScore, greaterThan(0));
      expect(res.predictedAmount, closeTo(95, 1));
    });

    test('detects increasing and decreasing spending trends', () {
      final increasing = [
        _expense(DateTime(2026, 8, 5), 300),
        _expense(DateTime(2026, 9, 5), 500),
        _expense(DateTime(2026, 10, 5), 700),
      ];
      final incRes = FuzzySpendingPredictor.predictNextMonth(
        transactions: increasing,
        currentMonthLimit: 1000,
        now: refNow,
      );
      expect(incRes.trendLabel, 'Increasing');
      expect(incRes.adjustmentFactor, greaterThan(0));
      expect(incRes.predictedAmount, greaterThan(500));

      final decreasing = [
        _expense(DateTime(2026, 8, 5), 700),
        _expense(DateTime(2026, 9, 5), 500),
        _expense(DateTime(2026, 10, 5), 300),
      ];
      final decRes = FuzzySpendingPredictor.predictNextMonth(
        transactions: decreasing,
        currentMonthLimit: 1000,
        now: refNow,
      );
      expect(decRes.trendLabel, 'Decreasing');
      expect(decRes.adjustmentFactor, lessThan(0));
      expect(decRes.predictedAmount, lessThan(500));
    });

    test('respects custom bucket limits instead of hardcoded 50/30/20', () {
      final txs = [
        _expense(DateTime(2026, 9, 5), 400, bucket: BudgetCategory.spending),
        _expense(DateTime(2026, 10, 5), 400, bucket: BudgetCategory.spending),
      ];

      final tightBucket = FuzzySpendingPredictor.predictNextMonth(
        transactions: txs,
        currentMonthLimit: 1000,
        spendingLimit: 300, // high utilization (400/300)
        now: refNow,
      );
      final generousBucket = FuzzySpendingPredictor.predictNextMonth(
        transactions: txs,
        currentMonthLimit: 1000,
        spendingLimit: 2000, // low utilization (400/2000)
        now: refNow,
      );

      expect(
        tightBucket.predictedSpending,
        greaterThan(generousBucket.predictedSpending),
      );
    });

    test('excludes incomplete current month when completed months exist', () {
      final midMonthNow = DateTime(2026, 11, 10);
      final txs = [
        _expense(DateTime(2026, 9, 5), 600),
        _expense(DateTime(2026, 10, 5), 600),
        _expense(DateTime(2026, 11, 2), 20), // partial November
      ];

      final res = FuzzySpendingPredictor.predictNextMonth(
        transactions: txs,
        currentMonthLimit: 1000,
        now: midMonthNow,
      );

      expect(res.predictedAmount, closeTo(600, 1));
    });

    test('keeps incomplete current month if it is the only month with data', () {
      final midMonthNow = DateTime(2026, 11, 10);
      final txs = [_expense(DateTime(2026, 11, 2), 250)];

      final res = FuzzySpendingPredictor.predictNextMonth(
        transactions: txs,
        currentMonthLimit: 1000,
        now: midMonthNow,
      );

      expect(res.predictedAmount, greaterThan(0));
      expect(res.confidenceScore, greaterThan(0));
    });
  });

  group('FuzzySpendingPredictor.predictSixMonths', () {
    test('returns 6 forecasts with monotonically non-increasing confidence', () {
      final txs = [
        _expense(DateTime(2026, 8, 5), 400),
        _expense(DateTime(2026, 9, 5), 450),
        _expense(DateTime(2026, 10, 5), 500),
      ];

      final six = FuzzySpendingPredictor.predictSixMonths(
        transactions: txs,
        currentMonthLimit: 1000,
        now: refNow,
      );

      expect(six.length, 6);
      for (int i = 1; i < six.length; i++) {
        expect(
          six[i].confidenceScore,
          lessThanOrEqualTo(six[i - 1].confidenceScore),
        );
      }
    });
  });
}
