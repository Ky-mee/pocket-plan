import 'package:cloud_firestore/cloud_firestore.dart';

class BucketData {
  final double limit; // Max allowed to spend
  final double spent; // How much spent so far
  final List<String> items; // User-defined sub-items

  BucketData({required this.limit, required this.spent, required this.items});

  double get remaining => limit - spent;
  double get percentageUsed =>
      limit > 0 ? (spent / limit * 100).clamp(0, 100) : 0;
  bool get isExceeded => spent > limit;

  factory BucketData.fromMap(Map<String, dynamic> data) {
    return BucketData(
      limit: (data['limit'] ?? 0.0).toDouble(),
      spent: (data['spent'] ?? 0.0).toDouble(),
      items: List<String>.from(data['items'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {'limit': limit, 'spent': spent, 'items': items};
  }

  BucketData copyWith({double? limit, double? spent, List<String>? items}) {
    return BucketData(
      limit: limit ?? this.limit,
      spent: spent ?? this.spent,
      items: items ?? this.items,
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
        spent: 0,
        items: ['House / Rent', 'Bills & Utilities'],
      ),
      spendings: BucketData(
        limit: allowance * 0.30,
        spent: 0,
        items: ['Food & Drinks', 'Shopping'],
      ),
      savings: BucketData(
        limit: allowance * 0.20,
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
