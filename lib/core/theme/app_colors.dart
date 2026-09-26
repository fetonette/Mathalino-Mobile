import 'package:flutter/material.dart';

/// Mathalino App Color Palette
/// Playful, gamified theme for young students
class AppColors {
  // Primary Colors
  static const Color primary = Color(0xFF4F46E5); // Playful Indigo
  static const Color primaryDark = Color(0xFF4338CA);
  static const Color primaryLight = Color(0xFF818CF8);

  // Secondary/Accent Colors
  static const Color accent = Color(0xFFF59E0B); // Vibrant Amber/Gold
  static const Color accentDark = Color(0xFFD97706);
  static const Color accentLight = Color(0xFFFCD34D);

  // Success/Reward Colors
  static const Color success = Color(0xFF10B981); // Emerald Green
  static const Color successDark = Color(0xFF059669);
  static const Color successLight = Color(0xFF34D399);

  // Background Colors
  static const Color background = Color(0xFFF3F4F6); // Soft Off-White/Light Purple
  static const Color backgroundLight = Color(0xFFFAFAFA);
  static const Color cardBackground = Color(0xFFFFFFFF);

  // Text Colors
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textLight = Color(0xFF9CA3AF);

  // Error Colors
  static const Color error = Color(0xFFEF4444);
  static const Color errorDark = Color(0xFFDC2626);

  // Warning Colors
  static const Color warning = Color(0xFFF59E0B);

  // Info Colors
  static const Color info = Color(0xFF3B82F6);

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
