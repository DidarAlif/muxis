import 'package:flutter/material.dart';

import '../../shared/utils/theme_catalog.dart';

/// Centralized Muxis Brand & Surface Colors (Dynamic Multi-Theme + Liquid Glass)
class MuxisColors {
  MuxisColors._();

  // --- Primary Brand Accents (Static Defaults for const compatibility) ---
  static const Color neonGreen = Color(0xFF00FF88);
  static const Color neonMint = Color(0xFF10FFA0);
  static const Color emeraldAccent = Color(0xFF00E676);
  static const Color cyberLime = Color(0xFF76FF03);
  static const Color neonGreenLight = Color(0xFF00A859);

  // --- Complementary Prismatic Spectrum Accents ---
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

  // Backwards-compatible aliases
  static const Color neonAccent = neonGreen;
  static const Color electricCyan = neonGreen;
  static const Color prismaticBlue = cyberTeal;
  static const Color velvetViolet = auroraViolet;
  static const Color neonMagenta = coralPulse;

  // --- Static Dark Defaults ---
  static const Color obsidian = Color(0xFF060910);
  static const Color deepSpace = Color(0xFF0B111C);
  static const Color elevatedSurface = Color(0xFF121A29);
  static const Color hoverSurface = Color(0xFF1A2538);
  static const Color subtleBorderDark = Color(0xFF233046);
  static const Color neonBorderDark = Color(0x4000FF88);

  // --- Static Light Defaults ---
  static const Color porcelain = Color(0xFFEEF7F6);
  static const Color whiteSurface = Color(0xFFFFFFFF);
  static const Color secondarySurface = Color(0xFFE6F3F2);
  static const Color hoverSurfaceLight = Color(0xFFD8EDE9);
  static const Color subtleBorderLight = Color(0xFFD0E3E8);
  static const Color neonBorderLight = Color(0x4500A859);

  // --- Static Text Tokens ---
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFFD2DFEE);
  static const Color textMutedDark = Color(0xFF9FB2C9);
  static const Color textDisabledDark = Color(0xFF7B8FA8);

  static const Color textPrimaryLight = Color(0xFF0B1320);
  static const Color textSecondaryLight = Color(0xFF1E2D40);
  static const Color textMutedLight = Color(0xFF475B73);
  static const Color textDisabledLight = Color(0xFF7D90A6);

  // --- Status & Feedback Tokens ---
  static const Color success = Color(0xFF00E676);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF00E5FF);

  // --- Interactive Highlights ---
  static const Color activeGreen = Color(0xFF00FF88);
  static const Color heartActive = Color(0xFFFF4D8D);

  // --- Active Dynamic Theme State (updated via MuxisThemeController) ---
  static MuxisThemeDefinition _activeDark = ThemeCatalog.findPreset(
    ThemeCatalog.defaultDarkId,
    isDark: true,
  );
  static MuxisThemeDefinition _activeLight = ThemeCatalog.findPreset(
    ThemeCatalog.defaultLightId,
    isDark: false,
  );
  static String _activeAccentTasteId = ThemeCatalog.defaultAccentTasteId;

  static MuxisThemeDefinition presetFor(bool isDark) =>
      isDark ? _activeDark : _activeLight;

  static String get activeAccentTasteId => _activeAccentTasteId;

  static void applyActivePresets({
    required String darkPresetId,
    required String lightPresetId,
    String? accentTasteId,
  }) {
    _activeDark = ThemeCatalog.findPreset(darkPresetId, isDark: true);
    _activeLight = ThemeCatalog.findPreset(lightPresetId, isDark: false);
    _activeAccentTasteId = accentTasteId?.isNotEmpty == true
        ? accentTasteId!
        : ThemeCatalog.defaultAccentTasteId;
  }

  // --- Contextual Theme-Aware Adapters ---
  static Color surface(bool isDark) => Color(presetFor(isDark).surface);
  static Color glassSurface(bool isDark) =>
      Color(presetFor(isDark).glassSurface);
  static Color glassRim(bool isDark) => Color(presetFor(isDark).glassRim);
  static Color background(bool isDark) => Color(presetFor(isDark).background);
  static Color secondaryBg(bool isDark) =>
      Color(presetFor(isDark).secondaryBackground);
  static Color border(bool isDark) => Color(presetFor(isDark).border);
  static Color textPrimary(bool isDark) => Color(presetFor(isDark).textPrimary);
  static Color textSecondary(bool isDark) =>
      Color(presetFor(isDark).textSecondary);
  static Color textMuted(bool isDark) => Color(presetFor(isDark).textMuted);

  static Color accent(bool isDark) => Color(
    ThemeCatalog.resolveAccentHex(presetFor(isDark), _activeAccentTasteId),
  );

  static Color teal(bool isDark) => Color(
    ThemeCatalog.resolveSecondaryHex(presetFor(isDark), _activeAccentTasteId),
  );

  static Color violet(bool isDark) => Color(presetFor(isDark).tertiary);
  static Color coral(bool isDark) => Color(presetFor(isDark).highlight);

  static Color onAccent(bool isDark) =>
      accent(isDark).computeLuminance() > 0.42 ? Colors.black : Colors.white;
}
