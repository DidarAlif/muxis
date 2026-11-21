import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/muxis_colors.dart';
import '../../app/theme/muxis_typography.dart';
import '../../core/audio/audio_playback_service.dart';
import '../../providers/public_domain_music_provider.dart';
import '../../shared/widgets/muxis_card.dart';

class ExploreScreen extends ConsumerWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioService = ref.read(playbackServiceProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final provider = PublicDomainMusicProvider();

    final moods = [
      {
        'title': 'Deep Focus',
        'subtitle': 'Ambient & Binaural Waves',
        'color': MuxisColors.electricCyan,
      },
      {
        'title': 'Cybernetic Synth',
        'subtitle': 'Retro Waves & Arpeggios',
        'color': MuxisColors.prismaticBlue,
      },
      {
        'title': 'Velvet Chill',
        'subtitle': 'Low-Tempo Jazz & Lo-Fi',
        'color': MuxisColors.velvetViolet,
      },
      {
        'title': 'Prismatic High',
        'subtitle': 'Uplifting Electronic Energy',
        'color': MuxisColors.neonMagenta,
      },
    ];

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      children: [
        Text(
          'Explore & Discover',
          style: MuxisTypography.pageTitle(isDark: isDark),
        ),
        const SizedBox(height: 6),
        const Text(
          'Browse curated genre stations, new lossless releases, and atmospheric soundscapes.',
          style: TextStyle(fontSize: 14, color: MuxisColors.textSecondaryDark),
        ),
        const SizedBox(height: 28),

        // Mood & Atmosphere Stations Grid
        Text(
          'Atmospheric Stations',
          style: MuxisTypography.sectionHeading(isDark: isDark),
        ),
        const SizedBox(height: 14),

        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            childAspectRatio: 1.8,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: moods.length,
          itemBuilder: (context, i) {
            final mood = moods[i];
            final color = mood['color'] as Color;

            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [color.withOpacity(0.35), color.withOpacity(0.1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: color.withOpacity(0.4), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    mood['title'] as String,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    mood['subtitle'] as String,
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            );
          },
        ),

        const SizedBox(height: 36),

        // Legal Free & Open Streaming Catalog
        Text(
          'Authorized Open Audio Catalog',
          style: MuxisTypography.sectionHeading(isDark: isDark),
        ),
        const SizedBox(height: 14),

        FutureBuilder(
          future: provider.getFeaturedTracks(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final tracks = snapshot.data!;
            return SizedBox(
              height: 230,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: tracks.length,
                separatorBuilder: (_, __) => const SizedBox(width: 16),
                itemBuilder: (context, i) {
                  final t = tracks[i];
                  return MuxisCard(
                    title: t.title,
                    subtitle: t.artist,
                    onTap: () => audioService.playTrack(t),
                    onPlayTap: () => audioService.playTrack(t),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}
