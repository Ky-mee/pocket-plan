import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  Future<void> checkAndResetIfNewMonth(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final currentMonth = DateFormat('yyyy-MM').format(DateTime.now());
    final lastResetMonth = prefs.getString('lastBudgetReset_$userId') ?? '';

    // If already reset this month, do nothing
    if (lastResetMonth == currentMonth) return;

    // Get current budget
    final budget = await _db.budgetStream(userId).first;
    if (budget == null) return;

    // Archive last month's data before resetting
    await _archiveLastMonth(userId, budget, lastResetMonth);

    // Reset spent amounts to 0 for new month
    await _resetBudgetSpent(userId, budget, currentMonth);

    // Save reset month to prevent double reset
    await prefs.setString('lastBudgetReset_$userId', currentMonth);
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
            },
            'spendings': {
              'limit': budget.spendings.limit,
              'spent': budget.spendings.spent,
            },
            'savings': {
              'limit': budget.savings.limit,
              'spent': budget.savings.spent,
            },
            'totalSpent': budget.totalSpent,
            'archivedAt': Timestamp.now(),
          });
    } catch (e) {
      // Silently fail — archiving is non-critical
    }
  }

  // ─────────────────────────────────────────
  // Reset spent to 0, keep limits intact
  // ─────────────────────────────────────────
  Future<void> _resetBudgetSpent(
    String userId,
    BudgetModel budget,
    String newMonth,
  ) async {
    await _firestore.collection('budgets').doc(userId).update({
      'commitments.spent': 0.0,
      'spendings.spent': 0.0,
      'savings.spent': 0.0,
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
  Future<void> manualReset(String userId) async {
    final budget = await _db.budgetStream(userId).first;
    if (budget == null) return;

    final currentMonth = DateFormat('yyyy-MM').format(DateTime.now());
    final lastMonth = DateFormat(
      'yyyy-MM',
    ).format(DateTime(DateTime.now().year, DateTime.now().month - 1));

    await _archiveLastMonth(userId, budget, lastMonth);
    await _resetBudgetSpent(userId, budget, currentMonth);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastBudgetReset_$userId', currentMonth);
  }
}
