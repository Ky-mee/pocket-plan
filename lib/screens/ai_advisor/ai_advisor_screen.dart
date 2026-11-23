import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:pocket_plan/core/config/app_config.dart';
import 'package:pocket_plan/core/layout/desktop_shell.dart';
import 'package:pocket_plan/core/services/database_service.dart';
import 'package:pocket_plan/core/themes/app_colors.dart';
import 'package:pocket_plan/core/utils/budget_calculator.dart';
import 'package:pocket_plan/core/utils/currency_formatter.dart';
import 'package:pocket_plan/models/budget_model.dart';
import 'package:pocket_plan/models/transaction_model.dart';
import 'package:pocket_plan/models/user_model.dart';
import 'package:pocket_plan/providers/currency_provider.dart';
import 'package:pocket_plan/widgets/simple_markdown_text.dart';

class AiAdvisorScreen extends ConsumerStatefulWidget {
  const AiAdvisorScreen({super.key});

  @override
  ConsumerState<AiAdvisorScreen> createState() => _AiAdvisorScreenState();
}

class _AiAdvisorScreenState extends ConsumerState<AiAdvisorScreen>
    with TickerProviderStateMixin {
  final DatabaseService _db = DatabaseService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  BudgetModel? _budget;
  UserModel? _userModel;
  List<TransactionModel> _transactions = [];
  StreamSubscription<BudgetModel?>? _budgetSub;
  StreamSubscription<List<TransactionModel>>? _txSub;

  String get _proxyUrl => AppConfig.geminiProxyUrl;
  String get _userId => FirebaseAuth.instance.currentUser?.uid ?? '';

  final List<Map<String, String>> _suggestions = [
    {'icon': '🍜', 'text': 'Where can I find affordable meals nearby?'},
    {'icon': '📊', 'text': 'Analyze my spending this month'},
    {'icon': '💡', 'text': 'How can I lower my monthly essentials?'},
    {'icon': '🛒', 'text': 'Can I afford a major purchase right now?'},
    {'icon': '🛡️', 'text': 'How much should I keep in an emergency fund?'},
    {'icon': '📈', 'text': 'What are sensible ways to grow my savings?'},
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _addWelcomeMessage();
  }

  @override
  void dispose() {
    _budgetSub?.cancel();
    _txSub?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    if (_userId.isEmpty) return;
    _budgetSub = _db.budgetStream(_userId).listen((budget) {
      if (mounted) setState(() => _budget = budget);
    });
    _txSub = _db.transactionsStream(_userId).listen((txs) {
      if (mounted) setState(() => _transactions = txs);
    });
    final user = await _db.getUser(_userId);
    if (mounted && user != null) {
      setState(() => _userModel = user);
      await ref.read(currencyProvider.notifier).syncFromProfile(user.currency);
    }
  }

  void _addWelcomeMessage() {
    _messages.add(
      ChatMessage(
        text:
            'Hi! I\'m your PocketPlan AI Financial Advisor 👋\n\nI can help you with:\n• Analyzing your monthly spending habits\n• Planning essential needs & groceries\n• Evaluating purchases against your budget\n• Suggesting practical ways to build savings\n\nWhat would you like to plan today?',
        isUser: false,
        timestamp: DateTime.now(),
        hasAnimated: true,
        isWelcome: true,
      ),
    );
  }

  Map<String, dynamic> _buildFinancialContextPayload(String currency) {
    final allowance = _budget?.monthlyAllowance ?? 0.0;
    final spent = _budget?.totalSpent ?? 0.0;
    final remaining = allowance - spent;

    final currentMonth = BudgetCalculator.monthKey(DateTime.now());
    final Map<String, double> catTotals = {};
    for (final tx in _transactions) {
      if (tx.type != TransactionType.expense) continue;
      if (!BudgetCalculator.isInBudgetMonth(tx.date, currentMonth)) continue;
      catTotals[tx.category] = (catTotals[tx.category] ?? 0.0) + tx.amount;
    }
    final topCats = catTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return {
      'currency': currency,
      'lifeStage': _userModel?.lifeStage ?? 'general',
      'monthlyIncome': allowance,
      'totalSpent': spent,
      'remaining': remaining,
      'buckets': {
        'commitments': {
          'spent': _budget?.commitments.spent ?? 0.0,
          'limit': _budget?.commitments.limit ?? 0.0,
          'ratio': _budget?.commitmentRatio ?? 0.50,
        },
        'spendings': {
          'spent': _budget?.spendings.spent ?? 0.0,
          'limit': _budget?.spendings.limit ?? 0.0,
          'ratio': _budget?.spendingRatio ?? 0.30,
        },
        'savings': {
          'spent': _budget?.savings.spent ?? 0.0,
          'limit': _budget?.savings.limit ?? 0.0,
          'ratio': _budget?.savingsRatio ?? 0.20,
        },
      },
      'topCategories': topCats
          .take(6)
          .map((e) => {'category': e.key, 'amount': e.value})
          .toList(),
      'recentTransactions': _transactions
          .take(10)
          .map(
            (t) => {
              'type': t.type == TransactionType.income ? 'income' : 'expense',
              'category': t.category,
              'amount': t.amount,
              'description': t.description,
            },
          )
          .toList(),
    };
  }

  Future<void> _sendMessage(String text, String currency) async {
    if (text.trim().isEmpty) return;

    final userMessage = ChatMessage(
      text: text.trim(),
      isUser: true,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
    });

    _messageController.clear();
    _scrollToBottom();

    final conversationHistory = _messages
        .where((m) => !m.isTyping && !m.isWelcome && !m.isError)
        .map(
          (m) => {'role': m.isUser ? 'user' : 'assistant', 'content': m.text},
        )
        .toList();

    try {
      if (_proxyUrl.isEmpty) {
        _handleError(
          'AI Advisor is not configured. Please try again later.',
        );
        return;
      }

      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token == null) {
        _handleError('Please sign in again to use the AI advisor.');
        return;
      }
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };
      final uri = Uri.parse(_proxyUrl);

      final response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode({
          'contents': conversationHistory
              .map(
                (m) => {
                  'role': m['role'] == 'assistant' ? 'model' : 'user',
                  'parts': [
                    {'text': m['content']},
                  ],
                },
              )
              .toList(),
          'context': _buildFinancialContextPayload(currency),
          'generationConfig': {'maxOutputTokens': 1024},
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiText =
            data['candidates'][0]['content']['parts'][0]['text'] as String;
        setState(() {
          _messages.add(
            ChatMessage(text: aiText, isUser: false, timestamp: DateTime.now()),
          );
          _isLoading = false;
        });
      } else if (response.statusCode == 401) {
        _handleError('Session expired. Please sign in again.');
      } else if (response.statusCode == 429) {
        _handleError(
          'You have reached today\'s AI limit. Please try again tomorrow.',
        );
      } else {
        debugPrint('AI proxy error ${response.statusCode}: ${response.body}');
        _handleError(
          'Unable to reach AI Advisor right now. Please try again.',
        );
      }
    } catch (e) {
      debugPrint('AI advisor request failed: $e');
      _handleError(
        'Connection failed. Please check your internet and try again.',
      );
    }

    _scrollToBottom();
  }

  void _handleError(String msg) {
    setState(() {
      _messages.add(
        ChatMessage(
          text: '⚠️ $msg',
          isUser: false,
          timestamp: DateTime.now(),
          isError: true,
        ),
      );
      _isLoading = false;
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final currency = ref.watch(currencyProvider);
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isDesktopLayout(context) ? 900 : double.infinity,
            ),
            child: Column(
              children: [
                _buildHeader(),
                _buildFinancialContext(currency),
                Expanded(
                  child: _messages.length <= 1
                      ? _buildSuggestionsView(currency)
                      : _buildChatList(),
                ),
                if (_isLoading) _buildTypingIndicator(),
                _buildDisclaimerBar(),
                _buildInputBar(currency),
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
          const SizedBox(width: 12),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colors.accent, colors.accent.withOpacity(0.7)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.smart_toy_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Financial Advisor',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Powered by Google Gemini',
                  style: TextStyle(color: colors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                _messages.clear();
                _addWelcomeMessage();
              });
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.refresh_rounded,
                color: colors.textSecondary,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => Navigator.of(context).pushNamed('/nearby-places'),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colors.success.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.success.withOpacity(0.3)),
              ),
              child: Icon(
                Icons.location_on_outlined,
                color: colors.success,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialContext(String currency) {
    final colors = context.colors;
    final remaining =
        (_budget?.monthlyAllowance ?? 0) - (_budget?.totalSpent ?? 0);
    final isLow = remaining < ((_budget?.monthlyAllowance ?? 1) * 0.2);
    final formatted = CurrencyFormatter.format(remaining, code: currency);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isLow
            ? colors.danger.withOpacity(0.1)
            : colors.accent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLow
              ? colors.danger.withOpacity(0.3)
              : colors.accent.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isLow
                ? Icons.warning_amber_rounded
                : Icons.account_balance_wallet_outlined,
            color: isLow ? colors.danger : colors.accent,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isLow
                  ? 'Low balance! $formatted remaining this month'
                  : 'Balance: $formatted remaining this month',
              style: TextStyle(
                color: isLow ? colors.danger : colors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsView(String currency) {
    final colors = context.colors;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAIBubble(_messages.first),
          const SizedBox(height: 24),
          Text(
            'Quick questions',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.5,
              mainAxisExtent: isDesktopLayout(context) ? 64 : null,
            ),
            itemCount: _suggestions.length,
            itemBuilder: (context, i) {
              final s = _suggestions[i];
              return GestureDetector(
                onTap: () => _sendMessage(s['text']!, currency),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: colors.accent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.accent.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Text(s['icon']!, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          s['text']!,
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChatList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      itemCount: _messages.length,
      itemBuilder: (context, i) {
        final msg = _messages[i];
        return msg.isUser ? _buildUserBubble(msg) : _buildAIBubble(msg);
      },
    );
  }

  Widget _buildUserBubble(ChatMessage msg) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colors.accent, colors.accent.withOpacity(0.7)],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: Text(
                msg.text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colors.accent, colors.accent.withOpacity(0.7)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: Colors.white,
              size: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIBubble(ChatMessage msg) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: colors.accent.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.smart_toy_rounded,
              color: colors.accent,
              size: 14,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: msg.isError
                    ? colors.danger.withOpacity(0.1)
                    : colors.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
                border: Border.all(
                  color: msg.isError
                      ? colors.danger.withOpacity(0.3)
                      : colors.border,
                ),
              ),
              child: msg.isError
                  ? Text(
                      msg.text,
                      style: TextStyle(
                        color: colors.danger,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    )
                  : SimpleMarkdownText(
                      data: msg.text,
                      accentColor: colors.accent,
                      codeBackgroundColor: colors.surfaceAlt,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: colors.accent.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.smart_toy_rounded,
              color: colors.accent,
              size: 14,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dot(0),
                const SizedBox(width: 4),
                _dot(150),
                const SizedBox(width: 4),
                _dot(300),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot(int delayMs) {
    final colors = context.colors;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.accent,
            ),
          ),
        );
      },
    );
  }

  Widget _buildDisclaimerBar() {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 13, color: colors.textTertiary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'AI guidance is informational only and not licensed financial advice.',
              style: TextStyle(color: colors.textTertiary, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(String currency) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              style: TextStyle(color: colors.textPrimary, fontSize: 14),
              maxLines: 3,
              minLines: 1,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: 'Ask about your finances...',
                hintStyle: TextStyle(color: colors.textTertiary, fontSize: 14),
                filled: true,
                fillColor: colors.surfaceAlt,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: colors.accent, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _isLoading
                ? null
                : () => _sendMessage(_messageController.text, currency),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: _isLoading
                    ? null
                    : LinearGradient(
                        colors: [colors.accent, colors.accent.withOpacity(0.7)],
                      ),
                color: _isLoading ? colors.surfaceAlt : null,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.send_rounded,
                color: _isLoading ? colors.textTertiary : Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isError;
  final bool isTyping;
  final bool isWelcome;
  bool hasAnimated;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isError = false,
    this.isTyping = false,
    this.isWelcome = false,
    this.hasAnimated = false,
  });
}
