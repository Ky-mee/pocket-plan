import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocket_plan/core/layout/desktop_shell.dart';
import 'package:pocket_plan/core/services/database_service.dart';
import 'package:pocket_plan/core/themes/app_colors.dart';
import 'package:pocket_plan/core/utils/amount_input.dart';
import 'package:pocket_plan/core/utils/currency_formatter.dart';
import 'package:pocket_plan/models/budget_model.dart';
import 'package:pocket_plan/models/transaction_model.dart';
import 'package:pocket_plan/providers/currency_provider.dart';

class BudgetScreen extends ConsumerStatefulWidget {
  const BudgetScreen({super.key});

  @override
  ConsumerState<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends ConsumerState<BudgetScreen>
    with TickerProviderStateMixin {
  final DatabaseService _db = DatabaseService();
  late AnimationController _entryController;
  late Animation<double> _fadeAnimation;

  String get _userId => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeIn,
    );
    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final currency = ref.watch(currencyProvider);
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: StreamBuilder<BudgetModel?>(
            stream: _db.budgetStream(_userId),
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Could not load budget. Please check your connection.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.textSecondary),
                    ),
                  ),
                );
              }
              final budget = snap.data;
              if (snap.connectionState == ConnectionState.waiting &&
                  !snap.hasData) {
                return Center(
                  child: CircularProgressIndicator(color: colors.accent),
                );
              }

              final cPct = '${((budget?.commitmentRatio ?? 0.50) * 100).round()}%';
              final spPct = '${((budget?.spendingRatio ?? 0.30) * 100).round()}%';
              final svPct = '${((budget?.savingsRatio ?? 0.20) * 100).round()}%';

              if (isDesktopLayout(context)) {
                return SingleChildScrollView(
                  child: _buildDesktopBody(
                    budget,
                    colors,
                    currency,
                    cPct,
                    spPct,
                    svPct,
                  ),
                );
              }
              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        _buildHeader(budget, currency),
                        _buildOverviewCard(budget, currency),
                        _buildDonutChart(budget),
                        _buildBucketCard(
                          budget: budget,
                          currency: currency,
                          category: BudgetCategory.commitment,
                          label: 'Essential Needs',
                          subtitle: 'Housing, groceries, bills, healthcare',
                          percent: cPct,
                          color: colors.accent,
                          icon: Icons.home_rounded,
                        ),
                        _buildBucketCard(
                          budget: budget,
                          currency: currency,
                          category: BudgetCategory.spending,
                          label: 'Lifestyle & Wants',
                          subtitle: 'Dining out, shopping, leisure',
                          percent: spPct,
                          color: colors.success,
                          icon: Icons.shopping_bag_rounded,
                        ),
                        _buildBucketCard(
                          budget: budget,
                          currency: currency,
                          category: BudgetCategory.savings,
                          label: 'Savings & Goals',
                          subtitle: 'Emergency fund, retirement, investments',
                          percent: svPct,
                          color: colors.warning,
                          icon: Icons.savings_rounded,
                        ),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopBody(
    BudgetModel? budget,
    AppColors colors,
    String currency,
    String cPct,
    String spPct,
    String svPct,
  ) {
    return Column(
      children: [
        _buildHeader(budget, currency),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildOverviewCard(budget, currency, minHeight: 258),
            ),
            Expanded(child: _buildDonutChart(budget)),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildBucketCard(
                budget: budget,
                currency: currency,
                category: BudgetCategory.commitment,
                label: 'Essential Needs',
                subtitle: 'Housing, groceries, bills, healthcare',
                percent: cPct,
                color: colors.accent,
                icon: Icons.home_rounded,
              ),
            ),
            Expanded(
              child: _buildBucketCard(
                budget: budget,
                currency: currency,
                category: BudgetCategory.spending,
                label: 'Lifestyle & Wants',
                subtitle: 'Dining out, shopping, leisure',
                percent: spPct,
                color: colors.success,
                icon: Icons.shopping_bag_rounded,
              ),
            ),
            Expanded(
              child: _buildBucketCard(
                budget: budget,
                currency: currency,
                category: BudgetCategory.savings,
                label: 'Savings & Goals',
                subtitle: 'Emergency fund, retirement, investments',
                percent: svPct,
                color: colors.warning,
                icon: Icons.savings_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildHeader(BudgetModel? budget, String currency) {
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
          Expanded(
            child: Text(
              'Budget Manager',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => budget != null ? _showChangeSplitSheet(budget) : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.border),
              ),
              child: Text(
                'Split',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () =>
                budget != null ? _showEditAllowanceDialog(budget, currency) : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colors.accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.accent.withOpacity(0.3)),
              ),
              child: Text(
                'Income',
                style: TextStyle(
                  color: colors.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCard(
    BudgetModel? budget,
    String currency, {
    double? minHeight,
  }) {
    final colors = context.colors;
    final allowance = budget?.monthlyAllowance ?? 0;
    final spent = budget?.totalSpent ?? 0;
    final remaining = allowance - spent;

    return Container(
      constraints: minHeight != null
          ? BoxConstraints(minHeight: minHeight)
          : null,
      alignment: minHeight != null ? Alignment.center : null,
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.accent, colors.accent.withOpacity(0.7)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colors.accent.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _overviewStat(
              'Monthly Income',
              CurrencyFormatter.format(allowance, code: currency),
              Icons.account_balance_wallet_outlined,
            ),
          ),
          Container(width: 1, height: 50, color: Colors.white.withOpacity(0.2)),
          Expanded(
            child: _overviewStat(
              'Total Spent',
              CurrencyFormatter.format(spent, code: currency),
              Icons.arrow_upward_rounded,
            ),
          ),
          Container(width: 1, height: 50, color: Colors.white.withOpacity(0.2)),
          Expanded(
            child: _overviewStat(
              'Remaining',
              CurrencyFormatter.format(remaining, code: currency),
              Icons.savings_outlined,
            ),
          ),
        ],
      ),
    );
  }

  Widget _overviewStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 10),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildDonutChart(BudgetModel? budget) {
    final colors = context.colors;
    if (budget == null) return const SizedBox(height: 20);

    final total = budget.monthlyAllowance;
    final committed = budget.commitments.spent;
    final spent = budget.spendings.spent;
    final saved = budget.savings.spent;
    final unspent = (total - committed - spent - saved).clamp(0.0, total);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Text(
            'Spending Breakdown',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              SizedBox(
                width: 140,
                height: 140,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 3,
                    centerSpaceRadius: 40,
                    sections: [
                      if (committed > 0)
                        PieChartSectionData(
                          value: committed,
                          color: colors.accent,
                          radius: 28,
                          showTitle: false,
                        ),
                      if (spent > 0)
                        PieChartSectionData(
                          value: spent,
                          color: colors.success,
                          radius: 28,
                          showTitle: false,
                        ),
                      if (saved > 0)
                        PieChartSectionData(
                          value: saved,
                          color: colors.warning,
                          radius: 28,
                          showTitle: false,
                        ),
                      if (unspent > 0)
                        PieChartSectionData(
                          value: unspent,
                          color: colors.border,
                          radius: 28,
                          showTitle: false,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _chartLegend(
                      'Essential Needs',
                      committed,
                      total,
                      colors.accent,
                    ),
                    const SizedBox(height: 12),
                    _chartLegend('Lifestyle', spent, total, colors.success),
                    const SizedBox(height: 12),
                    _chartLegend('Savings', saved, total, colors.warning),
                    const SizedBox(height: 12),
                    _chartLegend(
                      'Available',
                      unspent,
                      total,
                      colors.textTertiary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chartLegend(String label, double amount, double total, Color color) {
    final colors = context.colors;
    final pct = total > 0 ? (amount / total * 100) : 0;
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: colors.textSecondary, fontSize: 12),
          ),
        ),
        Text(
          '${pct.toStringAsFixed(0)}%',
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildBucketCard({
    required BudgetModel? budget,
    required String currency,
    required BudgetCategory category,
    required String label,
    required String subtitle,
    required String percent,
    required Color color,
    required IconData icon,
  }) {
    final colors = context.colors;
    BucketData? bucket;
    if (budget != null) {
      switch (category) {
        case BudgetCategory.commitment:
          bucket = budget.commitments;
          break;
        case BudgetCategory.spending:
          bucket = budget.spendings;
          break;
        case BudgetCategory.savings:
          bucket = budget.savings;
          break;
      }
    }

    final spent = bucket?.spent ?? 0;
    final limit = bucket?.limit ?? 0;
    final remaining = limit - spent;
    final progress = limit > 0 ? (spent / limit).clamp(0.0, 1.0) : 0.0;
    final isExceeded = bucket?.isExceeded ?? false;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isExceeded ? colors.danger.withOpacity(0.4) : colors.border,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              percent,
                              style: TextStyle(
                                color: color,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isExceeded)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colors.danger.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Exceeded',
                      style: TextStyle(
                        color: colors.danger,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _statItem(
                  'Spent',
                  CurrencyFormatter.format(spent, code: currency),
                  isExceeded ? colors.danger : color,
                ),
                _statItem(
                  'Limit',
                  CurrencyFormatter.format(limit, code: currency),
                  colors.textSecondary,
                ),
                _statItem(
                  'Remaining',
                  CurrencyFormatter.format(remaining.abs(), code: currency),
                  remaining < 0 ? colors.danger : colors.success,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: colors.border,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isExceeded ? colors.danger : color,
                    ),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${(progress * 100).toStringAsFixed(0)}% used',
                      style: TextStyle(
                        color: isExceeded
                            ? colors.danger
                            : colors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => budget != null
                          ? _showEditLimitDialog(
                              budget,
                              currency,
                              category,
                              label,
                              color,
                              limit,
                            )
                          : null,
                      child: Text(
                        'Edit limit',
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (budget != null && bucket != null)
            _buildItemsList(bucket.items, color, budget, category),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, Color color) {
    final colors = context.colors;
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: colors.textTertiary, fontSize: 11)),
      ],
    );
  }

  Widget _buildItemsList(
    List<String> items,
    Color color,
    BudgetModel budget,
    BudgetCategory category,
  ) {
    final colors = context.colors;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tracked Items',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              GestureDetector(
                onTap: () => _showAddItemDialog(budget, category, color),
                child: Icon(
                  Icons.add_circle_outline_rounded,
                  color: color,
                  size: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            Text(
              'No tracked items yet. Tap + to add.',
              style: TextStyle(color: colors.textTertiary, fontSize: 12),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: items.asMap().entries.map((entry) {
                final idx = entry.key;
                final item = entry.value;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item,
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => _removeBucketItem(
                          items: items,
                          removeIndex: idx,
                          category: category,
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: color.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Future<void> _removeBucketItem({
    required List<String> items,
    required int removeIndex,
    required BudgetCategory category,
  }) async {
    final bucketField = switch (category) {
      BudgetCategory.commitment => 'commitments',
      BudgetCategory.spending => 'spendings',
      BudgetCategory.savings => 'savings',
    };
    final updated = List<String>.from(items)..removeAt(removeIndex);
    try {
      await _db.updateBucketItems(
        userId: _userId,
        bucketField: bucketField,
        items: updated,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not remove item. Please try again.'),
            backgroundColor: context.colors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showChangeSplitSheet(BudgetModel budget) {
    final colors = context.colors;
    int cPct = (budget.commitmentRatio * 100).round();
    int spPct = (budget.spendingRatio * 100).round();
    int svPct = 100 - cPct - spPct;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final totalPct = cPct + spPct + svPct;
          final isValid = totalPct == 100;

          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Budget Split Rule',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pick a preset or customize how your monthly income is divided.',
                  style: TextStyle(color: colors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: kBudgetSplitPresets.map((p) {
                    final pc = (p.commitment * 100).round();
                    final psp = (p.spending * 100).round();
                    final psv = (p.savings * 100).round();
                    final selected = cPct == pc && spPct == psp && svPct == psv;
                    return GestureDetector(
                      onTap: () => setSheetState(() {
                        cPct = pc;
                        spPct = psp;
                        svPct = psv;
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? colors.accent.withOpacity(0.15)
                              : colors.surfaceAlt,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected ? colors.accent : colors.border,
                          ),
                        ),
                        child: Text(
                          '${p.name} (${p.ratioLabel})',
                          style: TextStyle(
                            color: selected
                                ? colors.accent
                                : colors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
                _ratioSlider(
                  'Essential Needs',
                  cPct,
                  colors.accent,
                  (v) => setSheetState(() => cPct = v.round()),
                ),
                _ratioSlider(
                  'Lifestyle & Wants',
                  spPct,
                  colors.success,
                  (v) => setSheetState(() => spPct = v.round()),
                ),
                _ratioSlider(
                  'Savings & Goals',
                  svPct,
                  colors.warning,
                  (v) => setSheetState(() => svPct = v.round()),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isValid
                          ? 'Total: 100%'
                          : 'Total: $totalPct% (must equal 100%)',
                      style: TextStyle(
                        color: isValid ? colors.success : colors.danger,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    ElevatedButton(
                      onPressed: !isValid
                          ? null
                          : () async {
                              try {
                                await _db.updateBudgetRatios(
                                  userId: _userId,
                                  commitmentRatio: cPct / 100.0,
                                  spendingRatio: spPct / 100.0,
                                  savingsRatio: svPct / 100.0,
                                );
                                if (ctx.mounted) Navigator.pop(ctx);
                              } catch (_) {
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                        'Failed to update budget split.',
                                      ),
                                      backgroundColor: colors.danger,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Apply Split'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _ratioSlider(
    String label,
    int pct,
    Color color,
    ValueChanged<double> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '$pct%',
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        Slider(
          value: pct.toDouble().clamp(0, 100),
          min: 0,
          max: 100,
          divisions: 20,
          activeColor: color,
          onChanged: onChanged,
        ),
      ],
    );
  }

  void _showEditAllowanceDialog(BudgetModel budget, String currency) {
    final colors = context.colors;
    final symbol = CurrencyFormatter.symbol(currency);
    final ctrl = TextEditingController(
      text: budget.monthlyAllowance.toString(),
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surfaceAlt,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Edit Monthly Income',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: const [AmountInputFormatter()],
          style: TextStyle(color: colors.textPrimary),
          decoration: InputDecoration(
            prefixText: '$symbol ',
            prefixStyle: TextStyle(color: colors.accent),
            filled: true,
            fillColor: colors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colors.accent),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: colors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              final val = double.tryParse(ctrl.text);
              if (val != null && val > 0) {
                try {
                  await _db.updateAllowance(_userId, val);
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (_) {
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Failed to update monthly income.'),
                        backgroundColor: context.colors.danger,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              }
            },
            child: Text(
              'Save',
              style: TextStyle(
                color: colors.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditLimitDialog(
    BudgetModel budget,
    String currency,
    BudgetCategory category,
    String label,
    Color color,
    double currentLimit,
  ) {
    final colors = context.colors;
    final symbol = CurrencyFormatter.symbol(currency);
    final ctrl = TextEditingController(text: currentLimit.toStringAsFixed(2));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surfaceAlt,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Edit $label Limit',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: const [AmountInputFormatter()],
          style: TextStyle(color: colors.textPrimary),
          decoration: InputDecoration(
            prefixText: '$symbol ',
            prefixStyle: TextStyle(color: color),
            filled: true,
            fillColor: colors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: color),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: colors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              final val = double.tryParse(ctrl.text);
              if (val != null && val > 0) {
                double commitmentLimit = budget.commitments.limit;
                double spendingLimit = budget.spendings.limit;
                double savingsLimit = budget.savings.limit;
                switch (category) {
                  case BudgetCategory.commitment:
                    commitmentLimit = val;
                    break;
                  case BudgetCategory.spending:
                    spendingLimit = val;
                    break;
                  case BudgetCategory.savings:
                    savingsLimit = val;
                    break;
                }
                try {
                  await _db.updateBudgetLimits(
                    userId: _userId,
                    commitmentLimit: commitmentLimit,
                    spendingLimit: spendingLimit,
                    savingsLimit: savingsLimit,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (_) {
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Failed to update limit.'),
                        backgroundColor: context.colors.danger,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              }
            },
            child: Text(
              'Save',
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddItemDialog(
    BudgetModel budget,
    BudgetCategory category,
    Color color,
  ) {
    final colors = context.colors;
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surfaceAlt,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Add Item',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: TextField(
          controller: ctrl,
          style: TextStyle(color: colors.textPrimary),
          decoration: InputDecoration(
            hintText: 'e.g. Internet, Childcare, Mortgage...',
            hintStyle: TextStyle(color: colors.textTertiary, fontSize: 13),
            filled: true,
            fillColor: colors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: color),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: colors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              if (ctrl.text.trim().isNotEmpty) {
                BucketData bucket;
                String bucketField;
                switch (category) {
                  case BudgetCategory.commitment:
                    bucket = budget.commitments;
                    bucketField = 'commitments';
                    break;
                  case BudgetCategory.spending:
                    bucket = budget.spendings;
                    bucketField = 'spendings';
                    break;
                  case BudgetCategory.savings:
                    bucket = budget.savings;
                    bucketField = 'savings';
                    break;
                }
                final newItems = [...bucket.items, ctrl.text.trim()];
                try {
                  await _db.updateBucketItems(
                    userId: _userId,
                    bucketField: bucketField,
                    items: newItems,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (_) {
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Failed to add item.'),
                        backgroundColor: context.colors.danger,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              }
            },
            child: Text(
              'Add',
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
