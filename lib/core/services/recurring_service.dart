import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pocket_plan/core/utils/budget_calculator.dart';
import 'package:pocket_plan/core/utils/budget_cycle.dart';
import 'package:pocket_plan/models/budget_model.dart';
import 'package:pocket_plan/models/recurring_transaction_model.dart';
import 'package:pocket_plan/models/transaction_model.dart';

/// Manages recurring bills & income templates and idempotently posts due
/// occurrences for the active [BudgetCycle].
class RecurringService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String userId) =>
      _db.collection('users').doc(userId).collection('recurring_items');

  Stream<List<RecurringTransactionModel>> streamRecurring(String userId) {
    return _col(userId)
        .orderBy('dayOfMonth')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => RecurringTransactionModel.fromFirestore(d))
              .toList(),
        );
  }

  Future<void> addRecurring(RecurringTransactionModel item) async {
    await _col(item.userId).add(item.toFirestore());
  }

  Future<void> updateRecurring(RecurringTransactionModel item) async {
    await _col(item.userId).doc(item.id).update(item.toFirestore());
  }

  Future<void> deleteRecurring(String userId, String itemId) async {
    await _col(userId).doc(itemId).delete();
  }

  /// Auto-posts any active recurring items whose due date inside the user's
  /// active [BudgetCycle] has arrived and haven't been logged for this cycle.
  ///
  /// Returns the number of newly posted transactions.
  Future<int> processDueRecurring(String userId, {DateTime? now}) async {
    final current = now ?? DateTime.now();
    final budgetDoc = await _db.collection('budgets').doc(userId).get();
    if (!budgetDoc.exists) return 0;

    final budget = BudgetModel.fromFirestore(budgetDoc);
    final cycle = BudgetCycle.forDate(
      current,
      startDay: budget.budgetStartDay,
    );

    final snap = await _col(userId).where('isActive', isEqualTo: true).get();
    int posted = 0;

    for (final doc in snap.docs) {
      final item = RecurringTransactionModel.fromFirestore(doc);
      if (!item.isDueForCycle(cycle, current)) continue;

      final didPost = await applyItemForCycle(
        userId,
        item.id,
        now: current,
        requireDue: true,
      );
      if (didPost) posted++;
    }
    return posted;
  }

  /// Atomically posts a single recurring item for the current [BudgetCycle],
  /// updating the budget and stamping [lastProcessedCycle] so each item can
  /// only post once per cycle.
  Future<bool> applyItemForCycle(
    String userId,
    String itemId, {
    DateTime? now,
    bool requireDue = false,
  }) async {
    final current = now ?? DateTime.now();
    final budgetRef = _db.collection('budgets').doc(userId);
    final itemRef = _col(userId).doc(itemId);

    return _db.runTransaction<bool>((txn) async {
      // Read everything before any writes (Firestore transaction requirement).
      final budgetDoc = await txn.get(budgetRef);
      final itemDoc = await txn.get(itemRef);
      if (!budgetDoc.exists || !itemDoc.exists) return false;

      final budget = BudgetModel.fromFirestore(budgetDoc);
      final item = RecurringTransactionModel.fromFirestore(itemDoc);
      final cycle = BudgetCycle.forDate(
        current,
        startDay: budget.budgetStartDay,
      );

      if (item.lastProcessedCycle == cycle.key) return false;
      if (requireDue && !item.isDueForCycle(cycle, current)) return false;

      final txDate = requireDue ? item.dueDateInCycle(cycle) : current;
      final tx = TransactionModel(
        id: '',
        userId: userId,
        type: item.type,
        budgetCategory: item.budgetCategory,
        amount: item.amount,
        category: item.category,
        subcategory: 'Recurring',
        description: item.title,
        date: txDate,
        createdAt: current,
      );

      final updatedBudget = BudgetCalculator.applyTransaction(budget, tx);
      final txRef = _db.collection('transactions').doc();

      txn.set(txRef, tx.toFirestore());
      txn.set(budgetRef, updatedBudget.toFirestore());
      txn.update(itemRef, {'lastProcessedCycle': cycle.key});
      return true;
    });
  }
}
