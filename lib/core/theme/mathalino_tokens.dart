import 'package:flutter/material.dart';

/// Design Tokens for Mathalino
/// Shared theme constants for colors, typography, shapes, and shadows
class AppTokens {
  // --- Colors ---
  static const Color background = Color(0xFFFFF6E9); // Warm cream
  static const Color primaryIndigo = Color(0xFF4F46E5);
  static const Color primaryShadow = Color(0xFF3730A3);
  static const Color headingIndigo = Color(0xFF3730A3);
  static const Color bodyText = Color(0xFF1E1B4B);
  static const Color secondaryText = Color(0xFF4B4872);
  static const Color accentOrange = Color(0xFFF59E0B);
  static const Color accentRing = Color(0xFFFDE68A);
  static const Color orangeText = Color(0xFFB45309);
  static const Color successGreen = Color(0xFF047857);
  static const Color successRing = Color(0xFFA7F3D0);
  static const Color indigoRing = Color(0xFFC7C3E8);
  static const Color cardBorder = Color(0xFFE0E7FF);
  static const Color inputBorder = Color(0xFFC7C3E8);
  static const Color iconBadgeFill = Color(0xFFE0E7FF);
  static const Color errorRed = Color(0xFFB91C1C);
  static const Color focusGlow = Color(0x334F46E5);

  // Decoration tiles colors & symbols
  static const Color tileYellow = Color(0xFFFBBF24);
  static const Color tileSymbolYellow = Color(0xFF7C2D12);

  static const Color tileMint = Color(0xFF34D399);
  static const Color tileSymbolMint = Color(0xFF064E3B);

  static const Color tilePeriwinkle = Color(0xFF818CF8);
  static const Color tileSymbolPeriwinkle = Color(0xFF1E1B4B);

  static const Color tileSky = Color(0xFF7DD3FC);
  static const Color tileSymbolSky = Color(0xFF0C4A6E);

  // --- Home / Level map ---
  static const Color zoneCard = Color(0xFF4338CA);
  static const Color zoneTrack = Color(0xFF6366F1);
  static const Color zoneFill = Color(0xFFFBBF24);
  static const Color zoneChipText = Color(0xFF1F1300);
  static const Color zoneDescription = Color(0xFFE0E7FF);
  static const Color currentBlue = Color(0xFF1473E6);
  static const Color currentBlueDark = Color(0xFF0B4FA8);
  static const Color completedRing = Color(0xFF6EE7B7);
  static const Color lockedFill = Color(0xFFE7E5F2);
  static const Color lockedBorder = Color(0xFFC7C3E8);
  static const Color lockedContent = Color(0xFF5B5780);
  static const Color navBorder = Color(0xFFEAE6F5);
  static const Color navActivePill = Color(0xFFE0E7FF);

  // --- Font Families ---
  static const String fontBaloo2 = 'Baloo2';
  static const String fontNunito = 'Nunito';

  // --- Radii ---
  static const double radiusPill = 32.0;
  static const double radiusCard = 28.0;
  static const double radiusInput = 22.0;
  static const double radiusTileWelcome = 15.0;
  static const double radiusTileLogin = 13.0;

  // --- Shadows ---
  static const BoxShadow cardSolidShadow = BoxShadow(
    color: cardBorder,
    offset: Offset(0, 6),
    blurRadius: 0,
    spreadRadius: 0,
  );

  static const BoxShadow buttonSolidShadow = BoxShadow(
    color: primaryShadow,
    offset: Offset(0, 6),
    blurRadius: 0,
    spreadRadius: 0,
  );

  static const BoxShadow buttonPressedShadow = BoxShadow(
    color: primaryShadow,
    offset: Offset(0, 2),
    blurRadius: 0,
    spreadRadius: 0,
  );

  // --- Typography Helpers ---
  static TextStyle baloo2({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.w700,
    Color color = headingIndigo,
    double? height,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: fontBaloo2,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle nunito({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.w600,
    Color color = bodyText,
    double? height,
    double? letterSpacing,
    TextDecoration? decoration,
  }) {
    return TextStyle(
      fontFamily: fontNunito,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      decoration: decoration,
    );
  }
}
