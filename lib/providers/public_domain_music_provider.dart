import '../shared/models/album.dart';
import '../shared/models/track.dart';
import 'music_provider.dart';

class PublicDomainMusicProvider implements MusicProvider {
  @override
  String get name => 'Authorized Free & Open Streams';

  @override
  MusicSource get source => MusicSource.publicDomain;

  static const List<Track> _catalog = [
    Track(
      id: 'cc-1',
      title: 'Neon Odyssey',
      artist: 'Aura Synthesis',
      album: 'Prismatic Dreams (CC-BY 4.0)',
      duration: Duration(minutes: 4, seconds: 12),
      source: MusicSource.publicDomain,
      audioFormat: 'FLAC 24-bit / 96kHz',
      streamUrl: 'https://files.freemusicarchive.org/storage-freemusicarchive-org/music/no_curator/Tours/Enthusiast/Tours_-_01_-_Enthusiast.mp3',
    ),
    Track(
      id: 'cc-2',
      title: 'Obsidian Reflections',
      artist: 'Kroma Soundworks',
      album: 'Atmospheres Vol. 1',
      duration: Duration(minutes: 3, seconds: 45),
      source: MusicSource.publicDomain,
      audioFormat: '320kbps MP3',
      streamUrl: 'https://files.freemusicarchive.org/storage-freemusicarchive-org/music/ccCommunity/Broke_For_Free/Directionless_EP/Broke_For_Free_-_01_-_Night_Owl.mp3',
    ),
    Track(
      id: 'cc-3',
      title: 'Velvet Aurora',
      artist: 'Lunar Pulse',
      album: 'Celestial Echoes',
      duration: Duration(minutes: 5, seconds: 02),
      source: MusicSource.publicDomain,
      audioFormat: 'FLAC 24-bit / 48kHz',
      streamUrl: 'https://files.freemusicarchive.org/storage-freemusicarchive-org/music/WFMU/Lame_Drivers/Frozen_Air/Lame_Drivers_-_01_-_Frozen_Air.mp3',
    ),
    Track(
      id: 'cc-4',
      title: 'Midnight Frequency',
      artist: 'Subtle Wave',
      album: 'Deep Space Oscillations',
      duration: Duration(minutes: 3, seconds: 20),
      source: MusicSource.publicDomain,
      audioFormat: 'FLAC 16-bit',
      streamUrl: 'https://files.freemusicarchive.org/storage-freemusicarchive-org/music/Music_for_Video/Doctor_Turtle/The_Double-Down_Two-Step/Doctor_Turtle_-_01_-_The_Double-Down_Two-Step.mp3',
    ),
  ];

  @override
  Future<List<Track>> search(String query) async {
    final lower = query.toLowerCase();
    return _catalog
        .where(
          (t) =>
              t.title.toLowerCase().contains(lower) ||
              t.artist.toLowerCase().contains(lower) ||
              t.album.toLowerCase().contains(lower),
        )
        .toList();
  }

  @override
  Future<List<Track>> getFeaturedTracks() async {
    return _catalog;
  }

  @override
  Future<List<Album>> getFeaturedAlbums() async {
    return [
      Album(
        id: 'cc-album-1',
        title: 'Prismatic Dreams',
        artist: 'Aura Synthesis',
        year: 2026,
        trackCount: 2,
        tracks: [_catalog[0], _catalog[1]],
      ),
      Album(
        id: 'cc-album-2',
        title: 'Deep Space Oscillations',
        artist: 'Subtle Wave',
        year: 2026,
        trackCount: 2,
        tracks: [_catalog[2], _catalog[3]],
      ),
    ];
  }

  @override
  Future<List<Playlist>> getCuratedPlaylists() async {
    return [
      Playlist(
        id: 'cc-playlist-focus',
        title: 'Prismatic Flow: Deep Focus',
        description: 'Atmospheric electronic & ambient soundscapes for deep concentration',
        tracks: _catalog,
      ),
    ];
  }

  @override
  Future<List<Track>> getRadioStation(String genreOrMood) async {
    return _catalog;
  }

  @override
  Future<String?> resolveAudioStreamUrl(Track track) async {
    return track.streamUrl;
  }
}
