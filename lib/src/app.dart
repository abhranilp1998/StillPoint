import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      home: const AppShell(),
    );
  }
}
