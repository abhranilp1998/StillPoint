import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'analytics/analytics_screen.dart';
import 'history/history_screen.dart';
import 'home/home_screen.dart';
import 'logging/quick_log_sheet.dart';
import 'security/lock_screen.dart';
import 'settings/privacy_settings_screen.dart';
import 'support/support_screen.dart';
import '../state/app_controller.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  int _index = 0;
  bool _unlocked = false;

  static const _screens = [
    HomeScreen(),
    AnalyticsScreen(),
    SupportScreen(),
    HistoryScreen(),
    PrivacySettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (mounted) {
        setState(() => _unlocked = false);
      } else {
        _unlocked = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref
        .watch(appControllerProvider)
        .maybeWhen(data: (state) => state.settings, orElse: () => null);
    final lockEnabled =
        settings != null &&
        (settings.biometricLock ||
            (settings.pinLock && settings.pinHash != null));

    if (lockEnabled && !_unlocked) {
      return LockScreen(
        settings: settings,
        onUnlocked: () => setState(() => _unlocked = true),
      );
    }

    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _index != 0) {
          setState(() => _index = 0);
        }
      },
      child: Scaffold(
        extendBody: true,
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: KeyedSubtree(key: ValueKey(_index), child: _screens[_index]),
        ),
        floatingActionButton: FloatingActionButton.large(
          tooltip: 'Quick log',
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          onPressed: () => showQuickLogSheet(context),
          child: const Icon(Icons.add_rounded),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          height: 78,
          onDestinationSelected: (value) => setState(() => _index = value),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights_rounded),
              label: 'Patterns',
            ),
            NavigationDestination(
              icon: Icon(Icons.self_improvement_outlined),
              selectedIcon: Icon(Icons.self_improvement_rounded),
              label: 'Support',
            ),
            NavigationDestination(
              icon: Icon(Icons.table_rows_outlined),
              selectedIcon: Icon(Icons.table_rows_rounded),
              label: 'History',
            ),
            NavigationDestination(
              icon: Icon(Icons.lock_outline_rounded),
              selectedIcon: Icon(Icons.lock_rounded),
              label: 'Privacy',
            ),
          ],
        ),
      ),
    );
  }
}
