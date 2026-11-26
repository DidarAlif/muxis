import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/muxis_colors.dart';
import '../../app/theme/muxis_gradients.dart';
import '../../app/theme/muxis_typography.dart';
import '../../core/audio/audio_playback_service.dart';
import '../../shared/models/playlist.dart';
import '../../shared/widgets/muxis_button.dart';
import '../../shared/widgets/muxis_scroll_view.dart';
import '../../shared/widgets/muxis_track_row.dart';

class PlaylistDetailScreen extends ConsumerWidget {
  final Playlist playlist;
  final VoidCallback onBack;

  const PlaylistDetailScreen({
    super.key,
    required this.playlist,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playbackServiceProvider);
    final audioService = ref.read(playbackServiceProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MuxisScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        // Back Button
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text('Back'),
            onPressed: onBack,
          ),
        ),
        const SizedBox(height: 12),

        // Playlist Header
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Cover Art
            Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: MuxisGradients.auroraSpectrum,
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 18,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.playlist_play_rounded,
                  size: 72,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 24),

            // Metadata
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PLAYLIST',
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: MuxisColors.electricCyan,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    playlist.title,
                    style: MuxisTypography.displayHero(isDark: isDark),
                  ),
                  if (playlist.description != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      playlist.description!,
                      style: TextStyle(
                        fontSize: 14,
                        color: MuxisColors.textSecondary(isDark),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Text(
                    '${playlist.trackCount} tracks • ${_formatDuration(playlist.totalDuration)}',
                    style: MuxisTypography.timecode(isDark: isDark),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      MuxisButton(
                        label: 'Play',
                        icon: Icon(
                          Icons.play_arrow_rounded,
                          color: isDark ? Colors.black : Colors.white,
                        ),
                        variant: MuxisButtonVariant.primary,
                        height: 38,
                        onPressed: () {
                          if (playlist.tracks.isNotEmpty) {
                            audioService.playTrack(
                              playlist.tracks[0],
                              newQueue: playlist.tracks,
                            );
                          }
                        },
                      ),
                      const SizedBox(width: 12),
                      MuxisButton(
                        label: 'Shuffle',
                        icon: const Icon(Icons.shuffle_rounded, size: 18),
                        variant: MuxisButtonVariant.secondary,
                        height: 38,
                        onPressed: () {
                          if (playlist.tracks.isNotEmpty) {
                            audioService.toggleShuffle();
                            audioService.playTrack(
                              playlist.tracks[0],
                              newQueue: playlist.tracks,
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 36),

        // Track Table
        ...List.generate(playlist.tracks.length, (i) {
          final track = playlist.tracks[i];
          return MuxisTrackRow(
            track: track,
            index: i,
            isPlaying:
                playback.currentTrack?.id == track.id && playback.isPlaying,
            onTap: () =>
                audioService.playTrack(track, newQueue: playlist.tracks),
            onFavoriteTap: () => audioService.toggleFavoriteCurrentTrack(),
            onPlayNextTap: () => audioService.addToQueue(track, playNext: true),
            onAddToQueueTap: () => audioService.addToQueue(track),
          );
        }),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m min $s sec';
  }
}
