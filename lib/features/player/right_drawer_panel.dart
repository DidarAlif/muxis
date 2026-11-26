import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/muxis_colors.dart';
import '../../app/theme/muxis_gradients.dart';
import '../../core/audio/audio_playback_service.dart';
import '../../core/audio/dsp/equalizer_node.dart';
import '../../core/audio/playback_state.dart';
import '../../core/lyrics/lyrics_service.dart';
import '../../shared/models/lyrics_line.dart';
import '../../shared/models/track.dart';
import 'audio_visualizer.dart';

class RightDrawerPanel extends ConsumerStatefulWidget {
  final VoidCallback onClose;

  const RightDrawerPanel({super.key, required this.onClose});

  @override
  ConsumerState<RightDrawerPanel> createState() => _RightDrawerPanelState();
}

class _RightDrawerPanelState extends ConsumerState<RightDrawerPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<LyricsLine> _lyrics = const [];
  String? _loadedTrackId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final track = ref.read(playbackServiceProvider).currentTrack;
    if (track != null) {
      _loadLyricsForTrack(track);
    }
  }

  Future<void> _loadLyricsForTrack(Track? track) async {
    final targetId = track?.id;
    _loadedTrackId = targetId;
    if (track == null) {
      if (mounted) setState(() => _lyrics = const []);
      return;
    }

    if (mounted) setState(() => _lyrics = const []);
    final lyrics = await ref.read(lyricsServiceProvider).fetchLyrics(track);
    if (!mounted || _loadedTrackId != targetId) return;
    setState(() => _lyrics = lyrics);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playback = ref.watch(playbackServiceProvider);
    final eq = ref.watch(equalizerProvider);
    final audioService = ref.read(playbackServiceProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = MuxisColors.accent(isDark);

    ref.listen<String?>(
      playbackServiceProvider.select((s) => s.currentTrack?.id),
      (prevId, nextId) {
        if (prevId != nextId) {
          _loadLyricsForTrack(ref.read(playbackServiceProvider).currentTrack);
        }
      },
    );

    final hasLyrics = _lyrics.isNotEmpty;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          width: 340,
          decoration: BoxDecoration(
            color: isDark
                ? MuxisColors.deepSpace.withValues(alpha: 0.78)
                : Colors.white.withValues(alpha: 0.80),
            border: Border(
              left: BorderSide(
                color: isDark
                    ? MuxisColors.subtleBorderDark
                    : Colors.white.withValues(alpha: 0.92),
                width: 1,
              ),
            ),
          ),
          child: Column(
            children: [
              // Drawer Header with Dynamic Tabs ('Up Next' + 'Lyrics' / 'Spectrum')
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
                        indicatorColor: accent,
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
                        tabs: [
                          const Tab(text: 'Up Next'),
                          Tab(text: hasLyrics ? 'Lyrics' : 'Spectrum'),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: isDark
                            ? MuxisColors.textSecondaryDark
                            : MuxisColors.textSecondaryLight,
                      ),
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
                    _buildQueueList(playback, audioService, isDark, accent),
                    hasLyrics
                        ? _buildLyricsView(playback.position, isDark, accent)
                        : _buildSpectrumMonitorView(
                            playback: playback,
                            eq: eq,
                            isDark: isDark,
                            accent: accent,
                          ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQueueList(
    PlaybackState playback,
    AudioPlaybackService audioService,
    bool isDark,
    Color accent,
  ) {
    final queue = playback.queue;
    final textMuted =
        isDark ? MuxisColors.textMutedDark : MuxisColors.textMutedLight;

    if (queue.isEmpty) {
      return Center(
        child: Text(
          'Queue is empty',
          style: TextStyle(color: textMuted),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${queue.length} TRACKS',
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: accent,
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
                key: ValueKey('${track.id}_$i'),
                margin: const EdgeInsets.symmetric(vertical: 3),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? (isDark
                          ? MuxisColors.elevatedSurface
                          : accent.withValues(alpha: 0.10))
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: isCurrent
                      ? Border.all(color: accent.withValues(alpha: 0.45))
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.drag_indicator_rounded,
                      size: 18,
                      color: textMuted,
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        gradient: isDark
                            ? MuxisGradients.prismaticPrimary
                            : MuxisGradients.prismaticLightPrimary,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: track.artworkUrl != null &&
                              track.artworkUrl!.isNotEmpty
                          ? Image.network(
                              track.artworkUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Center(
                                child: Icon(
                                  Icons.music_note_rounded,
                                  size: 18,
                                  color: isDark ? Colors.black : Colors.white,
                                ),
                              ),
                            )
                          : Center(
                              child: Icon(
                                Icons.music_note_rounded,
                                size: 18,
                                color: isDark ? Colors.black : Colors.white,
                              ),
                            ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                                  ? accent
                                  : (isDark
                                      ? MuxisColors.textPrimaryDark
                                      : MuxisColors.textPrimaryLight),
                            ),
                          ),
                          Text(
                            track.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: textMuted,
                      ),
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

  Widget _buildSpectrumMonitorView({
    required PlaybackState playback,
    required EqualizerState eq,
    required bool isDark,
    required Color accent,
  }) {
    final track = playback.currentTrack;
    final textPrimary = isDark
        ? MuxisColors.textPrimaryDark
        : MuxisColors.textPrimaryLight;
    final textSecondary = isDark
        ? MuxisColors.textSecondaryDark
        : MuxisColors.textSecondaryLight;
    final textMuted =
        isDark ? MuxisColors.textMutedDark : MuxisColors.textMutedLight;
    final bandGains =
        eq.isEnabled ? eq.bands.map((b) => b.gainDb).toList() : null;

    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? MuxisColors.elevatedSurface.withValues(alpha: 0.72)
                  : Colors.white.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark
                    ? MuxisColors.subtleBorderDark
                    : accent.withValues(alpha: 0.22),
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: isDark ? 0.12 : 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'STUDIO SPECTRUM',
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        color: accent,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        eq.isEnabled ? eq.activePreset : 'Bypass',
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: accent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                AudioVisualizer(
                  isPlaying: playback.isPlaying,
                  expandedStudio: true,
                  barCount: 34,
                  height: 175,
                  bandGains: bandGains,
                  volume: playback.isMuted ? 0.0 : playback.volume,
                  position: playback.position,
                  showMirror: true,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: ['32', '125', '500', '2K', '8K', '16K']
                      .map(
                        (f) => Text(
                          f,
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 9,
                            color: textMuted,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (track != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? MuxisColors.elevatedSurface.withValues(alpha: 0.45)
                    : Colors.white.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? MuxisColors.subtleBorderDark
                      : MuxisColors.subtleBorderLight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        track.source.name.toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: accent,
                        ),
                      ),
                      Text(
                        '${(playback.volume * 100).round()}% GAIN',
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 10,
                          color: textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Play a track from Spotify, YouTube Music, or your library to drive live DSP metering.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: textMuted, height: 1.4),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLyricsView(
    Duration currentPosition,
    bool isDark,
    Color accent,
  ) {
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                line.text,
                style: TextStyle(
                  fontSize: isActive ? 16 : 14,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                  color: isActive
                      ? accent
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
