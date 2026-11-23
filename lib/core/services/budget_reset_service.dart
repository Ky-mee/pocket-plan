import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pocket_plan/core/services/notification_service.dart';
import 'package:pocket_plan/core/utils/budget_calculator.dart';
import 'package:pocket_plan/models/budget_model.dart';

class BudgetResetService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ─────────────────────────────────────────
  // Check and reset budget if new month (atomic)
  // ─────────────────────────────────────────
  Future<void> checkAndResetIfNewMonth(
    String userId, {
    bool carryForwardEnabled = true,
  }) async {
    final currentMonth = BudgetCalculator.monthKey(DateTime.now());
    final docRef = _firestore.collection('budgets').doc(userId);

    final oldBudget = await _firestore.runTransaction<BudgetModel?>((
      txn,
    ) async {
      final doc = await txn.get(docRef);
      if (!doc.exists) return null;

      final budget = BudgetModel.fromFirestore(doc);
      if (budget.month == currentMonth) return null;

      final nextBudget = BudgetCalculator.resetForNewMonth(
        budget,
        newMonth: currentMonth,
        carryForwardEnabled: carryForwardEnabled,
      );
      txn.set(docRef, nextBudget.toFirestore());
      return budget;
    });

    if (oldBudget == null) return;

    await _archiveLastMonth(userId, oldBudget, oldBudget.month);

    await NotificationService().showLocalNotification(
      id: 10,
      title: '🔄 Budget Reset for ${_monthName(currentMonth)}',
      body: carryForwardEnabled
          ? 'Your budget has been reset. Unused balance has been carried forward to this month.'
          : 'Your budget has been reset for the new month. Good luck!',
    );
  }

  String _monthName(String yyyyMM) {
    final parts = yyyyMM.split('-');
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final idx = int.tryParse(parts[1]) ?? 1;
    return '${months[idx - 1]} ${parts[0]}';
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
              'carriedForward': BudgetCalculator.leftover(budget.commitments),
            },
            'spendings': {
              'limit': budget.spendings.limit,
              'spent': budget.spendings.spent,
              'carriedForward': BudgetCalculator.leftover(budget.spendings),
            },
            'savings': {
              'limit': budget.savings.limit,
              'spent': budget.savings.spent,
              'carriedForward': BudgetCalculator.leftover(budget.savings),
            },
            'totalSpent': budget.totalSpent,
            'archivedAt': Timestamp.now(),
          });
    } catch (_) {
      // Silently fail — archiving is non-critical
    }
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
    final currentMonth = BudgetCalculator.monthKey(DateTime.now());
    final docRef = _firestore.collection('budgets').doc(userId);

    final oldBudget = await _firestore.runTransaction<BudgetModel?>((
      txn,
    ) async {
      final doc = await txn.get(docRef);
      if (!doc.exists) return null;

      final budget = BudgetModel.fromFirestore(doc);
      final nextBudget = BudgetCalculator.resetForNewMonth(
        budget,
        newMonth: currentMonth,
        carryForwardEnabled: carryForwardEnabled,
      );
      txn.set(docRef, nextBudget.toFirestore());
      return budget;
    });

    if (oldBudget != null) {
      await _archiveLastMonth(userId, oldBudget, oldBudget.month);
    }
  }
}
