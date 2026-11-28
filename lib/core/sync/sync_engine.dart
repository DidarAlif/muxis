import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/theme_controller.dart';
import '../../shared/models/track.dart';
import '../audio/dsp/equalizer_node.dart';
import '../auth/supabase_auth_service.dart';
import '../config/app_config.dart';
import '../database/database_service.dart';
import '../storage/preferences_service.dart';
import 'sync_models.dart';

final syncEngineProvider = StateNotifierProvider<SyncEngine, SyncStatus>((ref) {
  final authState = ref.watch(authServiceProvider);
  final db = ref.watch(databaseServiceProvider);
  final themeCtrl = ref.read(muxisThemeProvider.notifier);
  final eqCtrl = ref.read(equalizerProvider.notifier);
  final engine = SyncEngine(
    userId: authState.user?.id,
    accessToken: authState.accessToken,
    readThemeState: () => ref.read(muxisThemeProvider),
    applySyncedTheme: themeCtrl.applySyncedTheme,
    readEqPreset: () => ref.read(equalizerProvider).activePreset,
    applySyncedEqPreset: (preset) {
      if (preset.isNotEmpty &&
          preset != 'Custom' &&
          ref.read(equalizerProvider).activePreset != preset) {
        eqCtrl.applyPreset(preset);
      }
    },
    db: db,
  );
  ref.listen<MuxisThemeState>(muxisThemeProvider, (prev, next) {
    if (prev != null &&
        (prev.mode != next.mode ||
            prev.darkPresetId != next.darkPresetId ||
            prev.lightPresetId != next.lightPresetId ||
            prev.accentTasteId != next.accentTasteId)) {
      engine.scheduleSync();
    }
  });
  return engine;
});

