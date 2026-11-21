import 'package:flutter/material.dart';

import 'muxis_colors.dart';

/// Centralized Muxis Elevation and Glow Shadows (Neon Green Aura)
class MuxisShadows {
  MuxisShadows._();

  /// Soft elevation shadow for cards and surfaces (Dark)
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x40000000),
      offset: Offset(0, 4),
      blurRadius: 16,
      spreadRadius: 0,
    ),
  ];

  /// Soft elevation shadow for cards and surfaces (Light)
  static const List<BoxShadow> cardLight = [
    BoxShadow(
      color: Color(0x0A0F172A),
      offset: Offset(0, 4),
      blurRadius: 16,
      spreadRadius: 0,
    ),
  ];

  /// Elevated card shadow with hover effect (Dark)
  static const List<BoxShadow> cardHover = [
    BoxShadow(
      color: Color(0x60000000),
      offset: Offset(0, 8),
      blurRadius: 24,
      spreadRadius: 1,
    ),
    BoxShadow(
      color: Color(0x3300FF88),
      offset: Offset(0, 0),
      blurRadius: 16,
      spreadRadius: 0,
    ),
  ];

  /// Elevated card shadow with hover effect (Light)
  static const List<BoxShadow> cardHoverLight = [
    BoxShadow(
      color: Color(0x140F172A),
      offset: Offset(0, 8),
      blurRadius: 20,
      spreadRadius: 1,
    ),
    BoxShadow(
      color: Color(0x2000A859),
      offset: Offset(0, 0),
      blurRadius: 12,
      spreadRadius: 0,
    ),
  ];

  /// Signature Prismatic Neon Glow for active buttons and controls (Dark)
  static const List<BoxShadow> prismaticGlow = [
    BoxShadow(
      color: Color(0x8000FF88),
      offset: Offset(0, 0),
      blurRadius: 16,
      spreadRadius: 2,
    ),
    BoxShadow(
      color: Color(0x4010FFA0),
      offset: Offset(0, 4),
      blurRadius: 24,
      spreadRadius: 0,
    ),
  ];

  /// Signature Prismatic Glow for active buttons and controls (Light)
  static const List<BoxShadow> prismaticGlowLight = [
    BoxShadow(
      color: Color(0x4000A859),
      offset: Offset(0, 2),
      blurRadius: 12,
      spreadRadius: 1,
    ),
  ];

  /// Bottom Playback bar subtle upward drop shadow (Dark)
  static const List<BoxShadow> playbackBarDark = [
    BoxShadow(
      color: Color(0xCC000000),
      offset: Offset(0, -6),
      blurRadius: 24,
      spreadRadius: 0,
    ),
  ];

  /// Bottom Playback bar subtle upward drop shadow (Light)
  static const List<BoxShadow> playbackBarLight = [
    BoxShadow(
      color: Color(0x0A000000),
      offset: Offset(0, -4),
      blurRadius: 20,
      spreadRadius: 0,
    ),
  ];
}
