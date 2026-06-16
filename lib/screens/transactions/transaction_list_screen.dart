import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pocket_plan/core/services/database_service.dart';
import 'package:pocket_plan/models/transaction_model.dart';
import 'package:pocket_plan/widgets/shimmer_widgets.dart';
import 'package:pocket_plan/screens/transactions/edit_transaction_screen.dart';
import 'package:pocket_plan/core/services/export_service.dart';

class TransactionListScreen extends StatefulWidget {
  const TransactionListScreen({super.key});

  @override
  State<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends State<TransactionListScreen>
    with TickerProviderStateMixin {
  final DatabaseService _db = DatabaseService();
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  BudgetCategory? _filterCategory;
  late TabController _tabController;

  String get _userId => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<TransactionModel> _applyFilters(List<TransactionModel> all) {
    return all.where((tx) {
      final matchSearch =
          _searchQuery.isEmpty ||
          tx.description.toLowerCase().contains(_searchQuery) ||
          tx.category.toLowerCase().contains(_searchQuery);
      final matchType = _tabController.index == 0
          ? true
          : _tabController.index == 1
          ? tx.type == TransactionType.expense
          : tx.type == TransactionType.income;
      final matchCategory =
          _filterCategory == null || tx.budgetCategory == _filterCategory;
      return matchSearch && matchType && matchCategory;
    }).toList();
  }

  Map<String, List<TransactionModel>> _groupByDate(List<TransactionModel> txs) {
    final Map<String, List<TransactionModel>> grouped = {};
    for (final tx in txs) {
      final key = _dateKey(tx.date);
      grouped.putIfAbsent(key, () => []).add(tx);
    }
    return grouped;
  }

  String _dateKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final txDate = DateTime(date.year, date.month, date.day);
    if (txDate == today) return 'Today';
    if (txDate == yesterday) return 'Yesterday';
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
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
            _buildTabBar(),
            _buildFilterChips(),
            Expanded(
              child: StreamBuilder<List<TransactionModel>>(
                stream: _db.transactionsStream(_userId),
                builder: (context, snap) {
                  // ── Shimmer while loading ──
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: TransactionShimmer(),
                    );
                  }

                  final all = snap.data ?? [];
                  final filtered = _applyFilters(all);

                  if (filtered.isEmpty) {
                    return _buildEmptyState(all.isEmpty);
                  }

                  final grouped = _groupByDate(filtered);
                  final dateKeys = grouped.keys.toList();

                  // ── Pull to refresh ──
                  return RefreshIndicator(
                    color: const Color(0xFF6C63FF),
                    backgroundColor: const Color(0xFF1A1A2E),
                    onRefresh: () async {
                      // Firestore stream auto-updates,
                      // just add a small delay for UX feel
                      await Future.delayed(const Duration(milliseconds: 800));
                    },
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: dateKeys.length,
                      itemBuilder: (context, i) {
                        final dateKey = dateKeys[i];
                        final txs = grouped[dateKey]!;
                        final dayTotal = txs.fold<double>(
                          0,
                          (sum, tx) => tx.type == TransactionType.expense
                              ? sum - tx.amount
                              : sum + tx.amount,
                        );
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 16),
                            _buildDateHeader(dateKey, dayTotal),
                            const SizedBox(height: 8),
                            ...txs.map((tx) => _buildTransactionCard(tx)),
                          ],
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).pushNamed('/add-transaction'),
        backgroundColor: const Color(0xFF6C63FF),
        child: const Icon(Icons.add_rounded, color: Colors.white),
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
            'Transactions',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => _showExportDialog(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF6C63FF).withOpacity(0.3),
                ),
              ),
              child: const Icon(
                Icons.download_outlined,
                color: Color(0xFF6C63FF),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search transactions...',
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.3),
            fontSize: 14,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFF6C63FF),
            size: 20,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                  child: Icon(
                    Icons.close_rounded,
                    color: Colors.white.withOpacity(0.4),
                    size: 18,
                  ),
                )
              : null,
          filled: true,
          fillColor: Colors.white.withOpacity(0.06),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF6C63FF), width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
        ),
        child: TabBar(
          controller: _tabController,
          onTap: (_) => setState(() {}),
          indicator: BoxDecoration(
            color: const Color(0xFF6C63FF),
            borderRadius: BorderRadius.circular(10),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xFF4A4A6A),
          labelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          dividerColor: Colors.transparent,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Expenses'),
            Tab(text: 'Income'),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          _filterChip(
            'All',
            _filterCategory == null,
            () => setState(() => _filterCategory = null),
            Colors.white,
          ),
          const SizedBox(width: 8),
          _filterChip(
            'Commitments',
            _filterCategory == BudgetCategory.commitment,
            () => setState(
              () => _filterCategory == BudgetCategory.commitment
                  ? _filterCategory = null
                  : _filterCategory = BudgetCategory.commitment,
            ),
            const Color(0xFF6C63FF),
          ),
          const SizedBox(width: 8),
          _filterChip(
            'Spending',
            _filterCategory == BudgetCategory.spending,
            () => setState(
              () => _filterCategory == BudgetCategory.spending
                  ? _filterCategory = null
                  : _filterCategory = BudgetCategory.spending,
            ),
            const Color(0xFF00D4AA),
          ),
          const SizedBox(width: 8),
          _filterChip(
            'Savings',
            _filterCategory == BudgetCategory.savings,
            () => setState(
              () => _filterCategory == BudgetCategory.savings
                  ? _filterCategory = null
                  : _filterCategory = BudgetCategory.savings,
            ),
            const Color(0xFFFFB347),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(
    String label,
    bool selected,
    VoidCallback onTap,
    Color color,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? color.withOpacity(0.5)
                : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : const Color(0xFF4A4A6A),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildDateHeader(String dateKey, double dayTotal) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          dateKey,
          style: const TextStyle(
            color: Color(0xFF9E9FBF),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          '${dayTotal >= 0 ? '+' : ''}RM ${dayTotal.toStringAsFixed(2)}',
          style: TextStyle(
            color: dayTotal >= 0
                ? const Color(0xFF00D4AA)
                : const Color(0xFFFF6B6B),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ── Better empty states with EmptyStateWidget ──
  Widget _buildEmptyState(bool noTransactionsAtAll) {
    if (_searchQuery.isNotEmpty) {
      return EmptyStateWidget(
        emoji: '🔍',
        title: 'No results found',
        subtitle:
            'No transactions match "$_searchQuery".\nTry a different search term.',
        buttonLabel: 'Clear Search',
        onButtonTap: () {
          _searchController.clear();
          setState(() => _searchQuery = '');
        },
      );
    }

    if (_filterCategory != null) {
      return EmptyStateWidget(
        emoji: '📂',
        title: 'No transactions here',
        subtitle:
            'No transactions in this category yet.\nTry a different filter.',
        buttonLabel: 'Clear Filter',
        onButtonTap: () => setState(() => _filterCategory = null),
      );
    }

    if (_tabController.index == 1) {
      return EmptyStateWidget(
        emoji: '💸',
        title: 'No expenses yet',
        subtitle: 'Start tracking your spending\nby adding your first expense.',
        buttonLabel: 'Add Expense',
        onButtonTap: () => Navigator.of(
          context,
        ).pushNamed('/add-transaction', arguments: 'expense'),
      );
    }

    if (_tabController.index == 2) {
      return EmptyStateWidget(
        emoji: '💰',
        title: 'No income recorded',
        subtitle:
            'Add your allowance or salary\nto start tracking your income.',
        buttonLabel: 'Add Income',
        onButtonTap: () => Navigator.of(
          context,
        ).pushNamed('/add-transaction', arguments: 'income'),
      );
    }

    return EmptyStateWidget(
      emoji: '📊',
      title: 'No transactions yet',
      subtitle:
          'Start by adding your first transaction.\nTrack every ringgit you spend or earn.',
      buttonLabel: 'Add Transaction',
      onButtonTap: () => Navigator.of(context).pushNamed('/add-transaction'),
    );
  }

  Widget _buildTransactionCard(TransactionModel tx) {
    final isExpense = tx.type == TransactionType.expense;
    final categoryColor = _categoryColor(tx.budgetCategory);
    final categoryIcon = _categoryIcon(tx.category);

    return Dismissible(
      key: Key(tx.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFE53935).withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: Color(0xFFE53935),
          size: 24,
        ),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E3A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Delete Transaction',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: const Text(
              'Are you sure? This will update your budget.',
              style: TextStyle(color: Color(0xFF9E9FBF), fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Color(0xFF9E9FBF)),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Delete',
                  style: TextStyle(
                    color: Color(0xFFE53935),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) async {
        await _db.deleteTransaction(tx);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Transaction deleted'),
              backgroundColor: const Color(0xFFE53935),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      },
      child: Container(
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
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: categoryColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      tx.category,
                      style: TextStyle(
                        color: categoryColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
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
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${tx.date.day}/${tx.date.month}/${tx.date.year}',
                  style: const TextStyle(
                    color: Color(0xFF4A4A6A),
                    fontSize: 11,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => EditTransactionScreen(transaction: tx),
                    ),
                  ),
                  child: Icon(
                    Icons.edit_outlined,
                    color: const Color(0xFF4A4A6A),
                    size: 16,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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

  IconData _categoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'food & drinks':
        return Icons.restaurant_outlined;
      case 'shopping':
        return Icons.shopping_bag_outlined;
      case 'house / rent':
        return Icons.home_outlined;
      case 'car / transport':
        return Icons.directions_car_outlined;
      case 'bills & utilities':
        return Icons.receipt_outlined;
      case 'insurance':
        return Icons.shield_outlined;
      case 'education loan (ptptn)':
        return Icons.school_outlined;
      case 'entertainment':
        return Icons.movie_outlined;
      case 'health':
        return Icons.favorite_outline;
      case 'asb':
      case 'bank savings':
      case 'gold':
      case 'investment':
        return Icons.savings_outlined;
      case 'travel':
        return Icons.flight_outlined;
      case 'personal care':
        return Icons.face_outlined;
      default:
        return Icons.attach_money_rounded;
    }
  }

  void _showExportDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Export Transactions',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            _exportOption(
              icon: Icons.picture_as_pdf_outlined,
              label: 'Export as PDF',
              subtitle: 'Formatted report with summary',
              color: const Color(0xFFFF6B6B),
              onTap: () async {
                Navigator.pop(ctx);
                final snap = await _db.transactionsStream(_userId).first;
                await ExportService.exportToPDF(snap, 0);
              },
            ),
            const SizedBox(height: 12),
            _exportOption(
              icon: Icons.table_chart_outlined,
              label: 'Export as CSV',
              subtitle: 'Spreadsheet compatible format',
              color: const Color(0xFF00D4AA),
              onTap: () async {
                Navigator.pop(ctx);
                final snap = await _db.transactionsStream(_userId).first;
                await ExportService.exportToCSV(snap);
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _exportOption({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
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
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
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
            Icon(
              Icons.chevron_right_rounded,
              color: color.withOpacity(0.5),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