class SyncEngine extends StateNotifier<SyncStatus> {
  final String? _userId;
  final String? _accessToken;
  final MuxisThemeState Function() _readThemeState;
  final Future<void> Function({
    required ThemeMode mode,
    required String darkPresetId,
    required String lightPresetId,
    required String accentTasteId,
  })
  _applySyncedTheme;
  final String Function() _readEqPreset;
  final void Function(String preset) _applySyncedEqPreset;
  final DatabaseService _db;
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'User-Agent': 'MUXIS/1.2.11 (CloudSync)',
      },
      validateStatus: (s) => s != null && s < 600,
    ),
  );
  Timer? _periodicTimer;
  Timer? _debounceTimer;
  bool _appliedRemoteSettingsOnce = false;

  SyncEngine({
    required String? userId,
    required String? accessToken,
    required MuxisThemeState Function() readThemeState,
    required Future<void> Function({
      required ThemeMode mode,
      required String darkPresetId,
      required String lightPresetId,
      required String accentTasteId,
    })
    applySyncedTheme,
    required String Function() readEqPreset,
    required void Function(String preset) applySyncedEqPreset,
    required DatabaseService db,
  }) : _userId = userId,
       _accessToken = accessToken,
       _readThemeState = readThemeState,
       _applySyncedTheme = applySyncedTheme,
       _readEqPreset = readEqPreset,
       _applySyncedEqPreset = applySyncedEqPreset,
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

  void scheduleSync() {
    if (_userId == null || _accessToken == null || _accessToken.isEmpty) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 3), () {
      unawaited(syncNow());
    });
  }

  Track _trackFromCloudRow(Map row) {
    final uri = (row['track_uri'] as String?) ?? '';
    final title = (row['title'] as String?)?.trim();
    final artist = (row['artist'] as String?)?.trim();
    final album = (row['album'] as String?)?.trim() ?? '';
    final durationMs = (row['duration_ms'] as num?)?.toInt() ?? 0;
    final source = uri.startsWith('yt:')
        ? MusicSource.youtube
        : (uri.startsWith('isrc:') ? MusicSource.spotify : MusicSource.local);
    return Track(
      id: uri,
      title: (title != null && title.isNotEmpty)
          ? title
          : uri.replaceFirst(RegExp(r'^[a-z]+:'), ''),
      artist: (artist != null && artist.isNotEmpty) ? artist : 'Unknown Artist',
      album: album,
      duration: Duration(milliseconds: durationMs > 0 ? durationMs : 210000),
      source: source,
      audioFormat: source == MusicSource.local ? 'Cloud Synced' : 'Stream',
    );
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
      // 1. Pull remote state (favorites, playlists, history, theme & EQ settings) from Cloudflare D1
      final pullRes = await _dio.get<dynamic>(
        '$baseUrl/api/sync/pull',
        options: authOpts,
      );
      if (pullRes.statusCode == 200 && pullRes.data is Map) {
        final favs = pullRes.data['favorites'] as List<dynamic>? ?? const [];
        for (final row in favs) {
          if (row is Map && row['track_uri'] is String) {
            final uri = row['track_uri'] as String;
            await _db.importSyncedTrackMetadata(_trackFromCloudRow(row));
            if (!_db.isFavorite(uri)) {
              await _db.mergeSyncedFavorite(uri);
              favoritesCount++;
            }
          }
        }

        final pls = pullRes.data['playlists'] as List<dynamic>? ?? const [];
        for (final pl in pls) {
          if (pl is Map && pl['title'] is String) {
            final title = pl['title'] as String;
            final rawTracks = pl['tracks'] as List<dynamic>? ?? const [];
            final trackUris = <String>[];
            for (final tr in rawTracks.whereType<Map>()) {
              final uri = tr['track_uri'] as String?;
              if (uri == null || uri.isEmpty) continue;
              await _db.importSyncedTrackMetadata(_trackFromCloudRow(tr));
              trackUris.add(uri);
            }
            await _db.setPlaylist(title, trackUris);
            playlistsCount++;
            tracksCount += trackUris.length;
          }
        }

        final histRows = pullRes.data['history'] as List<dynamic>? ?? const [];
        final pulledHistIds = <String>[];
        for (final row in histRows) {
          if (row is Map && row['track_uri'] is String) {
            final uri = row['track_uri'] as String;
            if (uri.isEmpty) continue;
            await _db.importSyncedTrackMetadata(_trackFromCloudRow(row));
            pulledHistIds.add(uri);
          }
        }
        if (pulledHistIds.isNotEmpty) {
          await _db.mergeSyncedHistory(pulledHistIds);
        }

        if (!_appliedRemoteSettingsOnce && pullRes.data['settings'] is Map) {
          _appliedRemoteSettingsOnce = true;
          final s = pullRes.data['settings'] as Map;
          final modeStr = (s['theme_mode'] as String?) ?? '';
          final mode = ThemeMode.values.firstWhere(
            (m) => m.name == modeStr,
            orElse: () => _readThemeState().mode,
          );
          final darkId = (s['dark_preset'] as String?) ?? '';
          final lightId = (s['light_preset'] as String?) ?? '';
          final tasteId = (s['accent_taste'] as String?) ?? '';
          if (darkId.isNotEmpty || lightId.isNotEmpty || tasteId.isNotEmpty) {
            await _applySyncedTheme(
              mode: mode,
              darkPresetId: darkId.isNotEmpty
                  ? darkId
                  : _readThemeState().darkPresetId,
              lightPresetId: lightId.isNotEmpty
                  ? lightId
                  : _readThemeState().lightPresetId,
              accentTasteId: tasteId.isNotEmpty
                  ? tasteId
                  : _readThemeState().accentTasteId,
            );
          }
          final eqPreset = (s['eq_preset'] as String?) ?? '';
          if (eqPreset.isNotEmpty) {
            _applySyncedEqPreset(eqPreset);
          }
          final remoteQuality = (s['audio_quality'] as String?) ?? '';
          if (remoteQuality.isNotEmpty) {
            await PreferencesService().saveAudioQuality(remoteQuality);
          }
        }
      }

      // 2. Push local favorites, playlists, listening history, offline mutations & theme/DSP preferences
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

      final localHistoryPayload = _db.getRecentlyPlayed().take(40).map((t) {
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
      final themeState = _readThemeState();
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
            'client_version': '1.2.11',
          },
          'mutations': mutations,
          'favorites': localFavPayload,
          'history': localHistoryPayload,
          'playlists': localPlaylistPayload,
          'settings': {
            'theme_mode': themeState.mode.name,
            'dark_preset': themeState.darkPresetId,
            'light_preset': themeState.lightPresetId,
            'accent_taste': themeState.accentTasteId,
            'audio_quality': audioQuality,
            'eq_preset': _readEqPreset(),
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
    _debounceTimer?.cancel();
    super.dispose();
  }
}
