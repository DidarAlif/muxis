import 'package:flutter/material.dart';

import 'muxis_colors.dart';

/// Centralized Muxis Elevation and Glow Shadows
class MuxisShadows {
  MuxisShadows._();

  /// Soft elevation shadow for cards and surfaces
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x33000000),
      offset: Offset(0, 4),
      blurRadius: 16,
      spreadRadius: 0,
    ),
  ];

  /// Elevated card shadow with hover effect
  static const List<BoxShadow> cardHover = [
    BoxShadow(
      color: Color(0x4D000000),
      offset: Offset(0, 8),
      blurRadius: 24,
      spreadRadius: 1,
    ),
    BoxShadow(
      color: Color(0x2600F2FE),
      offset: Offset(0, 0),
      blurRadius: 16,
      spreadRadius: 0,
    ),
  ];

  /// Signature Prismatic Glow for active buttons and controls
  static const List<BoxShadow> prismaticGlow = [
    BoxShadow(
      color: Color(0x6600F2FE),
      offset: Offset(0, 0),
      blurRadius: 16,
      spreadRadius: 2,
    ),
    BoxShadow(
      color: Color(0x4D7F00FF),
      offset: Offset(0, 4),
      blurRadius: 24,
      spreadRadius: 0,
    ),
  ];

  /// Bottom Playback bar subtle upward drop shadow
  static const List<BoxShadow> playbackBarDark = [
    BoxShadow(
      color: Color(0x99000000),
      offset: Offset(0, -6),
      blurRadius: 24,
      spreadRadius: 0,
    ),
  ];

  static const List<BoxShadow> playbackBarLight = [
    BoxShadow(
      color: Color(0x14000000),
      offset: Offset(0, -4),
      blurRadius: 20,
      spreadRadius: 0,
    ),
  ];
}
