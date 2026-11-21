import 'dart:io';

import '../shared/models/album.dart';
import '../shared/models/track.dart';
import 'music_provider.dart';

class LocalMusicProvider implements MusicProvider {
  @override
  String get name => 'Local Files';

  @override
  MusicSource get source => MusicSource.local;

  final List<Track> _scannedTracks = [];

  List<Track> get libraryTracks => List.unmodifiable(_scannedTracks);

  @override
  Future<List<Track>> search(String query) async {
    final lower = query.toLowerCase();
    return _scannedTracks.where((t) {
      return t.title.toLowerCase().contains(lower) ||
          t.artist.toLowerCase().contains(lower) ||
          t.album.toLowerCase().contains(lower);
    }).toList();
  }

  @override
  Future<List<Track>> getFeaturedTracks() async {
    return _scannedTracks.take(10).toList();
  }

  @override
  Future<List<Album>> getFeaturedAlbums() async {
    final Map<String, List<Track>> albumMap = {};
    for (final t in _scannedTracks) {
      albumMap.putIfAbsent(t.album, () => []).add(t);
    }

    return albumMap.entries.map((e) {
      return Album(
        id: 'local-album-${e.key.hashCode}',
        title: e.key,
        artist: e.value.first.artist,
        trackCount: e.value.length,
        tracks: e.value,
        artworkUrl: e.value.first.artworkUrl,
      );
    }).toList();
  }

  @override
  Future<List<Playlist>> getCuratedPlaylists() async {
    return [
      Playlist(
        id: 'local-playlist-all',
        title: 'All Local Audio',
        description: 'Every scanned audio track found on this computer',
        tracks: _scannedTracks,
      ),
    ];
  }

  @override
  Future<List<Track>> getRadioStation(String genreOrMood) async {
    return _scannedTracks;
  }

  @override
  Future<String?> resolveAudioStreamUrl(Track track) async {
    return track.localFilePath;
  }

  /// Scan a directory for common audio files (.mp3, .flac, .wav, .m4a, .ogg)
  Future<int> scanDirectory(Directory directory) async {
    final supportedExtensions = [
      '.mp3',
      '.flac',
      '.wav',
      '.m4a',
      '.ogg',
      '.aac',
    ];
    int count = 0;

    try {
      if (!await directory.exists()) return 0;

      await for (final entity in directory.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File) {
          final ext = entity.path.toLowerCase().substring(
            entity.path.lastIndexOf('.'),
          );
          if (supportedExtensions.contains(ext)) {
            final fileName = entity.uri.pathSegments.last;
            final cleanTitle = fileName.replaceAll(
              RegExp(r'\.[a-zA-Z0-9]+$'),
              '',
            );

            final track = Track(
              id: 'local-${entity.path.hashCode}',
              title: cleanTitle,
              artist: 'Local Artist',
              album: directory.uri.pathSegments.where((s) => s.isNotEmpty).last,
              duration: const Duration(minutes: 3, seconds: 30),
              localFilePath: entity.path,
              source: MusicSource.local,
              audioFormat: ext.toUpperCase().replaceAll('.', ''),
            );

            if (!_scannedTracks.any((t) => t.localFilePath == entity.path)) {
              _scannedTracks.add(track);
              count++;
            }
          }
        }
      }
    } catch (_) {}

    return count;
  }
}
