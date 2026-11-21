import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/muxis_colors.dart';
import '../../app/theme/muxis_gradients.dart';
import '../../app/theme/muxis_typography.dart';
import '../../core/audio/audio_playback_service.dart';
import '../../core/lyrics/lyrics_service.dart';
import '../../shared/models/lyrics_line.dart';

class RightDrawerPanel extends ConsumerStatefulWidget {
  final VoidCallback onClose;

  const RightDrawerPanel({super.key, required this.onClose});

  @override
  ConsumerState<RightDrawerPanel> createState() => _RightDrawerPanelState();
}

class _RightDrawerPanelState extends ConsumerState<RightDrawerPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<LyricsLine> _lyrics = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadLyrics();
  }

  Future<void> _loadLyrics() async {
    final track = ref.read(playbackServiceProvider).currentTrack;
    if (track != null) {
      final lyrics = await ref.read(lyricsServiceProvider).fetchLyrics(track);
      if (mounted) setState(() => _lyrics = lyrics);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playback = ref.watch(playbackServiceProvider);
    final audioService = ref.read(playbackServiceProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 340,
      decoration: BoxDecoration(
        color: isDark ? MuxisColors.deepSpace : MuxisColors.whiteSurface,
        border: Border(
          left: BorderSide(
            color: isDark
                ? MuxisColors.subtleBorderDark
                : MuxisColors.subtleBorderLight,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Drawer Header with Tabs & Close
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 16),
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
                Expanded(
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: MuxisColors.electricCyan,
                    indicatorWeight: 2.5,
                    labelColor: isDark
                        ? MuxisColors.textPrimaryDark
                        : MuxisColors.textPrimaryLight,
                    unselectedLabelColor: isDark
                        ? MuxisColors.textMutedDark
                        : MuxisColors.textMutedLight,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    tabs: const [
                      Tab(text: 'Up Next'),
                      Tab(text: 'Lyrics'),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  tooltip: 'Close Panel',
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Up Next Queue List
                _buildQueueList(playback, audioService, isDark),

                // Synchronized Lyrics
                _buildLyricsView(playback.position, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueList(
    dynamic playback,
    AudioPlaybackService audioService,
    bool isDark,
  ) {
    final queue = playback.queue;
    if (queue.isEmpty) {
      return const Center(
        child: Text(
          'Queue is empty',
          style: TextStyle(color: MuxisColors.textMutedDark),
        ),
      );
    }

    return Column(
      children: [
        // Queue Actions Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${queue.length} TRACKS',
                style: const TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: MuxisColors.electricCyan,
                ),
              ),
              TextButton(
                onPressed: () => audioService.clearQueue(),
                child: const Text(
                  'Clear Queue',
                  style: TextStyle(fontSize: 12, color: MuxisColors.error),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: queue.length,
            onReorder: (oldIndex, newIndex) =>
                audioService.reorderQueue(oldIndex, newIndex),
            itemBuilder: (context, i) {
              final track = queue[i];
              final isCurrent = i == playback.currentIndex;

              return Container(
                key: ValueKey(track.id + i.toString()),
                margin: const EdgeInsets.symmetric(vertical: 3),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? (isDark
                            ? MuxisColors.elevatedSurface
                            : MuxisColors.secondarySurface)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: isCurrent
                      ? Border.all(
                          color: MuxisColors.electricCyan.withOpacity(0.4),
                        )
                      : null,
                ),
                child: Row(
                  children: [
                    // Drag Handle
                    const Icon(
                      Icons.drag_indicator_rounded,
                      size: 18,
                      color: MuxisColors.textMutedDark,
                    ),
                    const SizedBox(width: 8),

                    // Artwork
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        gradient: MuxisGradients.prismaticPrimary,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.music_note_rounded,
                          size: 18,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Track Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAlignment.start,
                        children: [
                          Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isCurrent
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isCurrent
                                  ? MuxisColors.electricCyan
                                  : (isDark
                                        ? MuxisColors.textPrimaryDark
                                        : MuxisColors.textPrimaryLight),
                            ),
                          ),
                          Text(
                            track.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: MuxisColors.textMutedDark,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Remove Action
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16),
                      onPressed: () => audioService.removeFromQueue(i),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLyricsView(Duration currentPosition, bool isDark) {
    if (_lyrics.isEmpty) {
      return const Center(
        child: Text(
          'No synced lyrics available',
          style: TextStyle(color: MuxisColors.textMutedDark),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _lyrics.length,
      itemBuilder: (context, i) {
        final line = _lyrics[i];
        final isActive =
            currentPosition >= line.startTime &&
            (line.endTime == null || currentPosition < line.endTime!);

        return Padding(
          padding: EdgeInsets.symmetric(vertical: isActive ? 10 : 6),
          child: Column(
            crossAxisAlignment: CrossAlignment.start,
            children: [
              Text(
                line.text,
                style: TextStyle(
                  fontSize: isActive ? 16 : 14,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                  color: isActive
                      ? MuxisColors.electricCyan
                      : (isDark
                            ? MuxisColors.textSecondaryDark
                            : MuxisColors.textSecondaryLight),
                ),
              ),
              if (line.translation != null) ...[
                const SizedBox(height: 2),
                Text(
                  line.translation!,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? MuxisColors.textMutedDark
                        : MuxisColors.textMutedLight,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
