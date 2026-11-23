import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocket_plan/core/services/database_service.dart';
import 'package:pocket_plan/core/themes/app_colors.dart';
import 'package:pocket_plan/core/utils/amount_input.dart';
import 'package:pocket_plan/core/utils/currency_formatter.dart';
import 'package:pocket_plan/models/budget_model.dart';
import 'package:pocket_plan/models/transaction_model.dart';
import 'package:pocket_plan/providers/currency_provider.dart';
import 'package:pocket_plan/widgets/amount_field.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen>
    with TickerProviderStateMixin {
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  DateTime _lastSubmit = DateTime.fromMillisecondsSinceEpoch(0);
  final DatabaseService _db = DatabaseService();

  TransactionType _type = TransactionType.expense;
  BudgetCategory _budgetCategory = BudgetCategory.spending;
  String _selectedCategory = 'Dining Out & Cafes';
  String _selectedIncomeSource = 'Salary';
  BudgetModel? _budget;
  StreamSubscription<BudgetModel?>? _budgetSub;

  int _amountCents = 0;

  final List<String> _incomeSources = TransactionCategories.incomeSources;

  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  String get _userId => FirebaseAuth.instance.currentUser?.uid ?? '';
  double get _amountDouble => _amountCents / 100.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final arg = ModalRoute.of(context)?.settings.arguments;
      if (arg == 'income') setState(() => _type = TransactionType.income);
    });

    if (_userId.isNotEmpty) {
      _budgetSub = _db.budgetStream(_userId).listen((b) {
        if (mounted) setState(() => _budget = b);
      });
    }

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
    _budgetSub?.cancel();
    _descriptionController.dispose();
    _amountController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  List<String> get _currentCategories =>
      TransactionCategories.categories[_budgetCategory] ?? [];

  void _submit() {
    final now = DateTime.now();
    if (now.difference(_lastSubmit) < const Duration(milliseconds: 400)) return;
    _lastSubmit = now;
    _saveTransaction();
  }

  Future<void> _saveTransaction() async {
    if (_isLoading) return;
    final colors = context.colors;
    if (_amountCents == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter an amount'),
          backgroundColor: colors.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_type == TransactionType.income) {
        await _saveIncomeTransaction(_amountDouble);
      } else {
        await _saveExpenseTransaction(_amountDouble);
      }

      if (mounted) {
        final colors2 = context.colors;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _type == TransactionType.income
                  ? 'Income added! Budget limits updated with your split rule.'
                  : 'Expense recorded successfully!',
            ),
            backgroundColor: _type == TransactionType.income
                ? colors2.success
                : colors2.danger,
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
        final colors3 = context.colors;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: colors3.danger,
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

  Future<void> _saveIncomeTransaction(double amount) async {
    final tx = TransactionModel(
      id: '',
      userId: _userId,
      type: TransactionType.income,
      budgetCategory: BudgetCategory.savings,
      amount: amount,
      category: _selectedIncomeSource,
      description: _descriptionController.text.trim().isEmpty
          ? _selectedIncomeSource
          : _descriptionController.text.trim(),
      date: _selectedDate,
      createdAt: DateTime.now(),
    );
    await _db.addTransaction(tx);
  }

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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final currency = ref.watch(currencyProvider);
    final isIncome = _type == TransactionType.income;
    final color = isIncome ? colors.success : colors.danger;

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
                _buildHeader(isIncome),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTypeToggle(),
                        const SizedBox(height: 20),
                        AmountField(
                          controller: _amountController,
                          color: color,
                          currencySymbol: CurrencyFormatter.symbol(currency),
                          autofocus: kIsWeb,
                          onChanged: (text) =>
                              setState(() => _amountCents = parseCents(text)),
                          onSubmitted: _submit,
                        ),
                        const SizedBox(height: 20),
                        if (isIncome) ...[
                          _buildIncomeSourceSelector(),
                          const SizedBox(height: 16),
                          _buildIncomeSplitPreview(currency),
                        ] else ...[
                          _buildBucketSelector(),
                          const SizedBox(height: 16),
                          _buildCategorySelector(),
                        ],
                        const SizedBox(height: 16),
                        _buildDescriptionField(isIncome, color),
                        const SizedBox(height: 16),
                        _buildDatePicker(color),
                        const SizedBox(height: 24),
                        _buildSaveButton(isIncome, color),
                        const SizedBox(height: 32),
                      ],
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

  Widget _buildHeader(bool isIncome) {
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
            isIncome ? 'Add Income' : 'Add Expense',
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
          _amountCents = 0;
          _amountController.clear();
          _selectedCategory = 'Dining Out & Cafes';
          _budgetCategory = BudgetCategory.spending;
          _selectedIncomeSource = 'Salary';
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

  Widget _buildIncomeSourceSelector() {
    final colors = context.colors;
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
              value: _selectedIncomeSource,
              isExpanded: true,
              dropdownColor: colors.surface,
              style: TextStyle(color: colors.textPrimary, fontSize: 14),
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: colors.success,
              ),
              items: _incomeSources
                  .map(
                    (source) => DropdownMenuItem(
                      value: source,
                      child: Row(
                        children: [
                          Icon(
                            _incomeSourceIcon(source),
                            color: colors.success,
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

  Widget _buildIncomeSplitPreview(String currency) {
    final colors = context.colors;
    final cRatio = _budget?.commitmentRatio ?? 0.50;
    final spRatio = _budget?.spendingRatio ?? 0.30;
    final svRatio = _budget?.savingsRatio ?? 0.20;
    final commitments = _amountDouble * cRatio;
    final spending = _amountDouble * spRatio;
    final savings = _amountDouble * svRatio;
    final cPct = (cRatio * 100).round();
    final spPct = (spRatio * 100).round();
    final svPct = (svRatio * 100).round();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.success.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.success.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: colors.success, size: 16),
              const SizedBox(width: 8),
              Text(
                'Auto $cPct/$spPct/$svPct Split',
                style: TextStyle(
                  color: colors.success,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _splitRow(
            'Essential Needs ($cPct%)',
            commitments,
            colors.accent,
            currency,
          ),
          const SizedBox(height: 8),
          _splitRow('Lifestyle ($spPct%)', spending, colors.warning, currency),
          const SizedBox(height: 8),
          _splitRow('Savings ($svPct%)', savings, colors.success, currency),
          const SizedBox(height: 12),
          Text(
            'This income will automatically scale your budget limits using your current split.',
            style: TextStyle(
              color: colors.textPrimary.withOpacity(0.45),
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _splitRow(String label, double amount, Color color, String currency) {
    final colors = context.colors;
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
            style: TextStyle(color: colors.textSecondary, fontSize: 12),
          ),
        ),
        Text(
          CurrencyFormatter.format(amount, code: currency),
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
      case 'Salary':
        return Icons.payments_outlined;
      case 'Business / Self-Employed':
        return Icons.storefront_outlined;
      case 'Freelance / Side Hustle':
        return Icons.laptop_outlined;
      case 'Allowance':
        return Icons.family_restroom_rounded;
      case 'Pension / Retirement':
        return Icons.elderly_rounded;
      case 'Investments / Dividends':
        return Icons.trending_up_rounded;
      case 'Rental Income':
        return Icons.home_work_outlined;
      case 'Scholarship / Grant':
        return Icons.emoji_events_outlined;
      case 'Part-time Job':
        return Icons.work_outline_rounded;
      default:
        return Icons.attach_money_rounded;
    }
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
              'Essentials',
              colors.accent,
            ),
            const SizedBox(width: 8),
            _bucketChip(BudgetCategory.spending, 'Lifestyle', colors.success),
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
              value: _currentCategories.contains(_selectedCategory)
                  ? _selectedCategory
                  : _currentCategories.first,
              isExpanded: true,
              dropdownColor: colors.surface,
              style: TextStyle(color: colors.textPrimary, fontSize: 14),
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: colors.textSecondary,
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

  Widget _buildDescriptionField(bool isIncome, Color color) {
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
        TextField(
          controller: _descriptionController,
          style: TextStyle(color: colors.textPrimary, fontSize: 14),
          maxLines: 1,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            hintText: isIncome
                ? 'e.g. Monthly salary, freelance project...'
                : 'e.g. Weekly groceries, lunch, utility bill...',
            hintStyle: TextStyle(color: colors.textTertiary, fontSize: 13),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Icon(Icons.notes_rounded, color: color, size: 20),
            ),
            filled: true,
            fillColor: colors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: colors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: color, width: 1.5),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePicker(Color color) {
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
                Icon(Icons.calendar_today_outlined, color: color, size: 20),
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

  Widget _buildSaveButton(bool isIncome, Color color) {
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
