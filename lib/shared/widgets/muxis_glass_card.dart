import 'dart:ui';
import 'package:flutter/material.dart';

import '../../app/theme/muxis_colors.dart';
import '../../app/theme/muxis_gradients.dart';

class MuxisGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final VoidCallback? onTap;

  const MuxisGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 18,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardContent = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: isDark
            ? MuxisColors.elevatedSurface.withOpacity(0.55)
            : Colors.white.withOpacity(0.68),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.14)
              : Colors.white.withOpacity(0.92),
          width: 1.2,
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  Colors.white.withOpacity(0.08),
                  MuxisColors.elevatedSurface.withOpacity(0.55),
                  MuxisColors.neonGreen.withOpacity(0.04),
                ]
              : [
                  Colors.white.withOpacity(0.88),
                  const Color(0xCCF2FDFB),
                  const Color(0xB8F3EEFF),
                ],
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.45)
                : const Color(0x140F172A),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          if (!isDark)
            BoxShadow(
              color: MuxisColors.neonGreenLight.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: child,
    );

    final glassWrapper = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: cardContent,
      ),
    );

    if (onTap != null) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(onTap: onTap, child: glassWrapper),
      );
    }

    return glassWrapper;
  }
}

class MuxisEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const MuxisEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    MuxisColors.electricCyan.withOpacity(0.2),
                    MuxisColors.velvetViolet.withOpacity(0.2),
                  ],
                ),
                border: Border.all(
                  color: isDark
                      ? MuxisColors.subtleBorderDark
                      : MuxisColors.subtleBorderLight,
                ),
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: 32,
                  color: isDark
                      ? MuxisColors.textSecondaryDark
                      : MuxisColors.textSecondaryLight,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? MuxisColors.textPrimaryDark
                    : MuxisColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: isDark
                      ? MuxisColors.textSecondaryDark
                      : MuxisColors.textSecondaryLight,
                ),
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
