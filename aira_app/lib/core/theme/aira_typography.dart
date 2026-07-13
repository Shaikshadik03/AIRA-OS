import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:aira_app/core/theme/aira_colors.dart';

class AiraTypography {
  AiraTypography._();

  // Headings — Playfair Display (elegant serif)
  static TextStyle h1 = GoogleFonts.playfairDisplay(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: AiraColors.textPrimary,
    height: 1.2,
  );

  static TextStyle h2 = GoogleFonts.playfairDisplay(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AiraColors.textPrimary,
    height: 1.25,
  );

  static TextStyle h3 = GoogleFonts.playfairDisplay(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: AiraColors.textPrimary,
    height: 1.3,
  );

  static TextStyle h4 = GoogleFonts.playfairDisplay(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AiraColors.textPrimary,
    height: 1.35,
  );

  static TextStyle h5 = GoogleFonts.playfairDisplay(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: AiraColors.textPrimary,
    height: 1.4,
  );

  static TextStyle h6 = GoogleFonts.playfairDisplay(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AiraColors.textPrimary,
    height: 1.4,
  );

  // Body — Source Serif 4 (readable serif)
  static TextStyle bodyLarge = GoogleFonts.sourceSerif4(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AiraColors.textPrimary,
    height: 1.6,
  );

  static TextStyle bodyMedium = GoogleFonts.sourceSerif4(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AiraColors.textPrimary,
    height: 1.6,
  );

  static TextStyle bodySmall = GoogleFonts.sourceSerif4(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AiraColors.textPrimary,
    height: 1.5,
  );

  static TextStyle caption = GoogleFonts.sourceSerif4(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AiraColors.textSecondary,
    height: 1.4,
  );

  static TextStyle overline = GoogleFonts.sourceSerif4(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    color: AiraColors.textMuted,
    letterSpacing: 1.5,
    height: 1.4,
  );

  static TextStyle buttonText = GoogleFonts.sourceSerif4(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AiraColors.textPrimary,
    height: 1.2,
  );

  static TextStyle label = GoogleFonts.sourceSerif4(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AiraColors.textSecondary,
    height: 1.4,
  );
}
