import 'package:flutter/material.dart';

class AiraColors {
  AiraColors._();

  // ── Claude Warm Dark Palette ──
  static const Color canvasDark = Color(0xFF181816);
  static const Color cardDark = Color(0xFF22211F);
  static const Color surfaceDark = Color(0xFF2B2A27);
  static const Color surfaceLight = Color(0xFF383632);
  static const Color scaffoldDark = Color(0xFF181816);

  // ── Claude Warm Light Palette (Warm Linen / Eggshell) ──
  static const Color canvasLight = Color(0xFFFAF9F5);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color surfaceLightWarm = Color(0xFFF0EEE6);
  static const Color surfaceRaisedLight = Color(0xFFEBE8DE);
  static const Color scaffoldLight = Color(0xFFFAF9F5);

  // ── Claude Signature Accents ──
  static const Color claudeTerracotta = Color(0xFFD97757);
  static const Color claudeAmber = Color(0xFFE08844);
  static const Color claudeSand = Color(0xFFC4975A);

  // Primary - Electric Cyan & Accents
  static const Color electricCyan = Color(0xFF00E5FF);
  static const Color cyanLight = Color(0xFF67EFFF);
  static const Color cyanDark = Color(0xFF00B8D4);

  // Secondary - Purple
  static const Color purple = Color(0xFF7C3AED);
  static const Color purpleLight = Color(0xFFA78BFA);
  static const Color purpleDark = Color(0xFF5B21B6);

  // Accent
  static const Color neonBlue = Color(0xFF3B82F6);
  static const Color neonPink = Color(0xFFEC4899);
  static const Color amber = Color(0xFFF59E0B);

  // Status
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Text - Dark Mode
  static const Color textPrimary = Color(0xFFECEBE6);
  static const Color textSecondary = Color(0xFF9C9A92);
  static const Color textMuted = Color(0xFF6E6C65);

  // Text - Light Mode
  static const Color textPrimaryLight = Color(0xFF1E1E1C);
  static const Color textSecondaryLight = Color(0xFF7A7870);
  static const Color textMutedLight = Color(0xFF9E9B91);

  // Glass & Borders
  static Color glassBorder = Colors.white.withValues(alpha: 0.08);
  static Color glassBackground = Colors.white.withValues(alpha: 0.05);
  static Color glassHighlight = Colors.white.withValues(alpha: 0.1);
  static const Color borderDark = Color(0xFF383632);
  static const Color borderLight = Color(0xFFE5E2D9);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [claudeTerracotta, amber],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient claudeGradient = LinearGradient(
    colors: [Color(0xFFD97757), Color(0xFFE08844)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient purpleGradient = LinearGradient(
    colors: [purple, purpleLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient warmGradient = LinearGradient(
    colors: [claudeTerracotta, amber],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cyanPurpleGradient = LinearGradient(
    colors: [claudeTerracotta, purpleLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient darkCardGradient = LinearGradient(
    colors: [
      cardDark.withValues(alpha: 0.9),
      surfaceDark.withValues(alpha: 0.6),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
