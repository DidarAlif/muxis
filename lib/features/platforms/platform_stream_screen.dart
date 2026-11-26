import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/muxis_colors.dart';
import '../../app/theme/muxis_gradients.dart';
import '../../app/theme/muxis_typography.dart';
import '../../core/audio/audio_playback_service.dart';
import '../../core/auth/streaming_accounts_controller.dart';
import '../../providers/innertube_music_provider.dart';
import '../../providers/spotify_music_provider.dart';
import '../../shared/models/playlist.dart';
import '../../shared/models/track.dart';
import '../../shared/widgets/muxis_button.dart';
import '../../shared/widgets/muxis_card.dart';
import '../../shared/widgets/muxis_glass_card.dart';
import '../../shared/widgets/muxis_track_row.dart';

/// Dedicated Interactive Streaming Space for a Linked Platform (YouTube Music OR Spotify).
/// Displays live synced profile, personal playlists, liked tracks, top picks,
/// and inline platform-scoped search with 1-click ad-free playback.
class PlatformStreamScreen extends ConsumerStatefulWidget {
  final MusicSource platform;

  const PlatformStreamScreen({super.key, required this.platform});

  @override
  ConsumerState<PlatformStreamScreen> createState() =>
      _PlatformStreamScreenState();
}

class _PlatformStreamScreenState extends ConsumerState<PlatformStreamScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final InnerTubeMusicProvider _ytProvider = InnerTubeMusicProvider();
  final SpotifyMusicProvider _spotifyProvider = SpotifyMusicProvider();

  int _subTab = 0; // 0: Stream Picks, 1: Playlists, 2: Liked Songs
  Playlist? _openPlaylist;
  List<Track> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounce;

  bool get _isSpotify => widget.platform == MusicSource.spotify;

  @override
  void didUpdateWidget(covariant PlatformStreamScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.platform != widget.platform) {
      setState(() {
        _openPlaylist = null;
        _subTab = 0;
        _searchCtrl.clear();
        _searchResults = [];
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String raw) {
    _debounce?.cancel();
    final q = raw.trim();
    if (q.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final tracks = _isSpotify
            ? await _spotifyProvider.search(q)
            : await _ytProvider.search(q);
        if (mounted && _searchCtrl.text.trim() == q) {
          setState(() {
            _searchResults = tracks;
            _isSearching = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _isSearching = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accounts = ref.watch(streamingAccountsProvider);
    final accountsNotifier = ref.read(streamingAccountsProvider.notifier);
    final playback = ref.watch(playbackServiceProvider);
    final audioService = ref.read(playbackServiceProvider.notifier);

    final data = _isSpotify ? accounts.spotify : accounts.youtube;
    final brandColor =
        _isSpotify ? MuxisColors.spotifyGreen : MuxisColors.youtubeRed;
    final brandGradient = _isSpotify
        ? MuxisGradients.spotifyPlatformGradient
        : MuxisGradients.youtubePlatformGradient;
    final platformName = _isSpotify ? 'Spotify' : 'YouTube Music';

    if (!data.isConnected) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: MuxisGlassCard(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: brandGradient,
                  ),
                  child: Icon(
                    _isSpotify
                        ? Icons.graphic_eq_rounded
                        : Icons.smart_display_rounded,
                    size: 36,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Connect $platformName',
                  style: MuxisTypography.pageTitle(isDark: isDark),
                ),
                const SizedBox(height: 10),
                Text(
                  'Log in with your $platformName browser account to stream all your playlists, liked tracks, and mixes ad-free inside MUXIS.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: MuxisColors.textSecondary(isDark),
                  ),
                ),
                const SizedBox(height: 22),
                MuxisButton(
                  label: 'Sign In to $platformName',
                  icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                  variant: MuxisButtonVariant.primary,
                  isLoading: data.isSyncing,
                  onPressed: () async {
                    final res = _isSpotify
                        ? await accountsNotifier
                            .connectSpotifyWithBrowser(context)
                        : await accountsNotifier
                            .connectYouTubeWithBrowser(context);
                    if (mounted && !res.isSuccess && res.errorMessage != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(res.errorMessage!),
                          backgroundColor: MuxisColors.error,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    // If browsing inside a specific synced playlist
    if (_openPlaylist != null) {
      final pl = _openPlaylist!;
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: Icon(
                Icons.arrow_back_rounded,
                size: 18,
                color: MuxisColors.textPrimary(isDark),
              ),
              label: Text(
                'Back to $platformName',
                style: TextStyle(color: MuxisColors.textPrimary(isDark)),
              ),
              onPressed: () => setState(() => _openPlaylist = null),
            ),
          ),
          const SizedBox(height: 12),
          MuxisGlassCard(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: brandGradient,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: pl.artworkUrl != null && pl.artworkUrl!.isNotEmpty
                      ? Image.network(
                          pl.artworkUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.playlist_play_rounded,
                            size: 48,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.playlist_play_rounded,
                          size: 48,
                          color: Colors.white,
                        ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${platformName.toUpperCase()} PLAYLIST',
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: brandColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        pl.title,
                        style: MuxisTypography.pageTitle(isDark: isDark),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${pl.tracks.length} tracks • Ad-Free High Fidelity',
                        style: TextStyle(
                          fontSize: 13,
                          color: MuxisColors.textSecondary(isDark),
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (pl.tracks.isNotEmpty)
                        MuxisButton(
                          label: 'Stream Playlist',
                          icon: Icon(
                            Icons.play_arrow_rounded,
                            color: isDark ? Colors.black : Colors.white,
                          ),
                          variant: MuxisButtonVariant.primary,
                          height: 36,
                          onPressed: () => audioService.playTrack(
                            pl.tracks.first,
                            newQueue: pl.tracks,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (pl.tracks.isEmpty)
            MuxisEmptyState(
              icon: Icons.music_off_rounded,
              title: 'No Playable Tracks Found',
              message: 'Tap Sync in $platformName header to refresh tracks.',
            )
          else
            ...List.generate(pl.tracks.length, (i) {
              final track = pl.tracks[i];
              return MuxisTrackRow(
                track: track,
                index: i,
                isPlaying: playback.currentTrack?.id == track.id &&
                    playback.isPlaying,
                onTap: () =>
                    audioService.playTrack(track, newQueue: pl.tracks),
                onFavoriteTap: () => audioService.toggleFavoriteCurrentTrack(),
                onPlayNextTap: () =>
                    audioService.addToQueue(track, playNext: true),
                onAddToQueueTap: () => audioService.addToQueue(track),
              );
            }),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      children: [
        // --- PLATFORM ACCOUNT HERO HEADER ---
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: brandGradient,
            boxShadow: [
              BoxShadow(
                color: brandColor.withOpacity(isDark ? 0.35 : 0.28),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withOpacity(0.22),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.65),
                    width: 2,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: data.avatarUrl != null && data.avatarUrl!.isNotEmpty
                    ? Image.network(
                        data.avatarUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          _isSpotify
                              ? Icons.graphic_eq_rounded
                              : Icons.smart_display_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      )
                    : Icon(
                        _isSpotify
                            ? Icons.graphic_eq_rounded
                            : Icons.smart_display_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.28),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${platformName.toUpperCase()} • ${data.planBadge ?? 'LINKED'}',
                            style: const TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      data.displayName ?? '$platformName Listener',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      '${data.playlists.length} Playlists • ${data.likedTracks.length} Liked Tracks • Ad-Free Streaming Active',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              MuxisButton(
                label: data.isSyncing ? 'Syncing...' : 'Sync Library',
                icon: const Icon(
                  Icons.sync_rounded,
                  size: 16,
                  color: Colors.black87,
                ),
                variant: MuxisButtonVariant.liquidGlass,
                height: 38,
                isLoading: data.isSyncing,
                onPressed: _isSpotify
                    ? accountsNotifier.syncSpotifyLive
                    : accountsNotifier.syncYouTubeLive,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // --- PLATFORM-SCOPED INSTANT SEARCH ---
        TextField(
          controller: _searchCtrl,
          onChanged: _onSearch,
          style: TextStyle(
            color: MuxisColors.textPrimary(isDark),
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: 'Search tracks on $platformName (ad-free stream)...',
            hintStyle: TextStyle(
              color: MuxisColors.textMuted(isDark),
              fontSize: 13,
            ),
            prefixIcon: Icon(Icons.search_rounded, color: brandColor),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () {
                      _searchCtrl.clear();
                      _onSearch('');
                    },
                  )
                : null,
            filled: true,
            fillColor: isDark
                ? MuxisColors.elevatedSurface.withOpacity(0.76)
                : Colors.white.withOpacity(0.84),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: MuxisColors.border(isDark)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: MuxisColors.border(isDark)),
            ),
          ),
        ),
        const SizedBox(height: 18),

        // Inline Search Results (if typing)
        if (_isSearching)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 36),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_searchCtrl.text.trim().isNotEmpty) ...[
          Text(
            '$platformName Results (${_searchResults.length})',
            style: MuxisTypography.sectionHeading(isDark: isDark),
          ),
          const SizedBox(height: 12),
          ...List.generate(_searchResults.length, (i) {
            final track = _searchResults[i];
            return MuxisTrackRow(
              track: track,
              index: i,
              isPlaying:
                  playback.currentTrack?.id == track.id && playback.isPlaying,
              onTap: () =>
                  audioService.playTrack(track, newQueue: _searchResults),
              onFavoriteTap: () => audioService.toggleFavoriteCurrentTrack(),
              onPlayNextTap: () =>
                  audioService.addToQueue(track, playNext: true),
              onAddToQueueTap: () => audioService.addToQueue(track),
            );
          }),
        ] else ...[
          // --- SECTION TABS: PICKS | PLAYLISTS | LIKED ---
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _buildFilterChip(
                0,
                'Stream Picks (${data.recommendedTracks.length})',
                Icons.local_fire_department_rounded,
                brandColor,
                isDark,
              ),
              _buildFilterChip(
                1,
                'Your Playlists (${data.playlists.length})',
                Icons.playlist_play_rounded,
                brandColor,
                isDark,
              ),
              _buildFilterChip(
                2,
                'Liked Tracks (${data.likedTracks.length})',
                Icons.favorite_rounded,
                brandColor,
                isDark,
              ),
            ],
          ),
          const SizedBox(height: 22),

          if (_subTab == 0)
            _buildRecommendedGrid(
              data.recommendedTracks,
              playback,
              audioService,
              isDark,
              platformName,
            )
          else if (_subTab == 1)
            _buildPlaylistsGrid(
              data.playlists,
              isDark,
              brandGradient,
              platformName,
            )
          else
            _buildLikedTracksView(
              data.likedTracks,
              playback,
              audioService,
              isDark,
              platformName,
            ),
        ],
      ],
    );
  }

  Widget _buildFilterChip(
    int index,
    String label,
    IconData icon,
    Color brandColor,
    bool isDark,
  ) {
    final selected = _subTab == index;
    return InkWell(
      onTap: () => setState(() => _subTab = index),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? brandColor.withOpacity(isDark ? 0.22 : 0.16)
              : (isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.white.withOpacity(0.75)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? brandColor : MuxisColors.border(isDark),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? brandColor : MuxisColors.textMuted(isDark),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: MuxisColors.textPrimary(isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendedGrid(
    List<Track> tracks,
    dynamic playback,
    AudioPlaybackService audioService,
    bool isDark,
    String platformName,
  ) {
    if (tracks.isEmpty) {
      return MuxisEmptyState(
        icon: Icons.headphones_rounded,
        title: 'Loading $platformName Stream Picks',
        message: 'Tap Sync Library above or search any song to start streaming.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 232,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: tracks.take(12).length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, i) {
              final t = tracks[i];
              return MuxisCard(
                title: t.title,
                subtitle: t.artist,
                artworkUrl: t.artworkUrl,
                onTap: () => audioService.playTrack(t, newQueue: tracks),
                onPlayTap: () => audioService.playTrack(t, newQueue: tracks),
              );
            },
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'All Ready-to-Stream Tracks',
          style: MuxisTypography.sectionHeading(isDark: isDark),
        ),
        const SizedBox(height: 12),
        ...List.generate(tracks.length, (i) {
          final track = tracks[i];
          return MuxisTrackRow(
            track: track,
            index: i,
            isPlaying:
                playback.currentTrack?.id == track.id && playback.isPlaying,
            onTap: () => audioService.playTrack(track, newQueue: tracks),
            onFavoriteTap: () => audioService.toggleFavoriteCurrentTrack(),
            onPlayNextTap: () =>
                audioService.addToQueue(track, playNext: true),
            onAddToQueueTap: () => audioService.addToQueue(track),
          );
        }),
      ],
    );
  }

  Widget _buildPlaylistsGrid(
    List<Playlist> playlists,
    bool isDark,
    Gradient brandGradient,
    String platformName,
  ) {
    if (playlists.isEmpty) {
      return MuxisEmptyState(
        icon: Icons.playlist_play_rounded,
        title: 'No $platformName Playlists Synced Yet',
        message: 'Tap Sync Library above to pull your playlists.',
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 210,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.82,
      ),
      itemCount: playlists.length,
      itemBuilder: (ctx, i) {
        final pl = playlists[i];
        return InkWell(
          onTap: () => setState(() => _openPlaylist = pl),
          borderRadius: BorderRadius.circular(16),
          child: MuxisGlassCard(
            padding: const EdgeInsets.all(12),
            borderRadius: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: brandGradient,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: pl.artworkUrl != null && pl.artworkUrl!.isNotEmpty
                        ? Image.network(
                            pl.artworkUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.playlist_play_rounded,
                              size: 42,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.playlist_play_rounded,
                            size: 42,
                            color: Colors.white,
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  pl.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: MuxisColors.textPrimary(isDark),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${pl.tracks.isNotEmpty ? pl.tracks.length : pl.trackCount} tracks',
                  style: TextStyle(
                    fontSize: 11,
                    color: MuxisColors.textSecondary(isDark),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLikedTracksView(
    List<Track> liked,
    dynamic playback,
    AudioPlaybackService audioService,
    bool isDark,
    String platformName,
  ) {
    if (liked.isEmpty) {
      return MuxisEmptyState(
        icon: Icons.favorite_border_rounded,
        title: 'No Liked Tracks Imported Yet',
        message:
            'Your $platformName Liked Songs will appear here once synced.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${liked.length} Liked Songs on $platformName',
              style: MuxisTypography.sectionHeading(isDark: isDark),
            ),
            MuxisButton(
              label: 'Play All',
              icon: Icon(
                Icons.play_arrow_rounded,
                color: isDark ? Colors.black : Colors.white,
              ),
              variant: MuxisButtonVariant.primary,
              height: 34,
              onPressed: () =>
                  audioService.playTrack(liked.first, newQueue: liked),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...List.generate(liked.length, (i) {
          final track = liked[i];
          return MuxisTrackRow(
            track: track,
            index: i,
            isPlaying:
                playback.currentTrack?.id == track.id && playback.isPlaying,
            onTap: () => audioService.playTrack(track, newQueue: liked),
            onFavoriteTap: () => audioService.toggleFavoriteCurrentTrack(),
            onPlayNextTap: () =>
                audioService.addToQueue(track, playNext: true),
            onAddToQueueTap: () => audioService.addToQueue(track),
          );
        }),
      ],
    );
  }
}
