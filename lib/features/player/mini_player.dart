import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/muxis_colors.dart';
import '../../app/theme/muxis_gradients.dart';
import '../../app/theme/muxis_shadows.dart';
import '../../core/audio/audio_playback_service.dart';

class MuxisMiniPlayer extends ConsumerWidget {
  final VoidCallback onExpand;

  const MuxisMiniPlayer({super.key, required this.onExpand});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playbackServiceProvider);
    final audioService = ref.read(playbackServiceProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final track = playback.currentTrack;
    if (track == null) return const SizedBox.shrink();

    return Container(
      width: 320,
      height: 108,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? MuxisColors.elevatedSurface : MuxisColors.whiteSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? MuxisColors.subtleBorderDark
              : MuxisColors.subtleBorderLight,
        ),
        boxShadow: MuxisShadows.cardHover,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: MuxisGradients.prismaticPrimary,
                ),
                child: const Center(
                  child: Icon(
                    Icons.music_note_rounded,
                    size: 22,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(width: 10),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
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

              IconButton(
                icon: const Icon(Icons.open_in_full_rounded, size: 16),
                tooltip: 'Expand Player',
                onPressed: onExpand,
              ),
            ],
          ),
          const Spacer(),

          // Mini Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.skip_previous_rounded, size: 20),
                onPressed: () => audioService.playPrevious(),
              ),
              GestureDetector(
                onTap: () => audioService.togglePlay(),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    gradient: MuxisGradients.prismaticPrimary,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      playback.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      size: 18,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.skip_next_rounded, size: 20),
                onPressed: () => audioService.playNext(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
