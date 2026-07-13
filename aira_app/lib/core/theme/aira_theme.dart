import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:aira_app/core/theme/aira_colors.dart';

class AiraTheme {
  AiraTheme._();

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AiraColors.scaffoldDark,
      colorScheme: const ColorScheme.dark(
        primary: AiraColors.electricCyan,
        secondary: AiraColors.purple,
        surface: AiraColors.cardDark,
        error: AiraColors.error,
        onPrimary: AiraColors.scaffoldDark,
        onSecondary: Colors.white,
        onSurface: AiraColors.textPrimary,
        onError: Colors.white,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
        headlineLarge: GoogleFonts.outfit(
          fontSize: 32, fontWeight: FontWeight.w700, color: AiraColors.textPrimary,
        ),
        headlineMedium: GoogleFonts.outfit(
          fontSize: 28, fontWeight: FontWeight.w700, color: AiraColors.textPrimary,
        ),
        headlineSmall: GoogleFonts.outfit(
          fontSize: 24, fontWeight: FontWeight.w600, color: AiraColors.textPrimary,
        ),
        titleLarge: GoogleFonts.outfit(
          fontSize: 20, fontWeight: FontWeight.w600, color: AiraColors.textPrimary,
        ),
        titleMedium: GoogleFonts.outfit(
          fontSize: 18, fontWeight: FontWeight.w500, color: AiraColors.textPrimary,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16, fontWeight: FontWeight.w400, color: AiraColors.textPrimary,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14, fontWeight: FontWeight.w400, color: AiraColors.textPrimary,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 12, fontWeight: FontWeight.w400, color: AiraColors.textSecondary,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AiraColors.textPrimary,
        ),
        iconTheme: const IconThemeData(color: AiraColors.textPrimary),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AiraColors.cardDark,
        selectedItemColor: AiraColors.electricCyan,
        unselectedItemColor: AiraColors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: AiraColors.cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AiraColors.glassBorder),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AiraColors.electricCyan,
          foregroundColor: AiraColors.scaffoldDark,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AiraColors.electricCyan,
          side: const BorderSide(color: AiraColors.electricCyan, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AiraColors.electricCyan,
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AiraColors.surfaceDark,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AiraColors.glassBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AiraColors.glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AiraColors.electricCyan, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AiraColors.error),
        ),
        hintStyle: GoogleFonts.inter(fontSize: 14, color: AiraColors.textMuted),
        labelStyle: GoogleFonts.inter(fontSize: 14, color: AiraColors.textSecondary),
        prefixIconColor: AiraColors.textMuted,
        suffixIconColor: AiraColors.textMuted,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AiraColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AiraColors.surfaceDark,
        contentTextStyle: GoogleFonts.inter(fontSize: 14, color: AiraColors.textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AiraColors.cardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: AiraColors.glassBorder,
        thickness: 1,
      ),
      iconTheme: const IconThemeData(color: AiraColors.textSecondary, size: 24),
    );
  }
}
