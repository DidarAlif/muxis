import 'package:flutter/material.dart';

import 'muxis_colors.dart';

/// Centralized Muxis Gradients (Prismatic Aura Neon Green Specification)
class MuxisGradients {
  MuxisGradients._();

  /// Primary action & playback active indicator gradient (Electric Neon Green to Mint)
  static const LinearGradient prismaticPrimary = LinearGradient(
    colors: [MuxisColors.neonGreen, MuxisColors.neonMint],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Aurora full-spectrum neon gradient
  static const LinearGradient auroraSpectrum = LinearGradient(
    colors: [
      MuxisColors.neonGreen,
      MuxisColors.neonMint,
      MuxisColors.emeraldAccent,
      MuxisColors.cyberLime,
    ],
    stops: [0.0, 0.35, 0.70, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Subtle glass card gradient for dark theme
  static const LinearGradient glassSurfaceDark = LinearGradient(
    colors: [
      Color(0x1F00FF88), // 12% neon green tint
      Color(0x0A10FFA0), // 4% mint tint
      Color(0x05131A24), // subtle elevated surface
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Subtle glass card gradient for light theme (Clean Apple-like Liquid Glass)
  static const LinearGradient glassSurfaceLight = LinearGradient(
    colors: [Color(0xF0FFFFFF), Color(0xCCF1F5F9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Dark Theme Luxury Ambient Mesh Background
  static BoxDecoration darkAmbientBackground() {
    return const BoxDecoration(
      color: MuxisColors.obsidian,
      gradient: RadialGradient(
        center: Alignment(0.7, -0.9),
        radius: 1.5,
        colors: [
          Color(0x1400FF88), // Subtle ambient top neon green glow
          Color(0x0800E676), // Mid emerald mist
          MuxisColors.obsidian, // Deep space void
        ],
        stops: [0.0, 0.45, 1.0],
      ),
    );
  }

  /// Light Theme Crisp Pearlescent Background
  static BoxDecoration lightAmbientBackground() {
    return const BoxDecoration(
      color: MuxisColors.porcelain,
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFFFFFFF), // Crisp pure white top
          Color(0xFFF8FAFC), // Pearlescent mid
          Color(0xFFF1F5F9), // Soft zinc base
        ],
        stops: [0.0, 0.4, 1.0],
      ),
    );
  }

  /// Ambient background radial aura for Now Playing (Dark)
  static RadialGradient auroraAuraRadial({
    Color dominantColor = MuxisColors.neonGreen,
    Color secondaryColor = MuxisColors.neonMint,
  }) {
    return RadialGradient(
      center: const Alignment(0.0, -0.2),
      radius: 1.2,
      colors: [
        dominantColor.withOpacity(0.28),
        secondaryColor.withOpacity(0.12),
        MuxisColors.obsidian.withOpacity(0.0),
      ],
      stops: const [0.0, 0.45, 1.0],
    );
  }

  /// Ambient background radial aura for Light theme
  static RadialGradient auroraAuraRadialLight({
    Color dominantColor = MuxisColors.neonGreenLight,
  }) {
    return RadialGradient(
      center: const Alignment(0.0, -0.2),
      radius: 1.2,
      colors: [
        dominantColor.withOpacity(0.12),
        MuxisColors.porcelain.withOpacity(0.0),
      ],
      stops: const [0.0, 0.8],
    );
  }

  /// Subtle border highlight gradient (Neon Green Luminescence)
  static const LinearGradient subtleBorderGlow = LinearGradient(
    colors: [
      Color(0x8000FF88),
      Color(0x4010FFA0),
      Color(0x2000E676),
      Color(0x6000FF88),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
