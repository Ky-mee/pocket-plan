import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocket_plan/core/services/recurring_service.dart';
import 'package:pocket_plan/core/themes/app_colors.dart';
import 'package:pocket_plan/core/utils/amount_input.dart';
import 'package:pocket_plan/core/utils/budget_cycle.dart';
import 'package:pocket_plan/core/utils/currency_formatter.dart';
import 'package:pocket_plan/models/recurring_transaction_model.dart';
import 'package:pocket_plan/models/transaction_model.dart';
import 'package:pocket_plan/providers/currency_provider.dart';

/// Manage monthly recurring bills, subscriptions, and salary/income templates.
class RecurringScreen extends ConsumerStatefulWidget {
  const RecurringScreen({super.key});

  @override
  ConsumerState<RecurringScreen> createState() => _RecurringScreenState();
}

class _RecurringScreenState extends ConsumerState<RecurringScreen> {
  final _service = RecurringService();
  final _auth = FirebaseAuth.instance;
  bool _processingAll = false;

  String? get _uid => _auth.currentUser?.uid;

  Future<void> _syncDueNow() async {
    final uid = _uid;
    if (uid == null || _processingAll) return;
    setState(() => _processingAll = true);
    try {
      final count = await _service.processDueRecurring(uid);
      if (!mounted) return;
      final colors = context.colors;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            count > 0
                ? 'Logged $count due recurring item${count == 1 ? '' : 's'}.'
                : 'All due recurring items are already up to date.',
          ),
          backgroundColor: count > 0 ? colors.success : colors.surface,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Sync failed: $e')));
    } finally {
      if (mounted) setState(() => _processingAll = false);
    }
  }

  Future<void> _logItemNow(RecurringTransactionModel item) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final posted = await _service.applyItemForCycle(uid, item.id);
      if (!mounted) return;
      final colors = context.colors;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            posted
                ? 'Logged "${item.title}" to this cycle.'
                : '"${item.title}" was already logged this cycle.',
          ),
          backgroundColor: posted ? colors.success : colors.surface,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not log item: $e')));
    }
  }

  Future<void> _deleteItem(RecurringTransactionModel item) async {
    final uid = _uid;
    if (uid == null) return;
    final colors = context.colors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Recurring Item'),
        content: Text(
          'Stop tracking "${item.title}" automatically? Existing logged transactions will remain.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Delete', style: TextStyle(color: colors.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _service.deleteRecurring(uid, item.id);
    }
  }

  void _openEditor({RecurringTransactionModel? existing}) {
    final uid = _uid;
    if (uid == null) return;
    final currency = ref.read(currencyProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _RecurringEditorSheet(
        userId: uid,
        currencyCode: currency,
        existing: existing,
        onSave: (model) async {
          if (existing == null) {
            await _service.addRecurring(model);
          } else {
            await _service.updateRecurring(model);
          }
        },
      ),
    );
  }

  static String _ordinal(int day) {
    if (day >= 11 && day <= 13) return '${day}th';
    switch (day % 10) {
      case 1:
        return '${day}st';
      case 2:
        return '${day}nd';
      case 3:
        return '${day}rd';
      default:
        return '${day}th';
    }
  }

  static String _bucketLabel(BudgetCategory bucket) {
    switch (bucket) {
      case BudgetCategory.commitment:
        return 'Essentials';
      case BudgetCategory.spending:
        return 'Lifestyle';
      case BudgetCategory.savings:
        return 'Savings';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final currency = ref.watch(currencyProvider);
    final uid = _uid;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        title: Text(
          'Recurring Bills & Income',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: IconThemeData(color: colors.textPrimary),
        actions: [
          IconButton(
            tooltip: 'Sync Due Items Now',
            onPressed: _processingAll ? null : _syncDueNow,
            icon: _processingAll
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.accent,
                    ),
                  )
                : Icon(Icons.sync_rounded, color: colors.accent),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        backgroundColor: colors.accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Recurring'),
      ),
      body: uid == null
          ? Center(
              child: Text(
                'Please sign in to manage recurring items.',
                style: TextStyle(color: colors.textSecondary),
              ),
            )
          : StreamBuilder<List<RecurringTransactionModel>>(
              stream: _service.streamRecurring(uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return Center(
                    child: CircularProgressIndicator(color: colors.accent),
                  );
                }

                final items = snapshot.data ?? [];
                double totalIncome = 0;
                double totalExpenses = 0;
                for (final item in items.where((i) => i.isActive)) {
                  if (item.type == TransactionType.income) {
                    totalIncome += item.amount;
                  } else {
                    totalExpenses += item.amount;
                  }
                }

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  children: [
                    _buildSummaryCard(
                      colors: colors,
                      currency: currency,
                      income: totalIncome,
                      expenses: totalExpenses,
                    ),
                    const SizedBox(height: 16),
                    if (items.isEmpty)
                      _buildEmptyState(colors)
                    else
                      ...items.map(
                        (item) => _buildItemCard(
                          item: item,
                          colors: colors,
                          currency: currency,
                        ),
                      ),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildSummaryCard({
    required AppColors colors,
    required String currency,
    required double income,
    required double expenses,
  }) {
    final net = income - expenses;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.repeat_rounded, color: colors.accent, size: 20),
              const SizedBox(width: 8),
              Text(
                'Active Monthly Schedule',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _summaryStat(
                  colors,
                  'Scheduled Income',
                  CurrencyFormatter.format(income, code: currency),
                  colors.success,
                ),
              ),
              Expanded(
                child: _summaryStat(
                  colors,
                  'Scheduled Bills',
                  CurrencyFormatter.format(expenses, code: currency),
                  colors.danger,
                ),
              ),
              Expanded(
                child: _summaryStat(
                  colors,
                  'Net Scheduled',
                  CurrencyFormatter.signed(
                    net.abs(),
                    isExpense: net < 0,
                    code: currency,
                  ),
                  net >= 0 ? colors.success : colors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Active items are posted once per budget cycle automatically on or after their due day (1st–28th).',
            style: TextStyle(color: colors.textTertiary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _summaryStat(
    AppColors colors,
    String label,
    String value,
    Color valueColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: colors.textSecondary, fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: valueColor,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(AppColors colors) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Icon(
            Icons.event_repeat_rounded,
            size: 48,
            color: colors.accent.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 12),
          Text(
            'No recurring bills or income yet',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Add rent, mortgage, salary, internet, or subscriptions once and PocketPlan will log them automatically every cycle.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _openEditor(),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add First Item'),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard({
    required RecurringTransactionModel item,
    required AppColors colors,
    required String currency,
  }) {
    final isIncome = item.type == TransactionType.income;
    final accent = isIncome ? colors.success : colors.danger;
    final tagLabel = isIncome ? 'Income' : _bucketLabel(item.budgetCategory);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.isActive
              ? colors.border
              : colors.border.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      _ordinal(item.dayOfMonth),
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      'Cycle',
                      style: TextStyle(
                        color: colors.textTertiary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        color: item.isActive
                            ? colors.textPrimary
                            : colors.textTertiary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colors.accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            tagLabel,
                            style: TextStyle(
                              color: colors.accent,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (item.category.isNotEmpty)
                          Text(
                            item.category,
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyFormatter.signed(
                      item.amount,
                      isExpense: !isIncome,
                      code: currency,
                    ),
                    style: TextStyle(
                      color: item.isActive ? accent : colors.textTertiary,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Switch.adaptive(
                    value: item.isActive,
                    activeThumbColor: colors.accent,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: (val) => _service.updateRecurring(
                      item.copyWith(isActive: val),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 18),
          Row(
            children: [
              Text(
                item.lastProcessedCycle.isNotEmpty
                    ? 'Last logged: ${item.lastProcessedCycle}'
                    : 'Not logged yet',
                style: TextStyle(color: colors.textTertiary, fontSize: 11),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _logItemNow(item),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(0, 32),
                ),
                icon: Icon(
                  Icons.play_arrow_rounded,
                  size: 16,
                  color: colors.accent,
                ),
                label: Text(
                  'Log Now',
                  style: TextStyle(color: colors.accent, fontSize: 12),
                ),
              ),
              IconButton(
                tooltip: 'Edit',
                icon: Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: colors.textSecondary,
                ),
                onPressed: () => _openEditor(existing: item),
              ),
              IconButton(
                tooltip: 'Delete',
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: colors.danger,
                ),
                onPressed: () => _deleteItem(item),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecurringEditorSheet extends StatefulWidget {
  final String userId;
  final String currencyCode;
  final RecurringTransactionModel? existing;
  final Future<void> Function(RecurringTransactionModel model) onSave;

  const _RecurringEditorSheet({
    required this.userId,
    required this.currencyCode,
    required this.onSave,
    this.existing,
  });

  @override
  State<_RecurringEditorSheet> createState() => _RecurringEditorSheetState();
}

class _RecurringEditorSheetState extends State<_RecurringEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late TransactionType _type;
  late BudgetCategory _bucket;
  late String _category;
  late int _dayOfMonth;
  late bool _isActive;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titleController = TextEditingController(text: e?.title ?? '');
    _amountController = TextEditingController(
      text: e != null ? e.amount.toStringAsFixed(2) : '',
    );
    _type = e?.type ?? TransactionType.expense;
    _bucket = e?.budgetCategory ?? BudgetCategory.commitment;
    _dayOfMonth = e?.dayOfMonth ?? 1;
    _isActive = e?.isActive ?? true;
    _category = e?.category.isNotEmpty == true
        ? e!.category
        : _defaultCategory(_type, _bucket);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  static String _defaultCategory(TransactionType type, BudgetCategory bucket) {
    if (type == TransactionType.income) {
      return TransactionCategories.incomeSources.first;
    }
    return TransactionCategories.categories[bucket]!.first;
  }

  List<String> get _categoryOptions {
    if (_type == TransactionType.income) {
      return TransactionCategories.incomeSources;
    }
    return TransactionCategories.categories[_bucket] ?? const [];
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    final amount = parseCents(_amountController.text) / 100.0;
    if (amount <= 0) return;

    setState(() => _saving = true);
    try {
      final existing = widget.existing;
      final model = RecurringTransactionModel(
        id: existing?.id ?? '',
        userId: widget.userId,
        title: _titleController.text.trim(),
        amount: amount,
        type: _type,
        budgetCategory: _bucket,
        category: _category,
        dayOfMonth: BudgetCycle.clampStartDay(_dayOfMonth),
        isActive: _isActive,
        lastProcessedCycle: existing?.lastProcessedCycle ?? '',
        createdAt: existing?.createdAt ?? DateTime.now(),
      );
      await widget.onSave(model);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save item: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final symbol = CurrencyFormatter.symbol(widget.currencyCode);
    final options = _categoryOptions;
    if (!options.contains(_category) && options.isNotEmpty) {
      _category = options.first;
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.existing == null
                    ? 'New Recurring Item'
                    : 'Edit Recurring Item',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Bill / Expense'),
                      selected: _type == TransactionType.expense,
                      onSelected: (_) => setState(() {
                        _type = TransactionType.expense;
                        _category = _defaultCategory(_type, _bucket);
                      }),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Recurring Income'),
                      selected: _type == TransactionType.income,
                      onSelected: (_) => setState(() {
                        _type = TransactionType.income;
                        _category = _defaultCategory(_type, _bucket);
                      }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _titleController,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(color: colors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Title',
                  hintText: _type == TransactionType.income
                      ? 'e.g. Monthly Salary'
                      : 'e.g. Apartment Rent, Internet',
                  filled: true,
                  fillColor: colors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter a title' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [AmountInputFormatter()],
                      style: TextStyle(color: colors.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Amount ($symbol)',
                        prefixText: '$symbol ',
                        filled: true,
                        fillColor: colors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (v) => parseCents(v ?? '') <= 0
                          ? 'Enter amount > 0'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<int>(
                      key: ValueKey('day-$_dayOfMonth'),
                      initialValue: _dayOfMonth,
                      dropdownColor: colors.surface,
                      style: TextStyle(color: colors.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Day (1–28)',
                        filled: true,
                        fillColor: colors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: List.generate(
                        28,
                        (i) => DropdownMenuItem(
                          value: i + 1,
                          child: Text(_RecurringScreenState._ordinal(i + 1)),
                        ),
                      ),
                      onChanged: (v) {
                        if (v != null) setState(() => _dayOfMonth = v);
                      },
                    ),
                  ),
                ],
              ),
              if (_type == TransactionType.expense) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<BudgetCategory>(
                  key: ValueKey('bucket-$_bucket'),
                  initialValue: _bucket,
                  dropdownColor: colors.surface,
                  style: TextStyle(color: colors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Budget Bucket',
                    filled: true,
                    fillColor: colors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: BudgetCategory.commitment,
                      child: Text('Essentials (Commitments)'),
                    ),
                    DropdownMenuItem(
                      value: BudgetCategory.spending,
                      child: Text('Lifestyle (Spendings)'),
                    ),
                    DropdownMenuItem(
                      value: BudgetCategory.savings,
                      child: Text('Savings & Investing'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      _bucket = v;
                      _category = _defaultCategory(_type, _bucket);
                    });
                  },
                ),
              ],
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey('cat-${_type.name}-${_bucket.name}-$_category'),
                initialValue: _category,
                dropdownColor: colors.surface,
                style: TextStyle(color: colors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Category',
                  filled: true,
                  fillColor: colors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: options
                    .map(
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Text(c, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _category = v);
                },
              ),
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Active (auto-post each cycle)',
                  style: TextStyle(color: colors.textPrimary, fontSize: 14),
                ),
                value: _isActive,
                activeThumbColor: colors.accent,
                onChanged: (v) => setState(() => _isActive = v),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _saving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        widget.existing == null
                            ? 'Save Recurring Item'
                            : 'Update Item',
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
