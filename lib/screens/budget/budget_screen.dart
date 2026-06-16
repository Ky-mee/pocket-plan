import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pocket_plan/core/services/database_service.dart';
import 'package:pocket_plan/models/budget_model.dart';
import 'package:pocket_plan/models/transaction_model.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen>
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
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: StreamBuilder<BudgetModel?>(
            stream: _db.budgetStream(_userId),
            builder: (context, snap) {
              final budget = snap.data;
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
                );
              }
              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        _buildHeader(budget),
                        _buildOverviewCard(budget),
                        _buildDonutChart(budget),
                        _buildBucketCard(
                          budget: budget,
                          category: BudgetCategory.commitment,
                          label: 'Commitments',
                          subtitle: 'Bills, rent, loans, insurance',
                          percent: '50%',
                          color: const Color(0xFF6C63FF),
                          icon: Icons.home_rounded,
                        ),
                        _buildBucketCard(
                          budget: budget,
                          category: BudgetCategory.spending,
                          label: 'Spending',
                          subtitle: 'Food, shopping, entertainment',
                          percent: '30%',
                          color: const Color(0xFF00D4AA),
                          icon: Icons.shopping_bag_rounded,
                        ),
                        _buildBucketCard(
                          budget: budget,
                          category: BudgetCategory.savings,
                          label: 'Savings',
                          subtitle: 'Bank, ASB, gold, investments',
                          percent: '20%',
                          color: const Color(0xFFFFB347),
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

  // ─────────────────────────────────────────
  // HEADER
  // ─────────────────────────────────────────
  Widget _buildHeader(BudgetModel? budget) {
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
          const Expanded(
            child: Text(
              'Budget Manager',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          GestureDetector(
            onTap: () =>
                budget != null ? _showEditAllowanceDialog(budget) : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF6C63FF).withOpacity(0.3),
                ),
              ),
              child: const Text(
                'Edit',
                style: TextStyle(
                  color: Color(0xFF6C63FF),
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

  // ─────────────────────────────────────────
  // OVERVIEW CARD
  // ─────────────────────────────────────────
  Widget _buildOverviewCard(BudgetModel? budget) {
    final allowance = budget?.monthlyAllowance ?? 0;
    final spent = budget?.totalSpent ?? 0;
    final remaining = allowance - spent;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6C63FF), Color(0xFF4834D4)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _overviewStat(
              'Monthly Allowance',
              'RM ${allowance.toStringAsFixed(2)}',
              Icons.account_balance_wallet_outlined,
            ),
          ),
          Container(width: 1, height: 50, color: Colors.white.withOpacity(0.2)),
          Expanded(
            child: _overviewStat(
              'Total Spent',
              'RM ${spent.toStringAsFixed(2)}',
              Icons.arrow_upward_rounded,
            ),
          ),
          Container(width: 1, height: 50, color: Colors.white.withOpacity(0.2)),
          Expanded(
            child: _overviewStat(
              'Remaining',
              'RM ${remaining.toStringAsFixed(2)}',
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

  // ─────────────────────────────────────────
  // DONUT CHART
  // ─────────────────────────────────────────
  Widget _buildDonutChart(BudgetModel? budget) {
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
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          const Text(
            'Spending Breakdown',
            style: TextStyle(
              color: Colors.white,
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
                          color: const Color(0xFF6C63FF),
                          radius: 28,
                          showTitle: false,
                        ),
                      if (spent > 0)
                        PieChartSectionData(
                          value: spent,
                          color: const Color(0xFF00D4AA),
                          radius: 28,
                          showTitle: false,
                        ),
                      if (saved > 0)
                        PieChartSectionData(
                          value: saved,
                          color: const Color(0xFFFFB347),
                          radius: 28,
                          showTitle: false,
                        ),
                      if (unspent > 0)
                        PieChartSectionData(
                          value: unspent,
                          color: Colors.white.withOpacity(0.08),
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
                      'Commitments',
                      committed,
                      total,
                      const Color(0xFF6C63FF),
                    ),
                    const SizedBox(height: 12),
                    _chartLegend(
                      'Spending',
                      spent,
                      total,
                      const Color(0xFF00D4AA),
                    ),
                    const SizedBox(height: 12),
                    _chartLegend(
                      'Savings',
                      saved,
                      total,
                      const Color(0xFFFFB347),
                    ),
                    const SizedBox(height: 12),
                    _chartLegend(
                      'Available',
                      unspent,
                      total,
                      Colors.white.withOpacity(0.3),
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
            style: const TextStyle(color: Color(0xFF9E9FBF), fontSize: 12),
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

  // ─────────────────────────────────────────
  // BUCKET CARD
  // ─────────────────────────────────────────
  Widget _buildBucketCard({
    required BudgetModel? budget,
    required BudgetCategory category,
    required String label,
    required String subtitle,
    required String percent,
    required Color color,
    required IconData icon,
  }) {
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
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isExceeded
              ? const Color(0xFFFF6B6B).withOpacity(0.4)
              : Colors.white.withOpacity(0.06),
        ),
      ),
      child: Column(
        children: [
          // Header
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
                            style: const TextStyle(
                              color: Colors.white,
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
                        style: const TextStyle(
                          color: Color(0xFF9E9FBF),
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
                      color: const Color(0xFFFF6B6B).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Exceeded',
                      style: TextStyle(
                        color: Color(0xFFFF6B6B),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Stats row
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _statItem(
                  'Spent',
                  'RM ${spent.toStringAsFixed(2)}',
                  isExceeded ? const Color(0xFFFF6B6B) : color,
                ),
                _statItem(
                  'Limit',
                  'RM ${limit.toStringAsFixed(2)}',
                  const Color(0xFF9E9FBF),
                ),
                _statItem(
                  'Remaining',
                  'RM ${remaining.abs().toStringAsFixed(2)}',
                  remaining < 0
                      ? const Color(0xFFFF6B6B)
                      : const Color(0xFF00D4AA),
                ),
              ],
            ),
          ),

          // Progress bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white.withOpacity(0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isExceeded ? const Color(0xFFFF6B6B) : color,
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
                            ? const Color(0xFFFF6B6B)
                            : const Color(0xFF9E9FBF),
                        fontSize: 11,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => budget != null
                          ? _showEditLimitDialog(
                              budget,
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

          // Items list
          if (bucket != null && bucket.items.isNotEmpty)
            _buildItemsList(bucket.items, color, budget!, category),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, Color color) {
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
        Text(
          label,
          style: const TextStyle(color: Color(0xFF4A4A6A), fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildItemsList(
    List<String> items,
    Color color,
    BudgetModel budget,
    BudgetCategory category,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
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
                  color: Colors.white.withOpacity(0.6),
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
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: items
                .map(
                  (item) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: color.withOpacity(0.2)),
                    ),
                    child: Text(
                      item,
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // DIALOGS
  // ─────────────────────────────────────────
  void _showEditAllowanceDialog(BudgetModel budget) {
    final ctrl = TextEditingController(
      text: budget.monthlyAllowance.toString(),
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E3A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Edit Monthly Allowance',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            prefixText: 'RM ',
            prefixStyle: const TextStyle(color: Color(0xFF6C63FF)),
            filled: true,
            fillColor: Colors.white.withOpacity(0.06),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF6C63FF)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF9E9FBF)),
            ),
          ),
          TextButton(
            onPressed: () async {
              final val = double.tryParse(ctrl.text);
              if (val != null && val > 0) {
                await _db.updateAllowance(_userId, val);
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text(
              'Save',
              style: TextStyle(
                color: Color(0xFF6C63FF),
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
    BudgetCategory category,
    String label,
    Color color,
    double currentLimit,
  ) {
    final ctrl = TextEditingController(text: currentLimit.toStringAsFixed(2));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E3A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Edit $label Limit',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            prefixText: 'RM ',
            prefixStyle: TextStyle(color: color),
            filled: true,
            fillColor: Colors.white.withOpacity(0.06),
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
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF9E9FBF)),
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
                await _db.updateBudgetLimits(
                  userId: _userId,
                  commitmentLimit: commitmentLimit,
                  spendingLimit: spendingLimit,
                  savingsLimit: savingsLimit,
                );
                if (ctx.mounted) Navigator.pop(ctx);
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
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E3A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Add Item',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'e.g. Netflix, Gym, PTPTN...',
            hintStyle: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 13,
            ),
            filled: true,
            fillColor: Colors.white.withOpacity(0.06),
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
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF9E9FBF)),
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
                await _db.updateBucketItems(
                  userId: _userId,
                  bucketField: bucketField,
                  items: newItems,
                );
                if (ctx.mounted) Navigator.pop(ctx);
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
