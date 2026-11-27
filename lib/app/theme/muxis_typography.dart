import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'muxis_colors.dart';

/// Centralized Muxis Typography Tokens
class MuxisTypography {
  MuxisTypography._();

  static const List<String> _sansFallback = [
    'Segoe UI',
    'Inter',
    'Roboto',
    'Arial',
    'sans-serif',
  ];

  static const List<String> _monoFallback = [
    'Consolas',
    'Cascadia Mono',
    'Courier New',
    'monospace',
  ];

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
      ).copyWith(fontFamilyFallback: _sansFallback);

  static TextStyle pageTitle({bool isDark = true}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        height: 1.25,
        color: isDark
            ? MuxisColors.textPrimaryDark
            : MuxisColors.textPrimaryLight,
      ).copyWith(fontFamilyFallback: _sansFallback);

  static TextStyle sectionHeading({bool isDark = true}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        height: 1.3,
        color: isDark
            ? MuxisColors.textPrimaryDark
            : MuxisColors.textPrimaryLight,
      ).copyWith(fontFamilyFallback: _sansFallback);

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
      ).copyWith(fontFamilyFallback: _sansFallback);

  static TextStyle trackTitle({bool isDark = true}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.0,
        height: 1.25,
        color: isDark
            ? MuxisColors.textPrimaryDark
            : MuxisColors.textPrimaryLight,
      ).copyWith(fontFamilyFallback: _sansFallback);

  static TextStyle artistSubtitle({bool isDark = true}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.0,
        height: 1.3,
        color: isDark
            ? MuxisColors.textSecondaryDark
            : MuxisColors.textSecondaryLight,
      ).copyWith(fontFamilyFallback: _sansFallback);

  static TextStyle body({bool isDark = true}) => GoogleFonts.plusJakartaSans(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 1.4,
    color: isDark ? MuxisColors.textPrimaryDark : MuxisColors.textPrimaryLight,
  ).copyWith(fontFamilyFallback: _sansFallback);

  static TextStyle caption({bool isDark = true}) => GoogleFonts.plusJakartaSans(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.15,
    height: 1.3,
    color: isDark ? MuxisColors.textMutedDark : MuxisColors.textMutedLight,
  ).copyWith(fontFamilyFallback: _sansFallback);

  // --- Monospace / Timecodes & Technical Badges ---
  static TextStyle timecode({bool isDark = true, bool active = false}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: 12,
        fontWeight: active ? FontWeight.w600 : FontWeight.w500,
        letterSpacing: 0.4,
        height: 1.2,
        color: active
            ? MuxisColors.electricCyan
            : (isDark
                  ? MuxisColors.textSecondaryDark
                  : MuxisColors.textSecondaryLight),
      ).copyWith(fontFamilyFallback: _monoFallback);

  static TextStyle mono({
    double fontSize = 11,
    FontWeight fontWeight = FontWeight.w700,
    double letterSpacing = 0.8,
    Color? color,
    bool isDark = true,
  }) => GoogleFonts.jetBrainsMono(
    fontSize: fontSize,
    fontWeight: fontWeight,
    letterSpacing: letterSpacing,
    color: color ?? MuxisColors.textPrimary(isDark),
  ).copyWith(fontFamilyFallback: _monoFallback);

  static TextStyle badge({bool isDark = true}) => GoogleFonts.jetBrainsMono(
    fontSize: 10.5,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.6,
    color: isDark ? MuxisColors.electricCyan : MuxisColors.velvetViolet,
  ).copyWith(fontFamilyFallback: _monoFallback);

  static TextStyle buttonText({bool isDark = true}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ).copyWith(fontFamilyFallback: _sansFallback);
}
