import 'package:flutter/material.dart';

import 'muxis_colors.dart';

/// Centralized Muxis Gradients (Aligned Prismatic Emerald, Teal & Violet)
class MuxisGradients {
  MuxisGradients._();

  /// Primary action & playback active indicator gradient
  static const LinearGradient prismaticPrimary = LinearGradient(
    colors: [
      MuxisColors.neonGreen,
      MuxisColors.neonMint,
      MuxisColors.cyberTeal,
    ],
    stops: [0.0, 0.55, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Light-mode rich vivid gradient for badges & active chips (AAA contrast w/ white ink)
  static const LinearGradient prismaticLightPrimary = LinearGradient(
    colors: [Color(0xFF00A859), Color(0xFF0096C7), Color(0xFF6D28D9)],
    stops: [0.0, 0.52, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Aurora full-spectrum multi-tone gradient (Aligned across Dark & Light)
  static const LinearGradient auroraSpectrum = LinearGradient(
    colors: [
      MuxisColors.neonGreen,
      MuxisColors.cyberTeal,
      MuxisColors.auroraViolet,
      MuxisColors.coralPulse,
    ],
    stops: [0.0, 0.35, 0.72, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Light mode vibrant pastel-rich hero gradient
  static const LinearGradient auroraLightHero = LinearGradient(
    colors: [
      Color(0xFF00DC82),
      Color(0xFF06B6D4),
      Color(0xFF8B5CF6),
      Color(0xFFEC4899),
    ],
    stops: [0.0, 0.34, 0.70, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// YouTube Music platform card gradient
  static const LinearGradient youtubePlatformGradient = LinearGradient(
    colors: [Color(0xFFFF2D55), Color(0xFFFF6B35), Color(0xFF9D4EDD)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Spotify platform card gradient
  static const LinearGradient spotifyPlatformGradient = LinearGradient(
    colors: [Color(0xFF1DB954), Color(0xFF00E5A3), Color(0xFF00B4D8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// SoundCloud platform card gradient
  static const LinearGradient soundcloudPlatformGradient = LinearGradient(
    colors: [Color(0xFFFF5500), Color(0xFFFF8800), Color(0xFFFF2D55)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Subtle glass card gradient for dark theme
  static const LinearGradient glassSurfaceDark = LinearGradient(
    colors: [Color(0x2200FF88), Color(0x1400E5FF), Color(0x169D6BFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Subtle glass card gradient for light theme (Apple Liquid Glass)
  static const LinearGradient glassSurfaceLight = LinearGradient(
    colors: [Color(0xE0FFFFFF), Color(0xC2F0FDFA), Color(0xB8EEF2FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Dark Theme Luxury Ambient Mesh Background
  static BoxDecoration darkAmbientBackground() {
    return const BoxDecoration(
      color: MuxisColors.obsidian,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF071318), // Subtle emerald-teal night top left
          Color(0xFF060910), // Obsidian center
          Color(0xFF0E0B1A), // Subtle violet obsidian depth bottom right
        ],
        stops: [0.0, 0.5, 1.0],
      ),
    );
  }

  /// Light Theme Luminous Colorful Mesh Background
  static BoxDecoration lightAmbientBackground() {
    return const BoxDecoration(
      color: MuxisColors.porcelain,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFDDF9F1), // Fresh mint mist top-left
          Color(0xFFEAF4FF), // Iridescent sky center
          Color(0xFFF3ECFF), // Soft aurora lavender-rose bottom-right
        ],
        stops: [0.0, 0.5, 1.0],
      ),
    );
  }

  /// Ambient background radial aura for Now Playing (Dark)
  static RadialGradient auroraAuraRadial({
    Color dominantColor = MuxisColors.neonGreen,
    Color secondaryColor = MuxisColors.auroraViolet,
  }) {
    return RadialGradient(
      center: const Alignment(0.0, -0.15),
      radius: 1.25,
      colors: [
        dominantColor.withOpacity(0.28),
        secondaryColor.withOpacity(0.18),
        MuxisColors.cyberTeal.withOpacity(0.10),
        MuxisColors.obsidian.withOpacity(0.0),
      ],
      stops: const [0.0, 0.38, 0.70, 1.0],
    );
  }

  /// Ambient background radial aura for Light theme (Colorful Luminous Bloom)
  static RadialGradient auroraAuraRadialLight({
    Color dominantColor = MuxisColors.neonGreenLight,
  }) {
    return RadialGradient(
      center: const Alignment(0.0, -0.15),
      radius: 1.3,
      colors: [
        dominantColor.withOpacity(0.24),
        MuxisColors.cyberTeal.withOpacity(0.18),
        MuxisColors.auroraViolet.withOpacity(0.16),
        MuxisColors.porcelain.withOpacity(0.0),
      ],
      stops: const [0.0, 0.35, 0.70, 1.0],
    );
  }

  /// Subtle border highlight gradient (Neon Luminescence)
  static const LinearGradient subtleBorderGlow = LinearGradient(
    colors: [
      Color(0x8800FF88),
      Color(0x6600E5FF),
      Color(0x559D6BFF),
      Color(0x6600FF88),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
