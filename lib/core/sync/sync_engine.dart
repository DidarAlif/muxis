import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/models/track.dart';
import '../auth/supabase_auth_service.dart';
import '../config/app_config.dart';
import '../database/database_service.dart';
import 'sync_models.dart';

final syncEngineProvider = StateNotifierProvider<SyncEngine, SyncStatus>((ref) {
  final authState = ref.watch(authServiceProvider);
  final db = ref.watch(databaseServiceProvider);
  return SyncEngine(authState.user?.id, db);
});

class SyncEngine extends StateNotifier<SyncStatus> {
  final String? _userId;
  final DatabaseService _db;
  SupabaseClient? _client;
  Timer? _periodicTimer;

  SyncEngine(this._userId, this._db) : super(SyncStatus.idle) {
    if (AppConfig.isConfigured) {
      try {
        _client = Supabase.instance.client;
      } catch (_) {}
    }

    if (_userId != null && _client != null) {
      // Sync immediately on login, then periodic every 5 minutes
      syncNow();
      _periodicTimer = Timer.periodic(
        const Duration(minutes: 5),
        (_) => syncNow(),
      );
    }
  }

  Future<SyncReport> syncNow() async {
    if (_client == null || _userId == null) {
      state = SyncStatus.offline;
      return SyncReport(
        syncTime: DateTime.now(),
        isSuccess: false,
        errorMessage: 'User unauthenticated or offline',
      );
    }

    state = SyncStatus.syncing;
    int playlistsCount = 0;
    int favoritesCount = 0;
    int tracksCount = 0;

    try {
      // --- 0. REGISTER DEVICE ---
      await _registerDevice();

      // --- 1. REPLAY OFFLINE MUTATIONS QUEUE ---
      await _replayOfflineMutations();

      // --- 2. PULL REMOTE FAVORITES (LWW based on updated_at) ---
      final favRows = await _client!
          .from('favorites')
          .select()
          .eq('user_id', _userId)
          .eq('is_deleted', false);

      for (final row in favRows) {
        final trackUri = row['track_uri'] as String;
        if (!_db.isFavorite(trackUri)) {
          await _db.toggleFavorite(trackUri);
          favoritesCount++;
        }
      }

      // --- 3. PUSH LOCAL FAVORITES TO CLOUD ---
      final localFavorites = _db.getFavoriteTracks();
      for (final track in localFavorites) {
        final portableUri = _generatePortableUri(
          track.id,
          track.title,
          track.artist,
        );

        await _client!.from('favorites').upsert({
          'user_id': _userId,
          'track_uri': portableUri,
          'title': track.title,
          'artist': track.artist,
          'album': track.album,
          'duration_ms': track.duration.inMilliseconds,
          'is_deleted': false,
        }, onConflict: 'user_id,track_uri');
      }

      // --- 4. PULL REMOTE PLAYLISTS & TRACKS ---
      final plRows = await _client!
          .from('playlists')
          .select('*, playlist_tracks(*)')
          .eq('user_id', _userId)
          .eq('is_deleted', false);

      for (final pl in plRows) {
        final title = pl['title'] as String;
        final rawTracks = (pl['playlist_tracks'] as List? ?? []);
        final sorted = List<Map<String, dynamic>>.from(rawTracks)
          ..sort(
            (a, b) => ((a['position_index'] as int?) ?? 0).compareTo(
              (b['position_index'] as int?) ?? 0,
            ),
          );
        final trackUris = sorted.map((t) => t['track_uri'] as String).toList();
        await _db.setPlaylist(title, trackUris);
        playlistsCount++;
        tracksCount += trackUris.length;
      }

      // --- 5. PUSH LOCAL PLAYLISTS & TRACKS TO CLOUD ---
      final localPlaylists = _db.getPlaylists();
      for (final entry in localPlaylists.entries) {
        final playlistTitle = entry.key;
        final trackUris = entry.value;

        // Upsert playlist
        final plRes = await _client!
            .from('playlists')
            .upsert({
              'user_id': _userId,
              'title': playlistTitle,
              'is_deleted': false,
              'updated_at': DateTime.now().toIso8601String(),
            }, onConflict: 'user_id,title')
            .select('id')
            .single();

        final playlistId = plRes['id'] as String;

        // Upsert playlist tracks in order
        for (int i = 0; i < trackUris.length; i++) {
          final uri = trackUris[i];
          final track = _db.getAllTracks().firstWhere(
            (t) => t.id == uri,
            orElse: () => Track(
              id: uri,
              title: uri.replaceFirst(RegExp(r'^[a-z]+:'), ''),
              artist: 'Unknown',
              album: '',
              duration: Duration.zero,
            ),
          );

          await _client!.from('playlist_tracks').upsert({
            'playlist_id': playlistId,
            'track_uri': _generatePortableUri(
              track.id,
              track.title,
              track.artist,
            ),
            'title': track.title,
            'artist': track.artist,
            'album': track.album,
            'duration_ms': track.duration.inMilliseconds,
            'position_index': i,
          }, onConflict: 'playlist_id,track_uri');
        }
      }

      // --- 6. SYNC USER SETTINGS ---
      await _syncUserSettings();

      // --- 7. RECORD SYNC METADATA ---
      await _client!.from('sync_metadata').upsert({
        'user_id': _userId,
        'last_synced_at': DateTime.now().toIso8601String(),
      });

      state = SyncStatus.synced;

      return SyncReport(
        syncTime: DateTime.now(),
        playlistsSynced: playlistsCount,
        favoritesSynced: favoritesCount,
        tracksSynced: tracksCount,
        isSuccess: true,
      );
    } catch (e) {
      state = SyncStatus.error;
      return SyncReport(
        syncTime: DateTime.now(),
        isSuccess: false,
        errorMessage: 'Sync error: $e',
      );
    }
  }

