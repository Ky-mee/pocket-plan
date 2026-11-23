import 'package:flutter/material.dart';
import 'package:pocket_plan/core/layout/desktop_shell.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pocket_plan/core/services/auth_services.dart';
import 'package:pocket_plan/core/services/database_service.dart';
import 'package:pocket_plan/models/user_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocket_plan/providers/theme_provider.dart';
import 'package:pocket_plan/providers/accent_color_provider.dart';
import 'package:pocket_plan/core/themes/app_colors.dart';
import 'package:pocket_plan/core/utils/amount_input.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final DatabaseService _db = DatabaseService();

  bool _biometricEnabled = false;
  bool _notificationsEnabled = true;
  bool _darkMode = true;
  bool _biometricAvailable = false;
  bool _carryForwardEnabled = true;

  UserModel? _userModel;

  late AnimationController _entryController;
  late Animation<double> _fadeAnimation;

  String get _userId => FirebaseAuth.instance.currentUser?.uid ?? '';

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
    _loadData();
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    // Load user model
    final user = await _db.getUser(_userId);
    // Load preferences
    final prefs = await _db.getPreferences(_userId);
    // Check biometric availability
    final biometricAvailable = await _authService.isBiometricAvailable();
    final biometricEnabled = await _authService.isBiometricEnabled(_userId);

    if (mounted) {
      setState(() {
        _userModel = user;
        _biometricAvailable = biometricAvailable;
        _biometricEnabled = biometricEnabled;
        _notificationsEnabled = prefs['notificationsEnabled'] ?? true;
        _darkMode = ref.read(themeProvider.notifier).isDark;
        _carryForwardEnabled = prefs['carryForwardEnabled'] ?? true;
      });
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    await _authService.setBiometricEnabled(_userId, value);
    setState(() => _biometricEnabled = value);
  }

  Future<void> _toggleNotifications(bool value) async {
    await _db.savePreferences(_userId, {'notificationsEnabled': value});
    setState(() => _notificationsEnabled = value);
  }

  Future<void> _toggleDarkMode(bool value) async {
    await ref.read(themeProvider.notifier).toggleTheme();
    setState(() => _darkMode = value);
  }

  Future<void> _toggleCarryForward(bool value) async {
    await _db.savePreferences(_userId, {'carryForwardEnabled': value});
    setState(() => _carryForwardEnabled = value);
  }

  Future<void> _logout() async {
    final colors = context.colors;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surfaceAlt,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Sign Out',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Are you sure you want to sign out?',
          style: TextStyle(color: colors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: colors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Sign Out',
              style: TextStyle(
                color: colors.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _authService.logout();
      if (mounted) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    }
  }

  void _showEditNameDialog() {
    final colors = context.colors;
    final ctrl = TextEditingController(text: _userModel?.name ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surfaceAlt,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Edit Name',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: TextField(
          controller: ctrl,
          style: TextStyle(color: colors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Your full name',
            hintStyle: TextStyle(color: colors.textTertiary),
            filled: true,
            fillColor: colors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colors.accent),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: colors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              if (ctrl.text.trim().isNotEmpty) {
                await _db.updateUser(_userId, {'name': ctrl.text.trim()});
                await FirebaseAuth.instance.currentUser?.updateDisplayName(
                  ctrl.text.trim(),
                );
                await _loadData();
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: Text(
              'Save',
              style: TextStyle(
                color: colors.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditAllowanceDialog() {
    final colors = context.colors;
    final ctrl = TextEditingController(
      text: _userModel?.monthlyAllowance.toString() ?? '',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surfaceAlt,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Edit Monthly Allowance',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: const [AmountInputFormatter()],
          style: TextStyle(color: colors.textPrimary),
          decoration: InputDecoration(
            prefixText: 'RM ',
            prefixStyle: TextStyle(color: colors.accent),
            filled: true,
            fillColor: colors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colors.accent),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: colors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              final val = double.tryParse(ctrl.text);
              if (val != null && val > 0) {
                try {
                  await _db.updateAllowance(_userId, val);
                  await _loadData();
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (_) {
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Failed to update allowance.'),
                        backgroundColor: context.colors.danger,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              }
            },
            child: Text(
              'Save',
              style: TextStyle(
                color: colors.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isDesktopLayout(context) ? 760 : double.infinity,
              ),
              child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                _buildProfileCard(),
                const SizedBox(height: 24),
                _buildSection('Account', [
                  _settingsTile(
                    icon: Icons.person_outline_rounded,
                    label: 'Full Name',
                    value: _userModel?.name ?? '-',
                    color: colors.accent,
                    onTap: _showEditNameDialog,
                  ),
                  _settingsTile(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    value: FirebaseAuth.instance.currentUser?.email ?? '-',
                    color: colors.accent,
                    onTap: null,
                  ),
                  _settingsTile(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Monthly Allowance',
                    value:
                        'RM ${_userModel?.monthlyAllowance.toStringAsFixed(2) ?? '0.00'}',
                    color: colors.accent,
                    onTap: _showEditAllowanceDialog,
                  ),
                  _settingsTile(
                    icon: Icons.help_outline_rounded,
                    label: 'Help & Guide',
                    value: '',
                    color: colors.accent,
                    onTap: () => Navigator.of(context).pushNamed('/help'),
                  ),
                ]),
                const SizedBox(height: 20),
                _buildSection('Security', [
                  if (_biometricAvailable)
                    _settingsToggle(
                      icon: Icons.fingerprint_rounded,
                      label: 'Biometric Login',
                      subtitle: 'Use fingerprint or face ID to sign in',
                      color: colors.success,
                      value: _biometricEnabled,
                      onChanged: _toggleBiometric,
                    ),
                  _settingsTile(
                    icon: Icons.lock_outline_rounded,
                    label: 'Change Password',
                    value: '',
                    color: colors.success,
                    onTap: () async {
                      final email = FirebaseAuth.instance.currentUser?.email;
                      if (email != null) {
                        try {
                          await _authService.resetPassword(email);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                  'Reset link sent to your email!',
                                ),
                                backgroundColor: colors.success,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            );
                          }
                        } catch (_) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                  'Could not send reset email. Try again later.',
                                ),
                                backgroundColor: colors.danger,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            );
                          }
                        }
                      }
                    },
                  ),
                ]),
                const SizedBox(height: 20),
                _buildSection('Preferences', [
                  _settingsToggle(
                    icon: Icons.dark_mode_outlined,
                    label: 'Dark Mode',
                    subtitle: 'Toggle dark/light appearance',
                    color: colors.warning,
                    value: _darkMode,
                    onChanged: _toggleDarkMode,
                  ),
                  _accentColorRow(),
                  _settingsToggle(
                    icon: Icons.savings_outlined,
                    label: 'Carry Forward Balance',
                    subtitle: 'Unused budget rolls into next month',
                    color: colors.success,
                    value: _carryForwardEnabled,
                    onChanged: _toggleCarryForward,
                  ),
                  _settingsToggle(
                    icon: Icons.notifications_outlined,
                    label: 'Budget Notifications',
                    subtitle: 'Get alerts when budget is exceeded',
                    color: colors.warning,
                    value: _notificationsEnabled,
                    onChanged: _toggleNotifications,
                  ),
                  _settingsTile(
                    icon: Icons.currency_exchange_rounded,
                    label: 'Currency',
                    value: _userModel?.currency ?? 'MYR',
                    color: colors.warning,
                    onTap: null,
                  ),
                ]),
                const SizedBox(height: 24),
                _buildLogoutButton(),
                const SizedBox(height: 40),
              ],
            ),
          ),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // HEADER
  // ─────────────────────────────────────────
  Widget _buildHeader() {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
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
          Text(
            'Settings',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // PROFILE CARD
  // ─────────────────────────────────────────
  Widget _buildProfileCard() {
    final colors = context.colors;
    final user = FirebaseAuth.instance.currentUser;
    final name = _userModel?.name ?? user?.displayName ?? 'User';
    final email = user?.email ?? '';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.accent, const Color(0xFF4834D4)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colors.accent.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'RM ${_userModel?.monthlyAllowance.toStringAsFixed(2) ?? '0.00'} / month',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _showEditNameDialog,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.edit_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // SECTION
  // ─────────────────────────────────────────
  Widget _buildSection(String title, List<Widget> tiles) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            children: tiles
                .asMap()
                .entries
                .map(
                  (e) => Column(
                    children: [
                      e.value,
                      if (e.key < tiles.length - 1)
                        Divider(color: colors.border, height: 1, indent: 56),
                    ],
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required VoidCallback? onTap,
  }) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (value.isNotEmpty)
              Text(
                value,
                style: TextStyle(color: colors.textSecondary, fontSize: 13),
              ),
            if (onTap != null) ...[
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                color: colors.textTertiary,
                size: 18,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _settingsToggle({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(color: colors.textTertiary, fontSize: 11),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: color,
            activeTrackColor: color.withOpacity(0.3),
            inactiveThumbColor: colors.textTertiary,
            inactiveTrackColor: colors.border,
          ),
        ],
      ),
    );
  }

  Widget _accentColorRow() {
    final colors = context.colors;
    final currentAccent = ref.watch(accentColorProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: currentAccent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.palette_outlined,
                  color: currentAccent,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Accent Color',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'Personalize the app\'s highlight color',
                      style: TextStyle(
                        color: colors.textTertiary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (currentAccent.value !=
                  AccentColorNotifier.defaultAccent.value)
                GestureDetector(
                  onTap: () =>
                      ref.read(accentColorProvider.notifier).resetToDefault(),
                  child: Text(
                    'Reset',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: accentColorPresets.map((swatch) {
              final isSelected = swatch.value == currentAccent.value;
              return GestureDetector(
                onTap: () =>
                    ref.read(accentColorProvider.notifier).setAccent(swatch),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: swatch,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? colors.textPrimary
                          : Colors.transparent,
                      width: 2.5,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: swatch.withOpacity(0.5),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 16,
                        )
                      : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // LOGOUT BUTTON
  // ─────────────────────────────────────────
  Widget _buildLogoutButton() {
    final colors = context.colors;
    return GestureDetector(
      onTap: _logout,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: colors.danger.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.danger.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout_rounded, color: colors.danger, size: 20),
            const SizedBox(width: 10),
            Text(
              'Sign Out',
              style: TextStyle(
                color: colors.danger,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
