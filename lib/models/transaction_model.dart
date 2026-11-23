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
  static const List<String> incomeSources = [
    'Salary',
    'Business / Self-Employed',
    'Freelance / Side Hustle',
    'Allowance',
    'Pension / Retirement',
    'Investments / Dividends',
    'Rental Income',
    'Scholarship / Grant',
    'Part-time Job',
    'Other',
  ];

  static const Map<BudgetCategory, List<String>> categories = {
    BudgetCategory.commitment: [
      'Housing / Rent / Mortgage',
      'Groceries',
      'Bills & Utilities',
      'Transport & Fuel',
      'Healthcare & Medical',
      'Insurance',
      'Family & Childcare',
      'Debt & Loans',
      'Other Essentials',
    ],
    BudgetCategory.spending: [
      'Dining Out & Cafes',
      'Shopping',
      'Entertainment',
      'Subscriptions',
      'Personal Care',
      'Travel & Leisure',
      'Gifts & Donations',
      'Other Lifestyle',
    ],
    BudgetCategory.savings: [
      'Emergency Fund',
      'Bank Savings',
      'Retirement (EPF / 401k)',
      'Investments',
      'Education Fund',
      'Gold & Assets',
      'Other Savings',
    ],
  };
}

/// Optional prefill payload passed via route arguments to `/add-transaction`.
class TransactionPrefill {
  final TransactionType type;
  final BudgetCategory? budgetCategory;
  final String? category;
  final double? amount;
  final String? description;

  const TransactionPrefill({
    this.type = TransactionType.expense,
    this.budgetCategory,
    this.category,
    this.amount,
    this.description,
  });
}
