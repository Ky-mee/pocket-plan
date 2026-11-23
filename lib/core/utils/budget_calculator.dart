import 'package:pocket_plan/core/utils/budget_cycle.dart';
import 'package:pocket_plan/models/budget_model.dart';
import 'package:pocket_plan/models/transaction_model.dart';

/// Pure, side-effect-free calculations for monthly budgets and transactions.
class BudgetCalculator {
  /// Formats [date] as `"yyyy-MM"` according to [startDay], independent of locale settings.
  static String monthKey(DateTime date, {int startDay = 1}) =>
      BudgetCycle.forDate(date, startDay: startDay).key;

  /// True when [date] falls inside [budgetMonth] (`"yyyy-MM"`) for [startDay].
  static bool isInBudgetMonth(
    DateTime date,
    String budgetMonth, {
    int startDay = 1,
  }) =>
      BudgetCycle.forDate(date, startDay: startDay).key == budgetMonth;

  /// Returns a new [BudgetModel] reflecting an added [tx].
  ///
  /// Transactions outside [budget.month] leave the current cycle's budget
  /// unchanged so backfilling past cycles never corrupts active limits/spent.
  static BudgetModel applyTransaction(BudgetModel budget, TransactionModel tx) {
    if (!isInBudgetMonth(
      tx.date,
      budget.month,
      startDay: budget.budgetStartDay,
    )) {
      return budget;
    }

    if (tx.type == TransactionType.expense) {
      return _updateBucketSpent(budget, tx.budgetCategory, tx.amount);
    }

    // Income increases monthlyAllowance and scales each bucket's limit +
    // baseLimit using the budget's configured split ratios, without touching spent.
    return budget.copyWith(
      monthlyAllowance: budget.monthlyAllowance + tx.amount,
      commitments: _scaleLimit(
        budget.commitments,
        tx.amount * budget.commitmentRatio,
      ),
      spendings: _scaleLimit(
        budget.spendings,
        tx.amount * budget.spendingRatio,
      ),
      savings: _scaleLimit(budget.savings, tx.amount * budget.savingsRatio),
      updatedAt: DateTime.now(),
    );
  }

  /// Returns a new [BudgetModel] reversing a deleted [tx].
  static BudgetModel reverseTransaction(
    BudgetModel budget,
    TransactionModel tx,
  ) {
    if (!isInBudgetMonth(tx.date, budget.month, startDay: budget.budgetStartDay)) {
      return budget;
    }

    if (tx.type == TransactionType.expense) {
      return _updateBucketSpent(budget, tx.budgetCategory, -tx.amount);
    }

    return budget.copyWith(
      monthlyAllowance: (budget.monthlyAllowance - tx.amount)
          .clamp(0.0, double.infinity)
          .toDouble(),
      commitments: _scaleLimit(
        budget.commitments,
        -tx.amount * budget.commitmentRatio,
      ),
      spendings: _scaleLimit(
        budget.spendings,
        -tx.amount * budget.spendingRatio,
      ),
      savings: _scaleLimit(budget.savings, -tx.amount * budget.savingsRatio),
      updatedAt: DateTime.now(),
    );
  }

  /// Applies an edit from [oldTx] to [newTx] in a single transition.
  static BudgetModel applyEdit(
    BudgetModel budget,
    TransactionModel oldTx,
    TransactionModel newTx,
  ) {
    return applyTransaction(reverseTransaction(budget, oldTx), newTx);
  }

  /// Updates monthly income while preserving current spent, carry-forward
  /// bonuses, custom tracked items, split ratios, and month.
  static BudgetModel updateAllowance(BudgetModel budget, double newAllowance) {
    final cBase = newAllowance * budget.commitmentRatio;
    final spBase = newAllowance * budget.spendingRatio;
    final svBase = newAllowance * budget.savingsRatio;

    return budget.copyWith(
      monthlyAllowance: newAllowance,
      commitments: budget.commitments.copyWith(
        baseLimit: cBase,
        limit: cBase + budget.commitments.carriedForward,
      ),
      spendings: budget.spendings.copyWith(
        baseLimit: spBase,
        limit: spBase + budget.spendings.carriedForward,
      ),
      savings: budget.savings.copyWith(
        baseLimit: svBase,
        limit: svBase + budget.savings.carriedForward,
      ),
      updatedAt: DateTime.now(),
    );
  }

