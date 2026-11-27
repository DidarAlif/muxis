import 'package:flutter/material.dart';

/// Centralized Muxis Brand & Surface Colors (Aligned Light Aurora & Dark Obsidian)
class MuxisColors {
  MuxisColors._();

  // --- Primary Brand Accents (Vibrant Electric Neon Green & Multi-Tone Spectrum) ---
  static const Color neonGreen = Color(0xFF00FF88);
  static const Color neonMint = Color(0xFF10FFA0);
  static const Color emeraldAccent = Color(0xFF00E676);
  static const Color cyberLime = Color(0xFF76FF03);
  static const Color neonGreenLight = Color(
    0xFF00A859,
  ); // High-contrast emerald for light mode

  // --- Complementary Prismatic Spectrum Accents (Aligned Across Themes) ---
  static const Color cyberTeal = Color(0xFF00E5FF);
  static const Color cyberTealLight = Color(0xFF0284C7);
  static const Color auroraViolet = Color(0xFF9D6BFF);
  static const Color auroraVioletLight = Color(0xFF7C3AED);
  static const Color coralPulse = Color(0xFFFF4D8D);
  static const Color coralPulseLight = Color(0xFFDB2777);

  // Platform Brand Accents
  static const Color spotifyGreen = Color(0xFF1DB954);
  static const Color youtubeRed = Color(0xFFFF2D55);
  static const Color soundcloudOrange = Color(0xFFFF5500);

  // Backwards-compatible aliases mapped cleanly across the app
  static const Color neonAccent = neonGreen;
  static const Color electricCyan = neonGreen;
  static const Color prismaticBlue = cyberTeal;
  static const Color velvetViolet = auroraViolet;
  static const Color neonMagenta = coralPulse;

  // --- Dark Theme Surfaces (Obsidian Depth & Frosted Dark Glass) ---
  static const Color obsidian = Color(0xFF060910);
  static const Color deepSpace = Color(0xFF0B111C);
  static const Color elevatedSurface = Color(0xFF121A29);
  static const Color hoverSurface = Color(0xFF1A2538);
  static const Color subtleBorderDark = Color(0xFF233046);
  static const Color neonBorderDark = Color(0x4000FF88);

  // --- Light Theme Surfaces (Luminous Botanical Ice & Apple Liquid Glass) ---
  static const Color porcelain = Color(0xFFEEF7F6);
  static const Color whiteSurface = Color(0xFFFFFFFF);
  static const Color secondarySurface = Color(0xFFE6F3F2);
  static const Color hoverSurfaceLight = Color(0xFFD8EDE9);
  static const Color subtleBorderLight = Color(0xFFD0E3E8);
  static const Color neonBorderLight = Color(0x4500A859);

  // --- Dark Text & Icon Colors ---
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFFA3B3C9);
  static const Color textMutedDark = Color(0xFF6B7D96);
  static const Color textDisabledDark = Color(0xFF475569);

  // --- Light Text & Icon Colors (Crisp Ink Contrast on Luminous Surfaces) ---
  static const Color textPrimaryLight = Color(0xFF0B1320);
  static const Color textSecondaryLight = Color(0xFF2E4057);
  static const Color textMutedLight = Color(0xFF5A6D84);
  static const Color textDisabledLight = Color(0xFF94A3B8);

  // --- Status & Feedback Tokens ---
  static const Color success = Color(0xFF00E676);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF00E5FF);

  // --- Interactive Highlights ---
  static const Color activeGreen = Color(0xFF00FF88);
  static const Color heartActive = Color(0xFFFF4D8D);

  // --- Contextual Adapters ---
  static Color surface(bool isDark) => isDark ? elevatedSurface : whiteSurface;
  static Color glassSurface(bool isDark) =>
      isDark ? const Color(0xB8111928) : const Color(0xC2FFFFFF);
  static Color glassRim(bool isDark) =>
      isDark ? const Color(0x26FFFFFF) : const Color(0xE8FFFFFF);
  static Color background(bool isDark) => isDark ? obsidian : porcelain;
  static Color secondaryBg(bool isDark) =>
      isDark ? deepSpace : secondarySurface;
  static Color border(bool isDark) =>
      isDark ? subtleBorderDark : subtleBorderLight;
  static Color textPrimary(bool isDark) =>
      isDark ? textPrimaryDark : textPrimaryLight;
  static Color textSecondary(bool isDark) =>
      isDark ? textSecondaryDark : textSecondaryLight;
  static Color textMuted(bool isDark) =>
      isDark ? textMutedDark : textMutedLight;
  static Color accent(bool isDark) => isDark ? neonGreen : neonGreenLight;
  static Color teal(bool isDark) => isDark ? cyberTeal : cyberTealLight;
  static Color violet(bool isDark) => isDark ? auroraViolet : auroraVioletLight;
  static Color coral(bool isDark) => isDark ? coralPulse : coralPulseLight;
}
