import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_plan/core/utils/budget_calculator.dart';
import 'package:pocket_plan/models/budget_model.dart';
import 'package:pocket_plan/models/transaction_model.dart';

BudgetModel _makeBudget({
  String month = '2026-11',
  double allowance = 1000,
  double cSpent = 0,
  double spSpent = 0,
  double svSpent = 0,
  double cCarry = 0,
  double spCarry = 0,
  double svCarry = 0,
}) {
  return BudgetModel(
    userId: 'user-1',
    monthlyAllowance: allowance,
    commitments: BucketData(
      limit: allowance * 0.50 + cCarry,
      baseLimit: allowance * 0.50,
      spent: cSpent,
      items: const ['Rent', 'Utilities'],
      carriedForward: cCarry,
    ),
    spendings: BucketData(
      limit: allowance * 0.30 + spCarry,
      baseLimit: allowance * 0.30,
      spent: spSpent,
      items: const ['Food & Drinks'],
      carriedForward: spCarry,
    ),
    savings: BucketData(
      limit: allowance * 0.20 + svCarry,
      baseLimit: allowance * 0.20,
      spent: svSpent,
      items: const ['Bank Savings'],
      carriedForward: svCarry,
    ),
    month: month,
    updatedAt: DateTime(2026, 11, 1),
  );
}

TransactionModel _makeTx({
  String id = 'tx-1',
  TransactionType type = TransactionType.expense,
  BudgetCategory bucket = BudgetCategory.spending,
  double amount = 50,
  DateTime? date,
}) {
  final d = date ?? DateTime(2026, 11, 15);
  return TransactionModel(
    id: id,
    userId: 'user-1',
    type: type,
    budgetCategory: bucket,
    amount: amount,
    category: type == TransactionType.income ? 'Part-time Job' : 'Food & Drinks',
    date: d,
    createdAt: d,
  );
}

