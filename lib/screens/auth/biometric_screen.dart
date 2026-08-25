import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pocket_plan/core/services/auth_services.dart';
import 'package:pocket_plan/core/themes/app_colors.dart';

// ─────────────────────────────────────────
// BIOMETRIC UNLOCK SCREEN
// Shown on app open when a user is already
// signed in and has biometric login enabled.
// Not part of the sign-in flow itself —
// login_screen.dart handles that separately.
// ─────────────────────────────────────────
class BiometricScreen extends StatefulWidget {
  const BiometricScreen({super.key});

  @override
  State<BiometricScreen> createState() => _BiometricScreenState();
}

class _BiometricScreenState extends State<BiometricScreen>
    with TickerProviderStateMixin {
  final AuthService _authService = AuthService();

  bool _isAuthenticating = false;
  bool _authFailed = false;

  late AnimationController _entryController;
  late Animation<double> _fadeAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulse;

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

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Auto-trigger the OS biometric prompt shortly after this screen appears
    Future.delayed(const Duration(milliseconds: 400), _authenticate);
  }

  @override
  void dispose() {
    _entryController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _authenticate() async {
    if (!mounted || _isAuthenticating) return;
    setState(() {
      _isAuthenticating = true;
      _authFailed = false;
    });

    try {
      final success = await _authService.authenticateWithBiometrics();
      if (!mounted) return;

      if (success) {
        final user = _authService.currentUser;
        if (user != null) {
          Navigator.of(context).pushReplacementNamed('/home');
          return;
        } else {
          // Session no longer valid, fall back to password login
          Navigator.of(context).pushReplacementNamed('/login');
          return;
        }
      } else {
        setState(() => _authFailed = true);
      }
    } catch (_) {
      if (mounted) setState(() => _authFailed = true);
    } finally {
      if (mounted) setState(() => _isAuthenticating = false);
    }
  }

  Future<void> _usePasswordInstead() async {
    await _authService.logout();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName?.split(' ').first ?? 'there';

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),

                // Pulsing fingerprint icon
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.accent.withOpacity(0.12),
                        boxShadow: [
                          BoxShadow(
                            color: colors.accent.withOpacity(
                              0.25 * _pulse.value,
                            ),
                            blurRadius: 40 * _pulse.value,
                            spreadRadius: 8 * _pulse.value,
                          ),
                        ],
                      ),
                      child: Icon(
                        _authFailed
                            ? Icons.fingerprint_rounded
                            : Icons.fingerprint_rounded,
                        size: 56,
                        color: _authFailed ? colors.danger : colors.accent,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),

                Text(
                  'Welcome back, $name',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _authFailed
                      ? 'Authentication failed. Try again.'
                      : _isAuthenticating
                      ? 'Verifying...'
                      : 'Use your fingerprint or face to unlock PocketPlan',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _authFailed ? colors.danger : colors.textSecondary,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),

                const Spacer(flex: 1),

                // Retry / unlock button
                GestureDetector(
                  onTap: _isAuthenticating ? null : _authenticate,
                  child: Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [colors.accent, colors.accent.withOpacity(0.7)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: colors.accent.withOpacity(0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _isAuthenticating
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.fingerprint_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _authFailed ? 'Try Again' : 'Unlock',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                GestureDetector(
                  onTap: _usePasswordInstead,
                  child: Text(
                    'Use Password Instead',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                const Spacer(flex: 1),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
