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
    this.borderRadius = 16,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: isDark
            ? MuxisColors.elevatedSurface.withOpacity(0.85)
            : MuxisColors.whiteSurface.withOpacity(0.92),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: isDark
              ? MuxisColors.subtleBorderDark
              : MuxisColors.subtleBorderLight,
          width: 1,
        ),
        gradient: isDark
            ? MuxisGradients.glassSurfaceDark
            : MuxisGradients.glassSurfaceLight,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.35 : 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );

    if (onTap != null) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(onTap: onTap, child: content),
      );
    }

    return content;
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
                color: isDark
                    ? MuxisColors.elevatedSurface
                    : MuxisColors.secondarySurface,
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
                      ? MuxisColors.textMutedDark
                      : MuxisColors.textMutedLight,
                ),
              ),
            ),
            const SizedBox(height: 18),
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
              constraints: const BoxConstraints(maxWidth: 380),
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
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}
