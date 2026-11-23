import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/utils/budget_cycle.dart';

class BudgetSplitPreset {
  final String name;
  final String subtitle;
  final double commitment;
  final double spending;
  final double savings;

  const BudgetSplitPreset({
    required this.name,
    required this.subtitle,
    required this.commitment,
    required this.spending,
    required this.savings,
  });

  String get ratioLabel =>
      '${(commitment * 100).round()}/${(spending * 100).round()}/${(savings * 100).round()}';
}

const List<BudgetSplitPreset> kBudgetSplitPresets = [
  BudgetSplitPreset(
    name: 'Balanced',
    subtitle: 'Classic split for steady monthly budgeting',
    commitment: 0.50,
    spending: 0.30,
    savings: 0.20,
  ),
  BudgetSplitPreset(
    name: 'Essentials Focus',
    subtitle: 'Great for households, rent, or family bills',
    commitment: 0.60,
    spending: 0.20,
    savings: 0.20,
  ),
  BudgetSplitPreset(
    name: 'Tight Budget & Debt',
    subtitle: 'Prioritizes essential needs and debt payoff',
    commitment: 0.70,
    spending: 0.20,
    savings: 0.10,
  ),
  BudgetSplitPreset(
    name: 'Aggressive Saver',
    subtitle: 'Maximizes savings and long-term goals',
    commitment: 0.50,
    spending: 0.20,
    savings: 0.30,
  ),
];

class BucketData {
  final double limit; // Max allowed to spend (base + carried forward)
  final double baseLimit; // Pure bucket share, excluding carry-forward
  final double spent; // How much spent so far
  final List<String> items; // User-defined sub-items
  final double carriedForward; // Leftover balance rolled in from last month

  BucketData({
    required this.limit,
    required this.spent,
    required this.items,
    double? baseLimit,
    this.carriedForward = 0.0,
  }) : baseLimit = baseLimit ?? limit;

  double get remaining => limit - spent;
  double get percentageUsed =>
      limit > 0 ? (spent / limit * 100).clamp(0, 100) : 0;
  bool get isExceeded => spent > limit;

  factory BucketData.fromMap(Map<String, dynamic> data) {
    final limit = (data['limit'] ?? 0.0).toDouble();
    final carried = (data['carriedForward'] ?? 0.0).toDouble();
    return BucketData(
      limit: limit,
      baseLimit: (data['baseLimit'] ?? (limit - carried)).toDouble(),
      spent: (data['spent'] ?? 0.0).toDouble(),
      items: List<String>.from(data['items'] ?? []),
      carriedForward: carried,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'limit': limit,
      'baseLimit': baseLimit,
      'spent': spent,
      'items': items,
      'carriedForward': carriedForward,
    };
  }

  BucketData copyWith({
    double? limit,
    double? baseLimit,
    double? spent,
    List<String>? items,
    double? carriedForward,
  }) {
    return BucketData(
      limit: limit ?? this.limit,
      baseLimit: baseLimit ?? this.baseLimit,
      spent: spent ?? this.spent,
      items: items ?? this.items,
      carriedForward: carriedForward ?? this.carriedForward,
    );
  }
}

class BudgetModel {
  final String userId;
  final double monthlyAllowance;
  final BucketData commitments;
  final BucketData spendings;
  final BucketData savings;
  final double commitmentRatio;
  final double spendingRatio;
  final double savingsRatio;
  final int budgetStartDay; // 1..28, default 1 (calendar month)
  final String month; // Cycle key, e.g. "2026-04"
  final DateTime updatedAt;

  BudgetModel({
    required this.userId,
    required this.monthlyAllowance,
    required this.commitments,
    required this.spendings,
    required this.savings,
    this.commitmentRatio = 0.50,
    this.spendingRatio = 0.30,
    this.savingsRatio = 0.20,
    this.budgetStartDay = 1,
    required this.month,
    required this.updatedAt,
  });

  // Total spent across all buckets
  double get totalSpent => commitments.spent + spendings.spent + savings.spent;
  double get totalRemaining => monthlyAllowance - totalSpent;
  bool get isAnyExceeded =>
      commitments.isExceeded || spendings.isExceeded || savings.isExceeded;

