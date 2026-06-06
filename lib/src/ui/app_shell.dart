import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'analytics/analytics_screen.dart';
import 'history/history_screen.dart';
import 'home/home_screen.dart';
import 'logging/quick_log_sheet.dart';
import 'security/lock_screen.dart';
import 'settings/privacy_settings_screen.dart';
import 'trackers/tracker_catalog_screen.dart';
import '../state/app_controller.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, this.initiallyUnlocked = false});

  final bool initiallyUnlocked;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  int _index = 0;
  bool _unlocked = false;

  static const _screens = [
    HomeScreen(),
    TrackerCatalogScreen(),
    AnalyticsScreen(),
    HistoryScreen(),
    PrivacySettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _unlocked = widget.initiallyUnlocked;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initiallyUnlocked && !oldWidget.initiallyUnlocked) {
      _unlocked = true;
    }
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
          transitionBuilder: (child, animation) {
            final reduceMotion = MediaQuery.disableAnimationsOf(context);
            if (reduceMotion) {
              return FadeTransition(opacity: animation, child: child);
            }
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position:
                    Tween<Offset>(
                      begin: const Offset(0, .015),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                child: child,
              ),
            );
          },
          child: KeyedSubtree(key: ValueKey(_index), child: _screens[_index]),
        ),
        floatingActionButton: _index == 4
            ? null
            : FloatingActionButton(
                tooltip: 'Quick log',
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                onPressed: () => showQuickLogSheet(context),
                child: const Icon(Icons.add_rounded),
              ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        bottomNavigationBar: _EdgeNavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (value) => setState(() => _index = value),
        ),
      ),
    );
  }
}

class _EdgeNavigationBar extends StatelessWidget {
  const _EdgeNavigationBar({
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final radius = BorderRadius.circular(22);
    final glassColors = isDark
        ? [
            scheme.surfaceContainerHighest.withValues(alpha: .42),
            scheme.primaryContainer.withValues(alpha: .18),
            scheme.surface.withValues(alpha: .28),
          ]
        : [
            Colors.white.withValues(alpha: .66),
            scheme.primaryContainer.withValues(alpha: .30),
            scheme.secondaryContainer.withValues(alpha: .20),
          ];

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 14),
      child: Align(
        alignment: Alignment.bottomCenter,
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              boxShadow: [
                BoxShadow(
                  color: theme.shadowColor.withValues(
                    alpha: isDark ? .32 : .18,
                  ),
                  blurRadius: 34,
                  offset: const Offset(0, 18),
                ),
                BoxShadow(
                  color: scheme.primary.withValues(alpha: isDark ? .08 : .12),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: glassColors,
                    ),
                    borderRadius: radius,
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: .14)
                          : Colors.white.withValues(alpha: .74),
                    ),
                  ),
                  child: NavigationBarTheme(
                    data: theme.navigationBarTheme.copyWith(
                      indicatorColor: scheme.primary.withValues(
                        alpha: isDark ? .24 : .20,
                      ),
                      indicatorShape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: BorderSide(
                          color: isDark
                              ? Colors.white.withValues(alpha: .12)
                              : scheme.primary.withValues(alpha: .18),
                        ),
                      ),
                      iconTheme: WidgetStateProperty.resolveWith(
                        (states) => IconThemeData(
                          size: states.contains(WidgetState.selected) ? 27 : 25,
                          color: states.contains(WidgetState.selected)
                              ? scheme.primary
                              : scheme.onSurface.withValues(alpha: .78),
                        ),
                      ),
                      labelTextStyle: WidgetStateProperty.resolveWith(
                        (states) => TextStyle(
                          fontSize: 12,
                          fontWeight: states.contains(WidgetState.selected)
                              ? FontWeight.w900
                              : FontWeight.w700,
                          color: states.contains(WidgetState.selected)
                              ? scheme.primary
                              : scheme.onSurface.withValues(alpha: .72),
                        ),
                      ),
                    ),
                    child: NavigationBar(
                      selectedIndex: selectedIndex,
                      height: 74,
                      backgroundColor: Colors.transparent,
                      onDestinationSelected: onDestinationSelected,
                      destinations: const [
                        NavigationDestination(
                          icon: Icon(Icons.hourglass_empty_outlined),
                          selectedIcon: Icon(Icons.home_rounded),
                          label: 'Home',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.grid_view_outlined),
                          selectedIcon: Icon(Icons.grid_view_rounded),
                          label: 'Trackers',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.insights_outlined),
                          selectedIcon: Icon(Icons.insights_rounded),
                          label: 'Patterns',
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
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
