import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/theme_controller.dart';
import '../../shared/models/track.dart';
import '../auth/supabase_auth_service.dart';
import '../config/app_config.dart';
import '../database/database_service.dart';
import '../storage/preferences_service.dart';
import 'sync_models.dart';

final syncEngineProvider = StateNotifierProvider<SyncEngine, SyncStatus>((ref) {
  final authState = ref.watch(authServiceProvider);
  final themeState = ref.watch(muxisThemeProvider);
  final db = ref.watch(databaseServiceProvider);
  return SyncEngine(
    userId: authState.user?.id,
    accessToken: authState.accessToken,
    themeState: themeState,
    db: db,
  );
});

class SyncEngine extends StateNotifier<SyncStatus> {
  final String? _userId;
  final String? _accessToken;
  final MuxisThemeState _themeState;
  final DatabaseService _db;
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'User-Agent': 'MUXIS/1.2.9 (CloudSync)',
      },
      validateStatus: (s) => s != null && s < 600,
    ),
  );
  Timer? _periodicTimer;

  SyncEngine({
    required String? userId,
    required String? accessToken,
    required MuxisThemeState themeState,
    required DatabaseService db,
  }) : _userId = userId,
       _accessToken = accessToken,
       _themeState = themeState,
       _db = db,
       super(SyncStatus.idle) {
    if (_userId != null && _accessToken != null && _accessToken.isNotEmpty) {
      unawaited(syncNow());
      _periodicTimer = Timer.periodic(
        const Duration(minutes: 5),
        (_) => unawaited(syncNow()),
      );
    }
  }

  Future<SyncReport> syncNow() async {
    final token = _accessToken;
    if (_userId == null || token == null || token.isEmpty) {
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

    final baseUrl = AppConfig.cloudflareWorkerUrl;
    final authOpts = Options(headers: {'Authorization': 'Bearer $token'});

    try {
      // 1. Pull remote state from D1
      final pullRes = await _dio.get<dynamic>(
        '$baseUrl/api/sync/pull',
        options: authOpts,
      );
      if (pullRes.statusCode == 200 && pullRes.data is Map) {
        final favs = pullRes.data['favorites'] as List<dynamic>? ?? const [];
        for (final row in favs) {
          if (row is Map && row['track_uri'] is String) {
            final uri = row['track_uri'] as String;
            if (!_db.isFavorite(uri)) {
              await _db.toggleFavorite(uri);
              favoritesCount++;
            }
          }
        }

        final pls = pullRes.data['playlists'] as List<dynamic>? ?? const [];
        for (final pl in pls) {
          if (pl is Map && pl['title'] is String) {
            final title = pl['title'] as String;
            final rawTracks = pl['tracks'] as List<dynamic>? ?? const [];
            final trackUris = rawTracks
                .whereType<Map>()
                .map((t) => t['track_uri'] as String?)
                .whereType<String>()
                .toList();
            await _db.setPlaylist(title, trackUris);
            playlistsCount++;
            tracksCount += trackUris.length;
          }
        }
      }

      // 2. Push local favorites, playlists, offline mutations & theme preferences
      final allTracks = _db.getAllTracks();
      final trackLookup = {for (final t in allTracks) t.id: t};

      final localFavPayload = _db.getFavoriteTracks().map((t) {
        return {
          'track_uri': _generatePortableUri(t.id, t.title, t.artist),
          'title': t.title,
          'artist': t.artist,
          'album': t.album,
          'duration_ms': t.duration.inMilliseconds,
        };
      }).toList();

      final localPlaylists = _db.getPlaylists();
      final localPlaylistPayload = localPlaylists.entries.map((entry) {
        final tracks = entry.value.map((uri) {
          final track =
              trackLookup[uri] ??
              Track(
                id: uri,
                title: uri.replaceFirst(RegExp(r'^[a-z]+:'), ''),
                artist: 'Unknown Artist',
                album: '',
                duration: Duration.zero,
              );
          return {
            'track_uri': _generatePortableUri(
              track.id,
              track.title,
              track.artist,
            ),
            'title': track.title,
            'artist': track.artist,
            'album': track.album,
            'duration_ms': track.duration.inMilliseconds,
          };
        }).toList();
        return {'title': entry.key, 'tracks': tracks};
      }).toList();

      final mutations = _db.getOfflineMutations();
      final audioQuality = await PreferencesService().getAudioQuality();
      final hostName = kIsWeb
          ? 'Web Client'
          : (Platform.localHostname.isNotEmpty
                ? Platform.localHostname
                : 'MUXIS Device');

      final pushRes = await _dio.post<dynamic>(
        '$baseUrl/api/sync/push',
        options: authOpts,
        data: {
          'device': {
            'name': hostName,
            'platform': _getPlatformString(),
            'client_version': '1.2.9',
          },
          'mutations': mutations,
          'favorites': localFavPayload,
          'playlists': localPlaylistPayload,
          'settings': {
            'theme_mode': _themeState.mode.name,
            'dark_preset': _themeState.darkPresetId,
            'light_preset': _themeState.lightPresetId,
            'accent_taste': _themeState.accentTasteId,
            'audio_quality': audioQuality,
          },
        },
      );

      if (pushRes.statusCode == 200) {
        await _db.clearOfflineMutations();
        state = SyncStatus.synced;
        return SyncReport(
          syncTime: DateTime.now(),
          playlistsSynced: playlistsCount,
          favoritesSynced: favoritesCount,
          tracksSynced: tracksCount,
          isSuccess: true,
        );
      }

      state = SyncStatus.error;
      return SyncReport(
        syncTime: DateTime.now(),
        isSuccess: false,
        errorMessage: 'Cloud sync returned HTTP ${pushRes.statusCode}',
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

  String _getPlatformString() {
    if (kIsWeb) return 'web';
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isLinux) return 'linux';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'web';
  }

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
