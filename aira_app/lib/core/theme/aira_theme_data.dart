import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AiraThemeData {
  AiraThemeData._();

  // ──────────────────── Dark Theme (Claude Minimalist Dark) ────────────────────
  static ThemeData get darkTheme {
    const bgCanvas = Color(0xFF141413);
    const bgSurface = Color(0xFF1F1E1B);
    const accentCyan = Color(0xFF00E5FF);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgCanvas,
      primaryColor: accentCyan,
      colorScheme: const ColorScheme.dark(
        primary: accentCyan,
        secondary: Color(0xFFD97706),
        surface: bgSurface,
        onSurface: Color(0xFFF4F3EE),
        onPrimary: Colors.black,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
        headlineLarge: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold),
        headlineMedium: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold),
        titleLarge: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w600),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bgCanvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Color(0xFFF9FAFB)),
      ),
      cardTheme: CardThemeData(
        color: bgSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0x1AFFFFFF)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: bgSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgSurface,
        hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: accentCyan, width: 1.5),
        ),
      ),
    );
  }

  // ──────────────────── Light Theme (ChatGPT / Claude Light) ────────────────────
  static ThemeData get lightTheme {
    const bgCanvas = Color(0xFFF9FAFB);
    const bgSurface = Color(0xFFFFFFFF);
    const bgElevated = Color(0xFFF3F4F6);
    const accentCyan = Color(0xFF00B8D4);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: bgCanvas,
      primaryColor: accentCyan,
      colorScheme: const ColorScheme.light(
        primary: accentCyan,
        secondary: Color(0xFF7C3AED),
        surface: bgSurface,
        onSurface: Color(0xFF111827),
        onPrimary: Colors.white,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme).copyWith(
        headlineLarge: GoogleFonts.plusJakartaSans(color: const Color(0xFF111827), fontWeight: FontWeight.bold),
        headlineMedium: GoogleFonts.plusJakartaSans(color: const Color(0xFF111827), fontWeight: FontWeight.bold),
        titleLarge: GoogleFonts.plusJakartaSans(color: const Color(0xFF111827), fontWeight: FontWeight.w600),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bgCanvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Color(0xFF111827)),
      ),
      cardTheme: CardThemeData(
        color: bgSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0x0F000000)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: bgSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgElevated,
        hintStyle: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: accentCyan, width: 1.5),
        ),
      ),
    );
  }
}
