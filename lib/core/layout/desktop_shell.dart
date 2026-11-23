import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:pocket_plan/core/services/auth_services.dart';

/// Window width (logical px) from which the web build switches to the
/// desktop layout (sidebar + wide content pane).
const double kDesktopBreakpoint = 900;

/// Max width of the content pane next to the sidebar.
const double kContentMaxWidth = 1280;

const double _sidebarWidth = 248;

bool _isWideWeb(BuildContext context) =>
    kIsWeb && MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;

/// Marks the subtree rendered inside the desktop content pane.
class DesktopScope extends InheritedWidget {
  const DesktopScope({super.key, required super.child});

  @override
  bool updateShouldNotify(DesktopScope oldWidget) => false;
}

/// True when [context] is inside the desktop content pane (sidebar shown).
/// Always false on Android/iOS, so the mobile app is unchanged. Use this
/// (not window width) in screens: the pane overrides MediaQuery's width.
bool isDesktopLayout(BuildContext context) =>
    context.dependOnInheritedWidgetOfExactType<DesktopScope>() != null;

/// Global navigator key so the sidebar (which sits above the Navigator)
/// can navigate.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Tracks the name of the page route currently on top (ignores dialogs,
/// bottom sheets and other popup routes).
class RouteTracker extends NavigatorObserver {
  final ValueNotifier<String?> current = ValueNotifier<String?>(null);
  Route<dynamic>? _top;

  void _set(Route<dynamic>? route) {
    if (route is! PageRoute || route.settings.name == null) return;
    _top = route;
    final name = route.settings.name;
    // Defer: observers can fire while the framework is building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (current.value != name) current.value = name;
    });
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _set(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _set(newRoute);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute) _set(previousRoute);
  }

  // pushNamedAndRemoveUntil reports removed routes AFTER the new push, with
  // their old neighbours as previousRoute. Only react if the removed route
  // was the one currently on top.
  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (identical(route, _top)) _set(previousRoute);
  }
}

class _NavItem {
  final String route;
  final String label;
  final IconData icon;
  const _NavItem(this.route, this.label, this.icon);
}

const _items = <_NavItem>[
  _NavItem('/home', 'Home', Icons.dashboard_rounded),
  _NavItem('/transactions', 'Transactions', Icons.receipt_long_rounded),
  _NavItem('/budget', 'Budget', Icons.account_balance_wallet_rounded),
  _NavItem('/analytics', 'Analytics', Icons.insights_rounded),
  _NavItem('/ai-advisor', 'AI Advisor', Icons.auto_awesome_rounded),
  _NavItem('/nearby-places', 'Food Nearby', Icons.restaurant_rounded),
  _NavItem('/settings', 'Settings', Icons.settings_rounded),
  _NavItem('/help', 'Help', Icons.help_outline_rounded),
];

// Routes that belong to the signed-in app (sidebar visible on these).
const _appRoutes = <String>{
  '/home',
  '/transactions',
  '/add-transaction',
  '/budget',
  '/analytics',
  '/ai-advisor',
  '/nearby-places',
  '/settings',
  '/help',
};

// Signed-out routes shown as a split screen: brand panel + form.
const _splitRoutes = <String>{'/login', '/register', '/onboarding'};

/// Wraps the Navigator. On wide web screens, shows a sidebar and a
/// centred content pane for signed-in pages; otherwise passes [child]
/// through untouched.
class DesktopShell extends StatelessWidget {
  final Widget child;
  final RouteTracker tracker;
  const DesktopShell({super.key, required this.child, required this.tracker});

  @override
  Widget build(BuildContext context) {
    if (!_isWideWeb(context)) return child;

    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);