  // Total leftover balance eligible to be carried into next month —
  // sum of each bucket's positive remaining amount (overspending is
  // never carried forward as negative debt)
  double get totalCarryForwardEligible {
    double sum = 0;
    for (final bucket in [commitments, spendings, savings]) {
      final remaining = bucket.limit - bucket.spent;
      if (remaining > 0) sum += remaining;
    }
    return sum;
  }

  // Create a default budget from monthly income using configurable ratios
  factory BudgetModel.fromAllowance({
    required String userId,
    required double allowance,
    required String month,
    double commitmentRatio = 0.50,
    double spendingRatio = 0.30,
    double savingsRatio = 0.20,
    int budgetStartDay = 1,
  }) {
    final safeStartDay = BudgetCycle.clampStartDay(budgetStartDay);
    return BudgetModel(
      userId: userId,
      monthlyAllowance: allowance,
      commitmentRatio: commitmentRatio,
      spendingRatio: spendingRatio,
      savingsRatio: savingsRatio,
      budgetStartDay: safeStartDay,
      commitments: BucketData(
        limit: allowance * commitmentRatio,
        baseLimit: allowance * commitmentRatio,
        spent: 0,
        items: ['Housing / Rent', 'Groceries', 'Bills & Utilities'],
      ),
      spendings: BucketData(
        limit: allowance * spendingRatio,
        baseLimit: allowance * spendingRatio,
        spent: 0,
        items: ['Dining Out & Cafes', 'Shopping'],
      ),
      savings: BucketData(
        limit: allowance * savingsRatio,
        baseLimit: allowance * savingsRatio,
        spent: 0,
        items: ['Emergency Fund', 'Bank Savings'],
      ),
      month: month,
      updatedAt: DateTime.now(),
    );
  }

  factory BudgetModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final startDay = BudgetCycle.clampStartDay(
      (data['budgetStartDay'] as num?)?.toInt() ?? 1,
    );
    return BudgetModel(
      userId: doc.id,
      monthlyAllowance: (data['monthlyAllowance'] ?? 0.0).toDouble(),
      commitments: BucketData.fromMap(data['commitments'] ?? {}),
      spendings: BucketData.fromMap(data['spendings'] ?? {}),
      savings: BucketData.fromMap(data['savings'] ?? {}),
      commitmentRatio: (data['commitmentRatio'] ?? 0.50).toDouble(),
      spendingRatio: (data['spendingRatio'] ?? 0.30).toDouble(),
      savingsRatio: (data['savingsRatio'] ?? 0.20).toDouble(),
      budgetStartDay: startDay,
      month:
          data['month'] ??
          BudgetCycle.forDate(DateTime.now(), startDay: startDay).key,
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'monthlyAllowance': monthlyAllowance,
      'commitments': commitments.toMap(),
      'spendings': spendings.toMap(),
      'savings': savings.toMap(),
      'commitmentRatio': commitmentRatio,
      'spendingRatio': spendingRatio,
      'savingsRatio': savingsRatio,
      'budgetStartDay': budgetStartDay,
      'month': month,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  BudgetModel copyWith({
    String? userId,
    double? monthlyAllowance,
    BucketData? commitments,
    BucketData? spendings,
    BucketData? savings,
    double? commitmentRatio,
    double? spendingRatio,
    double? savingsRatio,
    int? budgetStartDay,
    String? month,
    DateTime? updatedAt,
  }) {
    return BudgetModel(
      userId: userId ?? this.userId,
      monthlyAllowance: monthlyAllowance ?? this.monthlyAllowance,
      commitments: commitments ?? this.commitments,
      spendings: spendings ?? this.spendings,
      savings: savings ?? this.savings,
      commitmentRatio: commitmentRatio ?? this.commitmentRatio,
      spendingRatio: spendingRatio ?? this.spendingRatio,
      savingsRatio: savingsRatio ?? this.savingsRatio,
      budgetStartDay: budgetStartDay != null
          ? BudgetCycle.clampStartDay(budgetStartDay)
          : this.budgetStartDay,
      month: month ?? this.month,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
