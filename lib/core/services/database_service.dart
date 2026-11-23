import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pocket_plan/core/services/notification_service.dart';
import 'package:pocket_plan/core/utils/budget_calculator.dart';
import 'package:pocket_plan/models/budget_model.dart';
import 'package:pocket_plan/models/transaction_model.dart';
import 'package:pocket_plan/models/user_model.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─────────────────────────────────────────
  // Collection references
  // ─────────────────────────────────────────
  CollectionReference get _users => _db.collection('users');
  CollectionReference get _transactions => _db.collection('transactions');
  CollectionReference get _budgets => _db.collection('budgets');

  // ─────────────────────────────────────────
  // USER operations
  // ─────────────────────────────────────────

  // Create user profile after registration
  Future<void> createUser(UserModel user) async {
    await _users.doc(user.uid).set(user.toFirestore());

    // Also create initial budget for current month
    final month = BudgetCalculator.monthKey(DateTime.now());
    final budget = BudgetModel.fromAllowance(
      userId: user.uid,
      allowance: user.monthlyAllowance,
      month: month,
    );
    await createOrUpdateBudget(user.uid, budget);
  }

  // Get user profile (one-time read)
  Future<UserModel?> getUser(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  // Listen to user profile changes (real-time stream)
  Stream<UserModel?> userStream(String uid) {
    return _users.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserModel.fromFirestore(doc);
    });
  }

  // Update user profile fields
  Future<void> updateUser(String uid, Map<String, dynamic> fields) async {
    await _users.doc(uid).update(fields);
  }

  // Update monthly allowance while preserving current month's spent,
  // carried-forward bonuses, and custom tracked items.
  Future<void> updateAllowance(String uid, double newAllowance) async {
    await _db.runTransaction((txn) async {
      final budgetRef = _budgets.doc(uid);
      final budgetDoc = await txn.get(budgetRef);
      final userRef = _users.doc(uid);

      txn.update(userRef, {'monthlyAllowance': newAllowance});

      if (budgetDoc.exists) {
        final existing = BudgetModel.fromFirestore(budgetDoc);
        final updated = BudgetCalculator.updateAllowance(
          existing,
          newAllowance,
        );
        txn.set(budgetRef, updated.toFirestore());
      } else {
        final month = BudgetCalculator.monthKey(DateTime.now());
        final budget = BudgetModel.fromAllowance(
          userId: uid,
          allowance: newAllowance,
          month: month,
        );
        txn.set(budgetRef, budget.toFirestore());
      }
    });
  }

  // ─────────────────────────────────────────
  // TRANSACTION operations
  // ─────────────────────────────────────────

  // Add a new transaction and atomically update the active month's budget.
  Future<String> addTransaction(TransactionModel transaction) async {
    final txRef = _transactions.doc();
    final updatedBudget = await _db.runTransaction<BudgetModel?>((txn) async {
      final budgetRef = _budgets.doc(transaction.userId);
      final budgetDoc = await txn.get(budgetRef);

      txn.set(txRef, transaction.toFirestore());

      if (!budgetDoc.exists) return null;
      final existing = BudgetModel.fromFirestore(budgetDoc);
      final updated = BudgetCalculator.applyTransaction(existing, transaction);
      txn.set(budgetRef, updated.toFirestore());
      return updated;
    });

    if (updatedBudget != null && transaction.type == TransactionType.expense) {
      final prefs = await getPreferences(transaction.userId);
      final notificationsEnabled = prefs['notificationsEnabled'] ?? true;
      if (notificationsEnabled) {
        await NotificationService().checkBudgetAlerts(updatedBudget);
      }
    }

    return txRef.id;
  }

  // Atomically update a transaction and transition the budget from oldTx to newTx.
  Future<void> updateTransaction(
    TransactionModel oldTx,
    TransactionModel newTx,
  ) async {
    final updatedBudget = await _db.runTransaction<BudgetModel?>((txn) async {
      final budgetRef = _budgets.doc(oldTx.userId);
      final budgetDoc = await txn.get(budgetRef);

      txn.update(_transactions.doc(oldTx.id), newTx.toFirestore());

      if (!budgetDoc.exists) return null;
      final existing = BudgetModel.fromFirestore(budgetDoc);
      final updated = BudgetCalculator.applyEdit(existing, oldTx, newTx);
      txn.set(budgetRef, updated.toFirestore());
      return updated;
    });

    if (updatedBudget != null && newTx.type == TransactionType.expense) {
      final prefs = await getPreferences(newTx.userId);
      final notificationsEnabled = prefs['notificationsEnabled'] ?? true;
      if (notificationsEnabled) {
        await NotificationService().checkBudgetAlerts(updatedBudget);
      }
    }
  }

  // Delete a transaction and atomically reverse its budget impact.
  Future<void> deleteTransaction(TransactionModel transaction) async {
    await _db.runTransaction((txn) async {
      final budgetRef = _budgets.doc(transaction.userId);
      final budgetDoc = await txn.get(budgetRef);

      txn.delete(_transactions.doc(transaction.id));

      if (!budgetDoc.exists) return;
      final existing = BudgetModel.fromFirestore(budgetDoc);
      final updated = BudgetCalculator.reverseTransaction(
        existing,
        transaction,
      );
      txn.set(budgetRef, updated.toFirestore());
    });
  }

  // Get all transactions for a user (real-time stream)
  Stream<List<TransactionModel>> transactionsStream(String userId) {
    return _transactions
        .where('userId', isEqualTo: userId)
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => TransactionModel.fromFirestore(d)).toList(),
        );
  }

  // Get transactions filtered by month
  Stream<List<TransactionModel>> transactionsByMonthStream(
    String userId,
    DateTime month,
  ) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    return _transactions
        .where('userId', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => TransactionModel.fromFirestore(d)).toList(),
        );
  }

  // Get transactions by budget category
  Stream<List<TransactionModel>> transactionsByCategoryStream(
    String userId,
    BudgetCategory category,
  ) {
    return _transactions
        .where('userId', isEqualTo: userId)
        .where('budgetCategory', isEqualTo: category.name)
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => TransactionModel.fromFirestore(d)).toList(),
        );
  }

  // ─────────────────────────────────────────
  // BUDGET operations
  // ─────────────────────────────────────────

  // Create or overwrite budget for current month
  Future<void> createOrUpdateBudget(String userId, BudgetModel budget) async {
    await _budgets.doc(userId).set(budget.toFirestore());
  }

  // Listen to budget in real time
  Stream<BudgetModel?> budgetStream(String userId) {
    return _budgets.doc(userId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return BudgetModel.fromFirestore(doc);
    });
  }

  // Update custom budget limits (also updates baseLimit so resets keep them)
  Future<void> updateBudgetLimits({
    required String userId,
    required double commitmentLimit,
    required double spendingLimit,
    required double savingsLimit,
  }) async {
    await _db.runTransaction((txn) async {
      final budgetRef = _budgets.doc(userId);
      final budgetDoc = await txn.get(budgetRef);
      if (!budgetDoc.exists) return;

      final existing = BudgetModel.fromFirestore(budgetDoc);
      final updated = BudgetCalculator.updateBucketLimits(
        existing,
        commitmentLimit: commitmentLimit,
        spendingLimit: spendingLimit,
        savingsLimit: savingsLimit,
      );
      txn.set(budgetRef, updated.toFirestore());
    });
  }

  // Update custom items inside a bucket
  Future<void> updateBucketItems({
    required String userId,
    required String bucketField, // 'commitments', 'spendings', or 'savings'
    required List<String> items,
  }) async {
    await _budgets.doc(userId).update({
      '$bucketField.items': items,
      'updatedAt': Timestamp.now(),
    });
  }

  // ─────────────────────────────────────────
  // USER PREFERENCES (subcollection)
  // ─────────────────────────────────────────

  Future<void> savePreferences(
    String userId,
    Map<String, dynamic> prefs,
  ) async {
    await _users
        .doc(userId)
        .collection('preferences')
        .doc('settings')
        .set(prefs, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>> getPreferences(String userId) async {
    final doc = await _users
        .doc(userId)
        .collection('preferences')
        .doc('settings')
        .get();
    return doc.exists ? doc.data() ?? {} : {};
  }

  Stream<Map<String, dynamic>> preferencesStream(String userId) {
    return _users
        .doc(userId)
        .collection('preferences')
        .doc('settings')
        .snapshots()
        .map((doc) => doc.exists ? doc.data() ?? {} : {});
  }
}
