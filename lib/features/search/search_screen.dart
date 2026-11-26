import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/muxis_colors.dart';
import '../../app/theme/muxis_typography.dart';
import '../../core/audio/audio_playback_service.dart';
import '../../core/storage/preferences_service.dart';
import '../../providers/innertube_music_provider.dart';
import '../../providers/spotify_music_provider.dart';
import '../../shared/models/track.dart';
import '../../shared/widgets/muxis_liquid_surface.dart';
import '../../shared/widgets/muxis_scroll_view.dart';
import '../../shared/widgets/muxis_search_field.dart';
import '../../shared/widgets/muxis_track_row.dart';

enum SearchFilterSource { all, youtube, spotify }

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final InnerTubeMusicProvider _ytProvider = InnerTubeMusicProvider();
  final SpotifyMusicProvider _spotifyProvider = SpotifyMusicProvider();

  SearchFilterSource _filterSource = SearchFilterSource.all;
  List<Track> _results = [];
  bool _isSearching = false;
  String _lastQuery = '';
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    ref.read(preferencesServiceProvider).getActiveSource().then((source) {
      if (mounted) {
        if (source == 'youtube') setState(() => _filterSource = SearchFilterSource.youtube);
        if (source == 'spotify') setState(() => _filterSource = SearchFilterSource.spotify);
      }
    });
  }

  void _onSearch(String query, {bool immediate = false}) {
    _debounceTimer?.cancel();
    final trimmed = query.trim();
    _lastQuery = trimmed;

    if (trimmed.isEmpty) {
      setState(() {
        _results = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    Future<void> runSearch() async {
      try {
        List<Track> searchResults = [];

        switch (_filterSource) {
          case SearchFilterSource.youtube:
            searchResults = await _ytProvider.search(trimmed);
            break;
          case SearchFilterSource.spotify:
            searchResults = await _spotifyProvider.search(trimmed);
            break;
          case SearchFilterSource.all:
            final ytFuture = _ytProvider.search(trimmed);
            final spFuture = _spotifyProvider.search(trimmed);
            final res = await Future.wait([ytFuture, spFuture]);
            final ytTracks = res[0];
            final spTracks = res[1];
            final seen = <String>{};
            for (final t in [...ytTracks, ...spTracks]) {
              final key = '${t.title.toLowerCase()}_${t.artist.toLowerCase()}';
              if (!seen.contains(key)) {
                seen.add(key);
                searchResults.add(t);
              }
            }
            break;
        }

        if (mounted && _lastQuery == trimmed) {
          setState(() {
            _results = searchResults;
            _isSearching = false;
          });
        }
      } catch (_) {
        if (mounted && _lastQuery == trimmed) {
          setState(() => _isSearching = false);
        }
      }
    }

    if (immediate) {
      runSearch();
    } else {
      _debounceTimer = Timer(const Duration(milliseconds: 280), runSearch);
    }
  }

  @override
  Widget build(BuildContext context) {
    final playback = ref.watch(playbackServiceProvider);
    final audioService = ref.read(playbackServiceProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MuxisScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        Text('Search & Discovery', style: MuxisTypography.pageTitle(isDark: isDark)),
        const SizedBox(height: 16),

        // Search Field
        MuxisSearchField(
          controller: _controller,
          onChanged: _onSearch,
          onSubmitted: (q) => _onSearch(q, immediate: true),
          onClear: () => _onSearch('', immediate: true),
        ),
        const SizedBox(height: 14),

        // Source Filter Chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildSourceChip('All Sources', SearchFilterSource.all, isDark),
            _buildSourceChip('YouTube Music', SearchFilterSource.youtube, isDark, icon: Icons.smart_display_rounded),
            _buildSourceChip('Spotify', SearchFilterSource.spotify, isDark, icon: Icons.graphic_eq_rounded),
          ],
        ),
        const SizedBox(height: 24),

        if (_isSearching)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: Column(
                children: [
                  CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(MuxisColors.electricCyan),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Querying ad-free global music streams...',
                    style: TextStyle(fontSize: 13, color: MuxisColors.textMutedDark),
                  ),
                ],
              ),
            ),
          )
        else if (_results.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Search Results (${_results.length})',
                style: MuxisTypography.sectionHeading(isDark: isDark),
              ),
              Text(
                'Ad-free audio streaming ready',
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'JetBrains Mono',
                  color: MuxisColors.electricCyan.withOpacity(0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...List.generate(_results.length, (i) {
            final track = _results[i];
            return MuxisTrackRow(
              track: track,
              index: i,
              isPlaying:
                  playback.currentTrack?.id == track.id && playback.isPlaying,
              onTap: () => audioService.playTrack(track),
              onFavoriteTap: () => audioService.toggleFavoriteCurrentTrack(),
              onPlayNextTap: () =>
                  audioService.addToQueue(track, playNext: true),
              onAddToQueueTap: () => audioService.addToQueue(track),
            );
          }),
        ] else if (_lastQuery.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.music_off_rounded,
                    size: 40,
                    color: MuxisColors.textMuted(isDark),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No matching songs found for "$_lastQuery"',
                    style: MuxisTypography.sectionHeading(isDark: isDark),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Try searching by exact song title + artist name.',
                    style: TextStyle(
                      fontSize: 13,
                      color: MuxisColors.textSecondary(isDark),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          // Default Search Suggestions
          Text(
            'Popular Global Searches',
            style: MuxisTypography.sectionHeading(isDark: isDark),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              'Daft Punk',
              'The Weeknd',
              'Queen Bohemian Rhapsody',
              'Synthwave Cyberpunk',
              'Lo-Fi Frequency',
              'Hans Zimmer Interstellar',
              'Despacito',
              'Coldplay',
            ]
                .map(
                  (term) => ActionChip(
                    backgroundColor: isDark
                        ? MuxisColors.elevatedSurface
                        : MuxisColors.secondarySurface,
                    label: Text(
                      term,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    onPressed: () {
                      _controller.text = term;
                      _onSearch(term);
                    },
                  ),
                )
                .toList(),
          ),
        ],
      ],
      ),
    );
  }

  Widget _buildSourceChip(String label, SearchFilterSource source, bool isDark, {IconData? icon}) {
    final isSelected = _filterSource == source;
    return MuxisLiquidSurface(
      onTap: () {
        setState(() => _filterSource = source);
        if (_controller.text.isNotEmpty) {
          _onSearch(_controller.text, immediate: true);
        }
      },
      enableGlass: false,
      blurSigma: 0,
      borderRadius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      colorOverride: isSelected
          ? (isDark ? MuxisColors.electricCyan.withOpacity(0.2) : MuxisColors.electricCyan.withOpacity(0.15))
          : (isDark ? MuxisColors.elevatedSurface : MuxisColors.secondarySurface),
      borderOverride: Border.all(
        color: isSelected
            ? MuxisColors.electricCyan
            : (isDark ? MuxisColors.subtleBorderDark : MuxisColors.subtleBorderLight),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 14,
              color: isSelected ? MuxisColors.electricCyan : (isDark ? Colors.white70 : Colors.black54),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected ? MuxisColors.electricCyan : (isDark ? Colors.white70 : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