  /// Updates the bucket split ratios (normalized to sum to 1.0) and
  /// recalculates each bucket's `baseLimit` and `limit` while keeping spent
  /// amounts, carry-forward bonuses, and custom items intact.
  static BudgetModel updateRatios(
    BudgetModel budget, {
    required double commitmentRatio,
    required double spendingRatio,
    required double savingsRatio,
  }) {
    final cRaw = commitmentRatio.clamp(0.0, double.infinity).toDouble();
    final spRaw = spendingRatio.clamp(0.0, double.infinity).toDouble();
    final svRaw = savingsRatio.clamp(0.0, double.infinity).toDouble();
    final total = cRaw + spRaw + svRaw;

    final double c = total > 0 ? cRaw / total : 0.50;
    final double sp = total > 0 ? spRaw / total : 0.30;
    final double sv = total > 0 ? svRaw / total : 0.20;

    final cBase = budget.monthlyAllowance * c;
    final spBase = budget.monthlyAllowance * sp;
    final svBase = budget.monthlyAllowance * sv;

    return budget.copyWith(
      commitmentRatio: c,
      spendingRatio: sp,
      savingsRatio: sv,
      commitments: budget.commitments.copyWith(
        baseLimit: cBase,
        limit: cBase + budget.commitments.carriedForward,
      ),
      spendings: budget.spendings.copyWith(
        baseLimit: spBase,
        limit: spBase + budget.spendings.carriedForward,
      ),
      savings: budget.savings.copyWith(
        baseLimit: svBase,
        limit: svBase + budget.savings.carriedForward,
      ),
      updatedAt: DateTime.now(),
    );
  }

  /// Updates custom bucket limits and aligns `baseLimit` (excluding any
  /// carried-forward bonus) so future month resets keep custom limits.
  static BudgetModel updateBucketLimits(
    BudgetModel budget, {
    required double commitmentLimit,
    required double spendingLimit,
    required double savingsLimit,
  }) {
    return budget.copyWith(
      commitments: _withCustomLimit(budget.commitments, commitmentLimit),
      spendings: _withCustomLimit(budget.spendings, spendingLimit),
      savings: _withCustomLimit(budget.savings, savingsLimit),
      updatedAt: DateTime.now(),
    );
  }

  /// Resets bucket spent values for [newMonth], optionally carrying forward
  /// positive leftover balances into each bucket's limit.
  static BudgetModel resetForNewMonth(
    BudgetModel budget, {
    required String newMonth,
    required bool carryForwardEnabled,
  }) {
    return budget.copyWith(
      commitments: _resetBucket(budget.commitments, carryForwardEnabled),
      spendings: _resetBucket(budget.spendings, carryForwardEnabled),
      savings: _resetBucket(budget.savings, carryForwardEnabled),
      month: newMonth,
      updatedAt: DateTime.now(),
    );
  }

  /// Positive unspent balance eligible to carry forward (overspending never
  /// carries forward as negative debt).
  static double leftover(BucketData bucket) {
    final remaining = bucket.limit - bucket.spent;
    return remaining > 0 ? remaining : 0.0;
  }

  static BucketData _withCustomLimit(BucketData bucket, double newLimit) {
    final clampedLimit = newLimit.clamp(0.0, double.infinity).toDouble();
    final newBase = (clampedLimit - bucket.carriedForward)
        .clamp(0.0, double.infinity)
        .toDouble();
    return bucket.copyWith(limit: clampedLimit, baseLimit: newBase);
  }

  static BucketData _resetBucket(BucketData bucket, bool carryForwardEnabled) {
    final carry = carryForwardEnabled ? leftover(bucket) : 0.0;
    return bucket.copyWith(
      limit: bucket.baseLimit + carry,
      spent: 0.0,
      carriedForward: carry,
    );
  }

  static BucketData _scaleLimit(BucketData bucket, double delta) {
    return bucket.copyWith(
      limit: (bucket.limit + delta).clamp(0.0, double.infinity).toDouble(),
      baseLimit: (bucket.baseLimit + delta)
          .clamp(0.0, double.infinity)
          .toDouble(),
    );
  }

  static BudgetModel _updateBucketSpent(
    BudgetModel budget,
    BudgetCategory category,
    double delta,
  ) {
    BucketData update(BucketData b) => b.copyWith(
      spent: (b.spent + delta).clamp(0.0, double.infinity).toDouble(),
    );

    switch (category) {
      case BudgetCategory.commitment:
        return budget.copyWith(
          commitments: update(budget.commitments),
          updatedAt: DateTime.now(),
        );
      case BudgetCategory.spending:
        return budget.copyWith(
          spendings: update(budget.spendings),
          updatedAt: DateTime.now(),
        );
      case BudgetCategory.savings:
        return budget.copyWith(
          savings: update(budget.savings),
          updatedAt: DateTime.now(),
        );
    }
  }
}
