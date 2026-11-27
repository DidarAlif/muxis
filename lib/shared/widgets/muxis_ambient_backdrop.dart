import 'package:flutter/material.dart';

import '../../app/theme/muxis_colors.dart';
import '../../app/theme/muxis_gradients.dart';

/// Multi-orb atmospheric aurora mesh backdrop for both Light and Dark themes.
/// Ensures Liquid Glass translucent surfaces reflect rich layered colors underneath.
class MuxisAmbientBackdrop extends StatelessWidget {
  final Widget child;
  final Color? primaryTint;

  const MuxisAmbientBackdrop({
    super.key,
    required this.child,
    this.primaryTint,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: isDark
          ? MuxisGradients.darkAmbientBackground()
          : MuxisGradients.lightAmbientBackground(),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Top-Left Emerald/Mint Aurora Orb
          IgnorePointer(
            child: Align(
              alignment: const Alignment(-0.95, -0.95),
              child: Container(
                width: 680,
                height: 680,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      (primaryTint ?? MuxisColors.accent(isDark)).withOpacity(
                        isDark ? 0.16 : 0.30,
                      ),
                      (primaryTint ?? MuxisColors.teal(isDark)).withOpacity(
                        isDark ? 0.05 : 0.12,
                      ),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.48, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // Top-Right Cyber Teal / Sky Aqua Orb
          IgnorePointer(
            child: Align(
              alignment: const Alignment(0.95, -0.75),
              child: Container(
                width: 620,
                height: 620,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      MuxisColors.teal(isDark)
                          .withOpacity(isDark ? 0.13 : 0.25),
                      MuxisColors.teal(isDark)
                          .withOpacity(isDark ? 0.03 : 0.09),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // Bottom-Right Aurora Violet / Iris Glow
          IgnorePointer(
            child: Align(
              alignment: const Alignment(0.85, 0.95),
              child: Container(
                width: 720,
                height: 720,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      MuxisColors.violet(isDark)
                          .withOpacity(isDark ? 0.16 : 0.22),
                      MuxisColors.violet(isDark)
                          .withOpacity(isDark ? 0.04 : 0.08),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.52, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // Bottom-Left Warm Rose-Coral Prism Highlight
          IgnorePointer(
            child: Align(
              alignment: const Alignment(-0.75, 0.90),
              child: Container(
                width: 520,
                height: 520,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      MuxisColors.coral(isDark)
                          .withOpacity(isDark ? 0.09 : 0.18),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // Foreground Workspace Content
          child,
        ],
      ),
    );
  }
}
