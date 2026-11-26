import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../shared/models/track.dart';

final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});

class DatabaseService {
  static const String _dbFileName = 'muxis_library.json';
  File? _dataFile;

  final List<Track> _tracks = [];
  final Set<String> _favoriteIds = {};
  final List<String> _historyIds = [];
  final Map<String, List<String>> _playlists = {};
  final List<Map<String, dynamic>> _offlineMutations = [];

  Future<void> init() async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final muxisDir = Directory('${docDir.path}/Muxis');
      if (!await muxisDir.exists()) {
        await muxisDir.create(recursive: true);
      }
      _dataFile = File('${muxisDir.path}/$_dbFileName');

      if (await _dataFile!.exists()) {
        final content = await _dataFile!.readAsString();
        if (content.isNotEmpty) {
          final data = jsonDecode(content) as Map<String, dynamic>;

          if (data['tracks'] != null) {
            final trackList = (data['tracks'] as List)
                .map((m) => Track.fromMap(m))
                .toList();
            _tracks.clear();
            _tracks.addAll(trackList);
          }

          if (data['favorites'] != null) {
            _favoriteIds.clear();
            _favoriteIds.addAll(List<String>.from(data['favorites']));
          }

          if (data['history'] != null) {
            _historyIds.clear();
            _historyIds.addAll(List<String>.from(data['history']));
          }

          if (data['playlists'] != null) {
            _playlists.clear();
            final plMap = data['playlists'] as Map<String, dynamic>;
            for (final entry in plMap.entries) {
              _playlists[entry.key] = List<String>.from(entry.value);
            }
          }

          if (data['offlineMutations'] != null) {
            _offlineMutations.clear();
            final list = data['offlineMutations'] as List;
            for (final item in list) {
              if (item is Map) {
                _offlineMutations.add(Map<String, dynamic>.from(item));
              }
            }
          }

          // Clean up any synthetic demo/fallback entries saved by earlier versions
          final staleFakeIds = _tracks
              .where((t) =>
                  t.id == 'sp-starboy' ||
                  t.id == 'sp-midnight-city' ||
                  t.artist == 'Muxis Frequency Studio' ||
                  t.title.endsWith(' (Prismatic Mix)'))
              .map((t) => t.id)
              .toSet();
          if (staleFakeIds.isNotEmpty) {
            _tracks.removeWhere((t) => staleFakeIds.contains(t.id));
            _favoriteIds.removeWhere(staleFakeIds.contains);
            _historyIds.removeWhere(staleFakeIds.contains);
            for (final list in _playlists.values) {
              list.removeWhere(staleFakeIds.contains);
            }
            await _persist();
          }
        }
      }
    } catch (_) {
      // In-memory fallback if filesystem restricted
    }
  }

  Future<void> saveTracks(List<Track> tracks) async {
    for (final t in tracks) {
      final idx = _tracks.indexWhere((x) => x.id == t.id);
      if (idx >= 0) {
        _tracks[idx] = t;
      } else {
        _tracks.add(t);
      }
    }
    await _persist();
  }

  List<Track> getAllTracks() => List.unmodifiable(_tracks);

  Future<void> removeTrack(String trackId) async {
    _tracks.removeWhere((t) => t.id == trackId);
    _favoriteIds.remove(trackId);
    _historyIds.remove(trackId);
    for (final list in _playlists.values) {
      list.remove(trackId);
    }
    await _persist();
  }

  Future<void> clearAllTracks() async {
    _tracks.clear();
    await _persist();
  }

  Future<void> clearHistory() async {
    _historyIds.clear();
    await _persist();
  }

  Future<int> getStorageUsageBytes() async {
    try {
      if (_dataFile != null && await _dataFile!.exists()) {
        return await _dataFile!.length();
      }
    } catch (_) {}
    return 0;
  }

  Future<void> clearCache() async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${docDir.path}/Muxis/cache');
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }
    } catch (_) {}
  }

  Future<void> toggleFavorite(String trackId) async {
    if (_favoriteIds.contains(trackId)) {
      _favoriteIds.remove(trackId);
    } else {
      _favoriteIds.add(trackId);
    }
    await _persist();
  }

  bool isFavorite(String trackId) => _favoriteIds.contains(trackId);

  List<Track> getFavoriteTracks() {
    return _tracks.where((t) => _favoriteIds.contains(t.id)).toList();
  }

  Future<void> recordHistory(String trackId) async {
    _historyIds.remove(trackId);
    _historyIds.insert(0, trackId);
    if (_historyIds.length > 100) {
      _historyIds.removeLast();
    }
    await _persist();
  }

  List<Track> getRecentlyPlayed() {
    final result = <Track>[];
    for (final id in _historyIds) {
      final t = _tracks.firstWhere(
        (x) => x.id == id,
        orElse: () => Track(
          id: id,
          title: 'Unknown',
          artist: 'Unknown',
          album: '',
          duration: Duration.zero,
        ),
      );
      if (t.duration > Duration.zero) result.add(t);
    }
    return result;
  }

  Map<String, List<String>> getPlaylists() => Map.unmodifiable(_playlists);

  List<String> getPlaylistTracks(String name) =>
      List.unmodifiable(_playlists[name] ?? []);

  Future<void> setPlaylist(String name, List<String> trackUris) async {
    _playlists[name] = List<String>.from(trackUris);
    await _persist();
  }

  Future<void> removePlaylist(String name) async {
    _playlists.remove(name);
    await _persist();
  }

  Future<void> addTrackToPlaylist(String name, String trackUri) async {
    final list = _playlists.putIfAbsent(name, () => []);
    if (!list.contains(trackUri)) {
      list.add(trackUri);
      await _persist();
    }
  }

  Future<void> removeTrackFromPlaylist(String name, String trackUri) async {
    if (_playlists.containsKey(name)) {
      _playlists[name]!.remove(trackUri);
      await _persist();
    }
  }

  List<Map<String, dynamic>> getOfflineMutations() =>
      List.unmodifiable(_offlineMutations);

  Future<void> queueOfflineMutation(Map<String, dynamic> mutation) async {
    _offlineMutations.add(mutation);
    await _persist();
  }

  Future<void> clearOfflineMutations() async {
    _offlineMutations.clear();
    await _persist();
  }

  Future<void> _persist() async {
    if (_dataFile == null) return;
    try {
      final payload = {
        'tracks': _tracks.map((t) => t.toMap()).toList(),
        'favorites': _favoriteIds.toList(),
        'history': _historyIds,
        'playlists': _playlists,
        'offlineMutations': _offlineMutations,
        'updatedAt': DateTime.now().toIso8601String(),
      };
      await _dataFile!.writeAsString(jsonEncode(payload));
    } catch (_) {}
  }
}
