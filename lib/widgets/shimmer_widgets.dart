import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

// ─────────────────────────────────────────
// BASE SHIMMER BOX
// ─────────────────────────────────────────
class ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.white.withOpacity(0.06),
      highlightColor: Colors.white.withOpacity(0.14),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// TRANSACTION LIST SHIMMER
// ─────────────────────────────────────────
class TransactionShimmer extends StatelessWidget {
  const TransactionShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        6,
        (i) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Row(
            children: [
              ShimmerBox(width: 44, height: 44, borderRadius: 12),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerBox(width: double.infinity, height: 14),
                    const SizedBox(height: 8),
                    ShimmerBox(width: 100, height: 10),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ShimmerBox(width: 70, height: 14),
                  const SizedBox(height: 8),
                  ShimmerBox(width: 50, height: 10),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// BUDGET CARD SHIMMER
// ─────────────────────────────────────────
class BudgetCardShimmer extends StatelessWidget {
  const BudgetCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ShimmerBox(width: 120, height: 13),
              ShimmerBox(width: 70, height: 24, borderRadius: 20),
            ],
          ),
          const SizedBox(height: 16),
          ShimmerBox(width: 200, height: 36),
          const SizedBox(height: 8),
          ShimmerBox(width: 160, height: 13),
          const SizedBox(height: 20),
          ShimmerBox(width: double.infinity, height: 6, borderRadius: 8),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ShimmerBox(width: 100, height: 12),
              ShimmerBox(width: 60, height: 12),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// HOME SCREEN SHIMMER
// ─────────────────────────────────────────
class HomeShimmer extends StatelessWidget {
  const HomeShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          // Top bar shimmer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(width: 80, height: 14),
                  const SizedBox(height: 6),
                  ShimmerBox(width: 120, height: 22),
                ],
              ),
              Row(
                children: [
                  ShimmerBox(width: 42, height: 42, borderRadius: 12),
                  const SizedBox(width: 10),
                  ShimmerBox(width: 42, height: 42, borderRadius: 12),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Balance card shimmer
          const BudgetCardShimmer(),
          const SizedBox(height: 16),
          // Budget ring shimmer
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                ShimmerBox(width: 120, height: 120, borderRadius: 60),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    children: [
                      ShimmerBox(width: double.infinity, height: 40),
                      const SizedBox(height: 12),
                      ShimmerBox(width: double.infinity, height: 40),
                      const SizedBox(height: 12),
                      ShimmerBox(width: double.infinity, height: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Quick actions shimmer
          ShimmerBox(width: 120, height: 15),
          const SizedBox(height: 12),
          Row(
            children: List.generate(
              4,
              (i) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i < 3 ? 12 : 0),
                  child: ShimmerBox(
                    width: double.infinity,
                    height: 72,
                    borderRadius: 16,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Recent transactions shimmer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ShimmerBox(width: 150, height: 15),
              ShimmerBox(width: 50, height: 13),
            ],
          ),
          const SizedBox(height: 12),
          const TransactionShimmer(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// EMPTY STATE WIDGET (with illustrations)
// ─────────────────────────────────────────
class EmptyStateWidget extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final String? buttonLabel;
  final VoidCallback? onButtonTap;

  const EmptyStateWidget({
    super.key,
    required this.emoji,
    required this.title,
    required this.subtitle,
    this.buttonLabel,
    this.onButtonTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Emoji illustration in a glowing circle
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF6C63FF).withOpacity(0.1),
                border: Border.all(
                  color: const Color(0xFF6C63FF).withOpacity(0.2),
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 44)),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF9E9FBF),
                fontSize: 14,
                height: 1.5,
              ),
            ),
            if (buttonLabel != null && onButtonTap != null) ...[
              const SizedBox(height: 24),
              GestureDetector(
                onTap: onButtonTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6C63FF), Color(0xFF9C8DFF)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6C63FF).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    buttonLabel!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
