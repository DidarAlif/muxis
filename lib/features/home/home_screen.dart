import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/muxis_colors.dart';
import '../../app/theme/muxis_gradients.dart';
import '../../app/theme/muxis_typography.dart';
import '../../core/audio/audio_playback_service.dart';
import '../../core/auth/streaming_accounts_controller.dart';
import '../../providers/innertube_music_provider.dart';
import '../../shared/models/playlist.dart';
import '../../shared/models/track.dart';
import '../../shared/widgets/muxis_button.dart';
import '../../shared/widgets/muxis_card.dart';
import '../../shared/widgets/muxis_glass_card.dart';
import '../../shared/widgets/muxis_scroll_view.dart';
import '../../shared/widgets/muxis_track_row.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final ValueChanged<int> onNavigate;

  const HomeScreen({super.key, required this.onNavigate});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final InnerTubeMusicProvider _ytProvider = InnerTubeMusicProvider();
  List<Track> _trendingTracks = [];
  bool _loadingTrending = true;

  @override
  void initState() {
    super.initState();
    _loadTrending();
  }

  Future<void> _loadTrending() async {
    try {
      final tracks = await _ytProvider.fetchHomeRecommendations();
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

  Future<void> _connectPlatform(String platform) async {
    final notifier = ref.read(streamingAccountsProvider.notifier);
    final res = platform == 'spotify'
        ? await notifier.connectSpotifyWithBrowser(context)
        : await notifier.connectYouTubeWithBrowser(context);

    if (!mounted) return;
    if (res.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Connected to ${res.platform} as ${res.displayName}! Synced ${res.playlistsImported} playlists & ${res.tracksImported} tracks.',
          ),
          backgroundColor: MuxisColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (res.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.errorMessage!),
          backgroundColor: MuxisColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final playback = ref.watch(playbackServiceProvider);
    final audioService = ref.read(playbackServiceProvider.notifier);
    final accounts = ref.watch(streamingAccountsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MuxisScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        // --- 1. HERO FEATURED PRISMATIC BANNER ---
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: isDark
                ? MuxisGradients.auroraSpectrum
                : MuxisGradients.auroraLightHero,
            boxShadow: [
              BoxShadow(
                color: (isDark
                        ? MuxisColors.neonGreen
                        : MuxisColors.neonGreenLight)
                    .withOpacity(0.28),
                blurRadius: 28,
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
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _heroBadge(
                          accounts.hasAnyConnected
                              ? '${accounts.connectedCount} STREAM PLATFORM${accounts.connectedCount == 2 ? 'S' : ''} LINKED'
                              : 'MULTI-PLATFORM AD-FREE AUDIO',
                        ),
                        if (accounts.youtube.isConnected)
                          _heroBadge('YT MUSIC LIVE'),
                        if (accounts.spotify.isConnected)
                          _heroBadge('SPOTIFY BRIDGE LIVE'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Prismatic Horizons',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.black : Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      accounts.hasAnyConnected
                          ? 'Your connected streaming libraries are synced below and ready for instant ad-free playback.'
                          : 'Sign in through the web browser to link YouTube Music, Spotify, or both and stream seamlessly without ads.',
                      maxLines: 2,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? const Color(0xCC000000)
                            : Colors.white.withOpacity(0.92),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      children: [
                        MuxisButton(
                          label: 'Play Spotlight',
                          icon: Icon(
                            Icons.play_arrow_rounded,
                            color: isDark ? Colors.white : MuxisColors.textPrimaryLight,
                          ),
                          variant: MuxisButtonVariant.secondary,
                          height: 38,
                          onPressed: () {
                            if (playback.queue.isNotEmpty) {
                              audioService.playTrack(playback.queue[0]);
                            } else if (accounts.youtube.recommendedTracks.isNotEmpty) {
                              audioService.playTrack(
                                accounts.youtube.recommendedTracks[0],
                                newQueue: accounts.youtube.recommendedTracks,
                              );
                            } else if (_trendingTracks.isNotEmpty) {
                              audioService.playTrack(
                                _trendingTracks[0],
                                newQueue: _trendingTracks,
                              );
                            }
                          },
                        ),
                        MuxisButton(
                          label: 'Search Catalog',
                          variant: MuxisButtonVariant.liquidGlass,
                          height: 38,
                          onPressed: () => widget.onNavigate(2),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Container(
                width: 116,
                height: 116,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.32),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  'assets/brand/app_icon_1024.png',
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // --- 2. QUICK CONNECT PLATFORM BANNER (Shown when < 2 platforms linked) ---
        if (!accounts.youtube.isConnected || !accounts.spotify.isConnected)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                accounts.hasAnyConnected
                    ? 'Link Another Platform'
                    : 'Connect Streaming Platforms',
                style: MuxisTypography.sectionHeading(isDark: isDark),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final both = !accounts.youtube.isConnected &&
                      !accounts.spotify.isConnected;
                  final twoCols = both && constraints.maxWidth >= 680;
                  final cardWidth = twoCols
                      ? (constraints.maxWidth - 16) / 2
                      : constraints.maxWidth;
                  return Wrap(
                    spacing: 16,
                    runSpacing: 14,
                    children: [
                      if (!accounts.youtube.isConnected)
                        SizedBox(
                          width: cardWidth,
                          child: _buildConnectPlatformCard(
                            title: 'YouTube Music',
                            subtitle:
                                'Browser sign-in • Sync playlists, likes & ad-free 256kbps',
                            icon: Icons.smart_display_rounded,
                            gradient: MuxisGradients.youtubePlatformGradient,
                            isLoading: accounts.youtube.isSyncing,
                            isDark: isDark,
                            onConnect: () => _connectPlatform('youtube'),
                          ),
                        ),
                      if (!accounts.spotify.isConnected)
                        SizedBox(
                          width: cardWidth,
                          child: _buildConnectPlatformCard(
                            title: 'Spotify',
                            subtitle:
                                'Browser sign-in • Import your playlists & stream via audio bridge',
                            icon: Icons.graphic_eq_rounded,
                            gradient: MuxisGradients.spotifyPlatformGradient,
                            isLoading: accounts.spotify.isSyncing,
                            isDark: isDark,
                            onConnect: () => _connectPlatform('spotify'),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 30),
            ],
          ),

        // --- 3. DYNAMIC LINKED STREAMING SECTION(S) (1 section if 1 linked, 2 sections if 2 linked) ---
        if (accounts.youtube.isConnected) ...[
          _buildLinkedPlatformSection(
            title: 'YouTube Music — Your Stream Hub',
            subtitle:
                '${accounts.youtube.displayName ?? 'Connected'} • ${accounts.youtube.playlists.length} Playlists',
            brandColor: MuxisColors.youtubeRed,
            tracks: accounts.youtube.recommendedTracks.isNotEmpty
                ? accounts.youtube.recommendedTracks
                : accounts.youtube.likedTracks,
            playlists: accounts.youtube.playlists,
            navDestination: 11,
            isDark: isDark,
            audioService: audioService,
          ),
          const SizedBox(height: 32),
        ],

        if (accounts.spotify.isConnected) ...[
          _buildLinkedPlatformSection(
            title: 'Spotify — Your Stream Hub',
            subtitle:
                '${accounts.spotify.displayName ?? 'Connected'} • ${accounts.spotify.playlists.length} Playlists',
            brandColor: MuxisColors.spotifyGreen,
            tracks: accounts.spotify.recommendedTracks.isNotEmpty
                ? accounts.spotify.recommendedTracks
                : accounts.spotify.likedTracks,
            playlists: accounts.spotify.playlists,
            navDestination: 12,
            isDark: isDark,
            audioService: audioService,
          ),
          const SizedBox(height: 32),
        ],

        // --- 4. TRENDING WORLDWIDE SPOTLIGHT ---
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Trending Worldwide (Ad-Free Streaming)',
              style: MuxisTypography.sectionHeading(isDark: isDark),
            ),
            TextButton(
              onPressed: () => widget.onNavigate(1),
              child: Text(
                'Explore All Stations',
                style: TextStyle(
                  color: MuxisColors.accent(isDark),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        if (_loadingTrending)
          const Center(child: CircularProgressIndicator())
        else if (_trendingTracks.isEmpty)
          MuxisGlassCard(
            padding: const EdgeInsets.all(20),
            borderRadius: 16,
            child: Text(
              'Unable to load live trending tracks right now. Try Search or sync a streaming account above.',
              style: TextStyle(
                fontSize: 13,
                color: MuxisColors.textSecondary(isDark),
              ),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final visible = _trendingTracks.take(12).toList();
              final cardWidth = _responsiveCardWidth(constraints.maxWidth);
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: visible.map((track) {
                  return MuxisCard(
                    width: cardWidth,
                    title: track.title,
                    subtitle: track.artist,
                    artworkUrl: track.artworkUrl,
                    onTap: () =>
                        audioService.playTrack(track, newQueue: _trendingTracks),
                    onPlayTap: () =>
                        audioService.playTrack(track, newQueue: _trendingTracks),
                  );
                }).toList(),
              );
            },
          ),

        const SizedBox(height: 36),

        // --- 5. QUEUED TRACKS LIST ---
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Active Audio Queue',
              style: MuxisTypography.sectionHeading(isDark: isDark),
            ),
            TextButton(
              onPressed: () => widget.onNavigate(4),
              child: Text(
                'View Local Library',
                style: TextStyle(
                  color: MuxisColors.accent(isDark),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (playback.queue.isEmpty)
          MuxisGlassCard(
            padding: const EdgeInsets.all(22),
            borderRadius: 16,
            child: Row(
              children: [
                Icon(
                  Icons.playlist_play_rounded,
                  size: 36,
                  color: MuxisColors.accent(isDark),
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
                      Text(
                        'Tap any track above or open a linked streaming platform to listen immediately.',
                        style: TextStyle(
                          fontSize: 12,
                          color: MuxisColors.textSecondary(isDark),
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
                      audioService.playTrack(
                        _trendingTracks[0],
                        newQueue: _trendingTracks,
                      );
                    }
                  },
                ),
              ],
            ),
          )
        else
          ...List.generate(playback.queue.take(10).length, (i) {
            final track = playback.queue[i];
            return MuxisTrackRow(
              track: track,
              index: i,
              isPlaying:
                  playback.currentTrack?.id == track.id && playback.isPlaying,
              onTap: () => audioService.playTrack(track),
              onFavoriteTap: () => audioService.toggleFavoriteCurrentTrack(),
            );
          }),
        ],
      ),
    );
  }

  static double _responsiveCardWidth(double availableWidth) {
    const double spacing = 16.0;
    const double target = 172.0;
    final cols = ((availableWidth + spacing) / (target + spacing))
        .floor()
        .clamp(2, 7);
    return ((availableWidth - spacing * (cols - 1)) / cols).clamp(146.0, 210.0);
  }

  Widget _heroBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'JetBrains Mono',
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildConnectPlatformCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Gradient gradient,
    required bool isLoading,
    required bool isDark,
    required VoidCallback onConnect,
  }) {
    return MuxisGlassCard(
      padding: const EdgeInsets.all(18),
      borderRadius: 16,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: MuxisColors.textPrimary(isDark),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: MuxisColors.textSecondary(isDark),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          MuxisButton(
            label: isLoading ? 'Connecting...' : 'Sign In',
            icon: const Icon(Icons.open_in_browser_rounded, size: 16),
            variant: MuxisButtonVariant.primary,
            height: 38,
            isLoading: isLoading,
            onPressed: onConnect,
          ),
        ],
      ),
    );
  }

  Widget _buildLinkedPlatformSection({
    required String title,
    required String subtitle,
    required Color brandColor,
    required List<Track> tracks,
    required List<Playlist> playlists,
    required int navDestination,
    required bool isDark,
    required AudioPlaybackService audioService,
  }) {
    final hasPlaylists = playlists.isNotEmpty;
    final hasTracks = tracks.isNotEmpty;

    return MuxisGlassCard(
      padding: const EdgeInsets.all(20),
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: brandColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: brandColor.withOpacity(0.6),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: MuxisTypography.sectionHeading(isDark: isDark),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: MuxisColors.textSecondary(isDark),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              MuxisButton(
                label: 'Open Hub',
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                variant: MuxisButtonVariant.liquidGlass,
                height: 36,
                onPressed: () => widget.onNavigate(navDestination),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!hasPlaylists && !hasTracks)
            Text(
              'Account linked! Open Hub or tap Sync Library to fetch your playlists and songs.',
              style: TextStyle(
                fontSize: 13,
                color: MuxisColors.textSecondary(isDark),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = _responsiveCardWidth(constraints.maxWidth);
                return Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    ...playlists.take(6).map((pl) {
                      return MuxisCard(
                        width: cardWidth,
                        title: pl.title,
                        subtitle:
                            'Playlist • ${pl.tracks.isNotEmpty ? pl.tracks.length : pl.trackCount} tracks',
                        artworkUrl: pl.artworkUrl,
                        onTap: () => widget.onNavigate(navDestination),
                        onPlayTap: pl.tracks.isNotEmpty
                            ? () => audioService.playTrack(
                                  pl.tracks.first,
                                  newQueue: pl.tracks,
                                )
                            : () => widget.onNavigate(navDestination),
                      );
                    }),
                    ...tracks.take(8).map((t) {
                      return MuxisCard(
                        width: cardWidth,
                        title: t.title,
                        subtitle: t.artist,
                        artworkUrl: t.artworkUrl,
                        onTap: () => audioService.playTrack(t, newQueue: tracks),
                        onPlayTap: () =>
                            audioService.playTrack(t, newQueue: tracks),
                      );
                    }),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}
