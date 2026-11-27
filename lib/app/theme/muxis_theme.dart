import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'muxis_colors.dart';

/// Complete ThemeData configurations for Muxis across all Dark & Light Presets
class MuxisTheme {
  MuxisTheme._();

  static ThemeData darkTheme() {
    final bg = MuxisColors.background(true);
    final secBg = MuxisColors.secondaryBg(true);
    final surf = MuxisColors.surface(true);
    final border = MuxisColors.border(true);
    final primaryText = MuxisColors.textPrimary(true);
    final secondaryText = MuxisColors.textSecondary(true);
    final accent = MuxisColors.accent(true);
    final teal = MuxisColors.teal(true);
    final violet = MuxisColors.violet(true);
    final onAccent = MuxisColors.onAccent(true);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      primaryColor: accent,
      canvasColor: secBg,
      cardColor: surf,
      dividerColor: border,
      colorScheme: ColorScheme.dark(
        primary: accent,
        secondary: teal,
        tertiary: violet,
        surface: surf,
        error: MuxisColors.error,
        onPrimary: onAccent,
        onSecondary: Colors.black,
        onSurface: primaryText,
      ),
      textTheme:
          GoogleFonts.plusJakartaSansTextTheme(ThemeData.dark().textTheme)
              .apply(
                bodyColor: primaryText,
                displayColor: primaryText,
                fontFamilyFallback: const [
                  'Segoe UI',
                  'Inter',
                  'Roboto',
                  'Arial',
                  'sans-serif',
                ],
              ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accent,
        inactiveTrackColor: border,
        thumbColor: accent,
        overlayColor: accent.withOpacity(0.2),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      ),
      iconTheme: IconThemeData(color: secondaryText, size: 20),
      dialogTheme: DialogTheme(
        backgroundColor: surf,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: border),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: secBg,
        selectedColor: accent.withOpacity(0.2),
        side: BorderSide(color: border),
        labelStyle: TextStyle(color: primaryText),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border),
        ),
        textStyle: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          color: primaryText,
        ),
      ),
    );
  }

  static ThemeData lightTheme() {
    final bg = MuxisColors.background(false);
    final secBg = MuxisColors.secondaryBg(false);
    final surf = MuxisColors.surface(false);
    final border = MuxisColors.border(false);
    final primaryText = MuxisColors.textPrimary(false);
    final secondaryText = MuxisColors.textSecondary(false);
    final accent = MuxisColors.accent(false);
    final teal = MuxisColors.teal(false);
    final violet = MuxisColors.violet(false);
    final onAccent = MuxisColors.onAccent(false);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: bg,
      primaryColor: accent,
      canvasColor: secBg,
      cardColor: surf,
      dividerColor: border,
      colorScheme: ColorScheme.light(
        primary: accent,
        secondary: teal,
        tertiary: violet,
        surface: surf,
        error: MuxisColors.error,
        onPrimary: onAccent,
        onSecondary: Colors.white,
        onSurface: primaryText,
      ),
      textTheme:
          GoogleFonts.plusJakartaSansTextTheme(ThemeData.light().textTheme)
              .apply(
                bodyColor: primaryText,
                displayColor: primaryText,
                fontFamilyFallback: const [
                  'Segoe UI',
                  'Inter',
                  'Roboto',
                  'Arial',
                  'sans-serif',
                ],
              ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accent,
        inactiveTrackColor: border,
        thumbColor: accent,
        overlayColor: accent.withOpacity(0.18),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      ),
      iconTheme: IconThemeData(color: secondaryText, size: 20),
      dialogTheme: DialogTheme(
        backgroundColor: surf.withOpacity(0.96),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: border),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surf.withOpacity(0.85),
        selectedColor: accent.withOpacity(0.16),
        side: BorderSide(color: border),
        labelStyle: TextStyle(color: primaryText),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x18000000),
              offset: Offset(0, 4),
              blurRadius: 12,
            ),
          ],
        ),
        textStyle: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          color: primaryText,
        ),
      ),
    );
  }
}
