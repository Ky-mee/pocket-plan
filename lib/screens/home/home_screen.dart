import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pocket_plan/core/services/database_service.dart';
import 'package:pocket_plan/models/budget_model.dart';
import 'package:pocket_plan/models/transaction_model.dart';
import 'package:pocket_plan/core/services/budget_reset_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {
  final DatabaseService _db = DatabaseService();
  late AnimationController _entryController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  String get _userId => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeIn,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(
          CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic),
        );
    _entryController.forward();

    _checkBudgetReset(); // ← add this
  }

  Future<void> _checkBudgetReset() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await BudgetResetService().checkAndResetIfNewMonth(user.uid);
    }
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
          child: SlideTransition(
            position: _slideAnimation,
            child: StreamBuilder<BudgetModel?>(
              stream: _db.budgetStream(_userId),
              builder: (context, budgetSnap) {
                final budget = budgetSnap.data;
                return StreamBuilder<List<TransactionModel>>(
                  stream: _db.transactionsStream(_userId),
                  builder: (context, txSnap) {
                    final transactions = txSnap.data ?? [];
                    return CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: Column(
                            children: [
                              _buildTopBar(),
                              _buildBalanceCard(budget),
                              _buildBudgetRing(budget),
                              _buildQuickActions(),
                              _buildRecentTransactions(transactions),
                              const SizedBox(height: 100),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: _buildFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  // ─────────────────────────────────────────
  // TOP BAR
  // ─────────────────────────────────────────
  Widget _buildTopBar() {
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName?.split(' ').first ?? 'there';
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting,',
                style: const TextStyle(color: Color(0xFF9E9FBF), fontSize: 14),
              ),
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          Row(
            children: [
              // Notification bell
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.notifications_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              // Avatar
              GestureDetector(
                onTap: () => Navigator.of(context).pushNamed('/settings'),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6C63FF), Color(0xFF9C8DFF)],
                    ),
                  ),
                  child: Center(
                    child: Text(
                      (user?.displayName?.isNotEmpty == true)
                          ? user!.displayName![0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // BALANCE CARD
  // ─────────────────────────────────────────
  Widget _buildBalanceCard(BudgetModel? budget) {
    final allowance = budget?.monthlyAllowance ?? 0;
    final spent = budget?.totalSpent ?? 0;
    final remaining = allowance - spent;
    final progress = allowance > 0 ? (spent / allowance).clamp(0.0, 1.0) : 0.0;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
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
            color: const Color(0xFF6C63FF).withOpacity(0.4),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Monthly Balance',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _getCurrentMonth(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'RM ${remaining.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'of RM ${allowance.toStringAsFixed(2)} allowance',
            style: const TextStyle(color: Colors.white60, fontSize: 13),
          ),
          const SizedBox(height: 20),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(
                progress > 0.85 ? const Color(0xFFFF6B6B) : Colors.white,
              ),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Spent: RM ${spent.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
              Text(
                '${(progress * 100).toStringAsFixed(0)}% used',
                style: TextStyle(
                  color: progress > 0.85
                      ? const Color(0xFFFF6B6B)
                      : Colors.white60,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // BUDGET RING (50/30/20)
  // ─────────────────────────────────────────
  Widget _buildBudgetRing(BudgetModel? budget) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '50 / 30 / 20 Budget',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).pushNamed('/budget'),
                child: const Text(
                  'Manage',
                  style: TextStyle(
                    color: Color(0xFF6C63FF),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              // Donut chart
              SizedBox(
                width: 120,
                height: 120,
                child: budget == null
                    ? const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF6C63FF),
                        ),
                      )
                    : PieChart(
                        PieChartData(
                          sectionsSpace: 3,
                          centerSpaceRadius: 35,
                          sections: [
                            PieChartSectionData(
                              value: budget.commitments.limit,
                              color: const Color(0xFF6C63FF),
                              radius: 22,
                              showTitle: false,
                            ),
                            PieChartSectionData(
                              value: budget.spendings.limit,
                              color: const Color(0xFF00D4AA),
                              radius: 22,
                              showTitle: false,
                            ),
                            PieChartSectionData(
                              value: budget.savings.limit,
                              color: const Color(0xFFFFB347),
                              radius: 22,
                              showTitle: false,
                            ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(width: 20),
              // Legend
              Expanded(
                child: Column(
                  children: [
                    _budgetLegendRow(
                      label: 'Commitments',
                      percent: '50%',
                      spent: budget?.commitments.spent ?? 0,
                      limit: budget?.commitments.limit ?? 0,
                      color: const Color(0xFF6C63FF),
                      isExceeded: budget?.commitments.isExceeded ?? false,
                    ),
                    const SizedBox(height: 12),
                    _budgetLegendRow(
                      label: 'Spending',
                      percent: '30%',
                      spent: budget?.spendings.spent ?? 0,
                      limit: budget?.spendings.limit ?? 0,
                      color: const Color(0xFF00D4AA),
                      isExceeded: budget?.spendings.isExceeded ?? false,
                    ),
                    const SizedBox(height: 12),
                    _budgetLegendRow(
                      label: 'Savings',
                      percent: '20%',
                      spent: budget?.savings.spent ?? 0,
                      limit: budget?.savings.limit ?? 0,
                      color: const Color(0xFFFFB347),
                      isExceeded: false,
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

  Widget _budgetLegendRow({
    required String label,
    required String percent,
    required double spent,
    required double limit,
    required Color color,
    required bool isExceeded,
  }) {
    final progress = limit > 0 ? (spent / limit).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF9E9FBF),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                if (isExceeded)
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFFF6B6B),
                    size: 12,
                  ),
                Text(
                  'RM ${spent.toStringAsFixed(0)}/${limit.toStringAsFixed(0)}',
                  style: TextStyle(
                    color: isExceeded ? const Color(0xFFFF6B6B) : Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white.withOpacity(0.08),
            valueColor: AlwaysStoppedAnimation<Color>(
              isExceeded ? const Color(0xFFFF6B6B) : color,
            ),
            minHeight: 4,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────
  // QUICK ACTIONS
  // ─────────────────────────────────────────
  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _quickActionCard(
                icon: Icons.add_circle_outline_rounded,
                label: 'Add\nExpense',
                color: const Color(0xFFFF6B6B),
                onTap: () => Navigator.of(
                  context,
                ).pushNamed('/add-transaction', arguments: 'expense'),
              ),
              const SizedBox(width: 12),
              _quickActionCard(
                icon: Icons.arrow_downward_rounded,
                label: 'Add\nIncome',
                color: const Color(0xFF00D4AA),
                onTap: () => Navigator.of(
                  context,
                ).pushNamed('/add-transaction', arguments: 'income'),
              ),
              const SizedBox(width: 12),
              _quickActionCard(
                icon: Icons.bar_chart_rounded,
                label: 'Analytics',
                color: const Color(0xFFFFB347),
                onTap: () => Navigator.of(context).pushNamed('/analytics'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _quickActionCard(
                icon: Icons.smart_toy_outlined,
                label: 'AI\nAdvisor',
                color: const Color(0xFF6C63FF),
                onTap: () => Navigator.of(context).pushNamed('/ai-advisor'),
              ),
              const SizedBox(width: 12),
              _quickActionCard(
                icon: Icons.location_on_rounded,
                label: 'Food\nNearby',
                color: const Color(0xFF00D4AA),
                onTap: () => Navigator.of(context).pushNamed('/nearby-places'),
              ),
              const SizedBox(width: 12),
              Expanded(child: SizedBox()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quickActionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // RECENT TRANSACTIONS
  // ─────────────────────────────────────────
  Widget _buildRecentTransactions(List<TransactionModel> transactions) {
    final recent = transactions.take(5).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Transactions',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).pushNamed('/transactions'),
                child: const Text(
                  'See all',
                  style: TextStyle(
                    color: Color(0xFF6C63FF),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (recent.isEmpty)
            _buildEmptyTransactions()
          else
            ...recent.map((tx) => _transactionItem(tx)),
        ],
      ),
    );
  }

  Widget _buildEmptyTransactions() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 48,
            color: Colors.white.withOpacity(0.2),
          ),
          const SizedBox(height: 12),
          Text(
            'No transactions yet',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap + to add your first transaction',
            style: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _transactionItem(TransactionModel tx) {
    final isExpense = tx.type == TransactionType.expense;
    final categoryColor = _categoryColor(tx.budgetCategory);
    final categoryIcon = _categoryIcon(tx.budgetCategory);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: categoryColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(categoryIcon, color: categoryColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.description.isNotEmpty ? tx.description : tx.category,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  tx.category,
                  style: const TextStyle(
                    color: Color(0xFF9E9FBF),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isExpense ? '-' : '+'}RM ${tx.amount.toStringAsFixed(2)}',
                style: TextStyle(
                  color: isExpense
                      ? const Color(0xFFFF6B6B)
                      : const Color(0xFF00D4AA),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _formatDate(tx.date),
                style: const TextStyle(color: Color(0xFF9E9FBF), fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // BOTTOM NAV
  // ─────────────────────────────────────────
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: BottomAppBar(
        color: Colors.transparent,
        elevation: 0,
        notchMargin: 8,
        shape: const CircularNotchedRectangle(),
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(Icons.home_rounded, 'Home', true, () {}),
              _navItem(
                Icons.receipt_long_outlined,
                'History',
                false,
                () => Navigator.of(context).pushNamed('/transactions'),
              ),
              const SizedBox(width: 48), // FAB space
              _navItem(
                Icons.pie_chart_outline_rounded,
                'Budget',
                false,
                () => Navigator.of(context).pushNamed('/budget'),
              ),
              _navItem(
                Icons.settings_outlined,
                'Settings',
                false,
                () => Navigator.of(context).pushNamed('/settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(
    IconData icon,
    String label,
    bool active,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: active ? const Color(0xFF6C63FF) : const Color(0xFF4A4A6A),
            size: 22,
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: active ? const Color(0xFF6C63FF) : const Color(0xFF4A4A6A),
              fontSize: 10,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // FAB
  // ─────────────────────────────────────────
  Widget _buildFAB() {
    return FloatingActionButton(
      onPressed: () => Navigator.of(context).pushNamed('/add-transaction'),
      backgroundColor: const Color(0xFF6C63FF),
      elevation: 4,
      child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
    );
  }

  // ─────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────
  String _getCurrentMonth() {
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
    final now = DateTime.now();
    return '${months[now.month - 1]} ${now.year}';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${date.day}/${date.month}';
  }

  Color _categoryColor(BudgetCategory category) {
    switch (category) {
      case BudgetCategory.commitment:
        return const Color(0xFF6C63FF);
      case BudgetCategory.spending:
        return const Color(0xFF00D4AA);
      case BudgetCategory.savings:
        return const Color(0xFFFFB347);
    }
  }

  IconData _categoryIcon(BudgetCategory category) {
    switch (category) {
      case BudgetCategory.commitment:
        return Icons.home_outlined;
      case BudgetCategory.spending:
        return Icons.shopping_bag_outlined;
      case BudgetCategory.savings:
        return Icons.savings_outlined;
    }
  }
}
