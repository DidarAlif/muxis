import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/muxis_colors.dart';
import '../../app/theme/muxis_gradients.dart';
import '../../app/theme/muxis_typography.dart';
import '../../core/audio/audio_playback_service.dart';
import '../../core/auth/streaming_accounts_controller.dart';
import '../../core/auth/supabase_auth_service.dart';
import '../../providers/innertube_music_provider.dart';
import '../../shared/models/featured_section.dart';
import '../../shared/models/playlist.dart';
import '../../shared/models/track.dart';
import '../../shared/widgets/muxis_button.dart';
import '../../shared/widgets/muxis_card.dart';
import '../../shared/widgets/muxis_glass_card.dart';
import '../../shared/widgets/muxis_scroll_view.dart';
import '../../shared/widgets/muxis_track_row.dart';
import '../auth/auth_dialog.dart';

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
        : (platform == 'soundcloud'
              ? await notifier.connectSoundCloudWithBrowser(context)
              : await notifier.connectYouTubeWithBrowser(context));

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
    final queue = ref.watch(playbackServiceProvider.select((s) => s.queue));
    final playingTrackId = ref.watch(
      playbackServiceProvider.select((s) => s.currentTrack?.id),
    );
    final isPlaying = ref.watch(
      playbackServiceProvider.select((s) => s.isPlaying),
    );
    final audioService = ref.read(playbackServiceProvider.notifier);
    final accounts = ref.watch(streamingAccountsProvider);
    final authState = ref.watch(authServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isMobile = MediaQuery.sizeOf(context).width < 600;

    return MuxisScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- 1. HERO FEATURED PRISMATIC BANNER ---
          Container(
            padding: EdgeInsets.all(isMobile ? 18 : 28),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(isMobile ? 18 : 22),
              gradient: MuxisGradients.activeHero(isDark),
              boxShadow: [
                BoxShadow(
                  color: MuxisColors.accent(isDark).withOpacity(0.28),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            foregroundDecoration: null,
            child: Container(
              padding: EdgeInsets.all(isMobile ? 14 : 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(isMobile ? 14 : 16),
                color: isDark
                    ? const Color(0xBD060A12)
                    : const Color(0x9E0B1320),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            if (isMobile) ...[
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.24),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
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
                              const SizedBox(width: 10),
                            ],
                            Expanded(
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  _heroBadge(
                                    accounts.hasAnyConnected
                                        ? '${accounts.connectedCount} STREAM PLATFORM${accounts.connectedCount > 1 ? 'S' : ''} LINKED'
                                        : 'MULTI-PLATFORM AD-FREE AUDIO',
                                  ),
                                  if (accounts.youtube.isConnected)
                                    _heroBadge('YT MUSIC LIVE'),
                                  if (accounts.spotify.isConnected)
                                    _heroBadge('SPOTIFY BRIDGE LIVE'),
                                  if (accounts.soundcloud.isConnected)
                                    _heroBadge('SOUNDCLOUD LIVE'),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: isMobile ? 10 : 12),
                        Text(
                          'Prismatic Horizons',
                          style: TextStyle(
                            fontSize: isMobile ? 22 : 28,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          accounts.hasAnyConnected
                              ? 'Your connected streaming libraries are synced below and ready for instant ad-free playback.'
                              : 'Sign in through the web browser to link YouTube Music, Spotify, and SoundCloud and stream seamlessly without ads.',
                          maxLines: isMobile ? 3 : 2,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        SizedBox(height: isMobile ? 12 : 16),
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            MuxisButton(
                              label: 'Play Spotlight',
                              icon: const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.black,
                              ),
                              variant: MuxisButtonVariant.primary,
                              height: isMobile ? 34 : 38,
                              onPressed: () {
                                if (queue.isNotEmpty) {
                                  audioService.playTrack(queue[0]);
                                } else if (accounts
                                    .youtube
                                    .recommendedTracks
                                    .isNotEmpty) {
                                  audioService.playTrack(
                                    accounts.youtube.recommendedTracks[0],
                                    newQueue:
                                        accounts.youtube.recommendedTracks,
                                  );
                                } else if (accounts
                                    .spotify
                                    .recommendedTracks
                                    .isNotEmpty) {
                                  audioService.playTrack(
                                    accounts.spotify.recommendedTracks[0],
                                    newQueue:
                                        accounts.spotify.recommendedTracks,
                                  );
                                } else if (accounts
                                    .soundcloud
                                    .recommendedTracks
                                    .isNotEmpty) {
                                  audioService.playTrack(
                                    accounts.soundcloud.recommendedTracks[0],
                                    newQueue:
                                        accounts.soundcloud.recommendedTracks,
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
                              variant: MuxisButtonVariant.secondary,
                              height: isMobile ? 34 : 38,
                              onPressed: () => widget.onNavigate(2),
                            ),
                            if (!authState.isAuthenticated)
                              MuxisButton(
                                label: 'Cloud Sign In',
                                icon: Icon(
                                  Icons.cloud_outlined,
                                  size: 16,
                                  color: MuxisColors.textPrimary(isDark),
                                ),
                                variant: MuxisButtonVariant.liquidGlass,
                                height: isMobile ? 34 : 38,
                                onPressed: () => showDialog(
                                  context: context,
                                  builder: (_) => const AuthDialog(),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!isMobile) ...[
                    const SizedBox(width: 24),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 112,
                          height: 112,
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
                        const SizedBox(height: 6),
                        Text(
                          'by A Leaf',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 28),

          // --- 2. QUICK CONNECT PLATFORM BANNER (Shown when < 3 platforms linked) ---
          if (!accounts.youtube.isConnected ||
              !accounts.spotify.isConnected ||
              !accounts.soundcloud.isConnected)
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
                    final unlinkedCount =
                        (!accounts.youtube.isConnected ? 1 : 0) +
                        (!accounts.spotify.isConnected ? 1 : 0) +
                        (!accounts.soundcloud.isConnected ? 1 : 0);
                    final cols =
                        unlinkedCount == 3 && constraints.maxWidth >= 900
                        ? 3
                        : (unlinkedCount >= 2 && constraints.maxWidth >= 640
                              ? 2
                              : 1);
                    final cardWidth = cols == 1
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 16 * (cols - 1)) / cols;
                    return Wrap(
                      spacing: 16,
                      runSpacing: 14,
                      children: [
                        if (!accounts.youtube.isConnected)
                          SizedBox(
                            width: cardWidth,
                            child: _buildConnectPlatformCard(
                              title: 'YouTube Music',
                              subtitle: 'Browser sign-in • Sync playlists, likes & ad-free 256kbps',
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
                              subtitle: 'Browser sign-in • Import your playlists & stream via audio bridge',
                              icon: Icons.graphic_eq_rounded,
                              gradient: MuxisGradients.spotifyPlatformGradient,
                              isLoading: accounts.spotify.isSyncing,
                              isDark: isDark,
                              onConnect: () => _connectPlatform('spotify'),
                            ),
                          ),
                        if (!accounts.soundcloud.isConnected)
                          SizedBox(
                            width: cardWidth,
                            child: _buildConnectPlatformCard(
                              title: 'SoundCloud',
                              subtitle: 'Browser sign-in • Stream mixes, likes, charts & curated picks',
                              icon: Icons.cloud_queue_rounded,
                              gradient:
                                  MuxisGradients.soundcloudPlatformGradient,
                              isLoading: accounts.soundcloud.isSyncing,
                              isDark: isDark,
                              onConnect: () => _connectPlatform('soundcloud'),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 30),
              ],
            ),

          // --- 3. DYNAMIC LINKED STREAMING SECTION(S) ---
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
              featuredSections: accounts.youtube.featuredSections,
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
              featuredSections: accounts.spotify.featuredSections,
              navDestination: 12,
              isDark: isDark,
              audioService: audioService,
            ),
            const SizedBox(height: 32),
          ],

          if (accounts.soundcloud.isConnected) ...[
            _buildLinkedPlatformSection(
              title: 'SoundCloud — Your Stream Hub',
              subtitle:
                  '${accounts.soundcloud.displayName ?? 'Connected'} • ${accounts.soundcloud.playlists.length} Sets',
              brandColor: MuxisColors.soundcloudOrange,
              tracks: accounts.soundcloud.recommendedTracks.isNotEmpty
                  ? accounts.soundcloud.recommendedTracks
                  : accounts.soundcloud.likedTracks,
              playlists: accounts.soundcloud.playlists,
              featuredSections: accounts.soundcloud.featuredSections,
              navDestination: 13,
              isDark: isDark,
              audioService: audioService,
            ),
            const SizedBox(height: 32),
          ],

          // --- 4. TRENDING WORLDWIDE SPOTLIGHT ---
          Wrap(
            spacing: 12,
            runSpacing: 4,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
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
                final spacing = constraints.maxWidth < 520 ? 12.0 : 16.0;
                final cardWidth = _responsiveCardWidth(constraints.maxWidth);
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: visible.map((track) {
                    return MuxisCard(
                      width: cardWidth,
                      title: track.title,
                      subtitle: track.artist,
                      artworkUrl: track.artworkUrl,
                      onTap: () => audioService.playTrack(
                        track,
                        newQueue: _trendingTracks,
                      ),
                      onPlayTap: () => audioService.playTrack(
                        track,
                        newQueue: _trendingTracks,
                      ),
                    );
                  }).toList(),
                );
              },
            ),

          const SizedBox(height: 30),

          // --- 5. QUEUED TRACKS LIST ---
          Wrap(
            spacing: 12,
            runSpacing: 4,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
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

          if (queue.isEmpty)
            MuxisGlassCard(
              padding: EdgeInsets.all(isMobile ? 16 : 22),
              borderRadius: 16,
              child: Wrap(
                spacing: 14,
                runSpacing: 12,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.playlist_play_rounded,
                        size: 32,
                        color: MuxisColors.accent(isDark),
                      ),
                      const SizedBox(width: 14),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                    ],
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
            ...List.generate(queue.take(10).length, (i) {
              final track = queue[i];
              return MuxisTrackRow(
                track: track,
                index: i,
                isPlaying: playingTrackId == track.id && isPlaying,
                onTap: () => audioService.playTrack(track),
                onFavoriteTap: () => audioService.toggleFavoriteCurrentTrack(),
              );
            }),
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

  Widget _heroBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xCC060910),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.18), width: 0.8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.7,
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
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stackCompact = constraints.maxWidth < 340;
          if (stackCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: gradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
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
                          const SizedBox(height: 2),
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
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: MuxisButton(
                    label: isLoading ? 'Connecting...' : 'Sign In',
                    icon: const Icon(Icons.open_in_browser_rounded, size: 15),
                    variant: MuxisButtonVariant.primary,
                    height: 34,
                    isLoading: isLoading,
                    onPressed: onConnect,
                  ),
                ),
              ],
            );
          }

          return Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
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
              const SizedBox(width: 10),
              MuxisButton(
                label: isLoading ? 'Connecting...' : 'Sign In',
                icon: const Icon(Icons.open_in_browser_rounded, size: 15),
                variant: MuxisButtonVariant.primary,
                height: 36,
                isLoading: isLoading,
                onPressed: onConnect,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLinkedPlatformSection({
    required String title,
    required String subtitle,
    required Color brandColor,
    required List<Track> tracks,
    required List<Playlist> playlists,
    required List<FeaturedSection> featuredSections,
    required int navDestination,
    required bool isDark,
    required AudioPlaybackService audioService,
  }) {
    final hasPlaylists = playlists.isNotEmpty;
    final hasTracks = tracks.isNotEmpty;
    final hasFeatured = featuredSections.isNotEmpty;

    return MuxisGlassCard(
      padding: const EdgeInsets.all(18),
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 10,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
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
                  Flexible(
                    child: Column(
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
                  ),
                ],
              ),
              MuxisButton(
                label: 'Open Hub',
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                variant: MuxisButtonVariant.liquidGlass,
                height: 34,
                onPressed: () => widget.onNavigate(navDestination),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!hasPlaylists && !hasTracks && !hasFeatured)
            Text(
              'Account linked! Open Hub or tap Sync Library to fetch your playlists and songs.',
              style: TextStyle(
                fontSize: 13,
                color: MuxisColors.textSecondary(isDark),
              ),
            )
          else ...[
            for (final sec in featuredSections.take(2)) ...[
              Text(
                sec.title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: MuxisColors.textPrimary(isDark),
                ),
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final spacing = constraints.maxWidth < 520 ? 12.0 : 14.0;
                  final cardWidth = _responsiveCardWidth(constraints.maxWidth);
                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: [
                      ...sec.playlists.take(4).map((pl) {
                        return MuxisCard(
                          width: cardWidth,
                          title: pl.title,
                          subtitle: pl.description ?? 'Featured Playlist',
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
                      ...sec.tracks.take(6).map((t) {
                        return MuxisCard(
                          width: cardWidth,
                          title: t.title,
                          subtitle: t.artist,
                          artworkUrl: t.artworkUrl,
                          onTap: () =>
                              audioService.playTrack(t, newQueue: sec.tracks),
                          onPlayTap: () =>
                              audioService.playTrack(t, newQueue: sec.tracks),
                        );
                      }),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
            ],
            if (!hasFeatured || hasPlaylists)
              LayoutBuilder(
                builder: (context, constraints) {
                  final spacing = constraints.maxWidth < 520 ? 12.0 : 14.0;
                  final cardWidth = _responsiveCardWidth(constraints.maxWidth);
                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
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
                      if (!hasFeatured)
                        ...tracks.take(8).map((t) {
                          return MuxisCard(
                            width: cardWidth,
                            title: t.title,
                            subtitle: t.artist,
                            artworkUrl: t.artworkUrl,
                            onTap: () =>
                                audioService.playTrack(t, newQueue: tracks),
                            onPlayTap: () =>
                                audioService.playTrack(t, newQueue: tracks),
                          );
                        }),
                    ],
                  );
                },
              ),
          ],
        ],
      ),
    );
  }
}
