import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/muxis_colors.dart';
import '../../app/theme/muxis_gradients.dart';
import '../../app/theme/muxis_shadows.dart';
import '../../app/theme/muxis_typography.dart';
import '../../core/audio/audio_playback_service.dart';
import '../../core/audio/playback_state.dart';
import '../../shared/widgets/muxis_slider.dart';

class BottomPlaybackBar extends ConsumerWidget {
  final VoidCallback onExpandNowPlaying;
  final VoidCallback onToggleRightDrawer;
  final VoidCallback onOpenAudioStudio;
  final bool isLyricsActive;
  final bool isQueueActive;

  const BottomPlaybackBar({
    super.key,
    required this.onExpandNowPlaying,
    required this.onToggleRightDrawer,
    required this.onOpenAudioStudio,
    this.isLyricsActive = false,
    this.isQueueActive = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playbackServiceProvider);
    final audioService = ref.read(playbackServiceProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final track = playback.currentTrack;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          height: 92,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          decoration: BoxDecoration(
            color: isDark
                ? MuxisColors.obsidian.withOpacity(0.76)
                : Colors.white.withOpacity(0.76),
            border: Border(
              top: BorderSide(
                color: isDark
                    ? Colors.white.withOpacity(0.10)
                    : Colors.white.withOpacity(0.92),
                width: 1,
              ),
            ),
            boxShadow: isDark
                ? MuxisShadows.playbackBarDark
                : MuxisShadows.playbackBarLight,
          ),
          child: Row(
        children: [
          // Left: Current Track Details & Artwork
          Expanded(
            flex: 3,
            child: Row(
              children: [
                GestureDetector(
                  onTap: onExpandNowPlaying,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: MuxisGradients.prismaticPrimary,
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: track?.artworkUrl != null &&
                              track!.artworkUrl!.isNotEmpty
                          ? Image.network(
                              track.artworkUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Center(
                                child: Icon(
                                  Icons.music_note_rounded,
                                  color: Colors.black,
                                  size: 28,
                                ),
                              ),
                            )
                          : (track == null
                              ? Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Image.asset(
                                    'assets/brand/muxis_mark.png',
                                    fit: BoxFit.contain,
                                    filterQuality: FilterQuality.high,
                                  ),
                                )
                              : const Center(
                                  child: Icon(
                                    Icons.music_note_rounded,
                                    color: Colors.black,
                                    size: 28,
                                  ),
                                )),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: onExpandNowPlaying,
                        child: Text(
                          track?.title ?? 'No track playing',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.1,
                            color: isDark
                                ? MuxisColors.textPrimaryDark
                                : MuxisColors.textPrimaryLight,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        track?.artist ?? 'Select a track to start listening',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: isDark
                              ? MuxisColors.textSecondaryDark
                              : MuxisColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),

                if (track != null)
                  IconButton(
                    icon: Icon(
                      track.isFavorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      size: 20,
                      color: track.isFavorite
                          ? MuxisColors.neonMagenta
                          : (isDark
                                ? MuxisColors.textSecondaryDark
                                : MuxisColors.textSecondaryLight),
                    ),
                    tooltip: track.isFavorite
                        ? 'Remove from Favorites'
                        : 'Save to Favorites',
                    onPressed: () => audioService.toggleFavoriteCurrentTrack(),
                  ),
              ],
            ),
          ),

          // Center: Primary Playback Controls & Precision Timeline Slider
          Expanded(
            flex: 6,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Control Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Shuffle Toggle
                    IconButton(
                      icon: Icon(
                        Icons.shuffle_rounded,
                        size: 18,
                        color: playback.isShuffle
                            ? MuxisColors.electricCyan
                            : (isDark
                                  ? MuxisColors.textSecondaryDark
                                  : MuxisColors.textSecondaryLight),
                      ),
                      tooltip: 'Shuffle',
                      onPressed: () => audioService.toggleShuffle(),
                    ),
                    const SizedBox(width: 6),

                    // Previous Track
                    IconButton(
                      icon: Icon(
                        Icons.skip_previous_rounded,
                        size: 24,
                        color: isDark
                            ? MuxisColors.textPrimaryDark
                            : MuxisColors.textPrimaryLight,
                      ),
                      tooltip: 'Previous (Ctrl + Left)',
                      onPressed: () => audioService.playPrevious(),
                    ),
                    const SizedBox(width: 10),

                    // Primary Play/Pause Button
                    GestureDetector(
                      onTap: () => audioService.togglePlay(),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: MuxisGradients.prismaticPrimary,
                          shape: BoxShape.circle,
                          boxShadow: playback.isPlaying
                              ? MuxisShadows.prismaticGlow
                              : null,
                        ),
                        child: Center(
                          child: Icon(
                            playback.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.black,
                            size: 26,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Next Track
                    IconButton(
                      icon: Icon(
                        Icons.skip_next_rounded,
                        size: 24,
                        color: isDark
                            ? MuxisColors.textPrimaryDark
                            : MuxisColors.textPrimaryLight,
                      ),
                      tooltip: 'Next (Ctrl + Right)',
                      onPressed: () => audioService.playNext(),
                    ),
                    const SizedBox(width: 6),

                    // Repeat Mode Toggle
                    IconButton(
                      icon: Icon(
                        playback.repeatMode == RepeatMode.one
                            ? Icons.repeat_one_rounded
                            : Icons.repeat_rounded,
                        size: 18,
                        color: playback.repeatMode != RepeatMode.off
                            ? MuxisColors.electricCyan
                            : (isDark
                                  ? MuxisColors.textSecondaryDark
                                  : MuxisColors.textSecondaryLight),
                      ),
                      tooltip: 'Repeat: ${playback.repeatMode.name}',
                      onPressed: () => audioService.cycleRepeatMode(),
                    ),
                  ],
                ),
                const SizedBox(height: 2),

                // Scrubber Bar with Timecodes
                Row(
                  children: [
                    Text(
                      _formatDuration(playback.position),
                      style: MuxisTypography.timecode(isDark: isDark),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: MuxisSlider(
                        value: playback.progressFraction,
                        bufferedValue: playback.bufferedFraction,
                        onChanged: (fraction) {
                          final targetMs =
                              (fraction * playback.duration.inMilliseconds)
                                  .toInt();
                          audioService.seek(Duration(milliseconds: targetMs));
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _formatDuration(playback.duration),
                      style: MuxisTypography.timecode(isDark: isDark),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Right: Secondary Actions (Lyrics, Queue, Studio, Volume, Fullscreen)
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Synced Lyrics Toggle
                IconButton(
                  icon: Icon(
                    Icons.lyrics_rounded,
                    size: 20,
                    color: isLyricsActive
                        ? MuxisColors.electricCyan
                        : (isDark
                              ? MuxisColors.textSecondaryDark
                              : MuxisColors.textSecondaryLight),
                  ),
                  tooltip: 'Synchronized Lyrics',
                  onPressed: onToggleRightDrawer,
                ),

                // Up-Next Queue Toggle
                IconButton(
                  icon: Icon(
                    Icons.queue_music_rounded,
                    size: 20,
                    color: isQueueActive
                        ? MuxisColors.electricCyan
                        : (isDark
                              ? MuxisColors.textSecondaryDark
                              : MuxisColors.textSecondaryLight),
                  ),
                  tooltip: 'Play Queue',
                  onPressed: onToggleRightDrawer,
                ),

                // Audio Studio (DSP / EQ / Effects)
                IconButton(
                  icon: Icon(
                    Icons.tune_rounded,
                    size: 20,
                    color: isDark
                        ? MuxisColors.textSecondaryDark
                        : MuxisColors.textSecondaryLight,
                  ),
                  tooltip: 'Audio Studio & Effects',
                  onPressed: onOpenAudioStudio,
                ),

                const SizedBox(width: 4),

                // Mute / Volume Icon
                IconButton(
                  icon: Icon(
                    playback.isMuted || playback.volume == 0
                        ? Icons.volume_off_rounded
                        : (playback.volume < 0.5
                              ? Icons.volume_down_rounded
                              : Icons.volume_up_rounded),
                    size: 20,
                    color: isDark
                        ? MuxisColors.textSecondaryDark
                        : MuxisColors.textSecondaryLight,
                  ),
                  tooltip: playback.isMuted ? 'Unmute' : 'Mute',
                  onPressed: () => audioService.toggleMute(),
                ),

                // Volume Slider
                SizedBox(
                  width: 90,
                  child: MuxisSlider(
                    value: playback.isMuted ? 0.0 : playback.volume,
                    onChanged: (val) => audioService.setVolume(val),
                  ),
                ),

                const SizedBox(width: 8),

                // Fullscreen Aurora Player Button
                IconButton(
                  icon: const Icon(Icons.open_in_full_rounded, size: 18),
                  tooltip: 'Full Screen Player',
                  onPressed: onExpandNowPlaying,
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

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
