import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Central design-token hub for the Fluent UI aesthetic.
///
/// Radius constants are the single source of truth — all widget themes
/// reference them so a one-line change here propagates everywhere.
class AppTheme {
  // ─── Colour seeds ────────────────────────────────────────────────────────
  static const _sage = Color(0xFF6A8F7A);
  static const _ink  = Color(0xFF1F2724);
  static const _warm = Color(0xFFC77D57);
  static const _blue = Color(0xFF4F8DAA);

  // ─── Radius tokens ───────────────────────────────────────────────────────
  /// Standard radius: cards, buttons, inputs, chips, list tiles.
  static const radius = BorderRadius.all(Radius.circular(16));

  /// Larger radius: dialogs, alert boxes, popup menus.
  static const cardRadius = BorderRadius.all(Radius.circular(20));

  /// Sheet radius: top edge of bottom sheets and modals.
  static const sheetRadius = BorderRadius.vertical(top: Radius.circular(24));

  // ─── Public factories ─────────────────────────────────────────────────────
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _sage,
      brightness: Brightness.light,
      primary: _sage,
      secondary: _blue,
      tertiary: _warm,
      surface: const Color(0xFFFFFCF7),
      dynamicSchemeVariant: DynamicSchemeVariant.expressive,
    );
    return _base(scheme).copyWith(
      scaffoldBackgroundColor: const Color(0xFFF4F1EA),
      // Softer shadow for light — depth without heaviness
      shadowColor: Colors.black.withValues(alpha: .08),
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
      dynamicSchemeVariant: DynamicSchemeVariant.expressive,
    );
    return _base(scheme).copyWith(
      scaffoldBackgroundColor: const Color(0xFF101412),
      // Softer shadow for dark — avoids overly inky halos
      shadowColor: Colors.black.withValues(alpha: .20),
    );
  }

  // ─── Base theme ───────────────────────────────────────────────────────────
  static ThemeData _base(ColorScheme scheme) {
    final textTheme = _buildTextTheme(scheme);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      // Inter via google_fonts — used as the app-wide font family
      textTheme: textTheme,
      visualDensity: VisualDensity.standard,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          TargetPlatform.iOS:     CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS:   CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux:   FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        },
      ),

      // ── AppBar ────────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.inter(
          color: scheme.onSurface,
          fontSize: 21,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.3,
        ),
      ),

      // ── Card ──────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),

      // ── Buttons ───────────────────────────────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(56, 50),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 50),
          shape: RoundedRectangleBorder(borderRadius: radius),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .72)),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size.square(48),
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
      ),

      // ── Chips ─────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHighest.withValues(alpha: .54),
        selectedColor: scheme.primaryContainer.withValues(alpha: .82),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .55)),
        checkmarkColor: scheme.primary,
        labelStyle: GoogleFonts.inter(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),

      // ── Inputs ────────────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: .48),
        hintStyle: GoogleFonts.inter(color: scheme.onSurfaceVariant),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: .35),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(
            color: scheme.primary.withValues(alpha: .60),
            width: 1.5,
          ),
        ),
      ),

      // ── List tiles ────────────────────────────────────────────────────────
      listTileTheme: ListTileThemeData(
        minLeadingWidth: 24,
        horizontalTitleGap: 12,
        iconColor: scheme.onSurfaceVariant,
        titleTextStyle: GoogleFonts.inter(
          color: scheme.onSurface,
          fontSize: 16,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
        subtitleTextStyle: GoogleFonts.inter(
          color: scheme.onSurfaceVariant,
          fontSize: 13,
          height: 1.35,
          letterSpacing: 0,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),

      // ── Switch ────────────────────────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbIcon: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? const Icon(Icons.check_rounded, size: 16)
              : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary.withValues(alpha: .45)
              : scheme.surfaceContainerHighest,
        ),
      ),

      // ── Navigation bar ────────────────────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: scheme.surface.withValues(alpha: .94),
        indicatorColor: scheme.primaryContainer.withValues(alpha: .7),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: states.contains(WidgetState.selected) ? 25 : 23,
            color: states.contains(WidgetState.selected)
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => GoogleFonts.inter(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w600,
          ),
        ),
      ),

      // ── Snack bar ─────────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: GoogleFonts.inter(
          color: scheme.onInverseSurface,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      // ── Popup menu ────────────────────────────────────────────────────────
      popupMenuTheme: PopupMenuThemeData(
        elevation: 8,
        color: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: cardRadius),
      ),

      // ── Divider ───────────────────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: .54),
        thickness: 1,
        space: 1,
      ),

      // ── FAB ───────────────────────────────────────────────────────────────
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 4,
        highlightElevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),

      // ── Dialog ───────────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        elevation: 8,
        surfaceTintColor: Colors.transparent,
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(borderRadius: cardRadius),
      ),

      // ── Time / date pickers ───────────────────────────────────────────────
      timePickerTheme: TimePickerThemeData(
        backgroundColor: scheme.surface,
        dialBackgroundColor: scheme.surfaceContainerHighest.withValues(
          alpha: .54,
        ),
        dayPeriodShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        hourMinuteShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: cardRadius),
      ),

      // ── Bottom sheet ─────────────────────────────────────────────────────
      bottomSheetTheme: const BottomSheetThemeData(
        showDragHandle: true,
        shape: RoundedRectangleBorder(borderRadius: sheetRadius),
      ),
    );
  }

  // ─── Text theme ───────────────────────────────────────────────────────────
  /// All type styles use Inter. Weights follow the Fluent ramp:
  ///   display → 800, headline → 900, title → 800/700, body → 600, label → 700+
  static TextTheme _buildTextTheme(ColorScheme scheme) {
    final base = scheme.brightness == Brightness.dark ? Colors.white : _ink;
    final muted = base.withValues(alpha: .72);

    return GoogleFonts.interTextTheme(
      TextTheme(
        // Display
        displayLarge:  TextStyle(fontSize: 57, fontWeight: FontWeight.w800, letterSpacing: -1.5, color: base),
        displayMedium: TextStyle(fontSize: 45, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: base),
        displaySmall:  TextStyle(fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: 0,    color: base),
        // Headline
        headlineLarge:  TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -0.5, color: base),
        headlineMedium: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.3, color: base),
        headlineSmall:  TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 0,    color: base),
        // Title
        titleLarge:  TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 0, color: base),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0, color: base),
        titleSmall:  TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0, color: base),
        // Body
        bodyLarge:  TextStyle(fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: 0, height: 1.5, color: base),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0, height: 1.5, color: base),
        bodySmall:  TextStyle(fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0, height: 1.4, color: muted),
        // Label
        labelLarge:  TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0, color: base),
        labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0, color: base),
        labelSmall:  TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.2, color: muted),
      ),
    );
  }
}
