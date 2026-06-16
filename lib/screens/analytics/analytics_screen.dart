import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pocket_plan/core/services/database_service.dart';
import 'package:pocket_plan/models/transaction_model.dart';
import 'package:pocket_plan/models/prediction_model.dart';

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
      backgroundColor: const Color(0xFF0F0F1A),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              _buildHeader(),
              _buildTabBar(),
              Expanded(
                child: StreamBuilder<List<TransactionModel>>(
                  stream: _db.transactionsStream(_userId),
                  builder: (context, snap) {
                    final transactions = snap.data ?? [];
                    return TabBarView(
                      controller: _tabController,
                      children: [
                        _buildOverviewTab(transactions),
                        _buildCategoryTab(transactions),
                        _buildPredictionTab(transactions),
                      ],
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

  // ─────────────────────────────────────────
  // HEADER
  // ─────────────────────────────────────────
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
            'Analytics',
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

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: const Color(0xFF6C63FF),
            borderRadius: BorderRadius.circular(10),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xFF4A4A6A),
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

  // ─────────────────────────────────────────
  // OVERVIEW TAB
  // ─────────────────────────────────────────
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

    // Group by day for bar chart (last 7 days)
    final barData = _getLast7DaysData(transactions);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      child: Column(
        children: [
          // Summary cards
          Row(
            children: [
              Expanded(
                child: _summaryCard(
                  'Total Income',
                  'RM ${totalIncome.toStringAsFixed(2)}',
                  Icons.arrow_downward_rounded,
                  const Color(0xFF00D4AA),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _summaryCard(
                  'Total Expense',
                  'RM ${totalExpense.toStringAsFixed(2)}',
                  Icons.arrow_upward_rounded,
                  const Color(0xFFFF6B6B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _summaryCard(
            'Net Savings',
            'RM ${netSavings.toStringAsFixed(2)}',
            Icons.savings_outlined,
            netSavings >= 0 ? const Color(0xFF6C63FF) : const Color(0xFFFF6B6B),
          ),
          const SizedBox(height: 20),

          // Bar chart - last 7 days
          _buildBarChart(barData),
          const SizedBox(height: 20),

          // Monthly comparison
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
                  style: const TextStyle(
                    color: Color(0xFF9E9FBF),
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
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Last 7 Days',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY:
                    barData
                        .map((d) => (d['expense'] as double))
                        .fold(0.0, (a, b) => a > b ? a : b) *
                    1.3,
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
                              style: const TextStyle(
                                color: Color(0xFF4A4A6A),
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
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.white.withOpacity(0.05),
                    strokeWidth: 1,
                  ),
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
                        color: const Color(0xFF6C63FF),
                        width: 20,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ],
                  );
                }).toList(),
              ),
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
    final lastMonth = transactions.where(
      (t) => t.date.month == now.month - 1 && t.date.year == now.year,
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
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Month Comparison',
            style: TextStyle(
              color: Colors.white,
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
                    const Text(
                      'This Month',
                      style: TextStyle(color: Color(0xFF9E9FBF), fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'RM ${thisTotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
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
                      ? const Color(0xFFFF6B6B).withOpacity(0.15)
                      : const Color(0xFF00D4AA).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      isUp
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      color: isUp
                          ? const Color(0xFFFF6B6B)
                          : const Color(0xFF00D4AA),
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${diff.abs().toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: isUp
                            ? const Color(0xFFFF6B6B)
                            : const Color(0xFF00D4AA),
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
                    const Text(
                      'Last Month',
                      style: TextStyle(color: Color(0xFF9E9FBF), fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'RM ${lastTotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Color(0xFF9E9FBF),
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

  // ─────────────────────────────────────────
  // CATEGORY TAB
  // ─────────────────────────────────────────
  Widget _buildCategoryTab(List<TransactionModel> transactions) {
    final expenses = transactions
        .where((t) => t.type == TransactionType.expense)
        .toList();

    // Group by category
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

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      child: Column(
        children: [
          // Pie chart
          _buildCategoryPieChart(sorted, totalExpense),
          const SizedBox(height: 20),
          // Category list
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
      const Color(0xFF6C63FF),
      const Color(0xFF00D4AA),
      const Color(0xFFFFB347),
      const Color(0xFFFF6B6B),
      const Color(0xFF4FC3F7),
      const Color(0xFFCE93D8),
      const Color(0xFF80CBC4),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          const Text(
            'Spending by Category',
            style: TextStyle(
              color: Colors.white,
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
      const Color(0xFF6C63FF),
      const Color(0xFF00D4AA),
      const Color(0xFFFFB347),
      const Color(0xFFFF6B6B),
      const Color(0xFF4FC3F7),
    ];
    final color = colors[category.hashCode.abs() % colors.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
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
                  style: const TextStyle(
                    color: Colors.white,
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
                    style: const TextStyle(
                      color: Color(0xFF9E9FBF),
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
              backgroundColor: Colors.white.withOpacity(0.06),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // PREDICTION TAB
  // ─────────────────────────────────────────
  Widget _buildPredictionTab(List<TransactionModel> transactions) {
    final expenses = transactions
        .where((t) => t.type == TransactionType.expense)
        .toList();

    // Get monthly totals for last 3 months
    final now = DateTime.now();
    final List<double> monthlyTotals = [];
    final List<String> monthLabels = [];

    for (int i = 3; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final monthTotal = expenses
          .where(
            (t) => t.date.month == month.month && t.date.year == month.year,
          )
          .fold<double>(0, (s, t) => s + t.amount);
      monthlyTotals.add(monthTotal);
      monthLabels.add(_monthLabel(month));
    }

    final historicalTotals = monthlyTotals.sublist(0, 3);
    final predicted = SpendingPredictor.movingAverage(historicalTotals);
    final confidence = SpendingPredictor.confidenceScore(historicalTotals);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      child: Column(
        children: [
          // Prediction card
          _buildPredictionCard(
            predicted,
            confidence.toDouble(),
            monthLabels.last,
          ),
          const SizedBox(height: 20),
          // Trend chart
          _buildTrendChart(monthlyTotals, monthLabels, predicted),
          const SizedBox(height: 20),
          // Tips
          _buildSpendingTips(predicted, historicalTotals),
        ],
      ),
    );
  }

  Widget _buildPredictionCard(
    double predicted,
    double confidence,
    String nextMonth,
  ) {
    final confidencePct = (confidence * 100).toStringAsFixed(0);
    return Container(
      padding: const EdgeInsets.all(24),
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
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_graph_rounded,
                color: Colors.white70,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'AI Spending Prediction',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$confidencePct% confidence',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'RM ${predicted.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Predicted spending for $nextMonth',
            style: const TextStyle(color: Colors.white60, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: Colors.white60,
                  size: 16,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Based on your last 3 months spending using moving average model.',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendChart(
    List<double> totals,
    List<String> labels,
    double predicted,
  ) {
    final allValues = [...totals, predicted];
    final maxY = allValues.fold(0.0, (a, b) => a > b ? a : b) * 1.3;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Spending Trend',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(width: 12, height: 3, color: const Color(0xFF6C63FF)),
              const SizedBox(width: 4),
              const Text(
                'Actual',
                style: TextStyle(color: Color(0xFF9E9FBF), fontSize: 11),
              ),
              const SizedBox(width: 12),
              Container(width: 12, height: 3, color: const Color(0xFFFFB347)),
              const SizedBox(width: 4),
              const Text(
                'Predicted',
                style: TextStyle(color: Color(0xFF9E9FBF), fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                maxY: maxY,
                minY: 0,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.white.withOpacity(0.05),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
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
                        if (idx >= 0 && idx < labels.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              labels[idx],
                              style: const TextStyle(
                                color: Color(0xFF4A4A6A),
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
                lineBarsData: [
                  // Actual line
                  LineChartBarData(
                    spots: totals
                        .asMap()
                        .entries
                        .map((e) => FlSpot(e.key.toDouble(), e.value))
                        .toList(),
                    isCurved: true,
                    color: const Color(0xFF6C63FF),
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, pct, bar, idx) =>
                          FlDotCirclePainter(
                            radius: 4,
                            color: const Color(0xFF6C63FF),
                            strokeWidth: 2,
                            strokeColor: const Color(0xFF0F0F1A),
                          ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF6C63FF).withOpacity(0.08),
                    ),
                  ),
                  // Predicted point
                  LineChartBarData(
                    spots: [
                      FlSpot(totals.length - 1, totals.last),
                      FlSpot(totals.length.toDouble(), predicted),
                    ],
                    isCurved: false,
                    color: const Color(0xFFFFB347),
                    barWidth: 2,
                    dashArray: [5, 5],
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, pct, bar, idx) =>
                          FlDotCirclePainter(
                            radius: idx == 1 ? 6 : 0,
                            color: const Color(0xFFFFB347),
                            strokeWidth: 2,
                            strokeColor: const Color(0xFF0F0F1A),
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpendingTips(double predicted, List<double> historicalTotals) {
    final avg = historicalTotals.isNotEmpty
        ? historicalTotals.fold(0.0, (a, b) => a + b) / historicalTotals.length
        : 0.0;
    final trend = avg > 0 ? (predicted - avg) / avg * 100 : 0.0;
    final isIncreasing = trend > 5;
    final isDecreasing = trend < -5;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Smart Insights',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _tipCard(
            icon: isIncreasing
                ? Icons.trending_up_rounded
                : isDecreasing
                ? Icons.trending_down_rounded
                : Icons.trending_flat_rounded,
            color: isIncreasing
                ? const Color(0xFFFF6B6B)
                : isDecreasing
                ? const Color(0xFF00D4AA)
                : const Color(0xFF6C63FF),
            title: isIncreasing
                ? 'Spending may increase'
                : isDecreasing
                ? 'Spending may decrease'
                : 'Spending is stable',
            body: isIncreasing
                ? 'Your predicted spending is ${trend.abs().toStringAsFixed(1)}% higher than your average. Consider reducing discretionary spending.'
                : isDecreasing
                ? 'Great job! Your predicted spending is ${trend.abs().toStringAsFixed(1)}% lower than average. Keep it up!'
                : 'Your spending pattern is consistent. Maintain your current budget habits.',
          ),
          const SizedBox(height: 12),
          _tipCard(
            icon: Icons.lightbulb_outline_rounded,
            color: const Color(0xFFFFB347),
            title: 'Budget tip',
            body:
                'Use the AI Financial Advisor to get personalized advice on reducing your expenses and growing your savings.',
          ),
        ],
      ),
    );
  }

  Widget _tipCard({
    required IconData icon,
    required Color color,
    required String title,
    required String body,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    color: Color(0xFF9E9FBF),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────
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

  String _monthLabel(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[date.month - 1];
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bar_chart_rounded,
            size: 64,
            color: Colors.white.withOpacity(0.15),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withOpacity(0.25),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
