import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pocket_plan/core/services/database_service.dart';
import 'package:pocket_plan/models/transaction_model.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final DatabaseService _db = DatabaseService();

  TransactionType _type = TransactionType.expense;
  BudgetCategory _budgetCategory = BudgetCategory.spending;
  String _selectedCategory = 'Food & Drinks';

  // ── NEW: Income source (replaces category for income transactions) ──
  String _selectedIncomeSource = 'Allowance';
  final List<String> _incomeSources = [
    'Allowance',
    'Part-time Job',
    'PTPTN',
    'MARA',
    'Scholarship',
    'Freelance',
    'Other',
  ];

  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  String get _userId => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();

    // Pre-fill type from route arguments if passed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final arg = ModalRoute.of(context)?.settings.arguments;
      if (arg == 'income') {
        setState(() {
          _type = TransactionType.income;
        });
      }
    });

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );
    _slideController.forward();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  List<String> get _currentCategories =>
      TransactionCategories.categories[_budgetCategory] ?? [];

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final amount = double.parse(_amountController.text);

      if (_type == TransactionType.income) {
        // ── INCOME: auto-split into 50/30/20 buckets ──
        await _saveIncomeTransaction(amount);
      } else {
        // ── EXPENSE: record normally under selected bucket/category ──
        await _saveExpenseTransaction(amount);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _type == TransactionType.income
                  ? 'Income added! Budget updated with 50/30/20 split.'
                  : 'Expense recorded successfully!',
            ),
            backgroundColor: _type == TransactionType.income
                ? const Color(0xFF00D4AA)
                : const Color(0xFFFF6B6B),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: const Color(0xFFE53935),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── INCOME: record transaction + auto-split budget limits ──
  Future<void> _saveIncomeTransaction(double amount) async {
    // 1. Record income transaction with source as category
    final tx = TransactionModel(
      id: '',
      userId: _userId,
      type: TransactionType.income,
      budgetCategory: BudgetCategory.savings, // neutral bucket for income
      amount: amount,
      category: _selectedIncomeSource,
      description: _descriptionController.text.trim().isEmpty
          ? _selectedIncomeSource
          : _descriptionController.text.trim(),
      date: _selectedDate,
      createdAt: DateTime.now(),
    );
    await _db.addTransaction(tx);

    // 2. Auto-split income into 50/30/20 budget limits
    final commitmentsAdd = amount * 0.50;
    final spendingsAdd = amount * 0.30;
    final savingsAdd = amount * 0.20;

    await FirebaseFirestore.instance.collection('budgets').doc(_userId).update({
      'commitments.limit': FieldValue.increment(commitmentsAdd),
      'spendings.limit': FieldValue.increment(spendingsAdd),
      'savings.limit': FieldValue.increment(savingsAdd),
      'monthlyAllowance': FieldValue.increment(amount),
      'updatedAt': Timestamp.now(),
    });
  }

  // ── EXPENSE: record transaction + deduct from bucket spent ──
  Future<void> _saveExpenseTransaction(double amount) async {
    final tx = TransactionModel(
      id: '',
      userId: _userId,
      type: TransactionType.expense,
      budgetCategory: _budgetCategory,
      amount: amount,
      category: _selectedCategory,
      description: _descriptionController.text.trim(),
      date: _selectedDate,
      createdAt: DateTime.now(),
    );
    await _db.addTransaction(tx);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF6C63FF),
            surface: Color(0xFF1A1A2E),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: SlideTransition(
        position: _slideAnimation,
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        _buildTypeToggle(),
                        const SizedBox(height: 24),
                        _buildAmountField(),
                        const SizedBox(height: 20),

                        // ── Show different inputs based on type ──
                        if (_type == TransactionType.income) ...[
                          _buildIncomeSourceSelector(),
                          const SizedBox(height: 16),
                          _buildIncomeSplitPreview(),
                        ] else ...[
                          _buildBucketSelector(),
                          const SizedBox(height: 20),
                          _buildCategorySelector(),
                        ],

                        const SizedBox(height: 20),
                        _buildDescriptionField(),
                        const SizedBox(height: 20),
                        _buildDatePicker(),
                        const SizedBox(height: 32),
                        _buildSaveButton(),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            _type == TransactionType.income ? 'Add Income' : 'Add Expense',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _typeTab(
            TransactionType.expense,
            'Expense',
            Icons.arrow_upward_rounded,
            const Color(0xFFFF6B6B),
          ),
          _typeTab(
            TransactionType.income,
            'Income',
            Icons.arrow_downward_rounded,
            const Color(0xFF00D4AA),
          ),
        ],
      ),
    );
  }

  Widget _typeTab(
    TransactionType type,
    String label,
    IconData icon,
    Color color,
  ) {
    final isSelected = _type == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _type = type;
          // Reset fields when switching type
          _selectedCategory = 'Food & Drinks';
          _budgetCategory = BudgetCategory.spending;
          _selectedIncomeSource = 'Allowance';
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(color: color.withOpacity(0.4))
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? color : const Color(0xFF4A4A6A),
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? color : const Color(0xFF4A4A6A),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAmountField() {
    final color = _type == TransactionType.expense
        ? const Color(0xFFFF6B6B)
        : const Color(0xFF00D4AA);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Amount (RM)',
          style: TextStyle(
            color: Color(0xFF9E9FBF),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(
            color: color,
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Amount is required';
            if (double.tryParse(v) == null) return 'Enter a valid amount';
            if (double.parse(v) <= 0) return 'Amount must be greater than 0';
            return null;
          },
          decoration: InputDecoration(
            hintText: '0.00',
            hintStyle: TextStyle(
              color: color.withOpacity(0.3),
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
            prefixText: 'RM ',
            prefixStyle: TextStyle(
              color: color.withOpacity(0.6),
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
            filled: true,
            fillColor: color.withOpacity(0.08),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: color, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: Color(0xFFE53935),
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.all(20),
          ),
        ),
      ],
    );
  }

  // ── NEW: Income source selector ──
  Widget _buildIncomeSourceSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Income Source',
          style: TextStyle(
            color: Color(0xFF9E9FBF),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF00D4AA).withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF00D4AA).withOpacity(0.3)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedIncomeSource,
              isExpanded: true,
              dropdownColor: const Color(0xFF1A1A2E),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF00D4AA),
              ),
              items: _incomeSources
                  .map(
                    (source) => DropdownMenuItem(
                      value: source,
                      child: Row(
                        children: [
                          Icon(
                            _incomeSourceIcon(source),
                            color: const Color(0xFF00D4AA),
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Text(source),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (val) => setState(() => _selectedIncomeSource = val!),
            ),
          ),
        ),
      ],
    );
  }

  // ── NEW: 50/30/20 split preview for income ──
  Widget _buildIncomeSplitPreview() {
    final amount = double.tryParse(_amountController.text) ?? 0;
    final commitments = amount * 0.50;
    final spending = amount * 0.30;
    final savings = amount * 0.20;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF00D4AA).withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00D4AA).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                color: Color(0xFF00D4AA),
                size: 16,
              ),
              const SizedBox(width: 8),
              const Text(
                'Auto 50/30/20 Split',
                style: TextStyle(
                  color: Color(0xFF00D4AA),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _splitRow('Commitments (50%)', commitments, const Color(0xFF6C63FF)),
          const SizedBox(height: 8),
          _splitRow('Spending (30%)', spending, const Color(0xFFFFB347)),
          const SizedBox(height: 8),
          _splitRow('Savings (20%)', savings, const Color(0xFF00D4AA)),
          const SizedBox(height: 12),
          Text(
            'This income will automatically increase your budget limits for each category.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _splitRow(String label, double amount, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFF9E9FBF), fontSize: 12),
          ),
        ),
        Text(
          'RM ${amount.toStringAsFixed(2)}',
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  IconData _incomeSourceIcon(String source) {
    switch (source) {
      case 'Allowance':
        return Icons.family_restroom_rounded;
      case 'Part-time Job':
        return Icons.work_outline_rounded;
      case 'PTPTN':
        return Icons.school_outlined;
      case 'MARA':
        return Icons.account_balance_outlined;
      case 'Scholarship':
        return Icons.emoji_events_outlined;
      case 'Freelance':
        return Icons.laptop_outlined;
      default:
        return Icons.attach_money_rounded;
    }
  }

  Widget _buildBucketSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Budget Bucket',
          style: TextStyle(
            color: Color(0xFF9E9FBF),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _bucketChip(
              BudgetCategory.commitment,
              'Commitments',
              const Color(0xFF6C63FF),
            ),
            const SizedBox(width: 8),
            _bucketChip(
              BudgetCategory.spending,
              'Spending',
              const Color(0xFF00D4AA),
            ),
            const SizedBox(width: 8),
            _bucketChip(
              BudgetCategory.savings,
              'Savings',
              const Color(0xFFFFB347),
            ),
          ],
        ),
      ],
    );
  }

  Widget _bucketChip(BudgetCategory bucket, String label, Color color) {
    final isSelected = _budgetCategory == bucket;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _budgetCategory = bucket;
          _selectedCategory = _currentCategories.first;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withOpacity(0.15)
                : Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? color.withOpacity(0.5)
                  : Colors.white.withOpacity(0.08),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? color : const Color(0xFF4A4A6A),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Category',
          style: TextStyle(
            color: Color(0xFF9E9FBF),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _currentCategories.contains(_selectedCategory)
                  ? _selectedCategory
                  : _currentCategories.first,
              isExpanded: true,
              dropdownColor: const Color(0xFF1A1A2E),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF9E9FBF),
              ),
              items: _currentCategories
                  .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                  .toList(),
              onChanged: (val) => setState(() => _selectedCategory = val!),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Description (Optional)',
          style: TextStyle(
            color: Color(0xFF9E9FBF),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _descriptionController,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          maxLines: 2,
          onChanged: (_) => setState(() {}), // rebuild split preview
          decoration: InputDecoration(
            hintText: _type == TransactionType.income
                ? 'e.g. Monthly allowance from parents...'
                : 'e.g. Lunch at Pak Ali, Monthly rent...',
            hintStyle: TextStyle(
              color: Colors.white.withOpacity(0.25),
              fontSize: 13,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Icon(
                Icons.notes_rounded,
                color: _type == TransactionType.income
                    ? const Color(0xFF00D4AA)
                    : const Color(0xFF6C63FF),
                size: 20,
              ),
            ),
            filled: true,
            fillColor: Colors.white.withOpacity(0.06),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: Colors.white.withOpacity(0.08),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: _type == TransactionType.income
                    ? const Color(0xFF00D4AA)
                    : const Color(0xFF6C63FF),
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Date',
          style: TextStyle(
            color: Color(0xFF9E9FBF),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickDate,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  color: _type == TransactionType.income
                      ? const Color(0xFF00D4AA)
                      : const Color(0xFF6C63FF),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                const Spacer(),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Color(0xFF9E9FBF),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    final isIncome = _type == TransactionType.income;
    final color = isIncome ? const Color(0xFF00D4AA) : const Color(0xFFFF6B6B);
    final gradientColors = isIncome
        ? [const Color(0xFF00D4AA), const Color(0xFF00F5C8)]
        : [const Color(0xFFFF6B6B), const Color(0xFFFF8E8E)];

    return GestureDetector(
      onTap: _isLoading ? null : _saveTransaction,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradientColors),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: _isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isIncome
                          ? Icons.add_circle_outline_rounded
                          : Icons.remove_circle_outline_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isIncome ? 'Add Income' : 'Record Expense',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
