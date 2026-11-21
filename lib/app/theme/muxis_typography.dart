import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'muxis_colors.dart';

/// Centralized Muxis Typography Tokens
class MuxisTypography {
  MuxisTypography._();

  // --- Display & Hero Headings ---
  static TextStyle displayHero({bool isDark = true}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 40,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.0,
        height: 1.15,
        color: isDark
            ? MuxisColors.textPrimaryDark
            : MuxisColors.textPrimaryLight,
      );

  static TextStyle pageTitle({bool isDark = true}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        height: 1.25,
        color: isDark
            ? MuxisColors.textPrimaryDark
            : MuxisColors.textPrimaryLight,
      );

  static TextStyle sectionHeading({bool isDark = true}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        height: 1.3,
        color: isDark
            ? MuxisColors.textPrimaryDark
            : MuxisColors.textPrimaryLight,
      );

  // --- Content & Cards ---
  static TextStyle cardTitle({bool isDark = true}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        height: 1.3,
        color: isDark
            ? MuxisColors.textPrimaryDark
            : MuxisColors.textPrimaryLight,
      );

  static TextStyle trackTitle({bool isDark = true}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.0,
        height: 1.25,
        color: isDark
            ? MuxisColors.textPrimaryDark
            : MuxisColors.textPrimaryLight,
      );

  static TextStyle artistSubtitle({bool isDark = true}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.0,
        height: 1.3,
        color: isDark
            ? MuxisColors.textSecondaryDark
            : MuxisColors.textSecondaryLight,
      );

  static TextStyle body({bool isDark = true}) => GoogleFonts.plusJakartaSans(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
    height: 1.4,
    color: isDark ? MuxisColors.textPrimaryDark : MuxisColors.textPrimaryLight,
  );

  static TextStyle caption({bool isDark = true}) => GoogleFonts.plusJakartaSans(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.2,
    height: 1.3,
    color: isDark ? MuxisColors.textMutedDark : MuxisColors.textMutedLight,
  );

  // --- Monospace / Timecodes & Technical Badges ---
  static TextStyle timecode({bool isDark = true, bool active = false}) =>
      GoogleFonts.jetbrainsMono(
        fontSize: 12,
        fontWeight: active ? FontWeight.w600 : FontWeight.w400,
        letterSpacing: 0.5,
        height: 1.2,
        color: active
            ? MuxisColors.electricCyan
            : (isDark
                  ? MuxisColors.textSecondaryDark
                  : MuxisColors.textSecondaryLight),
      );

  static TextStyle badge({bool isDark = true}) => GoogleFonts.jetbrainsMono(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
    color: isDark ? MuxisColors.electricCyan : MuxisColors.velvetViolet,
  );

  static TextStyle buttonText({bool isDark = true}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      );
}
