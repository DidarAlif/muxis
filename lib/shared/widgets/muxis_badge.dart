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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(isDark ? 0.20 : 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: primaryColor.withOpacity(isDark ? 0.50 : 0.42),
          width: 0.9,
        ),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.45,
          color: isDark ? Colors.white : primaryColor,
        ),
      ),
    );
  }
}
