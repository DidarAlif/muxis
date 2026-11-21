import 'album.dart';
import 'track.dart';

class Artist {
  final String id;
  final String name;
  final String? avatarUrl;
  final int monthlyListeners;
  final List<Album> albums;
  final List<Track> topTracks;

  const Artist({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.monthlyListeners = 0,
    this.albums = const [],
    this.topTracks = const [],
  });
}
