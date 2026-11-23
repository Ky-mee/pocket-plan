import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pocket_plan/core/utils/budget_cycle.dart';
import 'package:pocket_plan/models/transaction_model.dart';

/// Monthly recurring bill or income template stored under
/// `users/{uid}/recurring_items/{id}`.
class RecurringTransactionModel {
  final String id;
  final String userId;
  final String title;
  final double amount;
  final TransactionType type;
  final BudgetCategory budgetCategory;
  final String category;
  final int dayOfMonth; // 1..28
  final bool isActive;
  final String lastProcessedCycle; // BudgetCycle.key e.g. "2026-04"
  final DateTime createdAt;

  const RecurringTransactionModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.amount,
    required this.type,
    required this.budgetCategory,
    required this.category,
    required this.dayOfMonth,
    this.isActive = true,
    this.lastProcessedCycle = '',
    required this.createdAt,
  });

  /// Returns the due [DateTime] for this template inside [cycle].
  ///
  /// When [cycle.startDay] > 1, a cycle spans two calendar months; a
  /// [dayOfMonth] >= [cycle.startDay] falls in `cycle.start`'s month, while a
  /// smaller [dayOfMonth] falls in `cycle.end`'s month.
  DateTime dueDateInCycle(BudgetCycle cycle) {
    final safeDay = BudgetCycle.clampStartDay(dayOfMonth);
    if (safeDay >= cycle.startDay) {
      return DateTime(cycle.start.year, cycle.start.month, safeDay);
    }
    return DateTime(cycle.end.year, cycle.end.month, safeDay);
  }

  /// True when this template is active, hasn't yet been logged for [cycle],
  /// and its due date within [cycle] is on or before [now].
  bool isDueForCycle(BudgetCycle cycle, DateTime now) {
    if (!isActive) return false;
    if (lastProcessedCycle == cycle.key) return false;
    final today = DateTime(now.year, now.month, now.day);
    final due = dueDateInCycle(cycle);
    return !due.isAfter(today) && cycle.contains(due);
  }

  factory RecurringTransactionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RecurringTransactionModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      amount: (data['amount'] ?? 0.0).toDouble(),
      type: data['type'] == 'income'
          ? TransactionType.income
          : TransactionType.expense,
      budgetCategory: _parseBucket(data['budgetCategory']),
      category: data['category'] ?? '',
      dayOfMonth: BudgetCycle.clampStartDay(
        (data['dayOfMonth'] as num?)?.toInt() ?? 1,
      ),
      isActive: data['isActive'] ?? true,
      lastProcessedCycle: data['lastProcessedCycle'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'amount': amount,
      'type': type == TransactionType.income ? 'income' : 'expense',
      'budgetCategory': budgetCategory.name,
      'category': category,
      'dayOfMonth': BudgetCycle.clampStartDay(dayOfMonth),
      'isActive': isActive,
      'lastProcessedCycle': lastProcessedCycle,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  RecurringTransactionModel copyWith({
    String? id,
    String? userId,
    String? title,
    double? amount,
    TransactionType? type,
    BudgetCategory? budgetCategory,
    String? category,
    int? dayOfMonth,
    bool? isActive,
    String? lastProcessedCycle,
    DateTime? createdAt,
  }) {
    return RecurringTransactionModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      budgetCategory: budgetCategory ?? this.budgetCategory,
      category: category ?? this.category,
      dayOfMonth: dayOfMonth != null
          ? BudgetCycle.clampStartDay(dayOfMonth)
          : this.dayOfMonth,
      isActive: isActive ?? this.isActive,
      lastProcessedCycle: lastProcessedCycle ?? this.lastProcessedCycle,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static BudgetCategory _parseBucket(String? value) {
    switch (value) {
      case 'commitment':
        return BudgetCategory.commitment;
      case 'savings':
        return BudgetCategory.savings;
      default:
        return BudgetCategory.spending;
    }
  }
}
