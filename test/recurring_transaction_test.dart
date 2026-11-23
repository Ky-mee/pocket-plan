import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_plan/core/utils/budget_cycle.dart';
import 'package:pocket_plan/models/recurring_transaction_model.dart';
import 'package:pocket_plan/models/transaction_model.dart';

void main() {
  RecurringTransactionModel makeItem({
    int dayOfMonth = 15,
    bool isActive = true,
    String lastProcessedCycle = '',
  }) {
    return RecurringTransactionModel(
      id: 'rec_1',
      userId: 'u1',
      title: 'Internet Plan',
      amount: 99.0,
      type: TransactionType.expense,
      budgetCategory: BudgetCategory.commitment,
      category: 'Bills & Utilities',
      dayOfMonth: dayOfMonth,
      isActive: isActive,
      lastProcessedCycle: lastProcessedCycle,
      createdAt: DateTime(2026, 1, 1),
    );
  }

  group('RecurringTransactionModel', () {
    test('standard cycle due checks respect dayOfMonth, active & processed', () {
      final cycle = BudgetCycle.forDate(DateTime(2026, 4, 1));
      final item = makeItem(dayOfMonth: 15);

      expect(item.dueDateInCycle(cycle), DateTime(2026, 4, 15));
      expect(item.isDueForCycle(cycle, DateTime(2026, 4, 10)), isFalse);
      expect(item.isDueForCycle(cycle, DateTime(2026, 4, 15)), isTrue);
      expect(item.isDueForCycle(cycle, DateTime(2026, 4, 20)), isTrue);

      final alreadyProcessed = item.copyWith(lastProcessedCycle: '2026-04');
      expect(
        alreadyProcessed.isDueForCycle(cycle, DateTime(2026, 4, 20)),
        isFalse,
      );

      final paused = item.copyWith(isActive: false);
      expect(paused.isDueForCycle(cycle, DateTime(2026, 4, 20)), isFalse);
    });

    test('custom payday cycle maps day >= startDay to start month and < startDay to end month', () {
      final cycle = BudgetCycle.forDate(DateTime(2026, 4, 10), startDay: 25);

      final lateMonthBill = makeItem(dayOfMonth: 28);
      expect(lateMonthBill.dueDateInCycle(cycle), DateTime(2026, 3, 28));
      expect(lateMonthBill.isDueForCycle(cycle, DateTime(2026, 3, 29)), isTrue);

      final earlyMonthBill = makeItem(dayOfMonth: 5);
      expect(earlyMonthBill.dueDateInCycle(cycle), DateTime(2026, 4, 5));
      expect(
        earlyMonthBill.isDueForCycle(cycle, DateTime(2026, 3, 30)),
        isFalse,
      );
      expect(
        earlyMonthBill.isDueForCycle(cycle, DateTime(2026, 4, 6)),
        isTrue,
      );
    });

    test('copyWith clamps dayOfMonth to 1..28', () {
      final item = makeItem().copyWith(dayOfMonth: 31);
      expect(item.dayOfMonth, 28);
      final minItem = makeItem().copyWith(dayOfMonth: 0);
      expect(minItem.dayOfMonth, 1);
    });
  });
}
