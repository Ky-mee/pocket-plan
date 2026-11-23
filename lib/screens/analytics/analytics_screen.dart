import 'package:flutter/material.dart';
import 'package:pocket_plan/core/layout/desktop_shell.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pocket_plan/core/services/database_service.dart';
import 'package:pocket_plan/models/transaction_model.dart';
import 'package:pocket_plan/models/budget_model.dart';
import 'package:pocket_plan/core/services/fuzzy_spending_predictor.dart';
import 'package:pocket_plan/core/themes/app_colors.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with TickerProviderStateMixin {
  final DatabaseService _db = DatabaseService();
  late TabController _tabController;
  late AnimationController _entryController;
  late Animation<double> _fadeAnimation;

  String get _userId => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
    _tabController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              _buildHeader(),
              isDesktopLayout(context)
                  ? Align(
                      alignment: Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: _buildTabBar(),
                      ),
                    )
                  : _buildTabBar(),
              Expanded(
                child: StreamBuilder<List<TransactionModel>>(
                  stream: _db.transactionsStream(_userId),
                  builder: (context, txSnap) {
                    final transactions = txSnap.data ?? [];
                    return StreamBuilder<BudgetModel?>(
                      stream: _db.budgetStream(_userId),
                      builder: (context, budgetSnap) {
                        if (txSnap.hasError || budgetSnap.hasError) {
                          return _buildEmptyState(
                            'Unable to load analytics',
                            'Please check your connection and try again.',
                          );
                        }
                        final budget = budgetSnap.data;
                        return TabBarView(
                          controller: _tabController,
                          children: [
                            _buildOverviewTab(transactions),
                            _buildCategoryTab(transactions),
                            _buildPredictionTab(transactions, budget),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // HEADER
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
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.arrow_back_ios_new,
                color: context.colors.textPrimary,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'Analytics',
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: context.colors.accent,
            borderRadius: BorderRadius.circular(10),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          labelColor: Colors.white,
          unselectedLabelColor: context.colors.textTertiary,
          labelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          dividerColor: Colors.transparent,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Categories'),
            Tab(text: 'Prediction'),
          ],
        ),
      ),
    );
  }

  // OVERVIEW TAB
  Widget _buildOverviewTab(List<TransactionModel> transactions) {
    final expenses = transactions
        .where((t) => t.type == TransactionType.expense)
        .toList();
    final income = transactions
        .where((t) => t.type == TransactionType.income)
        .toList();

    final totalExpense = expenses.fold<double>(0, (s, t) => s + t.amount);
    final totalIncome = income.fold<double>(0, (s, t) => s + t.amount);
    final netSavings = totalIncome - totalExpense;

    final barData = _getLast7DaysData(transactions);

    if (isDesktopLayout(context)) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _summaryCard(
                    'Total Income',
                    'RM ${totalIncome.toStringAsFixed(2)}',
                    Icons.arrow_downward_rounded,
                    context.colors.success,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _summaryCard(
                    'Total Expense',
                    'RM ${totalExpense.toStringAsFixed(2)}',
                    Icons.arrow_upward_rounded,
                    context.colors.danger,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _summaryCard(
                    'Net Savings',
                    'RM ${netSavings.toStringAsFixed(2)}',
                    Icons.savings_outlined,
                    netSavings >= 0
                        ? context.colors.accent
                        : context.colors.danger,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildBarChart(barData)),
                const SizedBox(width: 16),
                Expanded(child: _buildMonthlyStats(transactions)),
              ],
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _summaryCard(
                  'Total Income',
                  'RM ${totalIncome.toStringAsFixed(2)}',
                  Icons.arrow_downward_rounded,
                  context.colors.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _summaryCard(
                  'Total Expense',
                  'RM ${totalExpense.toStringAsFixed(2)}',
                  Icons.arrow_upward_rounded,
                  context.colors.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _summaryCard(
            'Net Savings',
            'RM ${netSavings.toStringAsFixed(2)}',
            Icons.savings_outlined,
            netSavings >= 0 ? context.colors.accent : context.colors.danger,
          ),
          const SizedBox(height: 20),
          _buildBarChart(barData),
          const SizedBox(height: 20),
          _buildMonthlyStats(transactions),
        ],
      ),
    );
  }

  Widget _summaryCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart(List<Map<String, dynamic>> barData) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Last 7 Days',
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: Builder(
              builder: (context) {
                final maxBar = barData
                    .map((d) => (d['expense'] as double))
                    .fold(0.0, (a, b) => a > b ? a : b);
                return BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxBar > 0 ? maxBar * 1.3 : 100.0,
                    barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx >= 0 && idx < barData.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              barData[idx]['day'] as String,
                              style: TextStyle(
                                color: context.colors.textTertiary,
                                fontSize: 10,
                              ),
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) =>
                      FlLine(color: context.colors.border, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                    barGroups: barData.asMap().entries.map((e) {
                      final idx = e.key;
                      final data = e.value;
                      return BarChartGroupData(
                        x: idx,
                        barRods: [
                          BarChartRodData(
                            toY: data['expense'] as double,
                            color: context.colors.accent,
                            width: 20,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyStats(List<TransactionModel> transactions) {
    final now = DateTime.now();
    final thisMonth = transactions.where(
      (t) => t.date.month == now.month && t.date.year == now.year,
    );
    final lastMonthDate = DateTime(now.year, now.month - 1, 1);
    final lastMonth = transactions.where(
      (t) =>
          t.date.month == lastMonthDate.month &&
          t.date.year == lastMonthDate.year,
    );

    final thisTotal = thisMonth
        .where((t) => t.type == TransactionType.expense)
        .fold<double>(0, (s, t) => s + t.amount);
    final lastTotal = lastMonth
        .where((t) => t.type == TransactionType.expense)
        .fold<double>(0, (s, t) => s + t.amount);

    final diff = lastTotal > 0
        ? ((thisTotal - lastTotal) / lastTotal * 100)
        : 0.0;
    final isUp = diff > 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Month Comparison',
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This Month',
                      style: TextStyle(
                        color: context.colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'RM ${thisTotal.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isUp
                      ? context.colors.danger.withOpacity(0.15)
                      : context.colors.success.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      isUp
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      color: isUp
                          ? context.colors.danger
                          : context.colors.success,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${diff.abs().toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: isUp
                            ? context.colors.danger
                            : context.colors.success,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Last Month',
                      style: TextStyle(
                        color: context.colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'RM ${lastTotal.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: context.colors.textSecondary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
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

  // CATEGORY TAB
  Widget _buildCategoryTab(List<TransactionModel> transactions) {
    final expenses = transactions
        .where((t) => t.type == TransactionType.expense)
        .toList();

    final Map<String, double> categoryTotals = {};
    for (final tx in expenses) {
      categoryTotals[tx.category] =
          (categoryTotals[tx.category] ?? 0) + tx.amount;
    }

    final sorted = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final totalExpense = expenses.fold<double>(0, (s, t) => s + t.amount);

    if (sorted.isEmpty) {
      return _buildEmptyState(
        'No expense data yet',
        'Add transactions to see category breakdown',
      );
    }

    if (isDesktopLayout(context)) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: _buildCategoryPieChart(sorted, totalExpense),
            ),
            const SizedBox(width: 20),
            Expanded(
              flex: 3,
              child: Column(
                children: sorted
                    .map((e) => _buildCategoryRow(e.key, e.value, totalExpense))
                    .toList(),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      child: Column(
        children: [
          _buildCategoryPieChart(sorted, totalExpense),
          const SizedBox(height: 20),
          ...sorted.map((e) => _buildCategoryRow(e.key, e.value, totalExpense)),
        ],
      ),
    );
  }

  Widget _buildCategoryPieChart(
    List<MapEntry<String, double>> sorted,
    double total,
  ) {
    final colors = [
      context.colors.accent,
      context.colors.success,
      context.colors.warning,
      context.colors.danger,
      context.colors.info,
      const Color(0xFFCE93D8),
      const Color(0xFF80CBC4),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        children: [
          Text(
            'Spending by Category',
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: PieChart(
              PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 50,
                sections: sorted.asMap().entries.map((e) {
                  final color = colors[e.key % colors.length];
                  return PieChartSectionData(
                    value: e.value.value,
                    color: color,
                    radius: 30,
                    showTitle: false,
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryRow(String category, double amount, double total) {
    final pct = total > 0 ? (amount / total * 100) : 0.0;
    final colors = [
      context.colors.accent,
      context.colors.success,
      context.colors.warning,
      context.colors.danger,
      context.colors.info,
    ];
    final color = colors[category.hashCode.abs() % colors.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.label_outline_rounded,
                  color: color,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  category,
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'RM ${amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${pct.toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: context.colors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct / 100,
              backgroundColor: context.colors.border,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  // PREDICTION TAB (Fuzzy Logic)
  Widget _buildPredictionTab(
    List<TransactionModel> transactions,
    BudgetModel? budget,
  ) {
    final currentLimit = budget?.monthlyAllowance ?? 0.0;
    final nextMonth = FuzzySpendingPredictor.predictNextMonth(
      transactions: transactions,
      currentMonthLimit: currentLimit,
      commitmentLimit: budget?.commitments.limit,
      spendingLimit: budget?.spendings.limit,
      savingsLimit: budget?.savings.limit,
    );

    final sixMonths = FuzzySpendingPredictor.predictSixMonths(
      transactions: transactions,
      currentMonthLimit: currentLimit,
      commitmentLimit: budget?.commitments.limit,
      spendingLimit: budget?.spendings.limit,
      savingsLimit: budget?.savings.limit,
    );

    final hasData = transactions.any((t) => t.type == TransactionType.expense);

    if (isDesktopLayout(context)) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildNextMonthCard(nextMonth),
                  const SizedBox(height: 20),
                  if (hasData) ...[
                    _buildCategoryBreakdown(
                      nextMonth,
                      currentLimit,
                      budget: budget,
                    ),
                    const SizedBox(height: 20),
                  ],
                  _buildFuzzyExplainerCard(nextMonth),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '6-Month Spending Forecast',
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Powered by fuzzy logic inference',
                    style: TextStyle(
                      color: context.colors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSixMonthChart(sixMonths),
                  const SizedBox(height: 16),
                  ...sixMonths.asMap().entries.map(
                    (e) => _buildMonthForecastRow(e.key + 1, e.value),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildNextMonthCard(nextMonth),
          const SizedBox(height: 20),

          // ── Category breakdown ──
          if (hasData) ...[
            _buildCategoryBreakdown(nextMonth, currentLimit, budget: budget),
            const SizedBox(height: 20),
          ],

          // ── 6 month forecast ──
          Text(
            '6-Month Spending Forecast',
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Powered by fuzzy logic inference',
            style: TextStyle(color: context.colors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          _buildSixMonthChart(sixMonths),
          const SizedBox(height: 16),
          ...sixMonths.asMap().entries.map(
            (e) => _buildMonthForecastRow(e.key + 1, e.value),
          ),
          const SizedBox(height: 20),
          _buildFuzzyExplainerCard(nextMonth),
        ],
      ),
    );
  }

  Widget _buildNextMonthCard(FuzzyForecastResult result) {
    final isIncrease = result.adjustmentFactor > 0.02;
    final isDecrease = result.adjustmentFactor < -0.02;
    final color = isIncrease
        ? context.colors.danger
        : isDecrease
        ? context.colors.success
        : context.colors.accent;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_graph_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Next Month Forecast',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${result.confidenceScore.toStringAsFixed(0)}% confidence',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'RM ${result.predictedAmount.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${result.adjustmentFactor >= 0 ? '+' : ''}${(result.adjustmentFactor * 100).toStringAsFixed(1)}% vs. historical average',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _fuzzyTag('Trend: ${result.trendLabel}'),
              _fuzzyTag('Volatility: ${result.volatilityLabel}'),
              _fuzzyTag('Utilization: ${result.utilizationLabel}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _fuzzyTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // CATEGORY BREAKDOWN (per-bucket fuzzy forecast)
  // ═══════════════════════════════════════════════════════════
  Widget _buildCategoryBreakdown(
    FuzzyForecastResult result,
    double currentLimit, {
    BudgetModel? budget,
  }) {
    final commitmentLimit = budget?.commitments.limit ?? currentLimit * 0.5;
    final spendingLimit = budget?.spendings.limit ?? currentLimit * 0.3;
    final savingsLimit = budget?.savings.limit ?? currentLimit * 0.2;
    String pctLabel(double limit, String fallback) {
      if (currentLimit <= 0) return fallback;
      return '${(limit / currentLimit * 100).toStringAsFixed(0)}% of budget';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Predicted Spending by Category',
          style: TextStyle(
            color: context.colors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Fuzzy logic forecast per budget bucket',
          style: TextStyle(color: context.colors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 12),
        _categoryForecastCard(
          icon: Icons.home_outlined,
          label: 'Commitments',
          sublabel: pctLabel(commitmentLimit, '50% of budget'),
          predicted: result.predictedCommitments,
          limit: commitmentLimit,
          color: context.colors.accent,
        ),
        const SizedBox(height: 10),
        _categoryForecastCard(
          icon: Icons.shopping_bag_outlined,
          label: 'Spending',
          sublabel: pctLabel(spendingLimit, '30% of budget'),
          predicted: result.predictedSpending,
          limit: spendingLimit,
          color: context.colors.warning,
        ),
        const SizedBox(height: 10),
        _categoryForecastCard(
          icon: Icons.savings_outlined,
          label: 'Savings',
          sublabel: pctLabel(savingsLimit, '20% of budget'),
          predicted: result.predictedSavings,
          limit: savingsLimit,
          color: context.colors.success,
        ),
      ],
    );
  }

  Widget _categoryForecastCard({
    required IconData icon,
    required String label,
    required String sublabel,
    required double predicted,
    required double limit,
    required Color color,
  }) {
    final isOver = predicted > limit && limit > 0;
    final pct = limit > 0 ? (predicted / limit).clamp(0.0, 1.5) : 0.0;
    final diff = predicted - limit;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOver
              ? context.colors.danger.withOpacity(0.3)
              : context.colors.border,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      sublabel,
                      style: TextStyle(
                        color: context.colors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // ── Predicted amount ──
                  Text(
                    predicted > 0
                        ? 'RM ${predicted.toStringAsFixed(2)}'
                        : 'No data',
                    style: TextStyle(
                      color: isOver
                          ? context.colors.danger
                          : context.colors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  // ── Budget limit ──
                  if (limit > 0)
                    Text(
                      'of RM ${limit.toStringAsFixed(2)} limit',
                      style: TextStyle(
                        color: context.colors.textTertiary,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (limit > 0 && predicted > 0) ...[
            const SizedBox(height: 12),
            // ── Progress bar ──
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct.clamp(0.0, 1.0),
                backgroundColor: context.colors.border,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isOver ? context.colors.danger : color,
                ),
                minHeight: 5,
              ),
            ),
            const SizedBox(height: 8),
            // ── Status label ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isOver
                      ? '⚠️ Predicted to exceed by RM ${diff.toStringAsFixed(2)}'
                      : '✓ Within limit — RM ${diff.abs().toStringAsFixed(2)} to spare',
                  style: TextStyle(
                    color: isOver
                        ? context.colors.danger
                        : context.colors.success,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${(pct * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: isOver
                        ? context.colors.danger
                        : context.colors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSixMonthChart(List<FuzzyForecastResult> results) {
    final maxPredicted = results.isEmpty
        ? 0.0
        : results
              .map((r) => r.predictedAmount)
              .reduce((a, b) => a > b ? a : b);
    return Container(
      height: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxPredicted > 0 ? maxPredicted * 1.3 : 100.0,
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) => Text(
                  'M${value.toInt() + 1}',
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: results.asMap().entries.map((e) {
            final opacity = 1.0 - (e.key * 0.1);
            return BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: e.value.predictedAmount,
                  color: const Color(
                    0xFF6C63FF,
                  ).withOpacity(opacity.clamp(0.4, 1.0)),
                  width: 28,
                  borderRadius: BorderRadius.circular(6),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMonthForecastRow(int monthNum, FuzzyForecastResult result) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: context.colors.accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                'M$monthNum',
                style: TextStyle(
                  color: context.colors.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RM ${result.predictedAmount.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${result.trendLabel} • ${result.volatilityLabel} volatility',
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${result.confidenceScore.toStringAsFixed(0)}%',
            style: TextStyle(
              color: context.colors.textTertiary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFuzzyExplainerCard(FuzzyForecastResult result) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.accent.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lightbulb_outline_rounded,
            color: context.colors.accent,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'This forecast uses fuzzy logic to interpret your spending trend, volatility, and budget utilization as approximate linguistic terms (e.g. "Increasing", "High") rather than fixed numbers, producing a more human-like prediction than a simple average.',
              style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // HELPERS
  List<Map<String, dynamic>> _getLast7DaysData(
    List<TransactionModel> transactions,
  ) {
    final now = DateTime.now();
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final result = <Map<String, dynamic>>[];

    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final dayTx = transactions.where(
        (t) =>
            t.date.day == day.day &&
            t.date.month == day.month &&
            t.date.year == day.year &&
            t.type == TransactionType.expense,
      );
      final total = dayTx.fold<double>(0, (s, t) => s + t.amount);
      result.add({'day': days[day.weekday - 1], 'expense': total});
    }
    return result;
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bar_chart_rounded,
            size: 64,
            color: context.colors.textTertiary,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              color: context.colors.textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(color: context.colors.textTertiary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
