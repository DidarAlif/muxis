import 'package:flutter/material.dart';

import '../../app/theme/muxis_colors.dart';

class MuxisBadge extends StatelessWidget {
  final String label;
  final Color? color;
  final bool isAccent;

  const MuxisBadge({
    super.key,
    required this.label,
    this.color,
    this.isAccent = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor =
        color ??
        (isAccent
            ? MuxisColors.electricCyan
            : (isDark ? MuxisColors.prismaticBlue : MuxisColors.velvetViolet));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: primaryColor.withOpacity(0.35), width: 0.8),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontFamily: 'JetBrains Mono',
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: primaryColor,
        ),
      ),
    );
  }
}
