import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/biometric_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/transactions/add_transaction_screen.dart';
import 'screens/transactions/transaction_list_screen.dart';
import 'screens/budget/budget_screen.dart';
import 'screens/analytics/analytics_screen.dart';
import 'screens/ai_advisor/ai_advisor_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/nearby_places/nearby_places_screen.dart';
import 'screens/recurring/recurring_screen.dart';
import 'package:pocket_plan/providers/theme_provider.dart';
import 'package:pocket_plan/providers/accent_color_provider.dart';
import 'package:pocket_plan/screens/onboarding/onboarding_screen.dart';
import 'package:pocket_plan/screens/help/help_screen.dart';
import 'package:pocket_plan/core/themes/light_theme.dart';
import 'package:pocket_plan/core/themes/dark_theme.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:pocket_plan/core/services/notification_service.dart';
import 'package:pocket_plan/core/layout/desktop_shell.dart';

final RouteTracker _routeTracker = RouteTracker();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // Compile-time --dart-define values still work without a .env file.
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await NotificationService().initialize();

  runApp(const ProviderScope(child: PocketPlanApp()));
}

class PocketPlanApp extends ConsumerWidget {
  const PocketPlanApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final accent = ref.watch(accentColorProvider);
    return MaterialApp(
      title: 'PocketPlan',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(accent),
      darkTheme: buildDarkTheme(accent),
      themeMode: themeMode,
      navigatorKey: appNavigatorKey,
      navigatorObservers: [_routeTracker],
      // Web (wide screens): sidebar + wide content pane. Mobile: unchanged.
      builder: (context, child) => DesktopShell(
        tracker: _routeTracker,
        child: child ?? const SizedBox.shrink(),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/biometric': (context) => const BiometricScreen(),
        '/home': (context) => const HomeScreen(),
        '/add-transaction': (context) => const AddTransactionScreen(),
        '/transactions': (context) => const TransactionListScreen(),
        '/budget': (context) => const BudgetScreen(),
        '/analytics': (context) => const AnalyticsScreen(),
        '/ai-advisor': (context) => const AiAdvisorScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/nearby-places': (context) => const NearbyPlacesScreen(),
        '/recurring': (context) => const RecurringScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/help': (context) => const HelpScreen(),
      },
    );
  }
}
