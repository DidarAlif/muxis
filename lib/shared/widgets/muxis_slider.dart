import 'package:flutter/material.dart';

import '../../app/theme/muxis_colors.dart';

class MuxisSlider extends StatefulWidget {
  final double value; // 0.0 to 1.0
  final double bufferedValue; // 0.0 to 1.0
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;
  final double height;
  final bool showThumbAlways;

  const MuxisSlider({
    super.key,
    required this.value,
    this.bufferedValue = 0.0,
    required this.onChanged,
    this.onChangeEnd,
    this.height = 18,
    this.showThumbAlways = false,
  });

  @override
  State<MuxisSlider> createState() => _MuxisSliderState();
}

class _MuxisSliderState extends State<MuxisSlider> {
  bool _isHovered = false;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (details) {
          setState(() => _isDragging = true);
          _handleSeek(details.localPosition.dx, context.size!.width);
        },
        onHorizontalDragUpdate: (details) {
          _handleSeek(details.localPosition.dx, context.size!.width);
        },
        onHorizontalDragEnd: (details) {
          setState(() => _isDragging = false);
          widget.onChangeEnd?.call(widget.value);
        },
        onTapDown: (details) {
          _handleSeek(details.localPosition.dx, context.size!.width);
          widget.onChangeEnd?.call(widget.value);
        },
        child: SizedBox(
          height: widget.height,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final activeWidth = (widget.value.clamp(0.0, 1.0) * width);
              final bufferedWidth =
                  (widget.bufferedValue.clamp(0.0, 1.0) * width);
              final showThumb =
                  _isHovered || _isDragging || widget.showThumbAlways;

              return Stack(
                alignment: Alignment.centerLeft,
                children: [
                  // Base Inactive Track
                  Container(
                    width: width,
                    height: _isHovered || _isDragging ? 5 : 4,
                    decoration: BoxDecoration(
                      color: isDark
                          ? MuxisColors.subtleBorderDark
                          : MuxisColors.subtleBorderLight,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),

                  // Buffered Track
                  if (bufferedWidth > 0)
                    Container(
                      width: bufferedWidth,
                      height: _isHovered || _isDragging ? 5 : 4,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0x334FACFE)
                            : const Color(0x4D4FACFE),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),

                  // Active Track (Theme-aware Accent -> Secondary gradient)
                  Container(
                    width: activeWidth,
                    height: _isHovered || _isDragging ? 5 : 4,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          MuxisColors.accent(isDark),
                          MuxisColors.teal(isDark),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: _isHovered || _isDragging
                          ? [
                              BoxShadow(
                                color: MuxisColors.accent(isDark)
                                    .withOpacity(0.42),
                                blurRadius: 8,
                                offset: const Offset(0, 0),
                              ),
                            ]
                          : null,
                    ),
                  ),

                  // Scrubber Thumb
                  if (showThumb)
                    Positioned(
                      left: (activeWidth - 7).clamp(0.0, width - 14),
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: MuxisColors.accent(isDark),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: MuxisColors.accent(isDark)
                                  .withOpacity(0.5),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _handleSeek(double localX, double totalWidth) {
    if (totalWidth <= 0) return;
    final frac = (localX / totalWidth).clamp(0.0, 1.0);
    widget.onChanged(frac);
  }
}
