import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocket_plan/core/services/auth_services.dart';
import 'package:pocket_plan/core/themes/app_colors.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _allowanceController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  int _currentStep = 0; // 0 = personal info, 1 = financial info

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _allowanceController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await _authService.registerWithEmail(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        monthlyAllowance: double.tryParse(_allowanceController.text) ?? 0.0,
      );
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_friendlyError(e.toString())),
            backgroundColor: context.colors.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _friendlyError(String error) {
    if (error.contains('email-already-in-use')) {
      return 'This email is already registered.';
    } else if (error.contains('weak-password')) {
      return 'Password is too weak. Use at least 6 characters.';
    } else if (error.contains('invalid-email')) {
      return 'Please enter a valid email address.';
    }
    return 'Registration failed. Please try again.';
  }

  void _nextStep() {
    if (_currentStep == 0) {
      // Validate first step fields manually
      if (_nameController.text.trim().isEmpty) {
        _showError('Please enter your name.');
        return;
      }
      if (_emailController.text.trim().isEmpty ||
          !_emailController.text.contains('@')) {
        _showError('Please enter a valid email.');
        return;
      }
      if (_passwordController.text.length < 6) {
        _showError('Password must be at least 6 characters.');
        return;
      }
      if (_passwordController.text != _confirmPasswordController.text) {
        _showError('Passwords do not match.');
        return;
      }
      _fadeController.reset();
      setState(() => _currentStep = 1);
      _fadeController.forward();
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: context.colors.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colors.background, colors.surfaceAlt, colors.surface],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(),

              // Step indicator
              _buildStepIndicator(),

              // Form
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Form(
                      key: _formKey,
                      child: _currentStep == 0 ? _buildStep1() : _buildStep2(),
                    ),
                  ),
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          if (_currentStep == 1)
            GestureDetector(
              onTap: () {
                _fadeController.reset();
                setState(() => _currentStep = 0);
                _fadeController.forward();
              },
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
            )
          else
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
                _currentStep == 0 ? 'Create Account' : 'Financial Setup',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              Text(
                _currentStep == 0
                    ? 'Join PocketPlan today'
                    : 'Set your monthly budget',
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        children: [
          _stepDot(0, 'Personal'),
          Expanded(
            child: Container(
              height: 2,
              color: _currentStep >= 1 ? colors.accent : colors.border,
            ),
          ),
          _stepDot(1, 'Financial'),
        ],
      ),
    );
  }

  Widget _stepDot(int step, String label) {
    final colors = context.colors;
    final isActive = _currentStep >= step;
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? colors.accent : colors.surface,
            border: Border.all(
              color: isActive ? colors.accent : colors.border,
              width: 2,
            ),
          ),
          child: Center(
            child: isActive && _currentStep > step
                ? const Icon(Icons.check, color: Colors.white, size: 16)
                : Text(
                    '${step + 1}',
                    style: TextStyle(
                      color: isActive ? Colors.white : colors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isActive ? colors.accent : colors.textTertiary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildStep1() {
    final colors = context.colors;
    return Column(
      children: [
        const SizedBox(height: 8),
        _buildField(
          controller: _nameController,
          label: 'Full Name',
          hint: 'e.g. Daniel Aiman',
          icon: Icons.person_outline_rounded,
          validator: (v) => v == null || v.isEmpty ? 'Name is required' : null,
        ),
        const SizedBox(height: 16),
        _buildField(
          controller: _emailController,
          label: 'Email Address',
          hint: 'e.g. daniel@student.utem.edu.my',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          validator: (v) {
            if (v == null || v.isEmpty) return 'Email is required';
            if (!v.contains('@')) return 'Enter a valid email';
            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildField(
          controller: _passwordController,
          label: 'Password',
          hint: 'At least 6 characters',
          icon: Icons.lock_outline_rounded,
          obscure: _obscurePassword,
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: colors.textSecondary,
              size: 20,
            ),
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Password is required';
            if (v.length < 6) return 'Minimum 6 characters';
            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildField(
          controller: _confirmPasswordController,
          label: 'Confirm Password',
          hint: 'Re-enter your password',
          icon: Icons.lock_outline_rounded,
          obscure: _obscureConfirm,
          suffixIcon: IconButton(
            icon: Icon(
              _obscureConfirm
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: colors.textSecondary,
              size: 20,
            ),
            onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
          ),
          validator: (v) {
            if (v != _passwordController.text) return 'Passwords do not match';
            return null;
          },
          onSubmit: _nextStep,
        ),
        const SizedBox(height: 32),
        _buildButton(
          label: 'Continue',
          onTap: _nextStep,
          icon: Icons.arrow_forward_rounded,
        ),
        const SizedBox(height: 20),
        _buildLoginLink(),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildStep2() {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        // Info card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.accent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.accent.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, color: colors.accent, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'PocketPlan uses the 50/30/20 rule to split your allowance automatically.',
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.textPrimary.withOpacity(0.8),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildField(
          controller: _allowanceController,
          label: 'Monthly Allowance (RM)',
          hint: 'e.g. 1500.00',
          icon: Icons.account_balance_wallet_outlined,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Please enter your allowance';
            if (double.tryParse(v) == null) return 'Enter a valid amount';
            if (double.parse(v) <= 0) return 'Amount must be greater than 0';
            return null;
          },
          onSubmit: _register,
        ),
        const SizedBox(height: 20),

        // Budget breakdown preview
        if (_allowanceController.text.isNotEmpty) _buildBudgetPreview(),

        const SizedBox(height: 32),
        _buildButton(
          label: _isLoading ? 'Creating Account...' : 'Create Account',
          onTap: _isLoading ? null : _register,
          isLoading: _isLoading,
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildBudgetPreview() {
    final colors = context.colors;
    final amount = double.tryParse(_allowanceController.text) ?? 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Budget Breakdown',
            style: TextStyle(
              color: colors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          _budgetRow('Commitments (50%)', amount * 0.5, colors.accent),
          const SizedBox(height: 8),
          _budgetRow('Spending (30%)', amount * 0.3, colors.success),
          const SizedBox(height: 8),
          _budgetRow('Savings (20%)', amount * 0.2, colors.warning),
        ],
      ),
    );
  }

  Widget _budgetRow(String label, double amount, Color color) {
    final colors = context.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(color: colors.textSecondary, fontSize: 13),
            ),
          ],
        ),
        Text(
          'RM ${amount.toStringAsFixed(2)}',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    VoidCallback? onSubmit, // Enter on the last field of a step
  }) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          validator: validator,
          textInputAction:
              onSubmit != null ? TextInputAction.done : TextInputAction.next,
          onFieldSubmitted: (_) => onSubmit != null
              ? onSubmit()
              : FocusScope.of(context).nextFocus(),
          onChanged: (_) => setState(() {}),
          style: TextStyle(color: colors.textPrimary, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: colors.textTertiary, fontSize: 14),
            prefixIcon: Icon(icon, color: colors.accent, size: 20),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: colors.surface.withOpacity(0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: colors.border, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: colors.accent, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: colors.danger, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: colors.danger, width: 1.5),
            ),
            errorStyle: TextStyle(color: colors.danger),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildButton({
    required String label,
    VoidCallback? onTap,
    IconData? icon,
    bool isLoading = false,
  }) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: onTap == null
              ? null
              : LinearGradient(
                  colors: [colors.accent, colors.accent.withOpacity(0.7)],
                ),
          color: onTap == null ? colors.surface : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: onTap == null
              ? null
              : [
                  BoxShadow(
                    color: colors.accent.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                    if (icon != null) ...[
                      const SizedBox(width: 8),
                      Icon(icon, color: Colors.white, size: 18),
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildLoginLink() {
    final colors = context.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Already have an account? ',
          style: TextStyle(color: colors.textSecondary, fontSize: 14),
        ),
        GestureDetector(
          onTap: () => Navigator.of(context).pushReplacementNamed('/login'),
          child: Text(
            'Sign In',
            style: TextStyle(
              color: colors.accent,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
