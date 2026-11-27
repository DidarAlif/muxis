import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../app/theme/muxis_colors.dart';
import '../../core/audio/audio_playback_service.dart';
import '../../shared/models/track.dart';

/// Compact floating Mini-Player widget for Desktop minimize mode and quick overlay control.
class MuxisMiniPlayer extends ConsumerWidget {
  final VoidCallback? onExpandFull;
  final VoidCallback? onMinimizeToTaskbar;

  const MuxisMiniPlayer({
    super.key,
    this.onExpandFull,
    this.onMinimizeToTaskbar,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playbackServiceProvider);
    final audioService = ref.read(playbackServiceProvider.notifier);
    final track = playback.currentTrack;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = MuxisColors.accent(isDark);
    final isRadio = track?.source == MusicSource.radio;

    final cardContent = ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      MuxisColors.deepSpace.withOpacity(0.92),
                      MuxisColors.obsidian.withOpacity(0.95),
                    ]
                  : [
                      Colors.white.withOpacity(0.92),
                      const Color(0xFFF1F6FF).withOpacity(0.96),
                    ],
            ),
            border: Border.all(
              color: accent.withOpacity(isDark ? 0.42 : 0.55),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.55 : 0.16),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top bar: Artwork + Track Info + Window/Expand Buttons
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: isDark
                          ? Colors.white.withOpacity(0.08)
                          : Colors.black.withOpacity(0.05),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child:
                        track?.artworkUrl != null &&
                            track!.artworkUrl!.isNotEmpty
                        ? Image.network(
                            track.artworkUrl!,
                            width: 48,
                            height: 48,
                            cacheWidth: 144,
                            cacheHeight: 144,
                            gaplessPlayback: true,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => isRadio
                                ? Icon(
                                    Icons.radio_rounded,
                                    color: accent,
                                    size: 24,
                                  )
                                : Image.asset(
                                    'assets/brand/muxis_mark_square.png',
                                    fit: BoxFit.cover,
                                  ),
                          )
                        : (isRadio
                              ? Icon(
                                  Icons.radio_rounded,
                                  color: accent,
                                  size: 24,
                                )
                              : Image.asset(
                                  'assets/brand/muxis_mark_square.png',
                                  fit: BoxFit.cover,
                                )),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            if (isRadio)
                              Container(
                                margin: const EdgeInsets.only(right: 6),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: MuxisColors.electricCyan.withOpacity(
                                    0.2,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'LIVE',
                                  style: TextStyle(
                                    fontFamily: 'JetBrains Mono',
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w800,
                                    color: MuxisColors.electricCyan,
                                  ),
                                ),
                              ),
                            Expanded(
                              child: Text(
                                track?.title ?? 'MUXIS Ready',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                  color: MuxisColors.textPrimary(isDark),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          track?.artist ?? 'Select a song or radio station',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: MuxisColors.textSecondary(isDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onMinimizeToTaskbar != null)
                    _MiniWindowBtn(
                      icon: Icons.remove_rounded,
                      tooltip: 'Minimize to Taskbar',
                      isDark: isDark,
                      onPressed: onMinimizeToTaskbar!,
                    ),
                  if (onExpandFull != null)
                    _MiniWindowBtn(
                      icon: Icons.open_in_full_rounded,
                      tooltip: 'Restore Full Window',
                      isDark: isDark,
                      accentColor: accent,
                      onPressed: onExpandFull!,
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // Progress Scrubber + Compact Transport Controls
              Row(
                children: [
                  Expanded(
                    child: isRadio
                        ? Container(
                            height: 4,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              gradient: const LinearGradient(
                                colors: [
                                  MuxisColors.neonGreen,
                                  MuxisColors.electricCyan,
                                  MuxisColors.neonMagenta,
                                ],
                              ),
                            ),
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              minHeight: 4,
                              value: playback.progressFraction.clamp(0.0, 1.0),
                              backgroundColor: MuxisColors.border(isDark),
                              valueColor: AlwaysStoppedAnimation<Color>(accent),
                            ),
                          ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 28,
                      height: 28,
                    ),
                    icon: Icon(
                      (track?.isFavorite ?? false)
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      size: 16,
                      color: (track?.isFavorite ?? false)
                          ? MuxisColors.coralPulse
                          : MuxisColors.textMuted(isDark),
                    ),
                    tooltip: 'Favorite',
                    onPressed: track == null
                        ? null
                        : audioService.toggleFavoriteCurrentTrack,
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 30,
                      height: 30,
                    ),
                    icon: Icon(
                      Icons.skip_previous_rounded,
                      size: 20,
                      color: MuxisColors.textPrimary(isDark),
                    ),
                    tooltip: 'Previous',
                    onPressed: audioService.playPrevious,
                  ),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [accent, MuxisColors.electricCyan],
                      ),
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: playback.isLoading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : Icon(
                              playback.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              size: 20,
                              color: Colors.black,
                            ),
                      tooltip: playback.isPlaying ? 'Pause' : 'Play',
                      onPressed: audioService.togglePlay,
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 30,
                      height: 30,
                    ),
                    icon: Icon(
                      Icons.skip_next_rounded,
                      size: 20,
                      color: MuxisColors.textPrimary(isDark),
                    ),
                    tooltip: 'Next',
                    onPressed: audioService.playNext,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.linux)) {
      return DragToMoveArea(child: cardContent);
    }
    return cardContent;
  }
}

class _MiniWindowBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isDark;
  final Color? accentColor;
  final VoidCallback onPressed;

  const _MiniWindowBtn({
    required this.icon,
    required this.tooltip,
    required this.isDark,
    required this.onPressed,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 28, height: 28),
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(
        icon,
        size: 16,
        color: accentColor ?? MuxisColors.textSecondary(isDark),
      ),
    );
  }
}
