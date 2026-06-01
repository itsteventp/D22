import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ---------------------------------------------------------------------------
// D22 Design System — Central Token File
// ---------------------------------------------------------------------------

class AppColors {
  AppColors._();

  // Core surfaces — deep blue-black, not pure black
  static const Color background   = Color(0xFF0C0C10);
  static const Color surface      = Color(0xFF131318);
  static const Color surfaceHigh  = Color(0xFF1C1C24);
  static const Color surfaceHover = Color(0xFF22222E);

  // Borders — barely-there separators
  static const Color border       = Color(0xFF2A2A38);
  static const Color borderSubtle = Color(0xFF1E1E28);

  // Text — soft white scale
  static const Color textPrimary   = Color(0xFFEEEEF5);
  static const Color textSecondary = Color(0xFF8080A0);
  static const Color textMuted     = Color(0xFF4A4A65);

  // Semantic
  static const Color success = Color(0xFF10B981); // Emerald 500
  static const Color error   = Color(0xFFF43F5E); // Rose 500

  // Concept accent colors (node tinting)
  static const Color conceptPurple = Color(0xFFAB47BC);
  static const Color conceptBlue   = Color(0xFF42A5F5);
  static const Color conceptTeal   = Color(0xFF34D399);
  static const Color conceptOrange = Color(0xFFFFA726);
  static const Color conceptRose   = Color(0xFFF06292);

  // Utility
  static const Color white = Color(0xFFEEEEF5);
  static const Color black = Color(0xFF0C0C10);
}

class AppDurations {
  AppDurations._();

  static const Duration fast    = Duration(milliseconds: 150);
  static const Duration normal  = Duration(milliseconds: 250);
  static const Duration medium  = Duration(milliseconds: 350);
  static const Duration slow    = Duration(milliseconds: 500);
  static const Duration spring  = Duration(milliseconds: 600);
}

class AppRadius {
  AppRadius._();

  static const double xs  = 4.0;
  static const double sm  = 8.0;
  static const double md  = 12.0;
  static const double lg  = 16.0;
  static const double xl  = 24.0;
  static const double pill = 999.0;
}

class AppTextStyles {
  AppTextStyles._();

  // Display — big bold headers
  static TextStyle display({Color color = AppColors.textPrimary}) =>
      GoogleFonts.inter(
        fontSize: 26.0,
        fontWeight: FontWeight.w800,
        color: color,
        letterSpacing: -0.5,
      );

  // Title — section titles
  static TextStyle title({Color color = AppColors.textPrimary}) =>
      GoogleFonts.inter(
        fontSize: 16.0,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: -0.2,
      );

  // Label — tab labels, button text
  static TextStyle label({Color color = AppColors.textPrimary}) =>
      GoogleFonts.inter(
        fontSize: 13.0,
        fontWeight: FontWeight.w600,
        color: color,
      );

  // Caption — secondary small info
  static TextStyle caption({Color color = AppColors.textSecondary}) =>
      GoogleFonts.inter(
        fontSize: 11.0,
        fontWeight: FontWeight.w500,
        color: color,
        letterSpacing: 0.5,
      );

  // Body — general text
  static TextStyle body({Color color = AppColors.textSecondary}) =>
      GoogleFonts.inter(
        fontSize: 13.0,
        fontWeight: FontWeight.w400,
        color: color,
      );

  // Code — data/cipher text only
  static TextStyle code({Color color = AppColors.textPrimary, double size = 12.0}) =>
      TextStyle(
        fontFamily: 'monospace',
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: color,
      );
}

// ---------------------------------------------------------------------------
// MaterialApp ThemeData builder
// ---------------------------------------------------------------------------
ThemeData buildAppTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.dark(
      surface: AppColors.surface,
      primary: AppColors.textPrimary,
      secondary: AppColors.conceptTeal,
    ),
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
    hoverColor: Colors.transparent,
    inputDecorationTheme: InputDecorationTheme(
      border: InputBorder.none,
      hintStyle: AppTextStyles.body(color: AppColors.textMuted),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      elevation: 0,
    ),
  );
}