    return ValueListenableBuilder<String?>(
      valueListenable: tracker.current,
      builder: (context, route, _) {
        final showSidebar = route != null && _appRoutes.contains(route);

        // Splash (and the very first frame): full window.
        if (route == null || route == '/') return child;

        if (_splitRoutes.contains(route)) {
          return Material(
            color: theme.scaffoldBackgroundColor,
            child: Row(
              children: [
                const Expanded(flex: 5, child: _BrandPanel()),
                Expanded(
                  flex: 4,
                  child: ColoredBox(
                    color: theme.scaffoldBackgroundColor,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: child,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        if (!showSidebar) {
          // Anything else signed-out: centre a comfortably wide column.
          return ColoredBox(
            color: theme.scaffoldBackgroundColor,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: child,
              ),
            ),
          );
        }

        final available = size.width - _sidebarWidth;
        final paneWidth = available < kContentMaxWidth
            ? available
            : kContentMaxWidth;

        return Material(
          color: theme.scaffoldBackgroundColor,
          child: Row(
            children: [
              _Sidebar(currentRoute: route),
              VerticalDivider(width: 1, color: theme.dividerColor),
              Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: paneWidth,
                    // Screens read their width from MediaQuery; give them
                    // the pane width, not the whole window.
                    child: DesktopScope(
                      child: MediaQuery(
                        data: MediaQuery.of(
                          context,
                        ).copyWith(size: Size(paneWidth, size.height)),
                        child: child,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Sidebar extends StatelessWidget {
  final String currentRoute;
  const _Sidebar({required this.currentRoute});

  void _go(String route) {
    final nav = appNavigatorKey.currentState;
    if (nav == null || route == currentRoute) return;
    // Sidebar destinations are top-level. Keep Home underneath so the
    // screens' back arrows still have somewhere to go.
    if (route == '/home') {
      nav.pushNamedAndRemoveUntil(route, (_) => false);
    } else {
      nav.pushNamedAndRemoveUntil(route, ModalRoute.withName('/home'));
    }
  }

  Future<void> _logout() async {
    await AuthService().logout();
    appNavigatorKey.currentState?.pushNamedAndRemoveUntil(
      '/login',
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final user = FirebaseAuth.instance.currentUser;
    final name = (user?.displayName?.trim().isNotEmpty ?? false)
        ? user!.displayName!
        : (user?.email ?? 'PocketPlan');

    return Material(
      color: cs.surface,
      child: SizedBox(
        width: _sidebarWidth,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 20, 12, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: cs.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.account_balance_wallet_rounded,
                          color: cs.onPrimary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'PocketPlan',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => appNavigatorKey.currentState?.pushNamed(
                      '/add-transaction',
                    ),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add transaction'),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    children: [
                      for (final item in _items)
                        _SidebarTile(
                          item: item,
                          selected: item.route == currentRoute,
                          onTap: () => _go(item.route),
                        ),
                    ],
                  ),
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: 4),
                _SidebarTile(
                  item: const _NavItem('', 'Log out', Icons.logout_rounded),
                  selected: false,
                  onTap: _logout,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;
  const _SidebarTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = selected ? cs.primary : cs.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected ? cs.primary.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(item.icon, size: 20, color: fg),
                const SizedBox(width: 12),
                Text(
                  item.label,
                  style: TextStyle(
                    color: fg,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


/// Left half of the login / sign-up / onboarding split screen.
class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  static const _features = <(IconData, String)>[
    (Icons.pie_chart_rounded, 'Flexible monthly budget splits'),
    (Icons.insights_rounded, 'Smart spending forecast'),
    (Icons.auto_awesome_rounded, 'AI financial advisor'),
    (Icons.restaurant_rounded, 'Affordable food spots near you'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6C63FF), Color(0xFF4834D4)],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, cons) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: cons.maxHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 48),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Image.asset(
                        'assets/icons/Pocket_plan_app_logo.png',
                        width: 64,
                        height: 64,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.account_balance_wallet_rounded,
                          color: Colors.white,
                          size: 48,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        'PocketPlan',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 56),
                  const Text(
                    'Plan your monthly income,\nthe smart way.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      height: 1.2,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Track spending, stay on budget and plan for your '
                    'essential needs at every stage of life.',
                    style: TextStyle(
                      color: Color(0xCCFFFFFF),
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 40),
                  for (final f in _features)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0x26FFFFFF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(f.$1, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 14),
                          Text(
                            f.$2,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
