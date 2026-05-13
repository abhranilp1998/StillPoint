import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'state/app_controller.dart';
import 'theme/app_theme.dart';
import 'ui/app_shell.dart';

class RecoveryApp extends ConsumerWidget {
  const RecoveryApp({super.key});

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
        if (!(settings?.reduceMotion ?? false) || child == null) {
          return child ?? const SizedBox.shrink();
        }
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child,
        );
      },
      home: const AppShell(),
    );
  }
}
