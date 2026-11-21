import 'dart:ui';
import 'package:flutter/material.dart';

import '../../app/theme/muxis_colors.dart';
import '../../app/theme/muxis_gradients.dart';
import '../../app/theme/muxis_shadows.dart';

enum MuxisButtonVariant { primary, secondary, liquidGlass, ghost, iconOnly }

class MuxisButton extends StatefulWidget {
  final String? label;
  final Widget? icon;
  final VoidCallback? onPressed;
  final MuxisButtonVariant variant;
  final bool isLoading;
  final double? width;
  final double height;
  final double borderRadius;
  final String? tooltip;

  const MuxisButton({
    super.key,
    this.label,
    this.icon,
    this.onPressed,
    this.variant = MuxisButtonVariant.primary,
    this.isLoading = false,
    this.width,
    this.height = 42,
    this.borderRadius = 12,
    this.tooltip,
  });

  @override
  State<MuxisButton> createState() => _MuxisButtonState();
}

class _MuxisButtonState extends State<MuxisButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEnabled = widget.onPressed != null && !widget.isLoading;

    final isGlassVariant = widget.variant == MuxisButtonVariant.liquidGlass ||
        widget.variant == MuxisButtonVariant.secondary;

    Widget content = Center(
      child: widget.isLoading
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  widget.variant == MuxisButtonVariant.primary
                      ? Colors.black
                      : MuxisColors.electricCyan,
                ),
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.icon != null) ...[
                  widget.icon!,
                  if (widget.label != null) const SizedBox(width: 8),
                ],
                if (widget.label != null)
                  Text(
                    widget.label!,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                      color: _getTextColor(isDark, isEnabled),
                    ),
                  ),
              ],
            ),
    );

    Widget buttonSurface = Container(
      width: widget.width,
      height: widget.height,
      padding: widget.variant == MuxisButtonVariant.iconOnly
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 18),
      decoration: _buildDecoration(isDark, isEnabled),
      child: content,
    );

    // Apply frosted blur filter for Apple liquid glass variants
    if (isGlassVariant && isEnabled) {
      buttonSurface = ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: buttonSurface,
        ),
      );
    }

    // Spring micro-interaction
    Widget animatedButton = AnimatedScale(
      scale: _isPressed && isEnabled ? 0.94 : (_isHovered && isEnabled ? 1.02 : 1.0),
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutBack,
      child: buttonSurface,
    );

    if (widget.tooltip != null) {
      animatedButton = Tooltip(message: widget.tooltip!, child: animatedButton);
    }

    return MouseRegion(
      cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() {
        _isHovered = false;
        _isPressed = false;
      }),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: isEnabled ? widget.onPressed : null,
        child: animatedButton,
      ),
    );
  }

  BoxDecoration _buildDecoration(bool isDark, bool isEnabled) {
    if (!isEnabled) {
      return BoxDecoration(
        color: isDark ? const Color(0x33191F2D) : const Color(0x33DCE2EF),
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: Border.all(
          color: isDark
              ? MuxisColors.subtleBorderDark.withOpacity(0.4)
              : MuxisColors.subtleBorderLight,
        ),
      );
    }

    switch (widget.variant) {
      case MuxisButtonVariant.primary:
        return BoxDecoration(
          gradient: MuxisGradients.prismaticPrimary,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          boxShadow: [
            if (_isHovered)
              BoxShadow(
                color: MuxisColors.electricCyan.withOpacity(0.55),
                blurRadius: 18,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              )
            else
              BoxShadow(
                color: MuxisColors.electricCyan.withOpacity(0.25),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
          ],
        );

      case MuxisButtonVariant.liquidGlass:
        return BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    _isHovered ? Colors.white.withOpacity(0.18) : Colors.white.withOpacity(0.10),
                    _isHovered ? MuxisColors.electricCyan.withOpacity(0.12) : Colors.white.withOpacity(0.04),
                    Colors.black.withOpacity(0.25),
                  ]
                : [
                    _isHovered ? Colors.white.withOpacity(0.85) : Colors.white.withOpacity(0.65),
                    Colors.white.withOpacity(0.40),
                    Colors.white.withOpacity(0.25),
                  ],
          ),
          border: Border.all(
            color: _isHovered
                ? MuxisColors.electricCyan.withOpacity(0.8)
                : (isDark ? Colors.white.withOpacity(0.22) : Colors.white.withOpacity(0.7)),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: _isHovered
                  ? MuxisColors.electricCyan.withOpacity(0.25)
                  : Colors.black.withOpacity(isDark ? 0.35 : 0.08),
              blurRadius: _isHovered ? 16 : 10,
              offset: const Offset(0, 4),
            ),
          ],
        );

      case MuxisButtonVariant.secondary:
        return BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    _isHovered ? MuxisColors.hoverSurface.withOpacity(0.9) : MuxisColors.elevatedSurface.withOpacity(0.8),
                    MuxisColors.deepSpace.withOpacity(0.7),
                  ]
                : [
                    _isHovered ? MuxisColors.hoverSurfaceLight : MuxisColors.whiteSurface,
                    MuxisColors.secondarySurface,
                  ],
          ),
          border: Border.all(
            color: _isHovered
                ? MuxisColors.electricCyan.withOpacity(0.6)
                : (isDark
                      ? MuxisColors.subtleBorderDark
                      : MuxisColors.subtleBorderLight),
            width: 1,
          ),
          boxShadow: _isHovered ? MuxisShadows.card : null,
        );

      case MuxisButtonVariant.ghost:
        return BoxDecoration(
          color: _isHovered
              ? (isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.black.withOpacity(0.05))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(widget.borderRadius),
        );

      case MuxisButtonVariant.iconOnly:
        return BoxDecoration(
          color: _isHovered
              ? (isDark
                    ? MuxisColors.hoverSurface
                    : MuxisColors.hoverSurfaceLight)
              : Colors.transparent,
          shape: BoxShape.circle,
        );
    }
  }

  Color _getTextColor(bool isDark, bool isEnabled) {
    if (!isEnabled) {
      return isDark
          ? MuxisColors.textDisabledDark
          : MuxisColors.textDisabledLight;
    }

    switch (widget.variant) {
      case MuxisButtonVariant.primary:
        return Colors.black; // Optimal contrast on #00F2FE electric cyan
      case MuxisButtonVariant.liquidGlass:
        return isDark ? Colors.white : Colors.black87;
      case MuxisButtonVariant.secondary:
      case MuxisButtonVariant.ghost:
      case MuxisButtonVariant.iconOnly:
        return isDark
            ? MuxisColors.textPrimaryDark
            : MuxisColors.textPrimaryLight;
    }
  }
}
