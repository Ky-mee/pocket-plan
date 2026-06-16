import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pocket_plan/core/services/auth_services.dart';
import 'package:pocket_plan/core/services/database_service.dart';
import 'package:pocket_plan/models/user_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocket_plan/providers/theme_provider.dart';

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

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E3A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Sign Out',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Are you sure you want to sign out?',
          style: TextStyle(color: Color(0xFF9E9FBF), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF9E9FBF)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Sign Out',
              style: TextStyle(
                color: Color(0xFFFF6B6B),
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
    final ctrl = TextEditingController(text: _userModel?.name ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E3A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Edit Name',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Your full name',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
            filled: true,
            fillColor: Colors.white.withOpacity(0.06),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF6C63FF)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF9E9FBF)),
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
            child: const Text(
              'Save',
              style: TextStyle(
                color: Color(0xFF6C63FF),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditAllowanceDialog() {
    final ctrl = TextEditingController(
      text: _userModel?.monthlyAllowance.toString() ?? '',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E3A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Edit Monthly Allowance',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            prefixText: 'RM ',
            prefixStyle: const TextStyle(color: Color(0xFF6C63FF)),
            filled: true,
            fillColor: Colors.white.withOpacity(0.06),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF6C63FF)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF9E9FBF)),
            ),
          ),
          TextButton(
            onPressed: () async {
              final val = double.tryParse(ctrl.text);
              if (val != null && val > 0) {
                await _db.updateAllowance(_userId, val);
                await _loadData();
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text(
              'Save',
              style: TextStyle(
                color: Color(0xFF6C63FF),
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
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
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
                    color: const Color(0xFF6C63FF),
                    onTap: _showEditNameDialog,
                  ),
                  _settingsTile(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    value: FirebaseAuth.instance.currentUser?.email ?? '-',
                    color: const Color(0xFF6C63FF),
                    onTap: null,
                  ),
                  _settingsTile(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Monthly Allowance',
                    value:
                        'RM ${_userModel?.monthlyAllowance.toStringAsFixed(2) ?? '0.00'}',
                    color: const Color(0xFF6C63FF),
                    onTap: _showEditAllowanceDialog,
                  ),
                  _settingsTile(
                    icon: Icons.help_outline_rounded,
                    label: 'Help & Guide',
                    value: '',
                    color: const Color(0xFF6C63FF),
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
                      color: const Color(0xFF00D4AA),
                      value: _biometricEnabled,
                      onChanged: _toggleBiometric,
                    ),
                  _settingsTile(
                    icon: Icons.lock_outline_rounded,
                    label: 'Change Password',
                    value: '',
                    color: const Color(0xFF00D4AA),
                    onTap: () async {
                      final email = FirebaseAuth.instance.currentUser?.email;
                      if (email != null) {
                        await _authService.resetPassword(email);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                'Reset link sent to your email!',
                              ),
                              backgroundColor: const Color(0xFF00D4AA),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          );
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
                    color: const Color(0xFFFFB347),
                    value: _darkMode,
                    onChanged: _toggleDarkMode,
                  ),
                  _settingsToggle(
                    icon: Icons.notifications_outlined,
                    label: 'Budget Notifications',
                    subtitle: 'Get alerts when budget is exceeded',
                    color: const Color(0xFFFFB347),
                    value: _notificationsEnabled,
                    onChanged: _toggleNotifications,
                  ),
                  _settingsTile(
                    icon: Icons.currency_exchange_rounded,
                    label: 'Currency',
                    value: _userModel?.currency ?? 'MYR',
                    color: const Color(0xFFFFB347),
                    onTap: null,
                  ),
                ]),
                const SizedBox(height: 20),
                _buildSection('About', [
                  _settingsTile(
                    icon: Icons.info_outline_rounded,
                    label: 'App Version',
                    value: 'v1.0.0',
                    color: const Color(0xFF9E9FBF),
                    onTap: null,
                  ),
                  _settingsTile(
                    icon: Icons.school_outlined,
                    label: 'Developer',
                    value: 'UTeM FYP 2025/26',
                    color: const Color(0xFF9E9FBF),
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
    );
  }

  // ─────────────────────────────────────────
  // HEADER
  // ─────────────────────────────────────────
  Widget _buildHeader() {
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
          const Text(
            'Settings',
            style: TextStyle(
              color: Colors.white,
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
    final user = FirebaseAuth.instance.currentUser;
    final name = _userModel?.name ?? user?.displayName ?? 'User';
    final email = user?.email ?? '';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6C63FF), Color(0xFF4834D4)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withOpacity(0.35),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF9E9FBF),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
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
                        Divider(
                          color: Colors.white.withOpacity(0.05),
                          height: 1,
                          indent: 56,
                        ),
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
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (value.isNotEmpty)
              Text(
                value,
                style: const TextStyle(color: Color(0xFF9E9FBF), fontSize: 13),
              ),
            if (onTap != null) ...[
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF4A4A6A),
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF4A4A6A),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: color,
            activeTrackColor: color.withOpacity(0.3),
            inactiveThumbColor: const Color(0xFF4A4A6A),
            inactiveTrackColor: Colors.white.withOpacity(0.08),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // LOGOUT BUTTON
  // ─────────────────────────────────────────
  Widget _buildLogoutButton() {
    return GestureDetector(
      onTap: _logout,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: const Color(0xFFFF6B6B).withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFF6B6B).withOpacity(0.3)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout_rounded, color: Color(0xFFFF6B6B), size: 20),
            SizedBox(width: 10),
            Text(
              'Sign Out',
              style: TextStyle(
                color: Color(0xFFFF6B6B),
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
