import 'package:flutter/material.dart';

import '../../app/theme/muxis_colors.dart';

class MuxisSearchField extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final String hintText;
  final VoidCallback? onCommandPaletteTap;

  const MuxisSearchField({
    super.key,
    required this.controller,
    this.onChanged,
    this.onClear,
    this.hintText = 'Search tracks, albums, artists, or frequencies...',
    this.onCommandPaletteTap,
  });

  @override
  State<MuxisSearchField> createState() => _MuxisSearchFieldState();
}

class _MuxisSearchFieldState extends State<MuxisSearchField> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Focus(
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isDark
              ? MuxisColors.elevatedSurface
              : MuxisColors.whiteSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isFocused
                ? MuxisColors.electricCyan
                : (isDark
                      ? MuxisColors.subtleBorderDark
                      : MuxisColors.subtleBorderLight),
            width: _isFocused ? 1.5 : 1.0,
          ),
          boxShadow: _isFocused
              ? [
                  BoxShadow(
                    color: MuxisColors.electricCyan.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 0),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              Icons.search_rounded,
              size: 20,
              color: _isFocused
                  ? MuxisColors.electricCyan
                  : (isDark
                        ? MuxisColors.textSecondaryDark
                        : MuxisColors.textSecondaryLight),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: widget.controller,
                onChanged: widget.onChanged,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? MuxisColors.textPrimaryDark
                      : MuxisColors.textPrimaryLight,
                ),
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? MuxisColors.textMutedDark
                        : MuxisColors.textMutedLight,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),

            if (widget.controller.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                onPressed: () {
                  widget.controller.clear();
                  widget.onClear?.call();
                },
              ),

            // Command Palette Shortcut Hint
            GestureDetector(
              onTap: widget.onCommandPaletteTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark
                      ? MuxisColors.deepSpace
                      : MuxisColors.secondarySurface,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: isDark
                        ? MuxisColors.subtleBorderDark
                        : MuxisColors.subtleBorderLight,
                  ),
                ),
                child: Text(
                  'Ctrl + K',
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? MuxisColors.textSecondaryDark
                        : MuxisColors.textSecondaryLight,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
