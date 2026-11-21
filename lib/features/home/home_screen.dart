import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/muxis_colors.dart';
import '../../app/theme/muxis_gradients.dart';
import '../../app/theme/muxis_typography.dart';
import '../../core/audio/audio_playback_service.dart';
import '../../core/storage/preferences_service.dart';
import '../../providers/innertube_music_provider.dart';
import '../../providers/spotify_music_provider.dart';
import '../../shared/models/track.dart';
import '../../shared/widgets/muxis_button.dart';
import '../../shared/widgets/muxis_card.dart';
import '../../shared/widgets/muxis_track_row.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final ValueChanged<int> onNavigate;

  const HomeScreen({super.key, required this.onNavigate});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final InnerTubeMusicProvider _ytProvider = InnerTubeMusicProvider();
  final SpotifyMusicProvider _spotifyProvider = SpotifyMusicProvider();
  List<Track> _trendingTracks = [];
  bool _loadingTrending = true;
  String _activePlatform = 'youtube';

  @override
  void initState() {
    super.initState();
    _loadActivePlatformAndTracks();
  }

  Future<void> _loadActivePlatformAndTracks() async {
    final prefs = ref.read(preferencesServiceProvider);
    final platform = await prefs.getActiveSource();
    if (mounted) setState(() => _activePlatform = platform);

    try {
      final tracks = platform == 'spotify'
          ? await _spotifyProvider.getFeaturedTracks()
          : await _ytProvider.getFeaturedTracks();
      if (mounted) {
        setState(() {
          _trendingTracks = tracks;
          _loadingTrending = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingTrending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _activePlatform == 'spotify'
                            ? 'SPOTIFY STREAMING ACTIVE (AD-FREE)'
                            : 'YOUTUBE MUSIC STREAMING (AD-FREE)',
                        style: const TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Prismatic Horizons',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Instant ad-free streaming with YouTube Music InnerTube & Spotify audio bridge.',
                      maxLines: 2,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xCC000000),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        MuxisButton(
                          label: 'Play Spotlight',
                          icon: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                          ),
                          variant: MuxisButtonVariant.secondary,
                          height: 38,
                          onPressed: () {
                            if (playback.queue.isNotEmpty) {
                              audioService.playTrack(playback.queue[0]);
                            } else if (_trendingTracks.isNotEmpty) {
                              audioService.playTrack(_trendingTracks[0], newQueue: _trendingTracks);
                            }
                          },
                        ),
                        const SizedBox(width: 12),
                        MuxisButton(
                          label: 'Search Catalog',
                          variant: MuxisButtonVariant.liquidGlass,
                          height: 38,
                          onPressed: () => widget.onNavigate(2), // Search
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
                  color: Colors.black.withOpacity(0.12),
                  border: Border.all(
                    color: Colors.black.withOpacity(0.25),
                    width: 2,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.graphic_eq_rounded,
                    size: 64,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 36),

        // --- 2. TRENDING WORLDWIDE HITS SHELF ---
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Trending Worldwide (Ad-Free Streaming)',
              style: MuxisTypography.sectionHeading(isDark: isDark),
            ),
            TextButton(
              onPressed: () => widget.onNavigate(1), // Explore
              child: const Text(
                'Explore All Stations',
                style: TextStyle(color: MuxisColors.electricCyan),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        if (_loadingTrending)
          const Center(child: CircularProgressIndicator())
        else
          SizedBox(
            height: 230,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _trendingTracks.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (context, i) {
                final track = _trendingTracks[i];
                return MuxisCard(
                  title: track.title,
                  subtitle: track.artist,
                  artworkUrl: track.artworkUrl,
                  onTap: () => audioService.playTrack(track, newQueue: _trendingTracks),
                  onPlayTap: () => audioService.playTrack(track, newQueue: _trendingTracks),
                );
              },
            ),
          ),

        const SizedBox(height: 36),

        // --- 3. QUEUED TRACKS LIST ---
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Active Audio Queue',
              style: MuxisTypography.sectionHeading(isDark: isDark),
            ),
            TextButton(
              onPressed: () => widget.onNavigate(4), // Library
              child: const Text(
                'View Local Library',
                style: TextStyle(color: MuxisColors.electricCyan),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (playback.queue.isEmpty)
          Container(
            height: 120,
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
                  Icons.playlist_play_rounded,
                  size: 36,
                  color: MuxisColors.electricCyan,
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Queue is Ready',
                        style: MuxisTypography.cardTitle(isDark: isDark),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Tap any Trending track above or search to begin streaming instantly.',
                        style: TextStyle(
                          fontSize: 12,
                          color: MuxisColors.textSecondaryDark,
                        ),
                      ),
                    ],
                  ),
                ),
                MuxisButton(
                  label: 'Play Trending',
                  variant: MuxisButtonVariant.primary,
                  height: 36,
                  onPressed: () {
                    if (_trendingTracks.isNotEmpty) {
                      audioService.playTrack(_trendingTracks[0], newQueue: _trendingTracks);
                    }
                  },
                ),
              ],
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
