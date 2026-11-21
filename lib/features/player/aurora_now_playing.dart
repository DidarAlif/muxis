import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/muxis_colors.dart';
import '../../app/theme/muxis_gradients.dart';
import '../../app/theme/muxis_shadows.dart';
import '../../app/theme/muxis_typography.dart';
import '../../core/audio/audio_playback_service.dart';
import '../../core/audio/playback_state.dart';
import '../../core/lyrics/lyrics_service.dart';
import '../../shared/models/lyrics_line.dart';
import '../../shared/widgets/muxis_slider.dart';
import 'audio_visualizer.dart';

class AuroraNowPlaying extends ConsumerStatefulWidget {
  final VoidCallback onClose;

  const AuroraNowPlaying({super.key, required this.onClose});

  @override
  ConsumerState<AuroraNowPlaying> createState() => _AuroraNowPlayingState();
}

class _AuroraNowPlayingState extends ConsumerState<AuroraNowPlaying> {
  bool _showLyrics = true;
  List<LyricsLine> _lyrics = [];

  @override
  void initState() {
    super.initState();
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
  Widget build(BuildContext context) {
    final playback = ref.watch(playbackServiceProvider);
    final audioService = ref.read(playbackServiceProvider.notifier);
    final track = playback.currentTrack;

    return Scaffold(
      backgroundColor: MuxisColors.obsidian,
      body: Stack(
        children: [
          // Dynamic Atmospheric Aurora Light Pool
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: MuxisGradients.auroraAuraRadial(
                  dominantColor: MuxisColors.velvetViolet,
                  secondaryColor: MuxisColors.electricCyan,
                ),
              ),
            ),
          ),

          // Main Expanded Layout
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
              child: Column(
                children: [
                  // Top Command Bar (Back/Dismiss, App Monogram, Lyrics Toggle)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 32,
                          color: Colors.white,
                        ),
                        tooltip: 'Collapse',
                        onPressed: widget.onClose,
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: MuxisColors.elevatedSurface.withOpacity(
                                0.6,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: MuxisColors.subtleBorderDark,
                              ),
                            ),
                            child: const Text(
                              'AURORA NOW PLAYING',
                              style: TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                                color: MuxisColors.electricCyan,
                              ),
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: Icon(
                          _showLyrics
                              ? Icons.lyrics_rounded
                              : Icons.album_rounded,
                          size: 24,
                          color: _showLyrics
                              ? MuxisColors.electricCyan
                              : Colors.white70,
                        ),
                        tooltip: _showLyrics
                            ? 'Show Artwork'
                            : 'Show Synced Lyrics',
                        onPressed: () =>
                            setState(() => _showLyrics = !_showLyrics),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Center Stage: Dual View (Artwork & Lyrics)
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Large Artwork with Vinyl Depth
                        Flexible(
                          flex: 1,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 320,
                                  height: 320,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(24),
                                    gradient: MuxisGradients.auroraSpectrum,
                                    boxShadow: [
                                      BoxShadow(
                                        color: MuxisColors.velvetViolet
                                            .withOpacity(0.35),
                                        blurRadius: 36,
                                        spreadRadius: 2,
                                        offset: const Offset(0, 12),
                                      ),
                                    ],
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.music_note_rounded,
                                      size: 110,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 28),

                                // Audio Frequency Visualizer Bars
                                AudioVisualizer(
                                  isPlaying: playback.isPlaying,
                                  barCount: 40,
                                  height: 48,
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Synced Lyrics Stream (Right Column)
                        if (_showLyrics)
                          Flexible(
                            flex: 1,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                              ),
                              child: _buildLyricsView(playback.position),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Bottom Controls Console
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Track Title, Artist, & Favorite
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    track?.title ?? 'No track',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: MuxisTypography.pageTitle(
                                      isDark: true,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${track?.artist ?? "Unknown"} • ${track?.album ?? ""}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        MuxisTypography.sectionHeading(
                                          isDark: true,
                                        ).copyWith(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w400,
                                          color: MuxisColors.textSecondaryDark,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                (track?.isFavorite ?? false)
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                size: 28,
                                color: (track?.isFavorite ?? false)
                                    ? MuxisColors.neonMagenta
                                    : MuxisColors.textSecondaryDark,
                              ),
                              onPressed: () =>
                                  audioService.toggleFavoriteCurrentTrack(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Timeline Scrubber
                        MuxisSlider(
                          value: playback.progressFraction,
                          bufferedValue: playback.bufferedFraction,
                          onChanged: (frac) {
                            final targetMs =
                                (frac * playback.duration.inMilliseconds)
                                    .toInt();
                            audioService.seek(Duration(milliseconds: targetMs));
                          },
                        ),
                        const SizedBox(height: 8),

                        // Timestamps
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(playback.position),
                              style: MuxisTypography.timecode(isDark: true),
                            ),
                            Text(
                              _formatDuration(playback.duration),
                              style: MuxisTypography.timecode(isDark: true),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Playback Buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.shuffle_rounded,
                                color: playback.isShuffle
                                    ? MuxisColors.electricCyan
                                    : Colors.white60,
                              ),
                              onPressed: () => audioService.toggleShuffle(),
                            ),
                            const SizedBox(width: 24),
                            IconButton(
                              icon: const Icon(
                                Icons.skip_previous_rounded,
                                size: 36,
                                color: Colors.white,
                              ),
                              onPressed: () => audioService.playPrevious(),
                            ),
                            const SizedBox(width: 24),
                            GestureDetector(
                              onTap: () => audioService.togglePlay(),
                              child: Container(
                                width: 64,
                                height: 64,
                                decoration: const BoxDecoration(
                                  gradient: MuxisGradients.prismaticPrimary,
                                  shape: BoxShape.circle,
                                  boxShadow: MuxisShadows.prismaticGlow,
                                ),
                                child: Center(
                                  child: Icon(
                                    playback.isPlaying
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    color: Colors.black,
                                    size: 38,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 24),
                            IconButton(
                              icon: const Icon(
                                Icons.skip_next_rounded,
                                size: 36,
                                color: Colors.white,
                              ),
                              onPressed: () => audioService.playNext(),
                            ),
                            const SizedBox(width: 24),
                            IconButton(
                              icon: Icon(
                                playback.repeatMode == RepeatMode.one
                                    ? Icons.repeat_one_rounded
                                    : Icons.repeat_rounded,
                                color: playback.repeatMode != RepeatMode.off
                                    ? MuxisColors.electricCyan
                                    : Colors.white60,
                              ),
                              onPressed: () => audioService.cycleRepeatMode(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLyricsView(Duration currentPosition) {
    if (_lyrics.isEmpty) {
      return const Center(
        child: Text(
          'Synchronizing lyrics with stream...',
          style: TextStyle(color: MuxisColors.textSecondaryDark),
        ),
      );
    }

    return ListView.builder(
      itemCount: _lyrics.length,
      itemBuilder: (context, i) {
        final line = _lyrics[i];
        final isActive =
            currentPosition >= line.startTime &&
            (line.endTime == null || currentPosition < line.endTime!);

        return AnimatedPadding(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: isActive ? 12.0 : 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                line.text,
                style: TextStyle(
                  fontSize: isActive ? 22 : 16,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? Colors.white : Colors.white38,
                  shadows: isActive
                      ? [
                          const BoxShadow(
                            color: MuxisColors.electricCyan,
                            blurRadius: 18,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
              ),
              if (line.translation != null) ...[
                const SizedBox(height: 4),
                Text(
                  line.translation!,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: isActive ? MuxisColors.electricCyan : Colors.white24,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
