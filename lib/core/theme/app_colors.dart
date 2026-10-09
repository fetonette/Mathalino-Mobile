import 'package:flutter/material.dart';
import 'mathalino_tokens.dart';

/// Mathalino App Color Palette
/// Playful, gamified theme for young students with updated design tokens
class AppColors {
  // Primary Colors
  static const Color primary = AppTokens.primaryIndigo;
  static const Color primaryDark = AppTokens.primaryShadow;
  static const Color primaryLight = AppTokens.tilePeriwinkle;
  static const Color primaryShadow = AppTokens.primaryShadow;
  static const Color headingIndigo = AppTokens.headingIndigo;

  // Secondary/Accent Colors
  static const Color accent = AppTokens.accentOrange;
  static const Color accentDark = AppTokens.orangeText;
  static const Color accentLight = AppTokens.accentRing;
  static const Color accentRing = AppTokens.accentRing;
  static const Color orangeText = AppTokens.orangeText;

  // Success/Reward Colors
  static const Color success = AppTokens.successGreen;
  static const Color successDark = Color(0xFF064E3B);
  static const Color successLight = AppTokens.tileMint;
  static const Color successRing = AppTokens.successRing;

  // Background Colors - Warm Cream
  static const Color background = AppTokens.background;
  static const Color backgroundLight = AppTokens.background;
  static const Color cardBackground = Colors.white;

  // Text Colors
  static const Color textPrimary = AppTokens.bodyText;
  static const Color textSecondary = AppTokens.secondaryText;
  static const Color textLight = Color(0xFF9CA3AF);

  // Border & Badges
  static const Color cardBorder = AppTokens.cardBorder;
  static const Color inputBorder = AppTokens.inputBorder;
  static const Color iconBadgeFill = AppTokens.iconBadgeFill;

  // Error Colors
  static const Color error = AppTokens.errorRed;
  static const Color errorDark = Color(0xFF991B1B);

  // Warning Colors
  static const Color warning = AppTokens.accentOrange;

  // Info Colors
  static const Color info = Color(0xFF3B82F6);

  // Focus Glow
  static const Color focusGlow = AppTokens.focusGlow;

  // Gradient Colors
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [accent, accentLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [success, successLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Shadow Colors
  static const Color shadowColor = Color(0x1A000000);
  static const Color shadowLight = Color(0x0D000000);
}
