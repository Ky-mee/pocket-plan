import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocket_plan/core/layout/desktop_shell.dart';
import 'package:pocket_plan/core/services/budget_reset_service.dart';
import 'package:pocket_plan/core/services/database_service.dart';
import 'package:pocket_plan/core/services/recurring_service.dart';
import 'package:pocket_plan/core/themes/app_colors.dart';
import 'package:pocket_plan/core/utils/budget_cycle.dart';
import 'package:pocket_plan/core/utils/currency_formatter.dart';
import 'package:pocket_plan/models/budget_model.dart';
import 'package:pocket_plan/models/transaction_model.dart';
import 'package:pocket_plan/providers/currency_provider.dart';
import 'package:pocket_plan/widgets/shimmer_widgets.dart';

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

    _checkBudgetReset();
    _syncCurrencyFromProfile();
  }

  Future<void> _syncCurrencyFromProfile() async {
    if (_userId.isEmpty) return;
    final user = await _db.getUser(_userId);
    if (mounted && user != null) {
      await ref.read(currencyProvider.notifier).syncFromProfile(user.currency);
    }
  }

  Future<void> _checkBudgetReset() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final prefs = await _db.getPreferences(user.uid);
      final carryForward = prefs['carryForwardEnabled'] ?? true;
      await BudgetResetService().checkAndResetIfNewMonth(
        user.uid,
        carryForwardEnabled: carryForward,
      );
      try {
        final posted = await RecurringService().processDueRecurring(user.uid);
        if (posted > 0 && mounted) {
          final colors = context.colors;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Auto-logged $posted recurring item${posted == 1 ? '' : 's'} for this cycle.',
              ),
              backgroundColor: colors.success,
            ),
          );
        }
      } catch (_) {
        // Non-blocking: recurring auto-sync also runs from RecurringScreen.
      }
    }
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
          child: SlideTransition(
            position: _slideAnimation,
            child: StreamBuilder<BudgetModel?>(
              stream: _db.budgetStream(_userId),
              builder: (context, budgetSnap) {
                if (budgetSnap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Unable to load your budget. Please check your connection.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colors.textSecondary),
                      ),
                    ),
                  );
                }
                if (budgetSnap.connectionState == ConnectionState.waiting &&
                    !budgetSnap.hasData) {
                  return isDesktopLayout(context)
                      ? Center(
                          child: CircularProgressIndicator(
                            color: colors.accent,
                          ),
                        )
                      : const HomeShimmer();
                }
                final budget = budgetSnap.data;
                return StreamBuilder<List<TransactionModel>>(
                  stream: _db.transactionsStream(_userId),
                  builder: (context, txSnap) {
                    final transactions = txSnap.data ?? [];
                    if (isDesktopLayout(context)) {
                      return SingleChildScrollView(
                        child: _buildDesktopBody(
                          budget,
                          transactions,
                          currency,
                        ),
                      );
                    }
                    return CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: Column(
                            children: [
                              _buildTopBar(budget, currency),
                              _buildBalanceCard(budget, currency),
                              _buildBudgetRing(budget, currency),
                              _buildQuickActions(),
                              if (txSnap.hasError)
                                Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Text(
                                    'Unable to load recent transactions.',
                                    style: TextStyle(
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                )
                              else
                                _buildRecentTransactions(
                                  transactions,
                                  currency,
                                ),
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
      bottomNavigationBar: isDesktopLayout(context) ? null : _buildBottomNav(),
      floatingActionButton: isDesktopLayout(context) ? null : _buildFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildDesktopBody(
    BudgetModel? budget,
    List<TransactionModel> transactions,
    String currency,
  ) {
    return Column(
      children: [
        _buildTopBar(budget, currency),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: _buildBalanceCard(budget, currency)),
            Expanded(flex: 2, child: _buildBudgetRing(budget, currency)),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: _buildRecentTransactions(transactions, currency),
            ),
            Expanded(flex: 2, child: _buildQuickActions()),
          ],
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  bool _hasBudgetAlerts(BudgetModel? budget) {
    if (budget == null) return false;
    return budget.isAnyExceeded ||
        budget.commitments.percentageUsed >= 80 ||
        budget.spendings.percentageUsed >= 80;
  }

  Widget _buildTopBar(BudgetModel? budget, String currency) {
    final colors = context.colors;
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName?.split(' ').first ?? 'there';
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';
    final hasAlert = _hasBudgetAlerts(budget);

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
                style: TextStyle(color: colors.textSecondary, fontSize: 14),
              ),
              Text(
                name,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          Row(
            children: [
              GestureDetector(
                onTap: () => _showBudgetAlertsSheet(budget, currency),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.notifications_outlined,
                        color: colors.textPrimary,
                        size: 20,
                      ),
                    ),
                    if (hasAlert)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: colors.danger,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => Navigator.of(context).pushNamed('/settings'),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      colors: [colors.accent, colors.accent.withOpacity(0.7)],
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

  Widget _buildBalanceCard(BudgetModel? budget, String currency) {
    final colors = context.colors;
    final allowance = budget?.monthlyAllowance ?? 0;
    final spent = budget?.totalSpent ?? 0;
    final remaining = allowance - spent;
    final progress = allowance > 0 ? (spent / allowance).clamp(0.0, 1.0) : 0.0;

    final cycle = BudgetCycle.forDate(
      DateTime.now(),
      startDay: budget?.budgetStartDay ?? 1,
    );
    final daysLeft = cycle.daysRemaining(DateTime.now());
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.accent, const Color(0xFF4834D4)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colors.accent.withOpacity(0.4),
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
                  cycle.formatLabel(),
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
            CurrencyFormatter.format(remaining, code: currency),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'of ${CurrencyFormatter.format(allowance, code: currency)} monthly income',
            style: const TextStyle(color: Colors.white60, fontSize: 13),
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(
                progress > 0.85 ? colors.danger : Colors.white,
              ),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Spent: ${CurrencyFormatter.format(spent, code: currency)}',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
              Text(
                '${(progress * 100).toStringAsFixed(0)}% used · ${daysLeft}d left',
                style: TextStyle(
                  color: progress > 0.85 ? colors.danger : Colors.white60,
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

  Widget _buildBudgetRing(BudgetModel? budget, String currency) {
    final colors = context.colors;
    final cPct = ((budget?.commitmentRatio ?? 0.50) * 100).round();
    final spPct = ((budget?.spendingRatio ?? 0.30) * 100).round();
    final svPct = ((budget?.savingsRatio ?? 0.20) * 100).round();

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Budget Split ($cPct/$spPct/$svPct)',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).pushNamed('/budget'),
                child: Text(
                  'Manage',
                  style: TextStyle(
                    color: colors.accent,
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
              SizedBox(
                width: 120,
                height: 120,
                child: budget == null
                    ? Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.accent,
                        ),
                      )
                    : PieChart(
                        PieChartData(
                          sectionsSpace: 3,
                          centerSpaceRadius: 35,
                          sections: [
                            PieChartSectionData(
                              value: budget.commitments.limit,
                              color: colors.accent,
                              radius: 22,
                              showTitle: false,
                            ),
                            PieChartSectionData(
                              value: budget.spendings.limit,
                              color: colors.success,
                              radius: 22,
                              showTitle: false,
                            ),
                            PieChartSectionData(
                              value: budget.savings.limit,
                              color: colors.warning,
                              radius: 22,
                              showTitle: false,
                            ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  children: [
                    _budgetLegendRow(
                      label: 'Essential Needs',
                      currency: currency,
                      spent: budget?.commitments.spent ?? 0,
                      limit: budget?.commitments.limit ?? 0,
                      color: colors.accent,
                      isExceeded: budget?.commitments.isExceeded ?? false,
                    ),
                    const SizedBox(height: 12),
                    _budgetLegendRow(
                      label: 'Lifestyle',
                      currency: currency,
                      spent: budget?.spendings.spent ?? 0,
                      limit: budget?.spendings.limit ?? 0,
                      color: colors.success,
                      isExceeded: budget?.spendings.isExceeded ?? false,
                    ),
                    const SizedBox(height: 12),
                    _budgetLegendRow(
                      label: 'Savings',
                      currency: currency,
                      spent: budget?.savings.spent ?? 0,
                      limit: budget?.savings.limit ?? 0,
                      color: colors.warning,
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
    required String currency,
    required double spent,
    required double limit,
    required Color color,
    required bool isExceeded,
  }) {
    final colors = context.colors;
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
                  style: TextStyle(color: colors.textSecondary, fontSize: 12),
                ),
              ],
            ),
            Row(
              children: [
                if (isExceeded)
                  Icon(
                    Icons.warning_amber_rounded,
                    color: colors.danger,
                    size: 12,
                  ),
                Text(
                  '${CurrencyFormatter.format(spent, code: currency, decimals: 0)}/${CurrencyFormatter.format(limit, code: currency, decimals: 0)}',
                  style: TextStyle(
                    color: isExceeded ? colors.danger : colors.textPrimary,
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
            backgroundColor: colors.border,
            valueColor: AlwaysStoppedAnimation<Color>(
              isExceeded ? colors.danger : color,
            ),
            minHeight: 4,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: TextStyle(
              color: colors.textPrimary,
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
                color: colors.danger,
                onTap: () => Navigator.of(
                  context,
                ).pushNamed('/add-transaction', arguments: 'expense'),
              ),
              const SizedBox(width: 12),
              _quickActionCard(
                icon: Icons.arrow_downward_rounded,
                label: 'Add\nIncome',
                color: colors.success,
                onTap: () => Navigator.of(
                  context,
                ).pushNamed('/add-transaction', arguments: 'income'),
              ),
              const SizedBox(width: 12),
              _quickActionCard(
                icon: Icons.bar_chart_rounded,
                label: 'Analytics',
                color: colors.warning,
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
                color: colors.accent,
                onTap: () => Navigator.of(context).pushNamed('/ai-advisor'),
              ),
              const SizedBox(width: 12),
              _quickActionCard(
                icon: Icons.location_on_rounded,
                label: 'Food\nNearby',
                color: colors.success,
                onTap: () => Navigator.of(context).pushNamed('/nearby-places'),
              ),
              const SizedBox(width: 12),
              _quickActionCard(
                icon: Icons.repeat_rounded,
                label: 'Recurring\nBills',
                color: colors.info,
                onTap: () => Navigator.of(context).pushNamed('/recurring'),
              ),
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

  Widget _buildRecentTransactions(
    List<TransactionModel> transactions,
    String currency,
  ) {
    final colors = context.colors;
    final recent = transactions.take(5).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Transactions',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).pushNamed('/transactions'),
                child: Text(
                  'See all',
                  style: TextStyle(
                    color: colors.accent,
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
            ...recent.map((tx) => _transactionItem(tx, currency)),
        ],
      ),
    );
  }

  Widget _buildEmptyTransactions() {
    final colors = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 48,
            color: colors.textTertiary,
          ),
          const SizedBox(height: 12),
          Text(
            'No transactions yet',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap + to add your first transaction',
            style: TextStyle(color: colors.textTertiary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _transactionItem(TransactionModel tx, String currency) {
    final colors = context.colors;
    final isExpense = tx.type == TransactionType.expense;
    final categoryColor = _categoryColor(tx.budgetCategory);
    final categoryIcon = _categoryIcon(tx.budgetCategory);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
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
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  tx.category,
                  style: TextStyle(color: colors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                CurrencyFormatter.signed(
                  tx.amount,
                  isExpense: isExpense,
                  code: currency,
                ),
                style: TextStyle(
                  color: isExpense ? colors.danger : colors.success,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _formatDate(tx.date),
                style: TextStyle(color: colors.textSecondary, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border)),
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
              const SizedBox(width: 48),
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
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: active ? colors.accent : colors.textTertiary,
            size: 22,
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: active ? colors.accent : colors.textTertiary,
              fontSize: 10,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAB() {
    final colors = context.colors;
    return FloatingActionButton(
      onPressed: () => Navigator.of(context).pushNamed('/add-transaction'),
      backgroundColor: colors.accent,
      elevation: 4,
      child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
    );
  }

  void _showBudgetAlertsSheet(BudgetModel? budget, String currency) {
    final colors = context.colors;
    final alerts = <(String, String, Color)>[];
    if (budget != null) {
      void checkBucket(String name, BucketData b) {
        if (b.isExceeded) {
          alerts.add((
            '$name Budget Exceeded',
            'Spent ${CurrencyFormatter.format(b.spent, code: currency)} of ${CurrencyFormatter.format(b.limit, code: currency)}.',
            colors.danger,
          ));
        } else if (b.percentageUsed >= 80) {
          alerts.add((
            '$name at ${b.percentageUsed.toStringAsFixed(0)}%',
            '${CurrencyFormatter.format(b.remaining, code: currency)} remaining this month.',
            colors.warning,
          ));
        }
      }

      checkBucket('Essential Needs', budget.commitments);
      checkBucket('Lifestyle', budget.spendings);
      if (budget.savings.isExceeded) {
        alerts.add((
          'Savings Target Exceeded',
          'Recorded ${CurrencyFormatter.format(budget.savings.spent, code: currency)} vs ${CurrencyFormatter.format(budget.savings.limit, code: currency)}.',
          colors.warning,
        ));
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Budget Alerts',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.of(context).pushNamed('/settings');
                  },
                  child: Text(
                    'Preferences',
                    style: TextStyle(color: colors.accent),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (alerts.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.success.withOpacity(0.25)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      color: colors.success,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'All clear! Your spending is on track this month.',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              ...alerts.map(
                (a) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: a.$3.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: a.$3.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: a.$3, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              a.$1,
                              style: TextStyle(
                                color: a.$3,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              a.$2,
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${date.day}/${date.month}';
  }

  Color _categoryColor(BudgetCategory category) {
    final colors = context.colors;
    switch (category) {
      case BudgetCategory.commitment:
        return colors.accent;
      case BudgetCategory.spending:
        return colors.success;
      case BudgetCategory.savings:
        return colors.warning;
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
