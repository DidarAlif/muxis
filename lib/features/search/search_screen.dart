import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/muxis_colors.dart';
import '../../app/theme/muxis_typography.dart';
import '../../core/audio/audio_playback_service.dart';
import '../../providers/public_domain_music_provider.dart';
import '../../shared/models/track.dart';
import '../../shared/widgets/muxis_search_field.dart';
import '../../shared/widgets/muxis_track_row.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final PublicDomainMusicProvider _provider = PublicDomainMusicProvider();
  List<Track> _results = [];
  bool _isSearching = false;

  void _onSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _results = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    final results = await _provider.search(query);
    if (mounted) {
      setState(() {
        _results = results;
        _isSearching = false;
      });
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
        Text('Search', style: MuxisTypography.pageTitle(isDark: isDark)),
        const SizedBox(height: 16),

        // Search Field
        MuxisSearchField(
          controller: _controller,
          onChanged: _onSearch,
          onClear: () => _onSearch(''),
        ),
        const SizedBox(height: 24),

        if (_isSearching)
          const Center(child: CircularProgressIndicator())
        else if (_results.isNotEmpty) ...[
          Text(
            'Search Results (${_results.length})',
            style: MuxisTypography.sectionHeading(isDark: isDark),
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
            'Popular Searches',
            style: MuxisTypography.sectionHeading(isDark: isDark),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children:
                [
                      'Synthwave',
                      'Lossless FLAC',
                      'Prismatic Ambient',
                      'Electronic Beats',
                      'Classical Piano',
                      'Cyberpunk Soundscapes',
                    ]
                    .map(
                      (term) => ActionChip(
                        label: Text(term),
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
}
