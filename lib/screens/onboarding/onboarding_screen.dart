import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pocket_plan/core/themes/app_colors.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  List<OnboardingPage> _buildPages(AppColors colors) => [
    OnboardingPage(
      emoji: '👋',
      title: 'Welcome to\nPocketPlan',
      subtitle:
          'Your smart personal finance companion designed for Malaysian university students.',
      color: colors.accent,
      features: [],
    ),
    OnboardingPage(
      emoji: '💰',
      title: 'Smart Budget\nManagement',
      subtitle:
          'PocketPlan uses the 50/30/20 rule to automatically split your monthly allowance.',
      color: colors.success,
      features: [
        FeatureItem('50%', 'Commitments — rent, bills, loans'),
        FeatureItem('30%', 'Spending — food, shopping, fun'),
        FeatureItem('20%', 'Savings — ASB, gold, investments'),
      ],
    ),
    OnboardingPage(
      emoji: '📊',
      title: 'Track Every\nRinggit',
      subtitle:
          'Add income and expenses easily. Get real-time analytics and spending insights.',
      color: colors.warning,
      features: [
        FeatureItem('📈', 'Spending charts and trends'),
        FeatureItem('🔔', 'Budget exceeded alerts'),
        FeatureItem('📄', 'Export to PDF or CSV'),
      ],
    ),
    OnboardingPage(
      emoji: '🤖',
      title: 'AI Financial\nAdvisor',
      subtitle:
          'Ask our AI anything about your finances — from food budgets to investment tips.',
      color: const Color(0xFF9C8DFF),
      features: [
        FeatureItem('🍜', 'Find affordable food nearby'),
        FeatureItem('💡', 'Personalized spending advice'),
        FeatureItem('📍', 'Nearby restaurant suggestions'),
      ],
    ),
    OnboardingPage(
      emoji: '🚀',
      title: "You're All\nSet!",
      subtitle:
          'Start by entering your monthly allowance and PocketPlan will do the rest.',
      color: colors.accent,
      features: [],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding({
    String targetRoute = '/register',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    if (mounted) {
      Navigator.of(context).pushReplacementNamed(targetRoute);
    }
  }

  void _nextPage(int pageCount) {
    if (_currentPage < pageCount - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _skip() => _completeOnboarding();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final pages = _buildPages(colors);
    return Scaffold(
      backgroundColor: colors.background,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SafeArea(
          child: Column(
            children: [
              // Skip button
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Logo mini
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: colors.accent.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.account_balance_wallet_rounded,
                            color: colors.accent,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'PocketPlan',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    if (_currentPage < pages.length - 1)
                      GestureDetector(
                        onTap: _skip,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Skip',
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Pages
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                    _animController.reset();
                    _animController.forward();
                  },
                  itemCount: pages.length,
                  itemBuilder: (context, index) => _buildPage(pages[index]),
                ),
              ),

              // Bottom section
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: Column(
                  children: [
                    // Page indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        pages.length,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _currentPage == i ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _currentPage == i
                                ? pages[_currentPage].color
                                : colors.border,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Next / Get Started button
                    GestureDetector(
                      onTap: () => _nextPage(pages.length),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              pages[_currentPage].color,
                              pages[_currentPage].color.withOpacity(0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: pages[_currentPage].color.withOpacity(0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _currentPage == pages.length - 1
                                    ? 'Get Started'
                                    : 'Next',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                _currentPage == pages.length - 1
                                    ? Icons.rocket_launch_rounded
                                    : Icons.arrow_forward_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Already have account
                    if (_currentPage == pages.length - 1) ...[
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: () =>
                            _completeOnboarding(targetRoute: '/login'),
                        child: RichText(
                          text: TextSpan(
                            text: 'Already have an account? ',
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 13,
                            ),
                            children: [
                              TextSpan(
                                text: 'Sign In',
                                style: TextStyle(
                                  color: colors.accent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingPage page) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Emoji illustration
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.5, end: 1.0),
            duration: const Duration(milliseconds: 500),
            curve: Curves.elasticOut,
            builder: (context, value, child) =>
                Transform.scale(scale: value, child: child),
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: page.color.withOpacity(0.12),
                border: Border.all(
                  color: page.color.withOpacity(0.25),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: page.color.withOpacity(0.2),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: Center(
                child: Text(page.emoji, style: const TextStyle(fontSize: 60)),
              ),
            ),
          ),
          const SizedBox(height: 40),

          // Title
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              height: 1.2,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),

          // Subtitle
          Text(
            page.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 15,
              height: 1.6,
            ),
          ),

          // Feature list
          if (page.features.isNotEmpty) ...[
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: page.color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: page.color.withOpacity(0.2)),
              ),
              child: Column(
                children: page.features
                    .map(
                      (f) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: page.color.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  f.icon,
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                f.description,
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// DATA MODELS
// ─────────────────────────────────────────
class OnboardingPage {
  final String emoji;
  final String title;
  final String subtitle;
  final Color color;
  final List<FeatureItem> features;

  OnboardingPage({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.features,
  });
}

class FeatureItem {
  final String icon;
  final String description;

  FeatureItem(this.icon, this.description);
}
