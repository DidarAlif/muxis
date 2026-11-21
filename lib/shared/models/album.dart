import 'track.dart';

class Album {
  final String id;
  final String title;
  final String artist;
  final String? artistId;
  final String? artworkUrl;
  final int? year;
  final int trackCount;
  final List<Track> tracks;

  const Album({
    required this.id,
    required this.title,
    required this.artist,
    this.artistId,
    this.artworkUrl,
    this.year,
    this.trackCount = 0,
    this.tracks = const [],
  });
}
