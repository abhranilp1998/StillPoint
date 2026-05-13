import 'package:flutter/material.dart';

class AppTheme {
  static const _sage = Color(0xFF6A8F7A);
  static const _ink = Color(0xFF1F2724);
  static const _warm = Color(0xFFC77D57);
  static const _blue = Color(0xFF4F8DAA);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _sage,
      brightness: Brightness.light,
      primary: _sage,
      secondary: _blue,
      tertiary: _warm,
      surface: const Color(0xFFFBFAF7),
    );
    return _base(scheme).copyWith(
      scaffoldBackgroundColor: const Color(0xFFF5F3EE),
      shadowColor: Colors.black.withValues(alpha: .12),
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _sage,
      brightness: Brightness.dark,
      primary: const Color(0xFF9DC8AA),
      secondary: const Color(0xFF88C4DE),
      tertiary: const Color(0xFFE2A17E),
      surface: const Color(0xFF161B19),
    );
    return _base(scheme).copyWith(
      scaffoldBackgroundColor: const Color(0xFF101412),
      shadowColor: Colors.black.withValues(alpha: .28),
    );
  }

  static ThemeData _base(ColorScheme scheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'Roboto',
      visualDensity: VisualDensity.standard,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(56, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: .45),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: scheme.surface.withValues(alpha: .94),
        indicatorColor: scheme.primaryContainer.withValues(alpha: .7),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w600,
          ),
        ),
      ),
      textTheme:
          const TextTheme(
            headlineLarge: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
            headlineMedium: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
            titleLarge: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
            titleMedium: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
            bodyLarge: TextStyle(fontSize: 16, letterSpacing: 0, height: 1.35),
            bodyMedium: TextStyle(fontSize: 14, letterSpacing: 0, height: 1.35),
            labelLarge: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ).apply(
            bodyColor: scheme.brightness == Brightness.dark
                ? Colors.white.withValues(alpha: .92)
                : _ink,
            displayColor: scheme.brightness == Brightness.dark
                ? Colors.white
                : _ink,
          ),
    );
  }
}
