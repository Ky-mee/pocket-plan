import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pocket_plan/core/themes/app_colors.dart';
import 'package:pocket_plan/core/utils/amount_input.dart';

/// Big "RM 0.00" amount input. Uses the device's own keyboard (numeric
/// keyboard on phones, normal keyboard on desktop). Enter submits.
class AmountField extends StatelessWidget {
  final TextEditingController controller;
  final Color color;
  final bool autofocus;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;

  const AmountField({
    super.key,
    required this.controller,
    required this.color,
    required this.onChanged,
    required this.onSubmitted,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Amount',
            style: TextStyle(color: color.withOpacity(0.8), fontSize: 13),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'RM ',
                style: TextStyle(
                  color: color.withOpacity(0.7),
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  autofocus: autofocus,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.done,
                  inputFormatters: const [AmountInputFormatter()],
                  onChanged: onChanged,
                  onSubmitted: (_) => onSubmitted(),
                  cursorColor: color,
                  style: TextStyle(
                    color: color,
                    fontSize: 44,
                    fontWeight: FontWeight.w800,
                  ),
                  decoration: InputDecoration(
                    hintText: '0.00',
                    hintStyle: TextStyle(
                      color: colors.textTertiary,
                      fontSize: 44,
                      fontWeight: FontWeight.w800,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
