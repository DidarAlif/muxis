import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/muxis_colors.dart';
import '../../app/theme/muxis_gradients.dart';
import '../../app/theme/muxis_typography.dart';
import '../../core/audio/audio_playback_service.dart';
import '../../shared/models/track.dart';
import '../../shared/widgets/muxis_button.dart';
import '../../shared/widgets/muxis_card.dart';
import '../../shared/widgets/muxis_track_row.dart';

class HomeScreen extends ConsumerWidget {
  final ValueChanged<int> onNavigate;

  const HomeScreen({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playbackServiceProvider);
    final audioService = ref.read(playbackServiceProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      children: [
        // --- 1. HERO FEATURED PRISMATIC BANNER ---
        Container(
          height: 220,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: MuxisGradients.auroraSpectrum,
            boxShadow: [
              BoxShadow(
                color: MuxisColors.velvetViolet.withOpacity(0.35),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'FEATURED SPOTLIGHT',
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: MuxisColors.electricCyan,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Prismatic Horizons',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Immerse in high-fidelity 96kHz/24-bit lossless frequency synthesis by Aura Collective.',
                      maxLines: 2,
                      style: TextStyle(fontSize: 13, color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        MuxisButton(
                          label: 'Play Spotlight',
                          icon: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.black,
                          ),
                          variant: MuxisButtonVariant.primary,
                          height: 38,
                          onPressed: () {
                            if (playback.queue.isNotEmpty) {
                              audioService.playTrack(playback.queue[0]);
                            }
                          },
                        ),
                        const SizedBox(width: 12),
                        MuxisButton(
                          label: 'Explore Album',
                          variant: MuxisButtonVariant.secondary,
                          height: 38,
                          onPressed: () => onNavigate(1), // Explore
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              // Geometric Prism Graphic Icon
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withOpacity(0.25),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 2,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.graphic_eq_rounded,
                    size: 64,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 36),

        // --- 2. RECENTLY PLAYED SHELF ---
        Text(
          'Recently Played',
          style: MuxisTypography.sectionHeading(isDark: isDark),
        ),
        const SizedBox(height: 14),

        if (playback.queue.isEmpty)
          Container(
            height: 140,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark
                  ? MuxisColors.elevatedSurface
                  : MuxisColors.whiteSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? MuxisColors.subtleBorderDark
                    : MuxisColors.subtleBorderLight,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.history_rounded,
                  size: 36,
                  color: MuxisColors.electricCyan,
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'No Recent Tracks Yet',
                        style: MuxisTypography.cardTitle(isDark: isDark),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Your playback history will appear here once you play local tracks or stream audio.',
                        style: TextStyle(
                          fontSize: 12,
                          color: MuxisColors.textSecondaryDark,
                        ),
                      ),
                    ],
                  ),
                ),
                MuxisButton(
                  label: 'Go to Library',
                  variant: MuxisButtonVariant.secondary,
                  height: 36,
                  onPressed: () => onNavigate(4),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 230,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: playback.queue.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (context, i) {
                final track = playback.queue[i];
                return MuxisCard(
                  title: track.title,
                  subtitle: track.artist,
                  onTap: () => audioService.playTrack(track),
                  onPlayTap: () => audioService.playTrack(track),
                );
              },
            ),
          ),

        const SizedBox(height: 36),

        // --- 3. RECOMMENDED TRACKS LIST ---
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Tracks in Queue',
              style: MuxisTypography.sectionHeading(isDark: isDark),
            ),
            TextButton(
              onPressed: () => onNavigate(4), // Library
              child: const Text(
                'View All Library',
                style: TextStyle(color: MuxisColors.electricCyan),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (playback.queue.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'No tracks queued. Open your Library or Explore to queue audio.',
                style: MuxisTypography.caption(isDark: isDark),
              ),
            ),
          )
        else
          ...List.generate(playback.queue.length, (i) {
            final t = playback.queue[i];
            return MuxisTrackRow(
              track: t,
              index: i,
              isPlaying:
                  playback.currentTrack?.id == t.id && playback.isPlaying,
              onTap: () => audioService.playTrack(t),
              onFavoriteTap: () => audioService.toggleFavoriteCurrentTrack(),
              onPlayNextTap: () => audioService.addToQueue(t, playNext: true),
              onAddToQueueTap: () => audioService.addToQueue(t),
            );
          }),
      ],
    );
  }
}
