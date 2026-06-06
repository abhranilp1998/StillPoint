import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'state/app_controller.dart';
import 'theme/app_theme.dart';
import 'ui/app_shell.dart';
import 'ui/onboarding/privacy_consent_screen.dart';

class StillpointApp extends ConsumerWidget {
  const StillpointApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref
        .watch(appControllerProvider)
        .maybeWhen(data: (state) => state.settings, orElse: () => null);

    final themeMode = settings?.useSystemTheme ?? true
        ? ThemeMode.system
        : (settings?.darkMode ?? false ? ThemeMode.dark : ThemeMode.light);

    return MaterialApp(
      title: 'Stillpoint',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      builder: (context, child) {
        final baseChild = child ?? const SizedBox.shrink();
        final content = settings?.reduceMotion ?? false
            ? MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: baseChild,
              )
            : baseChild;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final overlayStyle = isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark;

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: overlayStyle.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarDividerColor: Colors.transparent,
            systemStatusBarContrastEnforced: false,
            systemNavigationBarContrastEnforced: false,
          ),
          child: content,
        );
      },
      home: const StartupGate(),
    );
  }
}

class StartupGate extends ConsumerStatefulWidget {
  const StartupGate({super.key});

  @override
  ConsumerState<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends ConsumerState<StartupGate> {
  bool _startUnlocked = false;

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appControllerProvider);
    return appState.when(
      data: (state) {
        if (!state.settings.privacyConsentCompleted) {
          return PrivacyConsentScreen(
            settings: state.settings,
            onComplete: () => setState(() => _startUnlocked = true),
          );
        }
        return AppShell(initiallyUnlocked: _startUnlocked);
      },
      loading: () => const _StartupStatusScreen(),
      error: (error, stackTrace) => _StartupStatusScreen(
        icon: Icons.error_outline_rounded,
        title: 'Stillpoint could not open',
        body: 'Please close the app and try again.',
      ),
    );
  }
}

class _StartupStatusScreen extends StatelessWidget {
  const _StartupStatusScreen({
    this.icon,
    this.title = 'Opening Stillpoint',
    this.body = 'Preparing your private space.',
  });

  final IconData? icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon == null)
                  const CircularProgressIndicator()
                else
                  Icon(icon, size: 40, color: theme.colorScheme.error),
                const SizedBox(height: 18),
                Text(title, style: theme.textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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
