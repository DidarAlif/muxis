import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/muxis_colors.dart';
import '../../app/theme/muxis_typography.dart';
import '../../core/audio/audio_playback_service.dart';
import '../../providers/innertube_music_provider.dart';
import '../../providers/spotify_music_provider.dart';
import '../../shared/models/track.dart';
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

  void _onSearch(String query) async {
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
          // Merge results: YouTube Music + Spotify
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

  @override
  Widget build(BuildContext context) {
    final playback = ref.watch(playbackServiceProvider);
    final audioService = ref.read(playbackServiceProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      children: [
        Text('Search & Discovery', style: MuxisTypography.pageTitle(isDark: isDark)),
        const SizedBox(height: 16),

        // Search Field
        MuxisSearchField(
          controller: _controller,
          onChanged: _onSearch,
          onClear: () => _onSearch(''),
        ),
        const SizedBox(height: 14),

        // Source Filter Chips
        Row(
          children: [
            _buildSourceChip('All Sources', SearchFilterSource.all, isDark),
            const SizedBox(width: 8),
            _buildSourceChip('YouTube Music', SearchFilterSource.youtube, isDark, icon: Icons.smart_display_rounded),
            const SizedBox(width: 8),
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
    );
  }

  Widget _buildSourceChip(String label, SearchFilterSource source, bool isDark, {IconData? icon}) {
    final isSelected = _filterSource == source;
    return GestureDetector(
      onTap: () {
        setState(() => _filterSource = source);
        if (_controller.text.isNotEmpty) {
          _onSearch(_controller.text);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? MuxisColors.electricCyan.withOpacity(0.2) : MuxisColors.electricCyan.withOpacity(0.15))
              : (isDark ? MuxisColors.elevatedSurface : MuxisColors.secondarySurface),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? MuxisColors.electricCyan
                : (isDark ? MuxisColors.subtleBorderDark : MuxisColors.subtleBorderLight),
          ),
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
      ),
    );
  }
}
