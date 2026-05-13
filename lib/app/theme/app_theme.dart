import 'package:flutter/material.dart';

import 'package:stopgrinding/app/theme/app_theme_tokens.dart';

final class AppTheme {
  static ThemeData build() {
    const Color paper = Color(0xFFF7F2E7);
    const Color ink = Color(0xFF1D2433);
    const Color teal = Color(0xFF0E7C86);
    const Color coral = Color(0xFFF06B4F);
    const Color gold = Color(0xFFF2B441);
    const Color mint = Color(0xFF7ED7B9);

    final ColorScheme colorScheme = const ColorScheme.light(
      primary: teal,
      secondary: coral,
      surface: paper,
      onSurface: ink,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      error: Color(0xFFB2392A),
      onError: Colors.white,
    );

    const AppThemeTokens tokens = AppThemeTokens(
      canvasGradient: <Color>[
        Color(0xFFFFF1D6),
        Color(0xFFF7DAB1),
        Color(0xFFEFBE8E),
      ],
      heroGradient: <Color>[
        Color(0xFF0D7186),
        Color(0xFF15A6AA),
        Color(0xFF7ED7B9),
      ],
      panelBackground: Color(0xD9FFF9F0),
      panelStroke: Color(0xFF2F3B4B),
      panelShadow: Color(0x33252C3B),
      accent: gold,
      accentMuted: Color(0xFFE7C76A),
      warn: Color(0xFFD45B31),
      success: mint,
      chrome: Color(0xFFF9FAF2),
      radiusLarge: 28,
      radiusMedium: 22,
      radiusSmall: 14,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: Colors.transparent,
      fontFamily: 'Avenir Next',
      textTheme: const TextTheme(
        displaySmall: TextStyle(
          fontFamily: 'Marker Felt',
          fontSize: 38,
          height: 0.98,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
        headlineSmall: TextStyle(
          fontFamily: 'Marker Felt',
          fontSize: 26,
          height: 1.0,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
        titleLarge: TextStyle(
          fontFamily: 'Marker Felt',
          fontSize: 24,
          height: 1.0,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
        titleMedium: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.1,
          color: ink,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          height: 1.35,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          height: 1.35,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
      extensions: const <ThemeExtension<dynamic>>[tokens],
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.78),
        labelStyle: const TextStyle(fontWeight: FontWeight.w700),
        hintStyle: TextStyle(color: ink.withValues(alpha: 0.6)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.radiusSmall),
          borderSide: const BorderSide(color: Color(0xFF2F3B4B), width: 1.6),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.radiusSmall),
          borderSide: BorderSide(
            color: ink.withValues(alpha: 0.55),
            width: 1.4,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.radiusSmall),
          borderSide: const BorderSide(color: coral, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: coral,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.radiusSmall),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          side: const BorderSide(color: ink, width: 1.4),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.radiusSmall),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: teal,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ink,
        contentTextStyle: const TextStyle(
          color: paper,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusSmall),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return coral;
          }
          return paper;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return gold.withValues(alpha: 0.7);
          }
          return ink.withValues(alpha: 0.2);
        }),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
    );
  }
}
