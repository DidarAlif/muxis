import 'package:flutter/material.dart';

import '../../app/theme/muxis_colors.dart';
import '../../app/theme/muxis_gradients.dart';
import '../../app/theme/muxis_shadows.dart';
import 'muxis_liquid_surface.dart';

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

    final isGlassVariant =
        widget.variant == MuxisButtonVariant.liquidGlass ||
        widget.variant == MuxisButtonVariant.secondary;
    final dec = _buildDecoration(isDark, isEnabled);

    Widget content = SizedBox(
      width: widget.width,
      height: widget.height,
      child: Center(
        child: widget.isLoading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    widget.variant == MuxisButtonVariant.primary
                        ? (isDark ? Colors.black : Colors.white)
                        : MuxisColors.accent(isDark),
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
      ),
    );

    Widget buttonSurface = MuxisLiquidSurface(
      borderRadius: widget.borderRadius,
      padding: widget.variant == MuxisButtonVariant.iconOnly
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 18),
      enableGlass: isGlassVariant && isEnabled,
      blurSigma: isGlassVariant && isEnabled ? 18 : 0,
      enableHoverWave: isEnabled,
      enableDropRipple: isEnabled,
      colorOverride: dec.color,
      gradientOverride: dec.gradient,
      borderOverride: dec.border,
      boxShadowOverride: dec.boxShadow,
      useClickCursor: isEnabled,
      child: content,
    );

    // Spring press feedback without fractional hover zoom so label glyphs stay 1:1 sharp
    Widget animatedButton = AnimatedScale(
      scale: _isPressed && isEnabled ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
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
          gradient: isDark
              ? MuxisGradients.prismaticPrimary
              : MuxisGradients.prismaticLightPrimary,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          boxShadow: [
            if (_isHovered)
              BoxShadow(
                color: MuxisColors.accent(isDark).withOpacity(0.45),
                blurRadius: 18,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              )
            else
              BoxShadow(
                color: MuxisColors.accent(isDark).withOpacity(0.25),
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
                    _isHovered
                        ? Colors.white.withOpacity(0.20)
                        : Colors.white.withOpacity(0.11),
                    _isHovered
                        ? MuxisColors.neonGreen.withOpacity(0.14)
                        : Colors.white.withOpacity(0.05),
                    Colors.black.withOpacity(0.25),
                  ]
                : [
                    _isHovered
                        ? Colors.white.withOpacity(0.95)
                        : Colors.white.withOpacity(0.80),
                    const Color(0xCCE6FAF5),
                    const Color(0xBBECE9FF),
                  ],
          ),
          border: Border.all(
            color: _isHovered
                ? MuxisColors.accent(isDark).withOpacity(0.85)
                : (isDark
                      ? Colors.white.withOpacity(0.24)
                      : Colors.white.withOpacity(0.95)),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: _isHovered
                  ? MuxisColors.accent(isDark).withOpacity(0.24)
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
                    _isHovered
                        ? MuxisColors.hoverSurface.withOpacity(0.9)
                        : MuxisColors.elevatedSurface.withOpacity(0.8),
                    MuxisColors.deepSpace.withOpacity(0.7),
                  ]
                : [
                    _isHovered ? Colors.white : const Color(0xF0FFFFFF),
                    const Color(0xFFE6F4F1),
                  ],
          ),
          border: Border.all(
            color: _isHovered
                ? MuxisColors.accent(isDark).withOpacity(0.65)
                : (isDark
                      ? MuxisColors.subtleBorderDark
                      : MuxisColors.subtleBorderLight),
            width: 1,
          ),
          boxShadow: _isHovered
              ? (isDark ? MuxisShadows.card : MuxisShadows.cardLight)
              : null,
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
        return isDark ? Colors.black : Colors.white;
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
