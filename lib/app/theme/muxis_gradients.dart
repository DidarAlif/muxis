import 'package:flutter/material.dart';

import 'muxis_colors.dart';

/// Centralized Muxis Gradients (Prismatic Aura Specification)
class MuxisGradients {
  MuxisGradients._();

  /// Primary action & playback active indicator gradient
  static const LinearGradient prismaticPrimary = LinearGradient(
    colors: [MuxisColors.electricCyan, MuxisColors.velvetViolet],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Aurora full-spectrum gradient
  static const LinearGradient auroraSpectrum = LinearGradient(
    colors: [
      MuxisColors.electricCyan,
      MuxisColors.prismaticBlue,
      MuxisColors.velvetViolet,
      MuxisColors.neonMagenta,
    ],
    stops: [0.0, 0.35, 0.70, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Subtle glass card gradient for dark theme
  static const LinearGradient glassSurfaceDark = LinearGradient(
    colors: [
      Color(0x1A00F2FE), // 10% electric cyan tint
      Color(0x0D7F00FF), // 5% velvet violet tint
      Color(0x05191F2D), // subtle elevated surface
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Subtle glass card gradient for light theme
  static const LinearGradient glassSurfaceLight = LinearGradient(
    colors: [Color(0xCCFFFFFF), Color(0x99F7F8FC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Ambient background radial aura for Now Playing (Dark)
  static RadialGradient auroraAuraRadial({
    Color dominantColor = MuxisColors.velvetViolet,
    Color secondaryColor = MuxisColors.electricCyan,
  }) {
    return RadialGradient(
      center: const Alignment(0.0, -0.2),
      radius: 1.2,
      colors: [
        dominantColor.withOpacity(0.35),
        secondaryColor.withOpacity(0.18),
        MuxisColors.obsidian.withOpacity(0.0),
      ],
      stops: const [0.0, 0.45, 1.0],
    );
  }

  /// Ambient background radial aura for Light theme
  static RadialGradient auroraAuraRadialLight({
    Color dominantColor = MuxisColors.prismaticBlue,
  }) {
    return RadialGradient(
      center: const Alignment(0.0, -0.2),
      radius: 1.2,
      colors: [
        dominantColor.withOpacity(0.15),
        MuxisColors.porcelain.withOpacity(0.0),
      ],
      stops: const [0.0, 0.8],
    );
  }

  /// Subtle border highlight gradient
  static const LinearGradient subtleBorderGlow = LinearGradient(
    colors: [
      Color(0x6600F2FE),
      Color(0x334FACFE),
      Color(0x337F00FF),
      Color(0x66E100FF),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
