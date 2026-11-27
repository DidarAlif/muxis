import 'playlist.dart';
import 'track.dart';

/// Represents a personalized or curated shelf from a user's streaming account
/// (e.g. "Made For You", "Listen Again", "Quick Picks", "Your Stream").
class FeaturedSection {
  final String id;
  final String title;
  final String? subtitle;
  final MusicSource source;
  final List<Track> tracks;
  final List<Playlist> playlists;

  const FeaturedSection({
    required this.id,
    required this.title,
    this.subtitle,
    required this.source,
    this.tracks = const [],
    this.playlists = const [],
  });

  bool get isEmpty => tracks.isEmpty && playlists.isEmpty;
  bool get isNotEmpty => !isEmpty;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'source': source.name,
      'tracks': tracks.map((t) => t.toMap()).toList(),
      'playlists': playlists
          .map(
            (p) => {
              'id': p.id,
              'title': p.title,
              'description': p.description,
              'artworkUrl': p.artworkUrl,
              'tracks': p.tracks.map((t) => t.toMap()).toList(),
              'trackCount': p.tracks.isNotEmpty
                  ? p.tracks.length
                  : p.trackCount,
            },
          )
          .toList(),
    };
  }

  factory FeaturedSection.fromMap(Map<String, dynamic> map) {
    final sourceName = map['source']?.toString() ?? 'youtube';
    final src = MusicSource.values.firstWhere(
      (e) => e.name == sourceName,
      orElse: () => MusicSource.youtube,
    );
    final rawTracks = (map['tracks'] as List<dynamic>?) ?? const [];
    final rawPls = (map['playlists'] as List<dynamic>?) ?? const [];

    return FeaturedSection(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Featured',
      subtitle: map['subtitle']?.toString(),
      source: src,
      tracks: rawTracks
          .whereType<Map>()
          .map((m) => Track.fromMap(Map<String, dynamic>.from(m)))
          .toList(),
      playlists: rawPls
          .whereType<Map>()
          .map((p) {
            final nested = (p['tracks'] as List<dynamic>?) ?? const [];
            final parsedTracks = nested
                .whereType<Map>()
                .map((m) => Track.fromMap(Map<String, dynamic>.from(m)))
                .toList();
            return Playlist(
              id: p['id']?.toString() ?? '',
              title: p['title']?.toString() ?? 'Playlist',
              description: p['description']?.toString(),
              artworkUrl: p['artworkUrl']?.toString(),
              tracks: parsedTracks,
              trackCount:
                  (p['trackCount'] as num?)?.toInt() ?? parsedTracks.length,
            );
          })
          .where((p) => p.id.isNotEmpty)
          .toList(),
    );
  }
}
