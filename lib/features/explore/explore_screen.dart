import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/muxis_colors.dart';
import '../../app/theme/muxis_typography.dart';
import '../../core/audio/audio_playback_service.dart';
import '../../core/auth/streaming_accounts_controller.dart';
import '../../providers/innertube_music_provider.dart';
import '../../providers/spotify_music_provider.dart';
import '../../shared/models/track.dart';
import '../../shared/widgets/muxis_card.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final InnerTubeMusicProvider _ytProvider = InnerTubeMusicProvider();
  final SpotifyMusicProvider _spotifyProvider = SpotifyMusicProvider();

  List<Track> _featuredYt = [];
  List<Track> _featuredSpotify = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFeatured();
  }

  Future<void> _loadFeatured() async {
    try {
      final ytFuture = _ytProvider.fetchHomeRecommendations();
      final spFuture = _spotifyProvider.getFeaturedTracks();
      final res = await Future.wait([ytFuture, spFuture]);
      if (mounted) {
        setState(() {
          _featuredYt = res[0];
          _featuredSpotify = res[1];
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final audioService = ref.read(playbackServiceProvider.notifier);
    final accounts = ref.watch(streamingAccountsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final spotifySpotlight = _featuredSpotify.isNotEmpty
        ? _featuredSpotify
        : (accounts.spotify.recommendedTracks.isNotEmpty
            ? accounts.spotify.recommendedTracks
            : accounts.spotify.likedTracks);

    final moods = [
      {
        'title': 'Deep Focus',
        'subtitle': 'Ambient & Binaural Waves',
        'color': MuxisColors.electricCyan,
        'query': 'Deep Focus Ambient',
      },
      {
        'title': 'Cybernetic Synth',
        'subtitle': 'Retro Waves & Arpeggios',
        'color': MuxisColors.prismaticBlue,
        'query': 'Synthwave Cyberpunk',
      },
      {
        'title': 'Velvet Chill',
        'subtitle': 'Low-Tempo Jazz & Lo-Fi',
        'color': MuxisColors.velvetViolet,
        'query': 'Lo-Fi Chill Beats',
      },
      {
        'title': 'Prismatic High',
        'subtitle': 'Uplifting Electronic Energy',
        'color': MuxisColors.neonMagenta,
        'query': 'Electronic High Energy',
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
        Text(
          'Browse curated genre stations, new lossless releases, and atmospheric soundscapes.',
          style: TextStyle(fontSize: 14, color: MuxisColors.textSecondary(isDark)),
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
            final query = mood['query'] as String;

            return InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () async {
                final tracks = await _ytProvider.search(query);
                if (tracks.isNotEmpty) {
                  audioService.playTrack(tracks.first, newQueue: tracks);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [color.withOpacity(0.22), color.withOpacity(0.08)]
                        : [color.withOpacity(0.22), Colors.white.withOpacity(0.75)],
                  ),
                  border: Border.all(
                    color: color.withOpacity(isDark ? 0.45 : 0.65),
                    width: 1.2,
                  ),
                  boxShadow: isDark
                      ? null
                      : [
                          BoxShadow(
                            color: color.withOpacity(0.16),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      mood['title'] as String,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : MuxisColors.textPrimaryLight,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          mood['subtitle'] as String,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white70 : MuxisColors.textSecondaryLight,
                          ),
                        ),
                        Icon(
                          Icons.play_circle_fill,
                          size: 20,
                          color: isDark ? Colors.white : color,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 36),

        // YouTube Music Curated Hits
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Trending Global Hits (Ad-Free YouTube Music)',
              style: MuxisTypography.sectionHeading(isDark: isDark),
            ),
            const Text(
              'High Fidelity Streams',
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 11,
                color: MuxisColors.electricCyan,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_featuredYt.isEmpty)
          Text(
            'Unable to fetch live charts right now. Use Atmospheric Stations above or Search.',
            style: TextStyle(fontSize: 13, color: MuxisColors.textSecondary(isDark)),
          )
        else
          SizedBox(
            height: 230,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _featuredYt.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (context, i) {
                final t = _featuredYt[i];
                return MuxisCard(
                  title: t.title,
                  subtitle: t.artist,
                  artworkUrl: t.artworkUrl,
                  onTap: () => audioService.playTrack(t, newQueue: _featuredYt),
                  onPlayTap: () => audioService.playTrack(t, newQueue: _featuredYt),
                );
              },
            ),
          ),

        if (!_loading && spotifySpotlight.isNotEmpty) ...[
          const SizedBox(height: 36),

          // Spotify Featured Bridge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Your Spotify Spotlight',
                style: MuxisTypography.sectionHeading(isDark: isDark),
              ),
              const Text(
                'Bridged Direct Audio',
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 11,
                  color: Color(0xFF1DB954),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          SizedBox(
            height: 230,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: spotifySpotlight.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (context, i) {
                final t = spotifySpotlight[i];
                return MuxisCard(
                  title: t.title,
                  subtitle: t.artist,
                  artworkUrl: t.artworkUrl,
                  onTap: () => audioService.playTrack(t, newQueue: spotifySpotlight),
                  onPlayTap: () => audioService.playTrack(t, newQueue: spotifySpotlight),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}