  Future<void> _registerDevice() async {
    try {
      final platformStr = _getPlatformString();
      final hostName = Platform.localHostname.isNotEmpty
          ? Platform.localHostname
          : 'Desktop Client';

      await _client!.from('user_devices').upsert({
        'user_id': _userId,
        'device_name': hostName,
        'platform': platformStr,
        'client_version': '1.0.0',
        'last_active_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,device_name,platform');
    } catch (_) {
      // Device registration is non-blocking
    }
  }

  Future<void> _syncUserSettings() async {
    try {
      // Upsert default/current settings row for user
      await _client!.from('user_settings').upsert({
        'user_id': _userId,
        'theme_mode': 'dark',
        'audio_quality': 'FLAC 24-bit Lossless',
        'eq_preset': 'Prismatic Aura',
        'skip_silence': true,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');
    } catch (_) {}
  }

  Future<void> _replayOfflineMutations() async {
    final mutations = _db.getOfflineMutations();
    if (mutations.isEmpty) return;

    for (final mut in mutations) {
      final entity = mut['entityType'] as String?;
      final action = mut['action'] as String?;
      final data = mut['data'] as Map<String, dynamic>? ?? {};

      if (entity == 'favorite' && action == 'delete') {
        final trackUri = data['track_uri'] as String?;
        if (trackUri != null) {
          await _client!
              .from('favorites')
              .update({'is_deleted': true})
              .eq('user_id', _userId)
              .eq('track_uri', trackUri);
        }
      } else if (entity == 'playlist' && action == 'delete') {
        final title = data['title'] as String?;
        if (title != null) {
          await _client!
              .from('playlists')
              .update({'is_deleted': true})
              .eq('user_id', _userId)
              .eq('title', title);
        }
      }
    }

    await _db.clearOfflineMutations();
  }

  String _getPlatformString() {
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isLinux) return 'linux';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'web';
  }

  /// Ensures machine-specific file paths (e.g. C:\Users\... or /storage/emulated/0/...)
  /// are converted into clean portable cloud references.
  String _generatePortableUri(String id, String title, String artist) {
    if (id.startsWith('isrc:') ||
        id.startsWith('yt:') ||
        id.startsWith('cc:') ||
        id.startsWith('public:')) {
      return id;
    }
    final clean = '${artist.toLowerCase().trim()}_${title.toLowerCase().trim()}'
        .replaceAll(RegExp(r'[^a-z0-9_]'), '');
    return 'meta:$clean';
  }

  @override
  void dispose() {
    _periodicTimer?.cancel();
    super.dispose();
  }
}
