import 'track.dart';

class Playlist {
  final String id;
  final String title;
  final String? description;
  final String? coverUrl;
  final bool isCustom;
  final List<Track> tracks;
  final DateTime? createdAt;

  const Playlist({
    required this.id,
    required this.title,
    this.description,
    this.coverUrl,
    this.isCustom = true,
    this.tracks = const [],
    this.createdAt,
  });

  int get trackCount => tracks.length;

  Duration get totalDuration =>
      tracks.fold(Duration.zero, (prev, t) => prev + t.duration);
}
