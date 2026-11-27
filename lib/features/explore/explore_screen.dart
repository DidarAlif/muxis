import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/muxis_colors.dart';
import '../../app/theme/muxis_typography.dart';
import '../../core/audio/audio_playback_service.dart';
import '../../core/auth/streaming_accounts_controller.dart';
import '../../providers/innertube_music_provider.dart';
import '../../providers/soundcloud_music_provider.dart';
import '../../providers/spotify_music_provider.dart';
import '../../shared/models/track.dart';
import '../../shared/widgets/muxis_card.dart';
import '../../shared/widgets/muxis_liquid_surface.dart';
import '../../shared/widgets/muxis_scroll_view.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final InnerTubeMusicProvider _ytProvider = InnerTubeMusicProvider();
  final SpotifyMusicProvider _spotifyProvider = SpotifyMusicProvider();
  final SoundCloudMusicProvider _soundCloudProvider = SoundCloudMusicProvider();

  List<Track> _featuredYt = [];
  List<Track> _featuredSpotify = [];
  List<Track> _featuredSoundCloud = [];
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
      final scFuture = _soundCloudProvider.fetchFeaturedSections();
      final res = await Future.wait([ytFuture, spFuture, scFuture]);
      final scSections = res[2] as List;
      final scTracks = <Track>[for (final s in scSections) ...s.tracks];
      if (mounted) {
        setState(() {
          _featuredYt = res[0] as List<Track>;
          _featuredSpotify = res[1] as List<Track>;
          _featuredSoundCloud = scTracks;
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
    final soundCloudSpotlight = _featuredSoundCloud.isNotEmpty
        ? _featuredSoundCloud
        : (accounts.soundcloud.recommendedTracks.isNotEmpty
              ? accounts.soundcloud.recommendedTracks
              : accounts.soundcloud.likedTracks);

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

    return MuxisScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Explore & Discover',
            style: MuxisTypography.pageTitle(isDark: isDark),
          ),
          const SizedBox(height: 6),
          Text(
            'Browse curated genre stations, new lossless releases, and atmospheric soundscapes.',
            style: TextStyle(
              fontSize: 14,
              color: MuxisColors.textSecondary(isDark),
            ),
          ),
          const SizedBox(height: 28),

          // Mood & Atmosphere Stations Grid (Responsive Wrap)
          Text(
            'Atmospheric Stations',
            style: MuxisTypography.sectionHeading(isDark: isDark),
          ),
          const SizedBox(height: 14),

          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 14.0;
              final cols = constraints.maxWidth >= 960
                  ? 4
                  : (constraints.maxWidth >= 560 ? 2 : 1);
              final tileWidth =
                  (constraints.maxWidth - spacing * (cols - 1)) / cols;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: moods.map((mood) {
                  final color = mood['color'] as Color;
                  final query = mood['query'] as String;
                  return SizedBox(
                    width: tileWidth,
                    child: MuxisLiquidSurface(
                      borderRadius: 16,
                      padding: const EdgeInsets.all(18),
                      accentColor: color,
                      blurSigma: 0,
                      gradientOverride: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [color.withOpacity(0.24), color.withOpacity(0.08)]
                            : [
                                color.withOpacity(0.22),
                                Colors.white.withOpacity(0.80),
                              ],
                      ),
                      borderOverride: Border.all(
                        color: color.withOpacity(isDark ? 0.45 : 0.65),
                        width: 1.2,
                      ),
                      boxShadowOverride: isDark
                          ? null
                          : [
                              BoxShadow(
                                color: color.withOpacity(0.16),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                      onTap: () async {
                        final tracks = await _ytProvider.search(query);
                        if (tracks.isNotEmpty) {
                          audioService.playTrack(
                            tracks.first,
                            newQueue: tracks,
                          );
                        }
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            mood['title'] as String,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? Colors.white
                                  : MuxisColors.textPrimaryLight,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  mood['subtitle'] as String,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? Colors.white70
                                        : MuxisColors.textSecondaryLight,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.play_circle_fill,
                                size: 22,
                                color: isDark ? Colors.white : color,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),

          const SizedBox(height: 36),

          // YouTube Music Curated Hits
          Wrap(
            spacing: 12,
            runSpacing: 4,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
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
              style: TextStyle(
                fontSize: 13,
                color: MuxisColors.textSecondary(isDark),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final spacing = constraints.maxWidth < 520 ? 12.0 : 16.0;
                final cardWidth = _responsiveCardWidth(constraints.maxWidth);
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: _featuredYt.take(12).map((t) {
                    return MuxisCard(
                      width: cardWidth,
                      title: t.title,
                      subtitle: t.artist,
                      artworkUrl: t.artworkUrl,
                      onTap: () =>
                          audioService.playTrack(t, newQueue: _featuredYt),
                      onPlayTap: () =>
                          audioService.playTrack(t, newQueue: _featuredYt),
                    );
                  }).toList(),
                );
              },
            ),

          if (!_loading && spotifySpotlight.isNotEmpty) ...[
            const SizedBox(height: 36),

            // Spotify Featured Bridge
            Wrap(
              spacing: 12,
              runSpacing: 4,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
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

            LayoutBuilder(
              builder: (context, constraints) {
                final spacing = constraints.maxWidth < 520 ? 12.0 : 16.0;
                final cardWidth = _responsiveCardWidth(constraints.maxWidth);
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: spotifySpotlight.take(12).map((t) {
                    return MuxisCard(
                      width: cardWidth,
                      title: t.title,
                      subtitle: t.artist,
                      artworkUrl: t.artworkUrl,
                      onTap: () =>
                          audioService.playTrack(t, newQueue: spotifySpotlight),
                      onPlayTap: () =>
                          audioService.playTrack(t, newQueue: spotifySpotlight),
                    );
                  }).toList(),
                );
              },
            ),
          ],

          if (!_loading && soundCloudSpotlight.isNotEmpty) ...[
            const SizedBox(height: 36),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'SoundCloud Trending & Featured Picks',
                  style: MuxisTypography.sectionHeading(isDark: isDark),
                ),
                const Text(
                  'SoundCloud Direct Stream',
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 11,
                    color: MuxisColors.soundcloudOrange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final spacing = constraints.maxWidth < 520 ? 12.0 : 16.0;
                final cardWidth = _responsiveCardWidth(constraints.maxWidth);
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: soundCloudSpotlight.take(12).map((t) {
                    return MuxisCard(
                      width: cardWidth,
                      title: t.title,
                      subtitle: t.artist,
                      artworkUrl: t.artworkUrl,
                      onTap: () => audioService.playTrack(
                        t,
                        newQueue: soundCloudSpotlight,
                      ),
                      onPlayTap: () => audioService.playTrack(
                        t,
                        newQueue: soundCloudSpotlight,
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  static double _responsiveCardWidth(double availableWidth) {
    final bool isCompact = availableWidth < 520;
    final double spacing = isCompact ? 12.0 : 16.0;
    final double target = isCompact ? 152.0 : 172.0;
    final cols = ((availableWidth + spacing) / (target + spacing))
        .floor()
        .clamp(2, 7);
    return ((availableWidth - spacing * (cols - 1)) / cols).clamp(132.0, 210.0);
  }
}
