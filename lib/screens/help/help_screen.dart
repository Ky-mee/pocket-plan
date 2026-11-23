import 'package:flutter/material.dart';
import 'package:pocket_plan/core/themes/app_colors.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> with TickerProviderStateMixin {
  late AnimationController _entryController;
  late Animation<double> _fadeAnimation;
  int _expandedIndex = -1;

  List<HelpSection> _buildSections(AppColors colors) => [
    HelpSection(
      icon: '💰',
      title: 'Getting Started',
      color: colors.accent,
      items: [
        HelpItem(
          question: 'How do I set my monthly income?',
          answer:
              'Go to Settings → tap on "Monthly Income" (or tap "Income" in Budget Manager) → enter your amount. PocketPlan splits it automatically across Essential Needs, Lifestyle & Wants, and Savings & Goals.',
        ),
        HelpItem(
          question: 'How do flexible budget splits work?',
          answer:
              'By default PocketPlan uses 50/30/20 (50% Essential Needs, 30% Lifestyle, 20% Savings). In Budget Manager, tap "Split" to switch to another preset like 60/20/20 or 70/20/10, or use sliders to set custom percentages.',
        ),
        HelpItem(
          question: 'Can I change currency or bucket limits?',
          answer:
              'Yes! Pick your preferred currency in Settings → Currency. You can also tap "Edit limit" under any bucket in Budget Manager to set a custom limit.',
        ),
      ],
    ),
    HelpSection(
      icon: '📝',
      title: 'Transactions',
      color: colors.success,
      items: [
        HelpItem(
          question: 'How do I add a transaction?',
          answer:
              'Tap the + button on the Home screen or Transactions page. Choose Expense or Income, enter the amount, pick a category and budget bucket, add an optional note, and tap Save.',
        ),
        HelpItem(
          question: 'How do I edit or delete a transaction?',
          answer:
              'Go to Transactions → tap the edit (pencil) icon to update details, or swipe left (or tap delete on desktop) to remove it. Your monthly budget updates automatically.',
        ),
        HelpItem(
          question: 'How do I export my transactions?',
          answer:
              'Go to Transactions → tap the download icon in the top right → choose Export as PDF or Export as CSV.',
        ),
      ],
    ),
    HelpSection(
      icon: '📊',
      title: 'Analytics & Budget',
      color: colors.warning,
      items: [
        HelpItem(
          question: 'What does the Analytics screen show?',
          answer:
              'The Analytics screen has 3 tabs:\n\n• Overview — income vs expenses, 7-day bar chart, month comparison\n• Categories — breakdown of spending by category with pie chart\n• Prediction — fuzzy-logic spending forecast for upcoming months based on your history',
        ),
        HelpItem(
          question: 'When does my budget reset?',
          answer:
              'Your budget automatically resets on the 1st of every month. Your previous month\'s summary is archived, and positive leftovers can carry forward if enabled in Settings.',
        ),
        HelpItem(
          question: 'Why is a bucket showing red?',
          answer:
              'Red means you have exceeded the limit for that bucket. Open Budget Manager to review your spending or adjust the bucket limit.',
        ),
      ],
    ),
    HelpSection(
      icon: '🤖',
      title: 'AI Financial Advisor & Food Nearby',
      color: const Color(0xFF9C8DFF),
      items: [
        HelpItem(
          question: 'What can the AI Advisor help with?',
          answer:
              'The AI Advisor can analyze your monthly spending, suggest ways to save on essentials, evaluate purchase affordability, and share general savings guidance tailored to your life stage. Note: AI replies are informational only and not licensed financial advice.',
        ),
        HelpItem(
          question: 'How does the AI know my budget?',
          answer:
              'When you send a message, PocketPlan shares your current monthly income, bucket totals, top categories, and recent transactions securely with our proxy so advice matches your real numbers.',
        ),
        HelpItem(
          question: 'How do I find affordable food or groceries nearby?',
          answer:
              'Tap the green location button in the AI Advisor header, or tap "Food Nearby" on the Home screen. The map shows restaurants, food courts, cafes, bakeries, and grocery stores within 5km using OpenStreetMap data.',
        ),
      ],
    ),
    HelpSection(
      icon: '🔒',
      title: 'Security, Privacy & Account',
      color: colors.danger,
      items: [
        HelpItem(
          question: 'How do I enable biometric login?',
          answer:
              'Go to Settings → Security → toggle on "Biometric Login" on supported mobile devices with fingerprint or face unlock configured.',
        ),
        HelpItem(
          question: 'How do I delete my account and data?',
          answer:
              'Go to Settings → Security → tap "Delete Account", confirm your password, and PocketPlan will permanently remove your account, budget, and transactions.',
        ),
        HelpItem(
          question: 'Is my financial data secure?',
          answer:
              'Yes. All data is stored in Firebase Firestore with owner-only security rules, and AI requests pass through an authenticated proxy.',
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
    final colors = context.colors;
    final sections = _buildSections(colors);
    return Scaffold(
      backgroundColor: colors.background,
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
                    ...sections.asMap().entries.map(
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Help & Guide',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'How to use PocketPlan',
                style: TextStyle(color: colors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchHint() {
    final colors = context.colors;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.accent, colors.accent.withOpacity(0.7)],
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
    final colors = context.colors;
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
            color: colors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.border),
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
                                    : colors.textPrimary,
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
                                  : colors.textTertiary,
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
                          style: TextStyle(
                            color: colors.textSecondary,
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
                    Divider(color: colors.border, height: 1, indent: 16),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildContactCard() {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          const Text('💼', style: TextStyle(fontSize: 32)),
          const SizedBox(height: 12),
          Text(
            'About PocketPlan',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Smart monthly budgeting, AI guidance, and local budget-friendly dining for every stage of life.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 12,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: colors.accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.accent.withOpacity(0.3)),
            ),
            child: Text(
              'v1.0.0',
              style: TextStyle(
                color: colors.accent,
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
