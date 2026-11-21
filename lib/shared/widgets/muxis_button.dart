import 'package:flutter/material.dart';

import '../../app/theme/muxis_colors.dart';
import '../../app/theme/muxis_gradients.dart';
import '../../app/theme/muxis_shadows.dart';

enum MuxisButtonVariant { primary, secondary, ghost, iconOnly }

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
    this.borderRadius = 10,
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

    Widget buttonBody = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: widget.width,
      height: widget.height,
      padding: widget.variant == MuxisButtonVariant.iconOnly
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 18),
      decoration: _buildDecoration(isDark, isEnabled),
      transform: _isPressed && isEnabled
          ? Matrix4.diagonal3Values(0.97, 0.97, 1.0)
          : Matrix4.identity(),
      child: Center(
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
      ),
    );

    if (widget.tooltip != null) {
      buttonBody = Tooltip(message: widget.tooltip!, child: buttonBody);
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
        child: buttonBody,
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
          boxShadow: _isHovered ? MuxisShadows.prismaticGlow : null,
        );

      case MuxisButtonVariant.secondary:
        return BoxDecoration(
          color: _isHovered
              ? (isDark
                    ? MuxisColors.hoverSurface
                    : MuxisColors.hoverSurfaceLight)
              : (isDark
                    ? MuxisColors.elevatedSurface
                    : MuxisColors.whiteSurface),
          borderRadius: BorderRadius.circular(widget.borderRadius),
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
                    ? Colors.white.withOpacity(0.06)
                    : Colors.black.withOpacity(0.04))
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
      case MuxisButtonVariant.secondary:
      case MuxisButtonVariant.ghost:
      case MuxisButtonVariant.iconOnly:
        return isDark
            ? MuxisColors.textPrimaryDark
            : MuxisColors.textPrimaryLight;
    }
  }
}
