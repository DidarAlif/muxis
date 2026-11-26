import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/muxis_colors.dart';
import '../../app/theme/theme_controller.dart';
import '../../core/audio/audio_playback_service.dart';

class CommandPaletteDialog extends ConsumerStatefulWidget {
  final ValueChanged<int> onNavigate;
  final VoidCallback onOpenStudio;

  const CommandPaletteDialog({
    super.key,
    required this.onNavigate,
    required this.onOpenStudio,
  });

  @override
  ConsumerState<CommandPaletteDialog> createState() =>
      _CommandPaletteDialogState();
}

class _CommandPaletteDialogState extends ConsumerState<CommandPaletteDialog> {
  final TextEditingController _searchCtrl = TextEditingController();

  final List<Map<String, dynamic>> _allCommands = [
    {
      'title': 'Play / Pause',
      'icon': Icons.play_arrow_rounded,
      'action': 'toggle_play',
      'category': 'Audio',
    },
    {
      'title': 'Next Track',
      'icon': Icons.skip_next_rounded,
      'action': 'next_track',
      'category': 'Audio',
    },
    {
      'title': 'Previous Track',
      'icon': Icons.skip_previous_rounded,
      'action': 'prev_track',
      'category': 'Audio',
    },
    {
      'title': 'Open Audio Studio (EQ & DSP)',
      'icon': Icons.tune_rounded,
      'action': 'studio',
      'category': 'Audio',
    },
    {
      'title': 'Go to Home',
      'icon': Icons.home_rounded,
      'action': 'nav_0',
      'category': 'Navigation',
    },
    {
      'title': 'Go to Explore',
      'icon': Icons.explore_rounded,
      'action': 'nav_1',
      'category': 'Navigation',
    },
    {
      'title': 'Search Music & Artists',
      'icon': Icons.search_rounded,
      'action': 'nav_2',
      'category': 'Navigation',
    },
    {
      'title': 'Open Library',
      'icon': Icons.library_music_rounded,
      'action': 'nav_4',
      'category': 'Navigation',
    },
    {
      'title': 'Toggle Theme (Dark / Light)',
      'icon': Icons.palette_rounded,
      'action': 'toggle_theme',
      'category': 'System',
    },
    {
      'title': 'Open Settings',
      'icon': Icons.settings_rounded,
      'action': 'nav_10',
      'category': 'System',
    },
  ];

  List<Map<String, dynamic>> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = _allCommands;
  }

  void _filter(String query) {
    if (query.isEmpty) {
      setState(() => _filtered = _allCommands);
      return;
    }
    final q = query.toLowerCase();
    setState(() {
      _filtered = _allCommands.where((c) {
        return (c['title'] as String).toLowerCase().contains(q) ||
            (c['category'] as String).toLowerCase().contains(q);
      }).toList();
    });
  }

  void _execute(String action) {
    Navigator.of(context).pop();
    final audioService = ref.read(playbackServiceProvider.notifier);

    if (action == 'toggle_play') audioService.togglePlay();
    if (action == 'next_track') audioService.playNext();
    if (action == 'prev_track') audioService.playPrevious();
    if (action == 'studio') widget.onOpenStudio();
    if (action == 'toggle_theme')
      ref.read(themeControllerProvider.notifier).toggleTheme();
    if (action.startsWith('nav_')) {
      final idx = int.parse(action.split('_')[1]);
      widget.onNavigate(idx);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? MuxisColors.obsidian : MuxisColors.whiteSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark
              ? MuxisColors.subtleBorderDark
              : MuxisColors.subtleBorderLight,
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 420),
        child: Column(
          children: [
            // Search Input Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDark
                        ? MuxisColors.subtleBorderDark
                        : MuxisColors.subtleBorderLight,
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.search_rounded,
                    size: 22,
                    color: MuxisColors.electricCyan,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      autofocus: true,
                      onChanged: _filter,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? MuxisColors.textPrimaryDark
                            : MuxisColors.textPrimaryLight,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Type a command, screen, or action...',
                        hintStyle: TextStyle(
                          fontSize: 14,
                          color: MuxisColors.textMuted(isDark),
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? MuxisColors.elevatedSurface
                          : MuxisColors.secondarySurface,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'ESC',
                      style: TextStyle(
                        fontSize: 10,
                        fontFamily: 'JetBrains Mono',
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Command Items List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: _filtered.length,
                itemBuilder: (context, i) {
                  final item = _filtered[i];
                  return ListTile(
                    dense: true,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    hoverColor: isDark
                        ? MuxisColors.hoverSurface
                        : MuxisColors.hoverSurfaceLight,
                    leading: Icon(
                      item['icon'] as IconData,
                      size: 20,
                      color: MuxisColors.electricCyan,
                    ),
                    title: Text(
                      item['title'] as String,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? MuxisColors.textPrimaryDark
                            : MuxisColors.textPrimaryLight,
                      ),
                    ),
                    trailing: Text(
                      item['category'] as String,
                      style: TextStyle(
                        fontSize: 11,
                        color: MuxisColors.textMuted(isDark),
                      ),
                    ),
                    onTap: () => _execute(item['action'] as String),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
