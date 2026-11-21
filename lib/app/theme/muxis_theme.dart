import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'muxis_colors.dart';

/// Complete ThemeData configurations for Muxis (Prismatic Aura Neon Green Specification)
class MuxisTheme {
  MuxisTheme._();

  /// Dark Theme (Aura Obsidian with Neon Green Energy)
  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: MuxisColors.obsidian,
      primaryColor: MuxisColors.neonGreen,
      canvasColor: MuxisColors.deepSpace,
      cardColor: MuxisColors.elevatedSurface,
      dividerColor: MuxisColors.subtleBorderDark,

      colorScheme: const ColorScheme.dark(
        primary: MuxisColors.neonGreen,
        secondary: MuxisColors.neonMint,
        tertiary: MuxisColors.emeraldAccent,
        surface: MuxisColors.elevatedSurface,
        error: MuxisColors.error,
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onSurface: MuxisColors.textPrimaryDark,
      ),

      textTheme:
          GoogleFonts.plusJakartaSansTextTheme(ThemeData.dark().textTheme)
              .apply(
                bodyColor: MuxisColors.textPrimaryDark,
                displayColor: MuxisColors.textPrimaryDark,
              ),

      sliderTheme: SliderThemeData(
        activeTrackColor: MuxisColors.neonGreen,
        inactiveTrackColor: MuxisColors.subtleBorderDark,
        thumbColor: MuxisColors.neonGreen,
        overlayColor: MuxisColors.neonGreen.withOpacity(0.2),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      ),

      iconTheme: const IconThemeData(
        color: MuxisColors.textSecondaryDark,
        size: 20,
      ),

      dialogTheme: DialogTheme(
        backgroundColor: MuxisColors.elevatedSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: MuxisColors.subtleBorderDark),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: MuxisColors.deepSpace,
        selectedColor: MuxisColors.neonGreen.withOpacity(0.2),
        side: const BorderSide(color: MuxisColors.subtleBorderDark),
        labelStyle: const TextStyle(color: MuxisColors.textPrimaryDark),
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: MuxisColors.elevatedSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: MuxisColors.subtleBorderDark),
        ),
        textStyle: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          color: MuxisColors.textPrimaryDark,
        ),
      ),
    );
  }

  /// Light Theme (Vastly Improved Apple-Inspired Porcelain & Emerald)
  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: MuxisColors.porcelain,
      primaryColor: MuxisColors.neonGreenLight,
      canvasColor: MuxisColors.secondarySurface,
      cardColor: MuxisColors.whiteSurface,
      dividerColor: MuxisColors.subtleBorderLight,

      colorScheme: const ColorScheme.light(
        primary: MuxisColors.neonGreenLight,
        secondary: MuxisColors.emeraldAccent,
        tertiary: MuxisColors.neonMint,
        surface: MuxisColors.whiteSurface,
        error: MuxisColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onSurface: MuxisColors.textPrimaryLight,
      ),

      textTheme:
          GoogleFonts.plusJakartaSansTextTheme(ThemeData.light().textTheme)
              .apply(
                bodyColor: MuxisColors.textPrimaryLight,
                displayColor: MuxisColors.textPrimaryLight,
              ),

      sliderTheme: SliderThemeData(
        activeTrackColor: MuxisColors.neonGreenLight,
        inactiveTrackColor: MuxisColors.subtleBorderLight,
        thumbColor: MuxisColors.neonGreenLight,
        overlayColor: MuxisColors.neonGreenLight.withOpacity(0.15),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      ),

      iconTheme: const IconThemeData(
        color: MuxisColors.textSecondaryLight,
        size: 20,
      ),

      dialogTheme: DialogTheme(
        backgroundColor: MuxisColors.whiteSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: MuxisColors.subtleBorderLight),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: MuxisColors.secondarySurface,
        selectedColor: MuxisColors.neonGreenLight.withOpacity(0.15),
        side: const BorderSide(color: MuxisColors.subtleBorderLight),
        labelStyle: const TextStyle(color: MuxisColors.textPrimaryLight),
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: MuxisColors.whiteSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: MuxisColors.subtleBorderLight),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              offset: Offset(0, 4),
              blurRadius: 12,
            ),
          ],
        ),
        textStyle: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          color: MuxisColors.textPrimaryLight,
        ),
      ),
    );
  }
}
