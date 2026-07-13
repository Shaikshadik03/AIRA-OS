import 'package:flutter/material.dart';

class AiraColors {
  AiraColors._();

  // Backgrounds
  static const Color scaffoldDark = Color(0xFF0A0E1A);
  static const Color cardDark = Color(0xFF111827);
  static const Color surfaceDark = Color(0xFF1F2937);
  static const Color surfaceLight = Color(0xFF374151);

  // Primary - Electric Cyan
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

  // Text
  static const Color textPrimary = Color(0xFFF9FAFB);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color textMuted = Color(0xFF6B7280);

  // Glass
  static Color glassBorder = Colors.white.withValues(alpha: 0.08);
  static Color glassBackground = Colors.white.withValues(alpha: 0.05);
  static Color glassHighlight = Colors.white.withValues(alpha: 0.1);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [electricCyan, neonBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient purpleGradient = LinearGradient(
    colors: [purple, purpleLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient warmGradient = LinearGradient(
    colors: [neonPink, amber],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cyanPurpleGradient = LinearGradient(
    colors: [electricCyan, purple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient darkCardGradient = LinearGradient(
    colors: [
      cardDark.withValues(alpha: 0.8),
      surfaceDark.withValues(alpha: 0.4),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
