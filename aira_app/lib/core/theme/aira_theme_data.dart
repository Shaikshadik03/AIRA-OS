import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:aira_app/core/theme/aira_colors.dart';

class AiraThemeData {
  AiraThemeData._();

  // ──────────────────── Dark Theme (Claude Warm Obsidian) ────────────────────
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AiraColors.canvasDark,
      primaryColor: AiraColors.claudeTerracotta,
      colorScheme: const ColorScheme.dark(
        primary: AiraColors.claudeTerracotta,
        secondary: AiraColors.claudeAmber,
        surface: AiraColors.cardDark,
        surfaceContainerHighest: AiraColors.surfaceDark,
        onSurface: AiraColors.textPrimary,
        onSurfaceVariant: AiraColors.textSecondary,
        outline: AiraColors.borderDark,
        onPrimary: Colors.white,
        error: AiraColors.error,
      ),
      textTheme: GoogleFonts.sourceSerif4TextTheme(ThemeData.dark().textTheme).copyWith(
        headlineLarge: GoogleFonts.playfairDisplay(
          color: AiraColors.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 32,
          letterSpacing: -0.5,
        ),
        headlineMedium: GoogleFonts.playfairDisplay(
          color: AiraColors.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 26,
        ),
        headlineSmall: GoogleFonts.playfairDisplay(
          color: AiraColors.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 22,
        ),
        titleLarge: GoogleFonts.sourceSerif4(
          color: AiraColors.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
        bodyLarge: GoogleFonts.sourceSerif4(
          color: AiraColors.textPrimary,
          fontSize: 16,
          height: 1.6,
        ),
        bodyMedium: GoogleFonts.sourceSerif4(
          color: AiraColors.textPrimary,
          fontSize: 14.5,
          height: 1.6,
        ),
        bodySmall: GoogleFonts.sourceSerif4(
          color: AiraColors.textSecondary,
          fontSize: 13,
          height: 1.5,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AiraColors.canvasDark,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AiraColors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: AiraColors.cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AiraColors.borderDark, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AiraColors.cardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AiraColors.borderDark),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AiraColors.borderDark,
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AiraColors.surfaceDark,
        hintStyle: const TextStyle(color: AiraColors.textMuted, fontSize: 14.5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: AiraColors.borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: AiraColors.borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: AiraColors.claudeTerracotta, width: 1.2),
        ),
      ),
    );
  }

  // ──────────────────── Light Theme (Claude Warm Linen / Eggshell) ────────────────────
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AiraColors.canvasLight,
      primaryColor: AiraColors.claudeTerracotta,
      colorScheme: const ColorScheme.light(
        primary: AiraColors.claudeTerracotta,
        secondary: AiraColors.claudeAmber,
        surface: AiraColors.cardLight,
        surfaceContainerHighest: AiraColors.surfaceLightWarm,
        onSurface: AiraColors.textPrimaryLight,
        onSurfaceVariant: AiraColors.textSecondaryLight,
        outline: AiraColors.borderLight,
        onPrimary: Colors.white,
        error: AiraColors.error,
      ),
      textTheme: GoogleFonts.sourceSerif4TextTheme(ThemeData.light().textTheme).copyWith(
        headlineLarge: GoogleFonts.playfairDisplay(
          color: AiraColors.textPrimaryLight,
          fontWeight: FontWeight.w700,
          fontSize: 32,
          letterSpacing: -0.5,
        ),
        headlineMedium: GoogleFonts.playfairDisplay(
          color: AiraColors.textPrimaryLight,
          fontWeight: FontWeight.w700,
          fontSize: 26,
        ),
        headlineSmall: GoogleFonts.playfairDisplay(
          color: AiraColors.textPrimaryLight,
          fontWeight: FontWeight.w600,
          fontSize: 22,
        ),
        titleLarge: GoogleFonts.sourceSerif4(
          color: AiraColors.textPrimaryLight,
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
        bodyLarge: GoogleFonts.sourceSerif4(
          color: AiraColors.textPrimaryLight,
          fontSize: 16,
          height: 1.6,
        ),
        bodyMedium: GoogleFonts.sourceSerif4(
          color: AiraColors.textPrimaryLight,
          fontSize: 14.5,
          height: 1.6,
        ),
        bodySmall: GoogleFonts.sourceSerif4(
          color: AiraColors.textSecondaryLight,
          fontSize: 13,
          height: 1.5,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AiraColors.canvasLight,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AiraColors.textPrimaryLight),
      ),
      cardTheme: CardThemeData(
        color: AiraColors.cardLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AiraColors.borderLight, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AiraColors.cardLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AiraColors.borderLight),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AiraColors.borderLight,
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AiraColors.surfaceLightWarm,
        hintStyle: const TextStyle(color: AiraColors.textMutedLight, fontSize: 14.5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: AiraColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: AiraColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: AiraColors.claudeTerracotta, width: 1.2),
        ),
      ),
    );
  }
}
