import 'package:cloud_firestore/cloud_firestore.dart';

// Transaction type: income or expense
enum TransactionType { income, expense }

// Which 50/30/20 bucket this belongs to
enum BudgetCategory { commitment, spending, savings }

class TransactionModel {
  final String id;
  final String userId;
  final TransactionType type;
  final BudgetCategory budgetCategory;
  final double amount;
  final String category; // e.g. "food", "bills", "asb"
  final String subcategory; // e.g. "lunch", "electricity", "monthly deposit"
  final String description;
  final DateTime date;
  final DateTime createdAt;

  TransactionModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.budgetCategory,
    required this.amount,
    required this.category,
    this.subcategory = '',
    this.description = '',
    required this.date,
    required this.createdAt,
  });

  factory TransactionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TransactionModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      type: data['type'] == 'income'
          ? TransactionType.income
          : TransactionType.expense,
      budgetCategory: _parseBudgetCategory(data['budgetCategory']),
      amount: (data['amount'] ?? 0.0).toDouble(),
      category: data['category'] ?? '',
      subcategory: data['subcategory'] ?? '',
      description: data['description'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : (data['date'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'type': type == TransactionType.income ? 'income' : 'expense',
      'budgetCategory': budgetCategory.name,
      'amount': amount,
      'category': category,
      'subcategory': subcategory,
      'description': description,
      'date': Timestamp.fromDate(date),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  static BudgetCategory _parseBudgetCategory(String? value) {
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

// Predefined categories for each bucket
class TransactionCategories {
  static const Map<BudgetCategory, List<String>> categories = {
    BudgetCategory.commitment: [
      'House / Rent',
      'Car / Transport',
      'Bills & Utilities',
      'Insurance',
      'Education Loan (PTPTN)',
      'Other Commitments',
    ],
    BudgetCategory.spending: [
      'Food & Drinks',
      'Shopping',
      'Entertainment',
      'Personal Care',
      'Health',
      'Travel',
      'Other Spending',
    ],
    BudgetCategory.savings: [
      'Bank Savings',
      'ASB',
      'Gold',
      'Investment',
      'Emergency Fund',
      'Other Savings',
    ],
  };
}
