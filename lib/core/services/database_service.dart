import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pocket_plan/models/user_model.dart';
import 'package:pocket_plan/models/transaction_model.dart';
import 'package:pocket_plan/models/budget_model.dart';
import 'package:pocket_plan/models/prediction_model.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─────────────────────────────────────────
  // Collection references
  // ─────────────────────────────────────────
  CollectionReference get _users => _db.collection('users');
  CollectionReference get _transactions => _db.collection('transactions');
  CollectionReference get _budgets => _db.collection('budgets');
  CollectionReference get _predictions => _db.collection('predictions');

  // ─────────────────────────────────────────
  // USER operations
  // ─────────────────────────────────────────

  // Create user profile after registration
  Future<void> createUser(UserModel user) async {
    await _users.doc(user.uid).set(user.toFirestore());

    // Also create initial budget for current month
    final month = DateFormat('yyyy-MM').format(DateTime.now());
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

  // Update monthly allowance and recalculate budget
  Future<void> updateAllowance(String uid, double newAllowance) async {
    await _users.doc(uid).update({'monthlyAllowance': newAllowance});
    final month = DateFormat('yyyy-MM').format(DateTime.now());
    final budget = BudgetModel.fromAllowance(
      userId: uid,
      allowance: newAllowance,
      month: month,
    );
    await createOrUpdateBudget(uid, budget);
  }

  // ─────────────────────────────────────────
  // TRANSACTION operations
  // ─────────────────────────────────────────

  // Add a new transaction
  Future<String> addTransaction(TransactionModel transaction) async {
    final ref = await _transactions.add(transaction.toFirestore());

    // Update the relevant budget bucket spent amount
    await _updateBudgetSpent(
      userId: transaction.userId,
      bucketCategory: transaction.budgetCategory,
      amount: transaction.type == TransactionType.expense
          ? transaction.amount
          : -transaction.amount, // subtract if income
    );

    return ref.id;
  }

  // Delete a transaction and reverse its budget impact
  Future<void> deleteTransaction(TransactionModel transaction) async {
    await _transactions.doc(transaction.id).delete();

    // Reverse the budget impact
    await _updateBudgetSpent(
      userId: transaction.userId,
      bucketCategory: transaction.budgetCategory,
      amount: transaction.type == TransactionType.expense
          ? -transaction.amount
          : transaction.amount,
    );
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

  // Update custom budget limits (when user customizes 50/30/20)
  Future<void> updateBudgetLimits({
    required String userId,
    required double commitmentLimit,
    required double spendingLimit,
    required double savingsLimit,
  }) async {
    await _budgets.doc(userId).update({
      'commitments.limit': commitmentLimit,
      'spendings.limit': spendingLimit,
      'savings.limit': savingsLimit,
      'updatedAt': Timestamp.now(),
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

  // Internal: update spent amount when transaction is added/deleted
  Future<void> _updateBudgetSpent({
    required String userId,
    required BudgetCategory bucketCategory,
    required double amount,
  }) async {
    final field = switch (bucketCategory) {
      BudgetCategory.commitment => 'commitments.spent',
      BudgetCategory.spending => 'spendings.spent',
      BudgetCategory.savings => 'savings.spent',
    };

    await _budgets.doc(userId).update({
      field: FieldValue.increment(amount),
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

  // ─────────────────────────────────────────
  // PREDICTION operations
  // ─────────────────────────────────────────

  Future<void> savePrediction(PredictionModel prediction) async {
    await _predictions.doc(prediction.userId).set(prediction.toFirestore());
  }

  Future<PredictionModel?> getPrediction(String userId) async {
    final doc = await _predictions.doc(userId).get();
    if (!doc.exists) return null;
    return PredictionModel.fromFirestore(doc);
  }

  // Get monthly totals for last N months (used to calculate prediction)
  Future<List<double>> getMonthlyTotals(String userId, {int months = 3}) async {
    final List<double> totals = [];
    final now = DateTime.now();

    for (int i = months; i >= 1; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final start = DateTime(month.year, month.month, 1);
      final end = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

      final snap = await _transactions
          .where('userId', isEqualTo: userId)
          .where('type', isEqualTo: 'expense')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();

      final total = snap.docs.fold<double>(
        0,
        (sum, doc) =>
            sum +
            ((doc.data() as Map<String, dynamic>)['amount'] as num).toDouble(),
      );

      totals.add(total);
    }

    return totals;
  }
}
