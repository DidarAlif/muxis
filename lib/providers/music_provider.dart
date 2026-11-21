import '../shared/models/album.dart';
import '../shared/models/track.dart';

abstract class MusicProvider {
  String get name;
  MusicSource get source;

  Future<List<Track>> search(String query);
  Future<List<Track>> getFeaturedTracks();
  Future<List<Album>> getFeaturedAlbums();
  Future<List<Playlist>> getCuratedPlaylists();
  Future<List<Track>> getRadioStation(String genreOrMood);
  Future<String?> resolveAudioStreamUrl(Track track);
}
