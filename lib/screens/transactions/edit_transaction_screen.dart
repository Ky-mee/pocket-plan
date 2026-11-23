import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pocket_plan/core/services/database_service.dart';
import 'package:pocket_plan/core/themes/app_colors.dart';
import 'package:pocket_plan/core/utils/amount_input.dart';
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
  final DatabaseService _db = DatabaseService();
  late TextEditingController _amountController;
  late TextEditingController _descriptionController;

  late TransactionType _type;
  late BudgetCategory _budgetCategory;
  late String _selectedCategory;
  late DateTime _selectedDate;
  bool _isLoading = false;
  DateTime _lastSubmit = DateTime.fromMillisecondsSinceEpoch(0);

  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
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

  // Enter key / keyboard "done" / button all come here; ignore double fires.
  void _submit() {
    final now = DateTime.now();
    if (now.difference(_lastSubmit) < const Duration(milliseconds: 400)) return;
    _lastSubmit = now;
    _saveEdit();
  }

  Future<void> _saveEdit() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final oldTx = widget.transaction;
      final newAmount = double.parse(_amountController.text);
      final trimmedDesc = _descriptionController.text.trim();
      final updatedTx = TransactionModel(
        id: oldTx.id,
        userId: oldTx.userId,
        type: _type,
        budgetCategory: _type == TransactionType.income
            ? BudgetCategory.savings
            : _budgetCategory,
        amount: newAmount,
        category: _selectedCategory,
        subcategory: oldTx.subcategory,
        description: trimmedDesc.isEmpty && _type == TransactionType.income
            ? _selectedCategory
            : trimmedDesc,
        date: _selectedDate,
        createdAt: oldTx.createdAt,
      );

      await _db.updateTransaction(oldTx, updatedTx);

      if (mounted) {
        final colors = context.colors;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Transaction updated!'),
            backgroundColor: colors.success,
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
        final colors = context.colors;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: colors.danger,
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

  Future<void> _pickDate() async {
    final colors = context.colors;
    final isDark = colors.background.computeLuminance() < 0.5;
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: (isDark ? ThemeData.dark() : ThemeData.light()).copyWith(
          colorScheme: ColorScheme(
            brightness: isDark ? Brightness.dark : Brightness.light,
            primary: colors.accent,
            onPrimary: Colors.white,
            secondary: colors.accent,
            onSecondary: Colors.white,
            error: colors.danger,
            onError: Colors.white,
            surface: colors.surface,
            onSurface: colors.textPrimary,
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
    final colors = context.colors;
    final isIncome = _type == TransactionType.income;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter): _submit,
        const SingleActivator(LogicalKeyboardKey.numpadEnter): _submit,
      },
      child: Scaffold(
        backgroundColor: colors.background,
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
                          if (isIncome)
                            _buildIncomeSourceSelector()
                          else ...[
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
      ),
    );
  }

  Widget _buildHeader() {
    final colors = context.colors;
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
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.arrow_back_ios_new,
                color: colors.textPrimary,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'Edit Transaction',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeToggle() {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _typeTab(
            TransactionType.expense,
            'Expense',
            Icons.arrow_upward_rounded,
            colors.danger,
          ),
          _typeTab(
            TransactionType.income,
            'Income',
            Icons.arrow_downward_rounded,
            colors.success,
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
    final colors = context.colors;
    final isSelected = _type == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _type = type;
          if (type == TransactionType.income) {
            _budgetCategory = BudgetCategory.savings;
            _selectedCategory =
                TransactionCategories.incomeSources.contains(
                  widget.transaction.category,
                )
                ? widget.transaction.category
                : TransactionCategories.incomeSources.first;
          } else {
            _budgetCategory = BudgetCategory.spending;
            _selectedCategory =
                _currentCategories.contains(widget.transaction.category)
                ? widget.transaction.category
                : _currentCategories.first;
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
                color: isSelected ? color : colors.textTertiary,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? color : colors.textTertiary,
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
    final colors = context.colors;
    final color = _type == TransactionType.expense
        ? colors.danger
        : colors.success;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Amount (RM)',
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: const [AmountInputFormatter()],
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _submit(),
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

  Widget _buildIncomeSourceSelector() {
    final colors = context.colors;
    final sources =
        TransactionCategories.incomeSources.contains(_selectedCategory)
        ? TransactionCategories.incomeSources
        : [_selectedCategory, ...TransactionCategories.incomeSources];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Income Source',
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: colors.success.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.success.withOpacity(0.3)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedCategory,
              isExpanded: true,
              dropdownColor: colors.surface,
              style: TextStyle(color: colors.textPrimary, fontSize: 14),
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: colors.success,
              ),
              items: sources
                  .map(
                    (source) =>
                        DropdownMenuItem(value: source, child: Text(source)),
                  )
                  .toList(),
              onChanged: (val) => setState(() => _selectedCategory = val!),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBucketSelector() {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Budget Bucket',
          style: TextStyle(
            color: colors.textSecondary,
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
              colors.accent,
            ),
            const SizedBox(width: 8),
            _bucketChip(BudgetCategory.spending, 'Spending', colors.success),
            const SizedBox(width: 8),
            _bucketChip(BudgetCategory.savings, 'Savings', colors.warning),
          ],
        ),
      ],
    );
  }

  Widget _bucketChip(BudgetCategory bucket, String label, Color color) {
    final colors = context.colors;
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
            color: isSelected ? color.withOpacity(0.15) : colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color.withOpacity(0.5) : colors.border,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? color : colors.textTertiary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySelector() {
    final colors = context.colors;
    final categories = _currentCategories.contains(_selectedCategory)
        ? _currentCategories
        : [_selectedCategory, ..._currentCategories];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category',
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedCategory,
              isExpanded: true,
              dropdownColor: colors.surface,
              style: TextStyle(color: colors.textPrimary, fontSize: 14),
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: colors.textSecondary,
              ),
              items: categories
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
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Description (Optional)',
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _descriptionController,
          style: TextStyle(color: colors.textPrimary, fontSize: 14),
          maxLines: 1,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            hintText: 'e.g. Lunch at Pak Ali, Monthly rent...',
            hintStyle: TextStyle(color: colors.textTertiary, fontSize: 13),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Icon(Icons.notes_rounded, color: colors.accent, size: 20),
            ),
            filled: true,
            fillColor: colors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: colors.border, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: colors.accent, width: 1.5),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePicker() {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Date',
          style: TextStyle(
            color: colors.textSecondary,
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
              color: colors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  color: colors.accent,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                  style: TextStyle(color: colors.textPrimary, fontSize: 14),
                ),
                const Spacer(),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: colors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    final colors = context.colors;
    final color = _type == TransactionType.expense
        ? colors.danger
        : colors.success;
    return GestureDetector(
      onTap: _isLoading ? null : _submit,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]),
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
