import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Refined Marsh palette (2025 rebrand)
  static const Color darkCobalt = Color(0xFF002C77);
  static const Color persianBlue = Color(0xFF016D9E);
  static const Color fluorescentTeal = Color(0xFF00A8C7);
  static const Color angelina = Color(0xFFA7E2F0);

  // Legacy aliases for backwards compatibility
  static const Color primaryBlue = darkCobalt;
  static const Color secondaryBlue = persianBlue;
  static const Color accentTeal = fluorescentTeal;

  // Anthropic-inspired warm accent
  static const Color claudeOrange = Color(0xFFCC785C);
  static const Color claudeCream = Color(0xFFF5F1EB);
  static const Color claudeWarmBg = Color(0xFFFAF7F2);

  // Priority colors
  static const Color highPriority = Color(0xFFDC2626);
  static const Color mediumPriority = Color(0xFFF59E0B);
  static const Color lowPriority = Color(0xFF16A34A);

  // Status colors
  static const Color breaking = Color(0xFFEF4444);
  static const Color live = Color(0xFF22C55E);
  static const Color paused = Color(0xFF6B7280);

  // Light theme - warm, generous whitespace
  static const Color lightBackground = Color(0xFFFAF7F2);
  static const Color lightSurface = Colors.white;
  static const Color lightCardBorder = Color(0xFFEDE6DA);
  static const Color lightTextPrimary = Color(0xFF1A1A1A);
  static const Color lightTextSecondary = Color(0xFF6B6B6B);

  // Dark theme
  static const Color darkBackground = Color(0xFF0A1628);
  static const Color darkSurface = Color(0xFF14233D);
  static const Color darkCardBorder = Color(0xFF22344F);
  static const Color darkTextPrimary = Color(0xFFF5F1EB);
  static const Color darkTextSecondary = Color(0xFFB8B8B8);
}

class AppTheme {
  // Generous border radius for soft, Anthropic-style cards
  static const double cardRadius = 16.0;
  static const double buttonRadius = 12.0;
  static const double chipRadius = 24.0;

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: AppColors.darkCobalt,
      secondary: AppColors.persianBlue,
      tertiary: AppColors.fluorescentTeal,
      surface: AppColors.lightSurface,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: AppColors.lightTextPrimary,
      error: AppColors.highPriority,
    ),
    scaffoldBackgroundColor: AppColors.lightBackground,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.lightSurface,
      foregroundColor: AppColors.lightTextPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.fraunces(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: AppColors.lightTextPrimary,
        letterSpacing: -0.3,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.lightSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cardRadius),
        side: const BorderSide(color: AppColors.lightCardBorder, width: 1),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.claudeCream,
      selectedColor: AppColors.darkCobalt.withValues(alpha: 0.12),
      labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(chipRadius),
      ),
      side: BorderSide.none,
    ),
    textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme).copyWith(
      displayLarge: GoogleFonts.fraunces(
        fontSize: 48,
        fontWeight: FontWeight.w600,
        letterSpacing: -1.0,
        color: AppColors.lightTextPrimary,
      ),
      displayMedium: GoogleFonts.fraunces(
        fontSize: 36,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.8,
        color: AppColors.lightTextPrimary,
      ),
      displaySmall: GoogleFonts.fraunces(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
        color: AppColors.lightTextPrimary,
      ),
      headlineLarge: GoogleFonts.fraunces(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        color: AppColors.lightTextPrimary,
      ),
      headlineMedium: GoogleFonts.fraunces(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.lightTextPrimary,
      ),
      headlineSmall: GoogleFonts.fraunces(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.lightTextPrimary,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.lightTextPrimary,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        height: 1.6,
        color: AppColors.lightTextPrimary,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        height: 1.6,
        color: AppColors.lightTextSecondary,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.claudeCream.withValues(alpha: 0.5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(buttonRadius),
        borderSide: const BorderSide(color: AppColors.lightCardBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(buttonRadius),
        borderSide: const BorderSide(color: AppColors.lightCardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(buttonRadius),
        borderSide: const BorderSide(color: AppColors.darkCobalt, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.darkCobalt,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
        ),
        elevation: 0,
        textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.darkCobalt,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
        ),
        side: const BorderSide(color: AppColors.darkCobalt, width: 1.5),
        textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.claudeOrange,
        textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.claudeOrange,
      foregroundColor: Colors.white,
      elevation: 2,
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.lightCardBorder,
      thickness: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.darkCobalt,
      contentTextStyle: GoogleFonts.inter(color: Colors.white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(buttonRadius),
      ),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.fluorescentTeal,
      secondary: AppColors.angelina,
      tertiary: AppColors.claudeOrange,
      surface: AppColors.darkSurface,
      onPrimary: AppColors.darkBackground,
      onSecondary: AppColors.darkBackground,
      onSurface: AppColors.darkTextPrimary,
      error: AppColors.highPriority,
    ),
    scaffoldBackgroundColor: AppColors.darkBackground,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.darkBackground,
      foregroundColor: AppColors.darkTextPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.fraunces(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: AppColors.darkTextPrimary,
        letterSpacing: -0.3,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.darkSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cardRadius),
        side: const BorderSide(color: AppColors.darkCardBorder, width: 1),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.darkSurface,
      selectedColor: AppColors.fluorescentTeal.withValues(alpha: 0.25),
      labelStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.darkTextPrimary, fontWeight: FontWeight.w500),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(chipRadius),
      ),
      side: BorderSide.none,
    ),
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
      displayLarge: GoogleFonts.fraunces(
        fontSize: 48,
        fontWeight: FontWeight.w600,
        letterSpacing: -1.0,
        color: AppColors.darkTextPrimary,
      ),
      displayMedium: GoogleFonts.fraunces(
        fontSize: 36,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.8,
        color: AppColors.darkTextPrimary,
      ),
      displaySmall: GoogleFonts.fraunces(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
        color: AppColors.darkTextPrimary,
      ),
      headlineLarge: GoogleFonts.fraunces(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: AppColors.darkTextPrimary,
      ),
      headlineMedium: GoogleFonts.fraunces(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.darkTextPrimary,
      ),
      headlineSmall: GoogleFonts.fraunces(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.darkTextPrimary,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.darkTextPrimary,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        height: 1.6,
        color: AppColors.darkTextPrimary,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        height: 1.6,
        color: AppColors.darkTextSecondary,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.darkSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(buttonRadius),
        borderSide: const BorderSide(color: AppColors.darkCardBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(buttonRadius),
        borderSide: const BorderSide(color: AppColors.darkCardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(buttonRadius),
        borderSide: const BorderSide(color: AppColors.fluorescentTeal, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.fluorescentTeal,
        foregroundColor: AppColors.darkBackground,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
        ),
        elevation: 0,
        textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.fluorescentTeal,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
        ),
        side: const BorderSide(color: AppColors.fluorescentTeal, width: 1.5),
        textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.claudeOrange,
        textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.claudeOrange,
      foregroundColor: Colors.white,
      elevation: 2,
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.darkCardBorder,
      thickness: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.darkSurface,
      contentTextStyle: GoogleFonts.inter(color: AppColors.darkTextPrimary),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(buttonRadius),
      ),
    ),
  );
}
