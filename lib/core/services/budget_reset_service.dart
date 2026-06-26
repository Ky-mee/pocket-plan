import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pocket_plan/core/services/database_service.dart';
import 'package:pocket_plan/models/budget_model.dart';
import 'package:intl/intl.dart';

class BudgetResetService {
  final DatabaseService _db = DatabaseService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ─────────────────────────────────────────
  // Check and reset budget if new month
  // Call this in main() or HomeScreen initState
  // ─────────────────────────────────────────
  Future<void> checkAndResetIfNewMonth(
    String userId, {
    bool carryForwardEnabled = true,
  }) async {
    final currentMonth = DateFormat('yyyy-MM').format(DateTime.now());

    // Get current budget
    final budget = await _db.budgetStream(userId).first;
    if (budget == null) return;

    // Use the budget's own 'month' field (stored in Firestore) instead
    // of SharedPreferences, so the check survives reinstalls and new devices
    if (budget.month == currentMonth) return; // already on the current month

    // Archive last month's data before resetting
    await _archiveLastMonth(userId, budget, budget.month);

    // Reset spent amounts to 0 for new month, optionally carrying
    // forward any unspent balance from each bucket
    await _resetBudgetSpent(
      userId,
      budget,
      currentMonth,
      carryForwardEnabled: carryForwardEnabled,
    );
  }

  // ─────────────────────────────────────────
  // Archive previous month's budget data
  // ─────────────────────────────────────────
  Future<void> _archiveLastMonth(
    String userId,
    BudgetModel budget,
    String month,
  ) async {
    if (month.isEmpty) return;

    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('budget_history')
          .doc(month)
          .set({
            'month': month,
            'monthlyAllowance': budget.monthlyAllowance,
            'commitments': {
              'limit': budget.commitments.limit,
              'spent': budget.commitments.spent,
              'carriedForward': _leftover(budget.commitments),
            },
            'spendings': {
              'limit': budget.spendings.limit,
              'spent': budget.spendings.spent,
              'carriedForward': _leftover(budget.spendings),
            },
            'savings': {
              'limit': budget.savings.limit,
              'spent': budget.savings.spent,
              'carriedForward': _leftover(budget.savings),
            },
            'totalSpent': budget.totalSpent,
            'archivedAt': Timestamp.now(),
          });
    } catch (e) {
      // Silently fail — archiving is non-critical
    }
  }

  // Leftover balance for a bucket — only positive (unspent) amounts
  // are eligible to be carried forward. Overspending does not carry
  // forward as negative debt onto the next month.
  double _leftover(BucketData bucket) {
    final remaining = bucket.limit - bucket.spent;
    return remaining > 0 ? remaining : 0.0;
  }

  // ─────────────────────────────────────────
  // Reset spent to 0, optionally carry forward leftover
  // balance by increasing next month's limit per bucket
  // ─────────────────────────────────────────
  Future<void> _resetBudgetSpent(
    String userId,
    BudgetModel budget,
    String newMonth, {
    required bool carryForwardEnabled,
  }) async {
    final commitmentsCarry = carryForwardEnabled
        ? _leftover(budget.commitments)
        : 0.0;
    final spendingsCarry = carryForwardEnabled
        ? _leftover(budget.spendings)
        : 0.0;
    final savingsCarry = carryForwardEnabled ? _leftover(budget.savings) : 0.0;

    await _firestore.collection('budgets').doc(userId).update({
      // Base limits stay tied to the 50/30/20 split of the allowance,
      // carried-forward leftovers are added on top as a bonus limit
      // for the new month.
      'commitments.limit': budget.commitments.baseLimit + commitmentsCarry,
      'commitments.spent': 0.0,
      'commitments.carriedForward': commitmentsCarry,

      'spendings.limit': budget.spendings.baseLimit + spendingsCarry,
      'spendings.spent': 0.0,
      'spendings.carriedForward': spendingsCarry,

      'savings.limit': budget.savings.baseLimit + savingsCarry,
      'savings.spent': 0.0,
      'savings.carriedForward': savingsCarry,

      'month': newMonth,
      'updatedAt': Timestamp.now(),
    });
  }

  // ─────────────────────────────────────────
  // Get budget history for analytics
  // ─────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getBudgetHistory(
    String userId, {
    int months = 6,
  }) async {
    final snap = await _firestore
        .collection('users')
        .doc(userId)
        .collection('budget_history')
        .orderBy('month', descending: true)
        .limit(months)
        .get();

    return snap.docs.map((d) => d.data()).toList();
  }

  // ─────────────────────────────────────────
  // Manual reset (for testing or user request)
  // ─────────────────────────────────────────
  Future<void> manualReset(
    String userId, {
    bool carryForwardEnabled = true,
  }) async {
    final budget = await _db.budgetStream(userId).first;
    if (budget == null) return;

    final currentMonth = DateFormat('yyyy-MM').format(DateTime.now());

    await _archiveLastMonth(userId, budget, budget.month);
    await _resetBudgetSpent(
      userId,
      budget,
      currentMonth,
      carryForwardEnabled: carryForwardEnabled,
    );
  }
}
