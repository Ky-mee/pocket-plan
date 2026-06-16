import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pocket_plan/models/transaction_model.dart';

class EditTransactionScreen extends StatefulWidget {
  final TransactionModel transaction;

  const EditTransactionScreen({super.key, required this.transaction});

  @override
  State<EditTransactionScreen> createState() => _EditTransactionScreenState();
}

class _EditTransactionScreenState extends State<EditTransactionScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountController;
  late TextEditingController _descriptionController;

  late TransactionType _type;
  late BudgetCategory _budgetCategory;
  late String _selectedCategory;
  late DateTime _selectedDate;
  bool _isLoading = false;

  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  String get _userId => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    // Pre-fill with existing transaction data
    _type = widget.transaction.type;
    _budgetCategory = widget.transaction.budgetCategory;
    _selectedCategory = widget.transaction.category;
    _selectedDate = widget.transaction.date;
    _amountController = TextEditingController(
      text: widget.transaction.amount.toStringAsFixed(2),
    );
    _descriptionController = TextEditingController(
      text: widget.transaction.description,
    );

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

  Future<void> _saveEdit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final oldTx = widget.transaction;
      final newAmount = double.parse(_amountController.text);

      // Step 1: Reverse old transaction's budget impact
      await _reverseOldImpact(oldTx);

      // Step 2: Update the transaction document
      await FirebaseFirestore.instance
          .collection('transactions')
          .doc(oldTx.id)
          .update({
            'type': _type == TransactionType.expense ? 'expense' : 'income',
            'budgetCategory': _budgetCategory.name,
            'amount': newAmount,
            'category': _selectedCategory,
            'description': _descriptionController.text.trim(),
            'date': Timestamp.fromDate(_selectedDate),
          });

      // Step 3: Apply new transaction's budget impact
      await _applyNewImpact(newAmount);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Transaction updated!'),
            backgroundColor: const Color(0xFF00D4AA),
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

  // Reverse old transaction's effect on budget
  Future<void> _reverseOldImpact(TransactionModel tx) async {
    final reverseAmount = tx.type == TransactionType.expense
        ? -tx.amount
        : tx.amount;
    final field = switch (tx.budgetCategory) {
      BudgetCategory.commitment => 'commitments.spent',
      BudgetCategory.spending => 'spendings.spent',
      BudgetCategory.savings => 'savings.spent',
    };
    await FirebaseFirestore.instance.collection('budgets').doc(_userId).update({
      field: FieldValue.increment(reverseAmount),
      'updatedAt': Timestamp.now(),
    });
  }

  // Apply new transaction's effect on budget
  Future<void> _applyNewImpact(double newAmount) async {
    final applyAmount = _type == TransactionType.expense
        ? newAmount
        : -newAmount;
    final field = switch (_budgetCategory) {
      BudgetCategory.commitment => 'commitments.spent',
      BudgetCategory.spending => 'spendings.spent',
      BudgetCategory.savings => 'savings.spent',
    };
    await FirebaseFirestore.instance.collection('budgets').doc(_userId).update({
      field: FieldValue.increment(applyAmount),
      'updatedAt': Timestamp.now(),
    });
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

  List<String> get _currentCategories =>
      TransactionCategories.categories[_budgetCategory] ?? [];

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
                        _buildBucketSelector(),
                        const SizedBox(height: 20),
                        _buildCategorySelector(),
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
          const Text(
            'Edit Transaction',
            style: TextStyle(
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
          if (type == TransactionType.income) {
            _budgetCategory = BudgetCategory.savings;
            _selectedCategory = 'Bank Savings';
          } else {
            _budgetCategory = BudgetCategory.spending;
            _selectedCategory = 'Food & Drinks';
          }
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
            contentPadding: const EdgeInsets.all(20),
          ),
        ),
      ],
    );
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
          decoration: InputDecoration(
            hintText: 'e.g. Lunch at Pak Ali, Monthly rent...',
            hintStyle: TextStyle(
              color: Colors.white.withOpacity(0.25),
              fontSize: 13,
            ),
            prefixIcon: const Padding(
              padding: EdgeInsets.only(bottom: 24),
              child: Icon(
                Icons.notes_rounded,
                color: Color(0xFF6C63FF),
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
              borderSide: const BorderSide(
                color: Color(0xFF6C63FF),
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
                const Icon(
                  Icons.calendar_today_outlined,
                  color: Color(0xFF6C63FF),
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
    final color = _type == TransactionType.expense
        ? const Color(0xFFFF6B6B)
        : const Color(0xFF00D4AA);
    return GestureDetector(
      onTap: _isLoading ? null : _saveEdit,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _type == TransactionType.expense
                ? [const Color(0xFFFF6B6B), const Color(0xFFFF8E8E)]
                : [const Color(0xFF00D4AA), const Color(0xFF00F5C8)],
          ),
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
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.save_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Save Changes',
                      style: TextStyle(
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
