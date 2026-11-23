import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_plan/core/utils/budget_calculator.dart';
import 'package:pocket_plan/core/utils/budget_cycle.dart';
import 'package:pocket_plan/models/budget_model.dart';
import 'package:pocket_plan/models/transaction_model.dart';

void main() {
  group('BudgetCycle', () {
    test('startDay 1 matches standard calendar month and leap Feb', () {
      final apr = BudgetCycle.forDate(DateTime(2026, 4, 15));
      expect(apr.key, '2026-04');
      expect(apr.start, DateTime(2026, 4, 1));
      expect(apr.end, DateTime(2026, 4, 30));
      expect(apr.totalDays, 30);
      expect(apr.formatLabel(), 'April 2026');

      final leapFeb = BudgetCycle.forDate(DateTime(2024, 2, 20));
      expect(leapFeb.key, '2024-02');
      expect(leapFeb.end, DateTime(2024, 2, 29));
      expect(leapFeb.totalDays, 29);
    });

    test('custom startDay 25 groups dates across month boundary', () {
      final beforePayday = BudgetCycle.forDate(
        DateTime(2026, 4, 10),
        startDay: 25,
      );
      expect(beforePayday.key, '2026-03');
      expect(beforePayday.start, DateTime(2026, 3, 25));
      expect(beforePayday.end, DateTime(2026, 4, 24));
      expect(beforePayday.contains(DateTime(2026, 3, 25)), isTrue);
      expect(beforePayday.contains(DateTime(2026, 4, 24)), isTrue);
      expect(beforePayday.contains(DateTime(2026, 4, 25)), isFalse);

      final onPayday = BudgetCycle.forDate(
        DateTime(2026, 4, 25),
        startDay: 25,
      );
      expect(onPayday.key, '2026-04');
      expect(onPayday.start, DateTime(2026, 4, 25));
      expect(onPayday.end, DateTime(2026, 5, 24));
    });

    test('handles December to January year rollover cleanly', () {
      final janEarly = BudgetCycle.forDate(
        DateTime(2026, 1, 10),
        startDay: 25,
      );
      expect(janEarly.key, '2025-12');
      expect(janEarly.start, DateTime(2025, 12, 25));
      expect(janEarly.end, DateTime(2026, 1, 24));
      expect(janEarly.daysRemaining(DateTime(2026, 1, 24)), 1);
      expect(janEarly.daysRemaining(DateTime(2026, 1, 26)), 0);
    });

    test('clamps startDay safely between 1 and 28', () {
      expect(BudgetCycle.clampStartDay(0), 1);
      expect(BudgetCycle.clampStartDay(-5), 1);
      expect(BudgetCycle.clampStartDay(31), 28);
      expect(BudgetCycle.clampStartDay(15), 15);
    });

    test('BudgetCalculator uses budgetStartDay for transaction membership', () {
      final budget = BudgetModel.fromAllowance(
        userId: 'u1',
        allowance: 3000,
        month: '2026-03',
        budgetStartDay: 25,
      );

      final inCycleTx = TransactionModel(
        id: 't1',
        userId: 'u1',
        type: TransactionType.expense,
        budgetCategory: BudgetCategory.spending,
        amount: 50,
        category: 'Dining Out & Cafes',
        date: DateTime(2026, 4, 10),
        createdAt: DateTime(2026, 4, 10),
      );

      final nextCycleTx = TransactionModel(
        id: 't2',
        userId: 'u1',
        type: TransactionType.expense,
        budgetCategory: BudgetCategory.spending,
        amount: 99,
        category: 'Dining Out & Cafes',
        date: DateTime(2026, 4, 26),
        createdAt: DateTime(2026, 4, 26),
      );

      final afterIn = BudgetCalculator.applyTransaction(budget, inCycleTx);
      expect(afterIn.spendings.spent, 50);

      final afterNext = BudgetCalculator.applyTransaction(afterIn, nextCycleTx);
      expect(afterNext.spendings.spent, 50);

      final reversed = BudgetCalculator.reverseTransaction(afterNext, inCycleTx);
      expect(reversed.spendings.spent, 0);
    });
  });
}
