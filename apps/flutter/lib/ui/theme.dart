import 'package:flutter/material.dart';

/// Brand palette:
/// - Main: vibrant yellow / amber
/// - Secondary: cool metallic grey / silver
/// - Accent: warm reddish-brown / wood
class AppTheme {
  /// Vibrant amber (primary actions, FAB, focus)
  static const amber = Color(0xFFF5B301);
  static const amberDeep = Color(0xFFE Pan0A00); // typo fix below

  /// Cool metallic grey / silver
  static const silver = Color(0xFFC5CBD3);
  static const silverMuted = Color(0xFF9AA3AD);
  static const metal = Color(0xFF2A2F38);
  static const metalDeep = Color(0xFF161A20);

  /// Warm wood / reddish-brown
  static const wood = Color(0xFF8B5A3C);
  static const woodDeep = Color(0xFF5C3A28);
  static const woodLight = Color(0xFFB07A55);

  static const seed = amber;
  static const bgDeep = metalDeep;
  static const bgMid = metal;
  static const glassFill = Color(0x18C5CBD3);
  static const glassBorder = Color(0x33C5CBD3);

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: amber,
      brightness: Brightness.dark,
      primary: amber,
      onPrimary: const Color(0xFF1A1200),
      secondary: silver,
      onSecondary: metalDeep,
      tertiary: wood,
      onTertiary: Colors.white,
      surface: metal,
      onSurface: silver,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: bgDeep,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: silver,
        iconTheme: IconThemeData(color: silver),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: metal.withValues(alpha: 0.92),
        indicatorColor: amber.withValues(alpha: 0.28),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 11, color: silver.withValues(alpha: 0.9)),
        ),
        iconTheme: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.selected)) {
            return const IconThemeData(color: amber);
          }
          return IconThemeData(color: silver.withValues(alpha: 0.7));
        }),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: amber,
        foregroundColor: const Color(0xFF1A1200),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: amber,
          foregroundColor: const Color(0xFF1A1200),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: silver.withValues(alpha: 0.08),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: silver.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: silver.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: amber, width: 1.4),
        ),
        hintStyle: TextStyle(color: silver.withValues(alpha: 0.4)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: wood.withValues(alpha: 0.35),
        side: BorderSide(color: woodLight.withValues(alpha: 0.5)),
        labelStyle: const TextStyle(color: silver),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: metal,
        contentTextStyle: const TextStyle(color: silver),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
