import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'muxis_colors.dart';

/// Complete ThemeData configurations for Muxis (Prismatic Aura)
class MuxisTheme {
  MuxisTheme._();

  /// Dark Theme (Aura Obsidian)
  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: MuxisColors.obsidian,
      primaryColor: MuxisColors.electricCyan,
      canvasColor: MuxisColors.deepSpace,
      cardColor: MuxisColors.elevatedSurface,
      dividerColor: MuxisColors.subtleBorderDark,

      colorScheme: const ColorScheme.dark(
        primary: MuxisColors.electricCyan,
        secondary: MuxisColors.velvetViolet,
        tertiary: MuxisColors.prismaticBlue,
        surface: MuxisColors.elevatedSurface,
        error: MuxisColors.error,
        onPrimary: Colors.black,
        onSecondary: Colors.white,
        onSurface: MuxisColors.textPrimaryDark,
      ),

      textTheme:
          GoogleFonts.plusJakartaSansTextTheme(ThemeData.dark().textTheme)
              .apply(
                bodyColor: MuxisColors.textPrimaryDark,
                displayColor: MuxisColors.textPrimaryDark,
              ),

      sliderTheme: SliderThemeData(
        activeTrackColor: MuxisColors.electricCyan,
        inactiveTrackColor: MuxisColors.subtleBorderDark,
        thumbColor: MuxisColors.electricCyan,
        overlayColor: MuxisColors.electricCyan.withOpacity(0.2),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      ),

      iconTheme: const IconThemeData(
        color: MuxisColors.textSecondaryDark,
        size: 20,
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

  /// Light Theme (Prismatic Porcelain)
  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: MuxisColors.porcelain,
      primaryColor: MuxisColors.velvetViolet,
      canvasColor: MuxisColors.secondarySurface,
      cardColor: MuxisColors.whiteSurface,
      dividerColor: MuxisColors.subtleBorderLight,

      colorScheme: const ColorScheme.light(
        primary: MuxisColors.velvetViolet,
        secondary: MuxisColors.electricCyan,
        tertiary: MuxisColors.prismaticBlue,
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
        activeTrackColor: MuxisColors.velvetViolet,
        inactiveTrackColor: MuxisColors.subtleBorderLight,
        thumbColor: MuxisColors.velvetViolet,
        overlayColor: MuxisColors.velvetViolet.withOpacity(0.15),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      ),

      iconTheme: const IconThemeData(
        color: MuxisColors.textSecondaryLight,
        size: 20,
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
