import 'package:cloud_firestore/cloud_firestore.dart';

class BucketData {
  final double limit; // Max allowed to spend (base + carried forward)
  final double baseLimit; // Pure 50/30/20 share, excluding carry-forward
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
  final BucketData commitments; // 50%
  final BucketData spendings; // 30%
  final BucketData savings; // 20%
  final String month; // Format: "2026-04"
  final DateTime updatedAt;

  BudgetModel({
    required this.userId,
    required this.monthlyAllowance,
    required this.commitments,
    required this.spendings,
    required this.savings,
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

  // Create a default budget from allowance using 50/30/20
  factory BudgetModel.fromAllowance({
    required String userId,
    required double allowance,
    required String month,
  }) {
    return BudgetModel(
      userId: userId,
      monthlyAllowance: allowance,
      commitments: BucketData(
        limit: allowance * 0.50,
        baseLimit: allowance * 0.50,
        spent: 0,
        items: ['House / Rent', 'Bills & Utilities'],
      ),
      spendings: BucketData(
        limit: allowance * 0.30,
        baseLimit: allowance * 0.30,
        spent: 0,
        items: ['Food & Drinks', 'Shopping'],
      ),
      savings: BucketData(
        limit: allowance * 0.20,
        baseLimit: allowance * 0.20,
        spent: 0,
        items: ['Bank Savings'],
      ),
      month: month,
      updatedAt: DateTime.now(),
    );
  }

  factory BudgetModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BudgetModel(
      userId: doc.id,
      monthlyAllowance: (data['monthlyAllowance'] ?? 0.0).toDouble(),
      commitments: BucketData.fromMap(data['commitments'] ?? {}),
      spendings: BucketData.fromMap(data['spendings'] ?? {}),
      savings: BucketData.fromMap(data['savings'] ?? {}),
      month: data['month'] ?? '',
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
      'month': month,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
