import 'package:flutter/material.dart';
import 'package:pocket_plan/core/themes/app_colors.dart';

// ─────────────────────────────────────────
// ATM-STYLE NUMPAD WIDGET
// Numbers fill from right to left like a
// banking app — no decimal point needed.
// Value is always stored as cents (int)
// and displayed as RM X.XX
// ─────────────────────────────────────────
class AtmNumpad extends StatelessWidget {
  final int valueCents; // current value in cents
  final Function(int) onValueChanged;

  const AtmNumpad({
    super.key,
    required this.valueCents,
    required this.onValueChanged,
  });

  void _onDigit(int digit) {
    // Append digit from the right, max 8 digits (RM 999,999.99)
    if (valueCents >= 9999999) return;
    onValueChanged(valueCents * 10 + digit);
  }

  void _onBackspace() {
    onValueChanged(valueCents ~/ 10);
  }

  void _onClear() {
    onValueChanged(0);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Numpad grid
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.2,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          children: [
            _numKey(1),
            _numKey(2),
            _numKey(3),
            _numKey(4),
            _numKey(5),
            _numKey(6),
            _numKey(7),
            _numKey(8),
            _numKey(9),
            _clearKey(),
            _numKey(0),
            _backspaceKey(),
          ],
        ),
      ],
    );
  }

  Widget _numKey(int digit) {
    return _NumKey(label: '$digit', onTap: () => _onDigit(digit));
  }

  Widget _backspaceKey() {
    return _NumKey(
      label: '⌫',
      isIcon: true,
      onTap: _onBackspace,
      onLongPress: _onClear,
    );
  }

  Widget _clearKey() {
    return _NumKey(label: 'C', onTap: _onClear, isSpecial: true);
  }
}

class _NumKey extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isIcon;
  final bool isSpecial;

  const _NumKey({
    required this.label,
    required this.onTap,
    this.onLongPress,
    this.isIcon = false,
    this.isSpecial = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isSpecial
              ? colors.danger.withOpacity(0.1)
              : colors.surface.withOpacity(0.6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSpecial ? colors.danger.withOpacity(0.25) : colors.border,
          ),
        ),
        child: Center(
          child: isIcon
              ? Icon(
                  Icons.backspace_outlined,
                  color: colors.textSecondary,
                  size: 22,
                )
              : Text(
                  label,
                  style: TextStyle(
                    color: isSpecial ? colors.danger : colors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// AMOUNT DISPLAY WIDGET
// Shows the current value in RM X.XX format
// with large banking-style text
// ─────────────────────────────────────────
class AtmAmountDisplay extends StatelessWidget {
  final int valueCents;
  final Color color;

  const AtmAmountDisplay({
    super.key,
    required this.valueCents,
    required this.color,
  });

  String get _formatted {
    final ringgit = valueCents ~/ 100;
    final cents = valueCents % 100;
    return '${ringgit.toString()}.${cents.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Amount',
            style: TextStyle(
              color: color.withOpacity(0.7),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                'RM ',
                style: TextStyle(
                  color: color.withOpacity(0.6),
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                _formatted,
                style: TextStyle(
                  color: color,
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
