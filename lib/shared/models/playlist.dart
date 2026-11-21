import 'track.dart';

class Playlist {
  final String id;
  final String title;
  final String? description;
  final String? coverUrl;
  final bool isCustom;
  final List<Track> tracks;
  final DateTime? createdAt;
  final int? _explicitTrackCount;

  const Playlist({
    required this.id,
    required this.title,
    this.description,
    String? coverUrl,
    String? artworkUrl,
    this.isCustom = true,
    this.tracks = const [],
    this.createdAt,
    int? trackCount,
  })  : coverUrl = coverUrl ?? artworkUrl,
        _explicitTrackCount = trackCount;

  String? get artworkUrl => coverUrl;
  int get trackCount => _explicitTrackCount ?? tracks.length;

  Duration get totalDuration =>
      tracks.fold(Duration.zero, (prev, t) => prev + t.duration);
}
