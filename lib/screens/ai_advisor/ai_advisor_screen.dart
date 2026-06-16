import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:pocket_plan/core/services/database_service.dart';
import 'package:pocket_plan/models/budget_model.dart';
import 'package:pocket_plan/models/transaction_model.dart';

class AiAdvisorScreen extends StatefulWidget {
  const AiAdvisorScreen({super.key});

  @override
  State<AiAdvisorScreen> createState() => _AiAdvisorScreenState();
}

class _AiAdvisorScreenState extends State<AiAdvisorScreen>
    with TickerProviderStateMixin {
  final DatabaseService _db = DatabaseService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  BudgetModel? _budget;
  List<TransactionModel> _transactions = [];

  // ── Replace with your actual Gemini API key ──
  static String get _apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

  String get _userId => FirebaseAuth.instance.currentUser?.uid ?? '';

  // Quick suggestion prompts
  final List<Map<String, String>> _suggestions = [
    {'icon': '🍜', 'text': 'Where can I eat affordably nearby?'},
    {'icon': '📊', 'text': 'Analyze my spending this month'},
    {'icon': '💰', 'text': 'How can I save more money?'},
    {'icon': '🛒', 'text': 'Is it worth buying a new phone now?'},
    {'icon': '🚗', 'text': 'Can I afford a car with my budget?'},
    {'icon': '📈', 'text': 'Best investment options for students?'},
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _addWelcomeMessage();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    _db.budgetStream(_userId).listen((budget) {
      if (mounted) setState(() => _budget = budget);
    });
    _db.transactionsStream(_userId).listen((txs) {
      if (mounted) setState(() => _transactions = txs);
    });
  }

  void _addWelcomeMessage() {
    _messages.add(
      ChatMessage(
        text:
            'Hi! I\'m your PocketPlan AI Financial Advisor 👋\n\nI can help you with:\n• Analyzing your spending habits\n• Finding affordable places to eat nearby\n• Advising on purchases and investments\n• Suggesting ways to save more\n\nWhat would you like to know today?',
        isUser: false,
        timestamp: DateTime.now(),
        hasAnimated: true,
      ),
    );
  }

  String _buildSystemPrompt() {
    final allowance = _budget?.monthlyAllowance ?? 0;
    final spent = _budget?.totalSpent ?? 0;
    final remaining = allowance - spent;
    final commitmentSpent = _budget?.commitments.spent ?? 0;
    final commitmentLimit = _budget?.commitments.limit ?? 0;
    final spendingSpent = _budget?.spendings.spent ?? 0;
    final spendingLimit = _budget?.spendings.limit ?? 0;
    final savingsSpent = _budget?.savings.spent ?? 0;
    final savingsLimit = _budget?.savings.limit ?? 0;

    // Get recent transactions summary
    final recentTx = _transactions
        .take(10)
        .map(
          (t) =>
              '${t.type == TransactionType.expense ? '-' : '+'}RM${t.amount.toStringAsFixed(2)} on ${t.category} (${t.description})',
        )
        .join(', ');

    return '''You are PocketPlan AI, a friendly and practical financial advisor for Malaysian university students. You speak in a friendly, conversational tone and give specific, actionable advice.

USER'S FINANCIAL SNAPSHOT:
- Monthly allowance: RM${allowance.toStringAsFixed(2)}
- Total spent this month: RM${spent.toStringAsFixed(2)}
- Remaining balance: RM${remaining.toStringAsFixed(2)}
- Commitments: RM${commitmentSpent.toStringAsFixed(2)} / RM${commitmentLimit.toStringAsFixed(2)}
- Spending: RM${spendingSpent.toStringAsFixed(2)} / RM${spendingLimit.toStringAsFixed(2)}
- Savings: RM${savingsSpent.toStringAsFixed(2)} / RM${savingsLimit.toStringAsFixed(2)}
- Recent transactions: $recentTx

GUIDELINES:
1. Always consider the user's actual financial data when giving advice
2. Be specific — give real RM amounts, not vague suggestions
3. For food questions, suggest affordable Malaysian options (mamak, food courts, pasar malam) with estimated prices
4. For purchase decisions, calculate if they can afford it based on remaining budget
5. For investments, suggest beginner-friendly Malaysian options (ASB, Tabung Haji, EPF, unit trust)
6. If budget is tight, be honest but encouraging
7. Keep responses concise — 2-4 short paragraphs maximum
8. Use emojis sparingly for friendliness
9. Always end with a practical next step or tip''';
  }

  Future<void> _sendMessage(String text) async {
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
        .where((m) => !m.isTyping)
        .map(
          (m) => {'role': m.isUser ? 'user' : 'assistant', 'content': m.text},
        )
        .toList();

    try {
      final response = await http.post(
        Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$_apiKey',
        ),
        headers: {'Content-Type': 'application/json'},
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
          'systemInstruction': {
            'parts': [
              {'text': _buildSystemPrompt()},
            ],
          },
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
      } else {
        _handleError('Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('ERROR: $e');
      _handleError('Error: $e');
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
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildFinancialContext(),
            Expanded(
              child: _messages.length <= 1
                  ? _buildSuggestionsView()
                  : _buildChatList(),
            ),
            if (_isLoading) _buildTypingIndicator(),
            _buildInputBar(),
          ],
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
          const SizedBox(width: 12),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFF9C8DFF)],
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
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Financial Advisor',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Powered by Google Gemini',
                  style: TextStyle(color: Color(0xFF9E9FBF), fontSize: 11),
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
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.refresh_rounded,
                color: Color(0xFF9E9FBF),
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // NEW — location button (add this)
          GestureDetector(
            onTap: () => Navigator.of(context).pushNamed('/nearby-places'),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF00D4AA).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF00D4AA).withOpacity(0.3),
                ),
              ),
              child: const Icon(
                Icons.location_on_outlined,
                color: Color(0xFF00D4AA),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // FINANCIAL CONTEXT BANNER
  // ─────────────────────────────────────────
  Widget _buildFinancialContext() {
    final remaining =
        (_budget?.monthlyAllowance ?? 0) - (_budget?.totalSpent ?? 0);
    final isLow = remaining < ((_budget?.monthlyAllowance ?? 1) * 0.2);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isLow
            ? const Color(0xFFFF6B6B).withOpacity(0.1)
            : const Color(0xFF6C63FF).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLow
              ? const Color(0xFFFF6B6B).withOpacity(0.3)
              : const Color(0xFF6C63FF).withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isLow
                ? Icons.warning_amber_rounded
                : Icons.account_balance_wallet_outlined,
            color: isLow ? const Color(0xFFFF6B6B) : const Color(0xFF6C63FF),
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            isLow
                ? 'Low balance! RM${remaining.toStringAsFixed(2)} remaining'
                : 'Balance: RM${remaining.toStringAsFixed(2)} remaining this month',
            style: TextStyle(
              color: isLow ? const Color(0xFFFF6B6B) : const Color(0xFF9E9FBF),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // SUGGESTIONS VIEW
  // ─────────────────────────────────────────
  Widget _buildSuggestionsView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome message
          _buildAIBubble(_messages.first),
          const SizedBox(height: 24),
          const Text(
            'Quick questions',
            style: TextStyle(
              color: Color(0xFF9E9FBF),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.5,
            ),
            itemCount: _suggestions.length,
            itemBuilder: (context, i) {
              final s = _suggestions[i];
              return GestureDetector(
                onTap: () => _sendMessage(s['text']!),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C63FF).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF6C63FF).withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(s['icon']!, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          s['text']!,
                          style: const TextStyle(
                            color: Color(0xFF9E9FBF),
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

  // ─────────────────────────────────────────
  // CHAT LIST
  // ─────────────────────────────────────────
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF9C8DFF)],
                ),
                borderRadius: BorderRadius.only(
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
              gradient: const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFF9C8DFF)],
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
              color: const Color(0xFF6C63FF).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.smart_toy_rounded,
              color: Color(0xFF6C63FF),
              size: 14,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: msg.isError
                    ? const Color(0xFFFF6B6B).withOpacity(0.1)
                    : const Color(0xFF1A1A2E),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
                border: Border.all(
                  color: msg.isError
                      ? const Color(0xFFFF6B6B).withOpacity(0.3)
                      : Colors.white.withOpacity(0.06),
                ),
              ),
              child: msg.isError || msg.hasAnimated
                  ? Text(
                      msg.text,
                      style: TextStyle(
                        color: msg.isError
                            ? const Color(0xFFFF6B6B)
                            : Colors.white,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    )
                  : TypewriterText(
                      text: msg.text,
                      style: const TextStyle(
                        color: Colors.white,
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

  // ─────────────────────────────────────────
  // TYPING INDICATOR
  // ─────────────────────────────────────────
  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.smart_toy_rounded,
              color: Color(0xFF6C63FF),
              size: 14,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
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
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF6C63FF),
            ),
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────
  // INPUT BAR
  // ─────────────────────────────────────────
  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              maxLines: 3,
              minLines: 1,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: 'Ask about your finances...',
                hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 14,
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.06),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: Color(0xFF6C63FF),
                    width: 1.5,
                  ),
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
                : () => _sendMessage(_messageController.text),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: _isLoading
                    ? null
                    : const LinearGradient(
                        colors: [Color(0xFF6C63FF), Color(0xFF9C8DFF)],
                      ),
                color: _isLoading ? Colors.white.withOpacity(0.06) : null,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.send_rounded,
                color: _isLoading
                    ? Colors.white.withOpacity(0.3)
                    : Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// CHAT MESSAGE MODEL
// ─────────────────────────────────────────
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isError;
  final bool isTyping;
  bool hasAnimated;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isError = false,
    this.isTyping = false,
    this.hasAnimated = false,
  });
}

class TypewriterText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration speed;

  const TypewriterText({
    super.key,
    required this.text,
    this.style,
    this.speed = const Duration(milliseconds: 12),
  });

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText> {
  String _displayedText = '';
  int _charIndex = 0;

  @override
  void initState() {
    super.initState();
    _startTyping();
  }

  void _startTyping() {
    Future.doWhile(() async {
      if (!mounted) return false;
      await Future.delayed(widget.speed);
      if (!mounted) return false;
      if (_charIndex < widget.text.length) {
        setState(() {
          _charIndex++;
          _displayedText = widget.text.substring(0, _charIndex);
        });
        return true;
      }
      return false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Text(_displayedText, style: widget.style);
  }
}
