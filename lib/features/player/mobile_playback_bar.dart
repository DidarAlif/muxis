import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/muxis_colors.dart';
import '../../app/theme/muxis_gradients.dart';
import '../../core/audio/audio_playback_service.dart';
import '../../core/audio/playback_state.dart';
import '../../shared/widgets/muxis_liquid_surface.dart';

/// Sleek, compact mobile playback bar designed for touch phones (`< 768px`).
/// Supports tap-to-expand Now Playing and horizontal swipe to skip tracks.
class MobilePlaybackBar extends ConsumerWidget {
  final VoidCallback onExpandNowPlaying;

  const MobilePlaybackBar({super.key, required this.onExpandNowPlaying});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playbackServiceProvider);
    final audioService = ref.read(playbackServiceProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final track = playback.currentTrack;
    final accent = MuxisColors.accent(isDark);

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (track == null) return;
        final vx = details.primaryVelocity ?? 0;
        if (vx < -220) {
          audioService.playNext();
        } else if (vx > 220) {
          audioService.playPrevious();
        }
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
        child: MuxisLiquidSurface(
          onTap: onExpandNowPlaying,
          borderRadius: 18,
          enableBackdropBlur: true,
          blurSigma: 20,
          accentColor: accent,
          colorOverride: isDark
              ? MuxisColors.deepSpace.withOpacity(0.90)
              : Colors.white.withOpacity(0.92),
          borderOverride: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.14)
                : MuxisColors.subtleBorderLight,
          ),
          boxShadowOverride: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.42 : 0.12),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
          child: SizedBox(
            height: 62,
            child: Column(
              children: [
                // Top hairline progress bar
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18),
                  ),
                  child: SizedBox(
                    height: 2.5,
                    width: double.infinity,
                    child: Stack(
                      children: [
                        Container(
                          color: isDark
                              ? Colors.white.withOpacity(0.08)
                              : Colors.black.withOpacity(0.06),
                        ),
                        FractionallySizedBox(
                          widthFactor: track == null
                              ? 0.0
                              : playback.progressFraction.clamp(0.0, 1.0),
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: MuxisGradients.auroraSpectrum,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Track info & compact controls
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        // Artwork or wise logo badge
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: isDark
                                ? MuxisColors.elevatedSurface
                                : Colors.white,
                            border: Border.all(
                              color: isDark
                                  ? MuxisColors.subtleBorderDark
                                  : MuxisColors.subtleBorderLight,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child:
                              track?.artworkUrl != null &&
                                  track!.artworkUrl!.isNotEmpty
                              ? Image.network(
                                  track.artworkUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _buildIdleLogo(isDark),
                                )
                              : _buildIdleLogo(isDark),
                        ),
                        const SizedBox(width: 10),

                        // Title & Artist
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                track?.title ?? 'Ready to Stream',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: MuxisColors.textPrimary(isDark),
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                track?.artist ?? 'Tap any song or platform mix',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: MuxisColors.textSecondary(isDark),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Favorite button
                        if (track != null)
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            constraints: const BoxConstraints(
                              minWidth: 34,
                              minHeight: 34,
                            ),
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              track.isFavorite
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              size: 19,
                              color: track.isFavorite
                                  ? MuxisColors.heartActive
                                  : MuxisColors.textMuted(isDark),
                            ),
                            onPressed: audioService.toggleFavoriteCurrentTrack,
                          ),

                        const SizedBox(width: 2),

                        // Play / Pause Circle
                        InkWell(
                          onTap: track == null ? null : audioService.togglePlay,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: track == null
                                  ? null
                                  : MuxisGradients.auroraSpectrum,
                              color: track == null
                                  ? MuxisColors.textMuted(isDark)
                                        .withOpacity(0.25)
                                  : null,
                            ),
                            child: playback.isLoading
                                ? const Padding(
                                    padding: EdgeInsets.all(9),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : Icon(
                                    playback.isPlaying
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    size: 21,
                                    color: track == null
                                        ? MuxisColors.textMuted(isDark)
                                        : Colors.white,
                                  ),
                          ),
                        ),

                        // Next button
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints(
                            minWidth: 34,
                            minHeight: 34,
                          ),
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            Icons.skip_next_rounded,
                            size: 22,
                            color: track == null
                                ? MuxisColors.textMuted(isDark)
                                : MuxisColors.textPrimary(isDark),
                          ),
                          onPressed: track == null
                              ? null
                              : audioService.playNext,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIdleLogo(bool isDark) {
    if (!isDark) {
      return Image.asset(
        'assets/brand/app_icon_1024.png',
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
      );
    }
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Image.asset(
        'assets/brand/muxis_mark_square.png',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}
