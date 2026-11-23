import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocket_plan/core/layout/desktop_shell.dart';
import 'package:pocket_plan/core/services/auth_services.dart';
import 'package:pocket_plan/core/services/database_service.dart';
import 'package:pocket_plan/core/themes/app_colors.dart';
import 'package:pocket_plan/core/utils/amount_input.dart';
import 'package:pocket_plan/core/utils/budget_cycle.dart';
import 'package:pocket_plan/core/utils/currency_formatter.dart';
import 'package:pocket_plan/models/user_model.dart';
import 'package:pocket_plan/providers/accent_color_provider.dart';
import 'package:pocket_plan/providers/currency_provider.dart';
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
  bool _biometricAvailable = false;
  bool _carryForwardEnabled = true;
  int _budgetStartDay = 1;

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
    final user = await _db.getUser(_userId);
    final prefs = await _db.getPreferences(_userId);
    final biometricAvailable = await _authService.isBiometricAvailable();
    final biometricEnabled = await _authService.isBiometricEnabled(_userId);

    if (user != null) {
      await ref.read(currencyProvider.notifier).syncFromProfile(user.currency);
    }

    if (mounted) {
      setState(() {
        _userModel = user;
        _biometricAvailable = biometricAvailable;
        _biometricEnabled = biometricEnabled;
        _notificationsEnabled = prefs['notificationsEnabled'] ?? true;
        _carryForwardEnabled = prefs['carryForwardEnabled'] ?? true;
        _budgetStartDay = BudgetCycle.clampStartDay(
          (prefs['budgetStartDay'] as num?)?.toInt() ?? 1,
        );
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

  Future<void> _showDeleteAccountDialog() async {
    final colors = context.colors;
    final passCtrl = TextEditingController();
    bool obscure = true;
    bool deleting = false;
    String? errorMsg;

    await showDialog<void>(
      context: context,
      barrierDismissible: !deleting,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: colors.surfaceAlt,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Delete Account',
            style: TextStyle(
              color: colors.danger,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This permanently deletes your PocketPlan profile, budget settings, and all transaction history. This cannot be undone.',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: passCtrl,
                obscureText: obscure,
                style: TextStyle(color: colors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Confirm your password',
                  hintStyle: TextStyle(color: colors.textTertiary),
                  filled: true,
                  fillColor: colors.surface,
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: colors.textSecondary,
                      size: 18,
                    ),
                    onPressed: () => setDialogState(() => obscure = !obscure),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              if (errorMsg != null) ...[
                const SizedBox(height: 10),
                Text(
                  errorMsg!,
                  style: TextStyle(color: colors.danger, fontSize: 12),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: deleting ? null : () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: TextStyle(color: colors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: deleting
                  ? null
                  : () async {
                      final password = passCtrl.text;
                      if (password.isEmpty) {
                        setDialogState(
                          () => errorMsg = 'Please enter your password.',
                        );
                        return;
                      }
                      setDialogState(() {
                        deleting = true;
                        errorMsg = null;
                      });
                      try {
                        await _authService.deleteAccount(password: password);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          Navigator.of(
                            context,
                          ).pushNamedAndRemoveUntil('/login', (r) => false);
                        }
                      } catch (e) {
                        final msg = e.toString();
                        setDialogState(() {
                          deleting = false;
                          if (msg.contains('wrong-password') ||
                              msg.contains('invalid-credential')) {
                            errorMsg = 'Incorrect password. Please try again.';
                          } else {
                            errorMsg =
                                'Could not delete account right now. Please try again.';
                          }
                        });
                      }
                    },
              child: deleting
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.danger,
                      ),
                    )
                  : Text(
                      'Delete Permanently',
                      style: TextStyle(
                        color: colors.danger,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
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

  void _showEditAllowanceDialog(String currency) {
    final colors = context.colors;
    final symbol = CurrencyFormatter.symbol(currency);
    final ctrl = TextEditingController(
      text: _userModel?.monthlyAllowance.toString() ?? '',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surfaceAlt,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Edit Monthly Income',
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
            prefixText: '$symbol ',
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
                        content: const Text('Failed to update monthly income.'),
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

  void _showLifeStagePicker() {
    final colors = context.colors;
    final current = _userModel?.lifeStage ?? 'general';
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Select Life Stage',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Helps tailor your AI Financial Advisor suggestions.',
              style: TextStyle(color: colors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 12),
            ...UserLifeStage.labels.entries.map((entry) {
              final selected = entry.key == current;
              return ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                title: Text(
                  entry.value,
                  style: TextStyle(
                    color: selected ? colors.accent : colors.textPrimary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                trailing: selected
                    ? Icon(Icons.check_rounded, color: colors.accent)
                    : null,
                onTap: () async {
                  Navigator.pop(ctx);
                  await _db.updateUser(_userId, {'lifeStage': entry.key});
                  await _loadData();
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showCurrencyPicker(String currentCurrency) {
    final colors = context.colors;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(ctx).height * 0.65,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Select Currency',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: kSupportedCurrencies.map((c) {
                      final selected = c.code == currentCurrency;
                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        leading: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: selected
                                ? colors.accent.withOpacity(0.15)
                                : colors.surfaceAlt,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              c.symbol,
                              style: TextStyle(
                                color: selected
                                    ? colors.accent
                                    : colors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          '${c.code} — ${c.name}',
                          style: TextStyle(
                            color: selected
                                ? colors.accent
                                : colors.textPrimary,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                        trailing: selected
                            ? Icon(Icons.check_rounded, color: colors.accent)
                            : null,
                        onTap: () async {
                          Navigator.pop(ctx);
                          await ref
                              .read(currencyProvider.notifier)
                              .setCurrency(c.code);
                          await _db.updateUser(_userId, {'currency': c.code});
                          await _loadData();
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showThemePicker(ThemeMode currentMode) {
    final colors = context.colors;
    const options = <(ThemeMode, String, IconData)>[
      (ThemeMode.system, 'System Default', Icons.brightness_auto_outlined),
      (ThemeMode.light, 'Light Mode', Icons.light_mode_outlined),
      (ThemeMode.dark, 'Dark Mode', Icons.dark_mode_outlined),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Appearance',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            ...options.map((opt) {
              final selected = opt.$1 == currentMode;
              return ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                leading: Icon(
                  opt.$3,
                  color: selected ? colors.accent : colors.textSecondary,
                ),
                title: Text(
                  opt.$2,
                  style: TextStyle(
                    color: selected ? colors.accent : colors.textPrimary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                trailing: selected
                    ? Icon(Icons.check_rounded, color: colors.accent)
                    : null,
                onTap: () async {
                  Navigator.pop(ctx);
                  await ref.read(themeProvider.notifier).setThemeMode(opt.$1);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  static String _ordinalDay(int day) {
    if (day >= 11 && day <= 13) return '${day}th';
    switch (day % 10) {
      case 1:
        return '${day}st';
      case 2:
        return '${day}nd';
      case 3:
        return '${day}rd';
      default:
        return '${day}th';
    }
  }

  void _showBudgetStartDayPicker() {
    final colors = context.colors;
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Budget Cycle Start Day',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Choose the day your salary or monthly income arrives (1st–28th). Monthly resets and cycle progress will align to this day.',
              style: TextStyle(color: colors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(28, (index) {
                final day = index + 1;
                final selected = day == _budgetStartDay;
                return GestureDetector(
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _db.updateBudgetStartDay(_userId, day);
                    if (mounted) setState(() => _budgetStartDay = day);
                  },
                  child: Container(
                    width: 46,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? colors.accent : colors.surfaceAlt,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected ? colors.accent : colors.border,
                      ),
                    ),
                    child: Text(
                      '$day',
                      style: TextStyle(
                        color: selected ? Colors.white : colors.textPrimary,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  void _showPrivacyDialog() {
    final colors = context.colors;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surfaceAlt,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Privacy & AI Disclaimer',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          '• Data Storage: Your profile, budgets, and transactions are stored privately under your Firebase account.\n\n'
          '• AI Advisor: When you chat with PocketPlan AI, your conversation and budget summary are processed via PocketPlan\'s secure Cloudflare Worker proxy using Google Gemini. Guidance is informational only and not licensed financial advice.\n\n'
          '• Nearby Places: Location coordinates are only used on demand to fetch nearby places from OpenStreetMap.\n\n'
          '• Account Deletion: You can permanently delete your account and all data anytime from Settings → Security.',
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 13,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close', style: TextStyle(color: colors.accent)),
          ),
        ],
      ),
    );
  }

  String _themeLabel(ThemeMode mode) => switch (mode) {
    ThemeMode.light => 'Light',
    ThemeMode.dark => 'Dark',
    ThemeMode.system => 'System',
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final currency = ref.watch(currencyProvider);
    final themeMode = ref.watch(themeProvider);

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
                    _buildProfileCard(currency),
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
                        icon: Icons.badge_outlined,
                        label: 'Life Stage',
                        value: UserLifeStage.labelOf(_userModel?.lifeStage),
                        color: colors.accent,
                        onTap: _showLifeStagePicker,
                      ),
                      _settingsTile(
                        icon: Icons.account_balance_wallet_outlined,
                        label: 'Monthly Income',
                        value: CurrencyFormatter.format(
                          _userModel?.monthlyAllowance ?? 0,
                          code: currency,
                        ),
                        color: colors.accent,
                        onTap: () => _showEditAllowanceDialog(currency),
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
                          final email =
                              FirebaseAuth.instance.currentUser?.email;
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
                      _settingsTile(
                        icon: Icons.delete_forever_outlined,
                        label: 'Delete Account',
                        value: 'Permanent',
                        color: colors.danger,
                        onTap: _showDeleteAccountDialog,
                      ),
                    ]),
                    const SizedBox(height: 20),
                    _buildSection('Preferences', [
                      _settingsTile(
                        icon: Icons.brightness_6_outlined,
                        label: 'Appearance',
                        value: _themeLabel(themeMode),
                        color: colors.warning,
                        onTap: () => _showThemePicker(themeMode),
                      ),
                      _accentColorRow(),
                      _settingsTile(
                        icon: Icons.calendar_today_rounded,
                        label: 'Budget Start Day',
                        value: '${_ordinalDay(_budgetStartDay)} of cycle',
                        color: colors.info,
                        onTap: _showBudgetStartDayPicker,
                      ),
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
                        value: currency,
                        color: colors.warning,
                        onTap: () => _showCurrencyPicker(currency),
                      ),
                      _settingsTile(
                        icon: Icons.privacy_tip_outlined,
                        label: 'Privacy & AI Disclaimer',
                        value: '',
                        color: colors.info,
                        onTap: _showPrivacyDialog,
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

  Widget _buildProfileCard(String currency) {
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
                    '${CurrencyFormatter.format(_userModel?.monthlyAllowance ?? 0, code: currency)} / month',
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
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
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.textSecondary, fontSize: 13),
                ),
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
            activeThumbColor: color,
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
              if (currentAccent.toARGB32() !=
                  AccentColorNotifier.defaultAccent.toARGB32())
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
              final isSelected = swatch.toARGB32() == currentAccent.toARGB32();
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
