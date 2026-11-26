import 'package:flutter/material.dart';

/// Centralized Muxis Elevation and Glow Shadows (Dark Obsidian + Luminous Light)
class MuxisShadows {
  MuxisShadows._();

  /// Soft elevation shadow for cards and surfaces (Dark)
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x45000000),
      offset: Offset(0, 6),
      blurRadius: 18,
      spreadRadius: 0,
    ),
  ];

  /// Soft elevation shadow for cards and surfaces (Light - Colored Depth)
  static const List<BoxShadow> cardLight = [
    BoxShadow(
      color: Color(0x140F172A),
      offset: Offset(0, 6),
      blurRadius: 20,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Color(0x1200A859),
      offset: Offset(0, 2),
      blurRadius: 12,
      spreadRadius: 0,
    ),
  ];

  /// Elevated card shadow with hover effect (Dark)
  static const List<BoxShadow> cardHover = [
    BoxShadow(
      color: Color(0x65000000),
      offset: Offset(0, 10),
      blurRadius: 26,
      spreadRadius: 1,
    ),
    BoxShadow(
      color: Color(0x3800FF88),
      offset: Offset(0, 0),
      blurRadius: 18,
      spreadRadius: 0,
    ),
  ];

  /// Elevated card shadow with hover effect (Light)
  static const List<BoxShadow> cardHoverLight = [
    BoxShadow(
      color: Color(0x1C0F172A),
      offset: Offset(0, 10),
      blurRadius: 24,
      spreadRadius: 1,
    ),
    BoxShadow(
      color: Color(0x2800B884),
      offset: Offset(0, 0),
      blurRadius: 16,
      spreadRadius: 0,
    ),
  ];

  /// Signature Prismatic Neon Glow for active buttons and controls (Dark)
  static const List<BoxShadow> prismaticGlow = [
    BoxShadow(
      color: Color(0x7500FF88),
      offset: Offset(0, 0),
      blurRadius: 16,
      spreadRadius: 1,
    ),
    BoxShadow(
      color: Color(0x4500E5FF),
      offset: Offset(0, 4),
      blurRadius: 24,
      spreadRadius: 0,
    ),
  ];

  /// Signature Prismatic Glow for active buttons and controls (Light)
  static const List<BoxShadow> prismaticGlowLight = [
    BoxShadow(
      color: Color(0x4800B884),
      offset: Offset(0, 4),
      blurRadius: 14,
      spreadRadius: 1,
    ),
    BoxShadow(
      color: Color(0x280284C7),
      offset: Offset(0, 2),
      blurRadius: 10,
      spreadRadius: 0,
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
      color: Color(0x140F172A),
      offset: Offset(0, -6),
      blurRadius: 24,
      spreadRadius: 0,
    ),
  ];
}