void main() {
  group('BudgetCalculator.applyTransaction & reverseTransaction', () {
    test('expense updates only its target bucket spent and reverses cleanly', () {
      final budget = _makeBudget();
      final tx = _makeTx(bucket: BudgetCategory.spending, amount: 75);

      final afterAdd = BudgetCalculator.applyTransaction(budget, tx);
      expect(afterAdd.spendings.spent, 75);
      expect(afterAdd.commitments.spent, 0);
      expect(afterAdd.savings.spent, 0);
      expect(afterAdd.monthlyAllowance, 1000);

      final afterDelete = BudgetCalculator.reverseTransaction(afterAdd, tx);
      expect(afterDelete.spendings.spent, 0);
      expect(afterDelete.monthlyAllowance, 1000);
    });

    test('income scales allowance and 50/30/20 limits without corrupting savings.spent', () {
      final budget = _makeBudget();
      final income = _makeTx(
        type: TransactionType.income,
        bucket: BudgetCategory.savings,
        amount: 200,
      );

      final afterAdd = BudgetCalculator.applyTransaction(budget, income);
      expect(afterAdd.savings.spent, 0);
      expect(afterAdd.monthlyAllowance, 1200);
      expect(afterAdd.commitments.limit, 600);
      expect(afterAdd.commitments.baseLimit, 600);
      expect(afterAdd.spendings.limit, 360);
      expect(afterAdd.spendings.baseLimit, 360);
      expect(afterAdd.savings.limit, 240);
      expect(afterAdd.savings.baseLimit, 240);

      final afterDelete = BudgetCalculator.reverseTransaction(afterAdd, income);
      expect(afterDelete.savings.spent, 0);
      expect(afterDelete.monthlyAllowance, 1000);
      expect(afterDelete.commitments.limit, 500);
      expect(afterDelete.spendings.limit, 300);
      expect(afterDelete.savings.limit, 200);
    });

    test('transactions outside active budget month are ignored', () {
      final budget = _makeBudget(month: '2026-11');
      final pastExpense = _makeTx(
        amount: 120,
        date: DateTime(2026, 10, 28),
      );

      final afterAdd = BudgetCalculator.applyTransaction(budget, pastExpense);
      expect(afterAdd.spendings.spent, 0);
      expect(afterAdd.monthlyAllowance, 1000);

      final afterDelete = BudgetCalculator.reverseTransaction(
        afterAdd,
        pastExpense,
      );
      expect(afterDelete.spendings.spent, 0);
    });
  });

  group('BudgetCalculator.applyEdit', () {
    test('handles amount change and bucket switch', () {
      final oldTx = _makeTx(bucket: BudgetCategory.spending, amount: 40);
      final budget = BudgetCalculator.applyTransaction(_makeBudget(), oldTx);

      final newTx = _makeTx(bucket: BudgetCategory.commitment, amount: 90);
      final updated = BudgetCalculator.applyEdit(budget, oldTx, newTx);

      expect(updated.spendings.spent, 0);
      expect(updated.commitments.spent, 90);
    });

    test('handles switching expense to income and back', () {
      final expense = _makeTx(bucket: BudgetCategory.spending, amount: 100);
      final budget = BudgetCalculator.applyTransaction(_makeBudget(), expense);

      final income = _makeTx(
        type: TransactionType.income,
        bucket: BudgetCategory.savings,
        amount: 200,
      );
      final asIncome = BudgetCalculator.applyEdit(budget, expense, income);
      expect(asIncome.spendings.spent, 0);
      expect(asIncome.savings.spent, 0);
      expect(asIncome.monthlyAllowance, 1200);
      expect(asIncome.commitments.limit, 600);

      final backToExpense = BudgetCalculator.applyEdit(asIncome, income, expense);
      expect(backToExpense.monthlyAllowance, 1000);
      expect(backToExpense.commitments.limit, 500);
      expect(backToExpense.spendings.spent, 100);
    });

    test('moving a current-month transaction to a past month removes current impact', () {
      final currentTx = _makeTx(amount: 60, date: DateTime(2026, 11, 5));
      final budget = BudgetCalculator.applyTransaction(_makeBudget(), currentTx);
      expect(budget.spendings.spent, 60);

      final movedTx = _makeTx(amount: 60, date: DateTime(2026, 10, 5));
      final updated = BudgetCalculator.applyEdit(budget, currentTx, movedTx);
      expect(updated.spendings.spent, 0);
    });
  });

  group('BudgetCalculator.updateAllowance & updateBucketLimits & reset', () {
    test('updateAllowance preserves spent, carryForward, and items', () {
      final budget = _makeBudget(
        allowance: 1000,
        cSpent: 120,
        spSpent: 80,
        spCarry: 40,
      );

      final updated = BudgetCalculator.updateAllowance(budget, 2000);
      expect(updated.monthlyAllowance, 2000);
      expect(updated.commitments.spent, 120);
      expect(updated.spendings.spent, 80);
      expect(updated.spendings.carriedForward, 40);
      expect(updated.spendings.baseLimit, 600);
      expect(updated.spendings.limit, 640);
      expect(updated.commitments.items, ['Rent', 'Utilities']);
    });

    test('updateBucketLimits persists custom baseLimit across monthly reset', () {
      final budget = _makeBudget(allowance: 1000, spCarry: 50);
      final customized = BudgetCalculator.updateBucketLimits(
        budget,
        commitmentLimit: 600,
        spendingLimit: 350,
        savingsLimit: 150,
      );

      expect(customized.commitments.baseLimit, 600);
      expect(customized.spendings.baseLimit, 300); // 350 - 50 carriedForward
      expect(customized.savings.baseLimit, 150);

      final resetNoCarry = BudgetCalculator.resetForNewMonth(
        customized,
        newMonth: '2026-12',
        carryForwardEnabled: false,
      );
      expect(resetNoCarry.commitments.limit, 600);
      expect(resetNoCarry.spendings.limit, 300);
      expect(resetNoCarry.savings.limit, 150);
      expect(resetNoCarry.month, '2026-12');
    });

    test('resetForNewMonth carries positive leftovers only (no negative debt)', () {
      final budget = _makeBudget(
        allowance: 1000, // limits: 500, 300, 200
        cSpent: 400, // leftover 100
        spSpent: 350, // overspent by 50 -> leftover 0
        svSpent: 50, // leftover 150
      );

      final reset = BudgetCalculator.resetForNewMonth(
        budget,
        newMonth: '2026-12',
        carryForwardEnabled: true,
      );

      expect(reset.commitments.carriedForward, 100);
      expect(reset.commitments.limit, 600);
      expect(reset.commitments.spent, 0);

      expect(reset.spendings.carriedForward, 0);
      expect(reset.spendings.limit, 300);
      expect(reset.spendings.spent, 0);

      expect(reset.savings.carriedForward, 150);
      expect(reset.savings.limit, 350);
      expect(reset.savings.spent, 0);
    });

    test('updateRatios normalizes ratios and income scales using custom split', () {
      final budget = _makeBudget(allowance: 1000, spCarry: 50);
      final updated = BudgetCalculator.updateRatios(
        budget,
        commitmentRatio: 60,
        spendingRatio: 20,
        savingsRatio: 20,
      );

      expect(updated.commitmentRatio, closeTo(0.60, 0.0001));
      expect(updated.spendingRatio, closeTo(0.20, 0.0001));
      expect(updated.savingsRatio, closeTo(0.20, 0.0001));
      expect(updated.commitments.baseLimit, closeTo(600, 0.01));
      expect(updated.spendings.baseLimit, closeTo(200, 0.01));
      expect(updated.spendings.limit, closeTo(250, 0.01)); // preserves 50 carry
      expect(updated.savings.baseLimit, closeTo(200, 0.01));

      final income = _makeTx(type: TransactionType.income, amount: 500);
      final afterIncome = BudgetCalculator.applyTransaction(updated, income);
      expect(afterIncome.monthlyAllowance, 1500);
      expect(afterIncome.commitments.limit, closeTo(900, 0.01));
      expect(afterIncome.spendings.limit, closeTo(350, 0.01));
      expect(afterIncome.savings.limit, closeTo(300, 0.01));

      final afterAllowanceUpdate = BudgetCalculator.updateAllowance(
        updated,
        2000,
      );
      expect(afterAllowanceUpdate.commitments.baseLimit, closeTo(1200, 0.01));
      expect(afterAllowanceUpdate.spendings.limit, closeTo(450, 0.01));
    });
  });
}
