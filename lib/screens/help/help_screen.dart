import 'package:flutter/material.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> with TickerProviderStateMixin {
  late AnimationController _entryController;
  late Animation<double> _fadeAnimation;
  int _expandedIndex = -1;

  final List<HelpSection> _sections = [
    HelpSection(
      icon: '💰',
      title: 'Getting Started',
      color: const Color(0xFF6C63FF),
      items: [
        HelpItem(
          question: 'How do I set my monthly allowance?',
          answer:
              'Go to Settings → tap on "Monthly Allowance" → enter your allowance amount. PocketPlan will automatically split it into 50% Commitments, 30% Spending and 20% Savings.',
        ),
        HelpItem(
          question: 'What is the 50/30/20 rule?',
          answer:
              'The 50/30/20 rule is a simple budgeting method:\n\n• 50% for Commitments — rent, bills, car, PTPTN\n• 30% for Spending — food, shopping, entertainment\n• 20% for Savings — bank savings, ASB, investments\n\nPocketPlan applies this rule automatically to your allowance.',
        ),
        HelpItem(
          question: 'Can I change the budget percentages?',
          answer:
              'Yes! Go to Budget Manager → tap "Edit limit" under any bucket to set a custom amount. You can adjust each bucket independently to fit your lifestyle.',
        ),
      ],
    ),
    HelpSection(
      icon: '📝',
      title: 'Transactions',
      color: const Color(0xFF00D4AA),
      items: [
        HelpItem(
          question: 'How do I add a transaction?',
          answer:
              'Tap the + button on the Home screen or the FAB button on any screen. Select Expense or Income, enter the amount, choose a category and budget bucket, add a description, and tap Save.',
        ),
        HelpItem(
          question: 'How do I edit a transaction?',
          answer:
              'Go to Transactions → find the transaction → tap the edit icon (pencil) on the right side of the card. Make your changes and tap Save Changes.',
        ),
        HelpItem(
          question: 'How do I delete a transaction?',
          answer:
              'Go to Transactions → swipe the transaction card from right to left → tap Delete in the confirmation dialog. Your budget will be automatically updated.',
        ),
        HelpItem(
          question: 'How do I export my transactions?',
          answer:
              'Go to Transactions → tap the download icon in the top right → choose Export as PDF or Export as CSV. The file will be shared via your phone\'s share sheet.',
        ),
      ],
    ),
    HelpSection(
      icon: '📊',
      title: 'Analytics & Budget',
      color: const Color(0xFFFFB347),
      items: [
        HelpItem(
          question: 'What does the Analytics screen show?',
          answer:
              'The Analytics screen has 3 tabs:\n\n• Overview — income vs expenses, 7-day bar chart, month comparison\n• Categories — breakdown of spending by category with pie chart\n• Prediction — AI-powered spending forecast for next month based on your history',
        ),
        HelpItem(
          question: 'When does my budget reset?',
          answer:
              'Your budget automatically resets on the 1st of every month. Your previous month\'s data is archived so you can review it in the Analytics screen.',
        ),
        HelpItem(
          question: 'Why is my budget showing red?',
          answer:
              'Red means you have exceeded the limit for that budget bucket. Go to Budget Manager to see which bucket is over the limit. You can either reduce spending or increase the limit for that bucket.',
        ),
      ],
    ),
    HelpSection(
      icon: '🤖',
      title: 'AI Financial Advisor',
      color: const Color(0xFF9C8DFF),
      items: [
        HelpItem(
          question: 'What can the AI Advisor help with?',
          answer:
              'The AI Advisor can:\n\n• Analyze your spending habits\n• Suggest affordable places to eat nearby\n• Advise on whether a purchase fits your budget\n• Recommend savings and investment options\n• Answer any finance-related questions',
        ),
        HelpItem(
          question: 'How does the AI know my finances?',
          answer:
              'The AI receives your current budget snapshot — allowance, total spent, remaining balance, and recent transactions — before answering. This makes the advice personalized to your actual financial situation.',
        ),
        HelpItem(
          question: 'How do I find food nearby?',
          answer:
              'Tap the green location button in the AI Advisor header, or tap "Food Nearby" on the Home screen. The map will show nearby restaurants, cafes, and food courts within 5km using OpenStreetMap data.',
        ),
      ],
    ),
    HelpSection(
      icon: '🔒',
      title: 'Security & Account',
      color: const Color(0xFFFF6B6B),
      items: [
        HelpItem(
          question: 'How do I enable fingerprint login?',
          answer:
              'Go to Settings → Security → toggle on "Biometric Login". Make sure your phone has fingerprint or face unlock set up. Next time you open the app, it will prompt for biometric authentication.',
        ),
        HelpItem(
          question: 'How do I change my password?',
          answer:
              'Go to Settings → Security → tap "Change Password". A password reset link will be sent to your registered email address.',
        ),
        HelpItem(
          question: 'Is my financial data secure?',
          answer:
              'Yes. All data is stored in Firebase Firestore with security rules that ensure only you can access your own data. Firebase Authentication handles login security with industry-standard encryption.',
        ),
      ],
    ),
  ];

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
          child: Column(
            children: [
              _buildHeader(),
              _buildSearchHint(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                  children: [
                    ..._sections.asMap().entries.map(
                      (entry) => _buildSection(entry.value, entry.key),
                    ),
                    const SizedBox(height: 20),
                    _buildContactCard(),
                  ],
                ),
              ),
            ],
          ),
        ),
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
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Help & Guide',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'How to use PocketPlan',
                style: TextStyle(color: Color(0xFF9E9FBF), fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchHint() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF4834D4)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.lightbulb_outline_rounded,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Tap any question to expand the answer.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(HelpSection section, int sectionIndex) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Row(
          children: [
            Text(section.icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text(
              section.title,
              style: TextStyle(
                color: section.color,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Column(
            children: section.items.asMap().entries.map((entry) {
              final itemIndex = sectionIndex * 100 + entry.key;
              final item = entry.value;
              final isExpanded = _expandedIndex == itemIndex;
              final isLast = entry.key == section.items.length - 1;

              return Column(
                children: [
                  GestureDetector(
                    onTap: () => setState(
                      () => _expandedIndex = isExpanded ? -1 : itemIndex,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.question,
                              style: TextStyle(
                                color: isExpanded
                                    ? section.color
                                    : Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          AnimatedRotation(
                            turns: isExpanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: isExpanded
                                  ? section.color
                                  : const Color(0xFF4A4A6A),
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Answer
                  AnimatedCrossFade(
                    firstChild: const SizedBox(width: double.infinity),
                    secondChild: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: section.color.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: section.color.withOpacity(0.2),
                          ),
                        ),
                        child: Text(
                          item.answer,
                          style: const TextStyle(
                            color: Color(0xFF9E9FBF),
                            fontSize: 13,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ),
                    crossFadeState: isExpanded
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 250),
                  ),
                  if (!isLast)
                    Divider(
                      color: Colors.white.withOpacity(0.05),
                      height: 1,
                      indent: 16,
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildContactCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          const Text('👨‍💻', style: TextStyle(fontSize: 32)),
          const SizedBox(height: 12),
          const Text(
            'PocketPlan FYP',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Universiti Teknikal Malaysia Melaka\nFaculty of Information & Communication Technology\nSession 2025/2026',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF9E9FBF),
              fontSize: 12,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF6C63FF).withOpacity(0.3),
              ),
            ),
            child: const Text(
              'v1.0.0',
              style: TextStyle(
                color: Color(0xFF6C63FF),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// DATA MODELS
// ─────────────────────────────────────────
class HelpSection {
  final String icon;
  final String title;
  final Color color;
  final List<HelpItem> items;

  HelpSection({
    required this.icon,
    required this.title,
    required this.color,
    required this.items,
  });
}

class HelpItem {
  final String question;
  final String answer;

  HelpItem({required this.question, required this.answer});
}
