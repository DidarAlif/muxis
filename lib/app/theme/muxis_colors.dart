import 'package:flutter/material.dart';

/// Centralized Muxis Brand & Surface Colors (Prismatic Aura Neon Green Specification)
class MuxisColors {
  MuxisColors._();

  // --- Primary Brand Accents (Vibrant Electric Neon Green) ---
  static const Color neonGreen = Color(0xFF00FF88);
  static const Color neonMint = Color(0xFF10FFA0);
  static const Color emeraldAccent = Color(0xFF00E676);
  static const Color cyberLime = Color(0xFF76FF03);
  static const Color neonGreenLight = Color(0xFF00A859); // High-contrast for light theme

  // Backwards-compatible aliases mapped to Neon Green family
  static const Color neonAccent = neonGreen;
  static const Color electricCyan = neonGreen;
  static const Color prismaticBlue = neonMint;
  static const Color velvetViolet = Color(0xFF05DF72);
  static const Color neonMagenta = neonGreen;

  // --- Dark Theme Surfaces (Aura Obsidian with Emerald Depth) ---
  static const Color obsidian = Color(0xFF07090E);
  static const Color deepSpace = Color(0xFF0D1219);
  static const Color elevatedSurface = Color(0xFF131A24);
  static const Color hoverSurface = Color(0xFF1B2433);
  static const Color subtleBorderDark = Color(0xFF232D3F);
  static const Color neonBorderDark = Color(0x3300FF88);

  // --- Light Theme Surfaces (Vastly Improved Apple-Inspired Porcelain & Zinc) ---
  static const Color porcelain = Color(0xFFF8FAFC);
  static const Color whiteSurface = Color(0xFFFFFFFF);
  static const Color secondarySurface = Color(0xFFF1F5F9);
  static const Color hoverSurfaceLight = Color(0xFFE2E8F0);
  static const Color subtleBorderLight = Color(0xFFE2E8F0);
  static const Color neonBorderLight = Color(0x3300A859);

  // --- Dark Text & Icon Colors ---
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color textMutedDark = Color(0xFF64748B);
  static const Color textDisabledDark = Color(0xFF475569);

  // --- Light Text & Icon Colors (Razor-Sharp Legibility) ---
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF334155);
  static const Color textMutedLight = Color(0xFF64748B);
  static const Color textDisabledLight = Color(0xFF94A3B8);

  // --- Status & Feedback Tokens ---
  static const Color success = Color(0xFF00FF88);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF10FFA0);

  // --- Interactive Highlights ---
  static const Color activeGreen = Color(0xFF00FF88);
  static const Color heartActive = Color(0xFF00FF88);

  // --- Contextual Adapters ---
  static Color surface(bool isDark) => isDark ? elevatedSurface : whiteSurface;
  static Color background(bool isDark) => isDark ? obsidian : porcelain;
  static Color secondaryBg(bool isDark) => isDark ? deepSpace : secondarySurface;
  static Color border(bool isDark) => isDark ? subtleBorderDark : subtleBorderLight;
  static Color textPrimary(bool isDark) => isDark ? textPrimaryDark : textPrimaryLight;
  static Color textSecondary(bool isDark) => isDark ? textSecondaryDark : textSecondaryLight;
  static Color textMuted(bool isDark) => isDark ? textMutedDark : textMutedLight;
  static Color accent(bool isDark) => isDark ? neonGreen : neonGreenLight;
}
