import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/transactions/add_transaction_screen.dart';
import 'screens/transactions/transaction_list_screen.dart';
import 'screens/budget/budget_screen.dart';
import 'screens/analytics/analytics_screen.dart';
import 'screens/ai_advisor/ai_advisor_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/nearby_places/nearby_places_screen.dart';
import 'package:pocket_plan/providers/theme_provider.dart';
import 'package:pocket_plan/screens/onboarding/onboarding_screen.dart';
import 'package:pocket_plan/screens/help/help_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const ProviderScope(child: PocketPlanApp()));
}

class PocketPlanApp extends ConsumerWidget {
  const PocketPlanApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    return MaterialApp(
      title: 'PocketPlan',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        // Smooth page transitions app-wide
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      themeMode: themeMode,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const HomeScreen(),
        '/add-transaction': (context) => const AddTransactionScreen(),
        '/transactions': (context) => const TransactionListScreen(),
        '/budget': (context) => const BudgetScreen(),
        '/analytics': (context) => const AnalyticsScreen(),
        '/ai-advisor': (context) => const AiAdvisorScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/nearby-places': (context) => const NearbyPlacesScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/help': (context) => const HelpScreen(),
      },
    );
  }
}
