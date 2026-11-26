import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/innertube_music_provider.dart';
import '../../providers/spotify_music_provider.dart';
import '../../shared/models/playlist.dart';
import '../../shared/models/track.dart';
import '../database/database_service.dart';
import '../storage/preferences_service.dart';
import 'streaming_oauth_service.dart';
import 'webview_auth_bridge.dart';

class PlatformConnectionData {
  final bool isConnected;
  final bool isSyncing;
  final String? displayName;
  final String? avatarUrl;
  final String? planBadge;
  final List<Playlist> playlists;
  final List<Track> likedTracks;
  final List<Track> recommendedTracks;

  const PlatformConnectionData({
    this.isConnected = false,
    this.isSyncing = false,
    this.displayName,
    this.avatarUrl,
    this.planBadge,
    this.playlists = const [],
    this.likedTracks = const [],
    this.recommendedTracks = const [],
  });

  PlatformConnectionData copyWith({
    bool? isConnected,
    bool? isSyncing,
    String? displayName,
    String? avatarUrl,
    String? planBadge,
    List<Playlist>? playlists,
    List<Track>? likedTracks,
    List<Track>? recommendedTracks,
    bool clearProfile = false,
  }) {
    return PlatformConnectionData(
      isConnected: isConnected ?? this.isConnected,
      isSyncing: isSyncing ?? this.isSyncing,
      displayName: clearProfile ? null : (displayName ?? this.displayName),
      avatarUrl: clearProfile ? null : (avatarUrl ?? this.avatarUrl),
      planBadge: clearProfile ? null : (planBadge ?? this.planBadge),
      playlists: playlists ?? this.playlists,
      likedTracks: likedTracks ?? this.likedTracks,
      recommendedTracks: recommendedTracks ?? this.recommendedTracks,
    );
  }
}

class StreamingAccountsState {
  final PlatformConnectionData youtube;
  final PlatformConnectionData spotify;
  final String activeSource;
  final bool isLoading;

  const StreamingAccountsState({
    this.youtube = const PlatformConnectionData(),
    this.spotify = const PlatformConnectionData(),
    this.activeSource = 'youtube',
    this.isLoading = true,
  });

  int get connectedCount =>
      (youtube.isConnected ? 1 : 0) + (spotify.isConnected ? 1 : 0);

  bool get hasAnyConnected => connectedCount > 0;

  StreamingAccountsState copyWith({
    PlatformConnectionData? youtube,
    PlatformConnectionData? spotify,
    String? activeSource,
    bool? isLoading,
  }) {
    return StreamingAccountsState(
      youtube: youtube ?? this.youtube,
      spotify: spotify ?? this.spotify,
      activeSource: activeSource ?? this.activeSource,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

final streamingAccountsProvider =
    StateNotifierProvider<StreamingAccountsNotifier, StreamingAccountsState>(
  (ref) {
    final prefs = ref.watch(preferencesServiceProvider);
    final db = ref.watch(databaseServiceProvider);
    final oauth = ref.watch(streamingOAuthServiceProvider);
    return StreamingAccountsNotifier(prefs: prefs, db: db, oauth: oauth);
  },
);

class StreamingAccountsNotifier extends StateNotifier<StreamingAccountsState> {
  final PreferencesService _prefs;
  final DatabaseService _db;
  final StreamingOAuthService _oauth;

  bool _syncingYouTube = false;
  bool _syncingSpotify = false;

  StreamingAccountsNotifier({
    required PreferencesService prefs,
    required DatabaseService db,
    required StreamingOAuthService oauth,
  })  : _prefs = prefs,
        _db = db,
        _oauth = oauth,
        super(const StreamingAccountsState()) {
    refreshFromStorage();
  }

  /// Hydrates linked accounts and locally persisted platform playlists/tracks immediately.
  Future<void> refreshFromStorage({bool triggerBackgroundSync = true}) async {
    final ytCookie = await _prefs.getYtCookie();
    final ytSapisid = await _prefs.getYtSapisid();
    final ytName = await _prefs.getYtUserName();
    final ytAvatar = await _prefs.getYtUserAvatar();
    final ytCacheJson = await _prefs.getYtPlaylistsCache();

    final spToken = await _prefs.getSpotifyAccessToken();
    final spClientId = await _prefs.getSpotifyClientId();
    final spName = await _prefs.getSpotifyUserName();
    final spAvatar = await _prefs.getSpotifyUserAvatar();
    final spProd = await _prefs.getSpotifyProduct();
    final spCacheJson = await _prefs.getSpotifyPlaylistsCache();
    final active = await _prefs.getActiveSource();

    final hasYt = (ytCookie != null && ytCookie.isNotEmpty) ||
        (ytSapisid != null && ytSapisid.isNotEmpty) ||
        (ytName != null && ytName.isNotEmpty);
    final hasSp = (spToken != null && spToken.isNotEmpty) ||
        (spClientId != null && spClientId.isNotEmpty) ||
        (spName != null && spName.isNotEmpty);

    final allTracks = _db.getAllTracks();
    final savedPlaylists = _db.getPlaylists();
    final favs = _db.getFavoriteTracks();

    final dbYtPlaylists = <Playlist>[];
    final dbSpPlaylists = <Playlist>[];
    for (final entry in savedPlaylists.entries) {
      final memberTracks = allTracks
          .where((t) =>
              entry.value.contains(t.id) ||
              (t.localFilePath != null && entry.value.contains(t.localFilePath)))
          .toList();
      if (memberTracks.isEmpty) continue;
      final isSp = memberTracks.any((t) => t.source == MusicSource.spotify);
      final plObj = Playlist(
        id: entry.key,
        title: entry.key,
        artworkUrl: memberTracks.first.artworkUrl,
        tracks: memberTracks,
        trackCount: memberTracks.length,
      );
      if (isSp) {
        dbSpPlaylists.add(plObj);
      } else if (memberTracks.any((t) => t.source == MusicSource.youtube)) {
        dbYtPlaylists.add(plObj);
      }
    }

    final ytPlaylists = _mergePlaylistsCache(ytCacheJson, dbYtPlaylists);
    final spPlaylists = _mergePlaylistsCache(spCacheJson, dbSpPlaylists);

    final ytTracks =
        allTracks.where((t) => t.source == MusicSource.youtube).toList();
    final spTracks =
        allTracks.where((t) => t.source == MusicSource.spotify).toList();
    final ytFavs = favs.where((t) => t.source == MusicSource.youtube).toList();
    final spFavs = favs.where((t) => t.source == MusicSource.spotify).toList();

    state = state.copyWith(
      activeSource: active,
      isLoading: false,
      youtube: state.youtube.copyWith(
        isConnected: hasYt,
        displayName: ytName,
        avatarUrl: ytAvatar,
        planBadge: 'AD-FREE INNERTUBE',
        playlists: ytPlaylists.isNotEmpty ? ytPlaylists : state.youtube.playlists,
        likedTracks: ytFavs.isNotEmpty ? ytFavs : state.youtube.likedTracks,
        recommendedTracks:
            ytTracks.isNotEmpty ? ytTracks : state.youtube.recommendedTracks,
      ),
      spotify: state.spotify.copyWith(
        isConnected: hasSp,
        displayName: spName,
        avatarUrl: spAvatar,
        planBadge: spProd ?? 'HI-FI BRIDGE',
        playlists: spPlaylists.isNotEmpty ? spPlaylists : state.spotify.playlists,
        likedTracks: spFavs.isNotEmpty ? spFavs : state.spotify.likedTracks,
        recommendedTracks:
            spTracks.isNotEmpty ? spTracks : state.spotify.recommendedTracks,
      ),
    );

    if (triggerBackgroundSync) {
      if (hasYt && state.youtube.playlists.isEmpty && !_syncingYouTube) {
        syncYouTubeLive();
      }
      if (hasSp && state.spotify.playlists.isEmpty && !_syncingSpotify) {
        syncSpotifyLive();
      }
    }
  }

  List<Playlist> _mergePlaylistsCache(
    String? cacheJson,
    List<Playlist> dbPlaylists,
  ) {
    final byTitle = <String, Playlist>{};
    for (final p in dbPlaylists) {
      byTitle[p.title] = p;
    }

    if (cacheJson != null && cacheJson.isNotEmpty) {
      try {
        final list = jsonDecode(cacheJson) as List<dynamic>;
        final merged = <Playlist>[];
        for (final raw in list) {
          if (raw is! Map) continue;
          final id = raw['id']?.toString() ?? '';
          final title = raw['title']?.toString() ?? '';
          if (id.isEmpty || title.isEmpty) continue;
          final existing = byTitle.remove(title);
          merged.add(
            Playlist(
              id: id,
              title: title,
              description: raw['description']?.toString(),
              artworkUrl: raw['artworkUrl']?.toString() ?? existing?.artworkUrl,
              tracks: existing?.tracks ?? const [],
              trackCount: (existing != null && existing.tracks.isNotEmpty)
                  ? existing.tracks.length
                  : ((raw['trackCount'] as num?)?.toInt() ?? 0),
            ),
          );
        }
        merged.addAll(byTitle.values);
        return merged;
      } catch (_) {}
    }

    return dbPlaylists;
  }

  Future<void> _savePlaylistsCache(
    List<Playlist> playlists, {
    required bool isSpotify,
  }) async {
    final jsonStr = jsonEncode(
      playlists
          .map((p) => {
                'id': p.id,
                'title': p.title,
                'description': p.description,
                'artworkUrl': p.artworkUrl,
                'trackCount': p.tracks.isNotEmpty ? p.tracks.length : p.trackCount,
              })
          .toList(),
    );
    if (isSpotify) {
      await _prefs.saveSpotifyPlaylistsCache(jsonStr);
    } else {
      await _prefs.saveYtPlaylistsCache(jsonStr);
    }
  }

  /// Launches genuine browser login for YouTube Music & syncs account + playlists.
  Future<StreamingAuthResult> connectYouTubeWithBrowser(
    BuildContext context,
  ) async {
    state = state.copyWith(
      youtube: state.youtube.copyWith(isSyncing: true),
    );
    final res = await _oauth.signInWithYouTubeWeb(context);
    await refreshFromStorage(triggerBackgroundSync: false);
    if (res.isSuccess) {
      await syncYouTubeLive();
    } else {
      state = state.copyWith(
        youtube: state.youtube.copyWith(isSyncing: false),
      );
    }
    return res;
  }

  /// Launches genuine browser login for Spotify & syncs account + playlists without 429 bursts.
  Future<StreamingAuthResult> connectSpotifyWithBrowser(
    BuildContext context,
  ) async {
    state = state.copyWith(
      spotify: state.spotify.copyWith(isSyncing: true),
    );
    final res = await _oauth.signInWithSpotifyWeb(context);
    await refreshFromStorage(triggerBackgroundSync: false);
    if (res.isSuccess) {
      // Only perform supplementary sync if browser login didn't already capture playlists + liked
      if (state.spotify.playlists.isEmpty || state.spotify.likedTracks.isEmpty) {
        await syncSpotifyLive();
      } else {
        state = state.copyWith(
          spotify: state.spotify.copyWith(isSyncing: false),
        );
      }
    } else {
      state = state.copyWith(
        spotify: state.spotify.copyWith(isSyncing: false),
      );
    }
    return res;
  }

  /// Pulls live YouTube Music recommendations, playlists, and likes via InnerTube.
  Future<String> syncYouTubeLive() async {
    if (!state.youtube.isConnected) return 'YouTube Music is not connected.';
    if (_syncingYouTube) return 'YouTube Music sync already running.';
    _syncingYouTube = true;

    state = state.copyWith(
      youtube: state.youtube.copyWith(isSyncing: true),
    );

    try {
      final yt = InnerTubeMusicProvider(prefs: _prefs);
      final profile = await yt.fetchUserProfile();
      final playlists = await yt.fetchUserPlaylists();
      final liked = await yt.fetchLikedTracks();
      final home = await yt.fetchHomeRecommendations();

      if (profile['displayName'] != null &&
          profile['displayName']!.isNotEmpty) {
        await _prefs.saveYtUserProfile(
          profile['displayName']!,
          profile['avatarUrl'],
        );
      }

      final hydratedPlaylists = <Playlist>[];
      for (final pl in playlists.take(10)) {
        final plTracks = await yt.fetchPlaylistTracks(pl.id);
        if (plTracks.isNotEmpty) {
          await _db.saveTracks(plTracks);
          await _db.setPlaylist(pl.title, plTracks.map((t) => t.id).toList());
        }
        hydratedPlaylists.add(
          pl.copyWith(
            tracks: plTracks,
            trackCount: plTracks.isNotEmpty ? plTracks.length : pl.trackCount,
          ),
        );
      }
      if (playlists.length > 10) {
        hydratedPlaylists.addAll(playlists.skip(10));
      }

      if (hydratedPlaylists.isNotEmpty) {
        await _savePlaylistsCache(hydratedPlaylists, isSpotify: false);
      }
      if (liked.isNotEmpty) {
        await _db.saveTracks(liked);
        for (final t in liked) {
          if (!_db.isFavorite(t.id)) {
            await _db.toggleFavorite(t.id);
          }
        }
      }

      state = state.copyWith(
        youtube: state.youtube.copyWith(
          isSyncing: false,
          displayName: profile['displayName'] ?? state.youtube.displayName,
          avatarUrl: profile['avatarUrl'] ?? state.youtube.avatarUrl,
          playlists: hydratedPlaylists.isNotEmpty
              ? hydratedPlaylists
              : state.youtube.playlists,
          likedTracks: liked.isNotEmpty ? liked : state.youtube.likedTracks,
          recommendedTracks:
              home.isNotEmpty ? home : state.youtube.recommendedTracks,
        ),
      );

      final countPl = state.youtube.playlists.length;
      final countLiked = state.youtube.likedTracks.length;
      return 'YouTube Music synced: $countPl playlists & $countLiked liked songs.';
    } catch (e) {
      state = state.copyWith(
        youtube: state.youtube.copyWith(isSyncing: false),
      );
      return 'YouTube Music sync encountered an issue: $e';
    } finally {
      _syncingYouTube = false;
    }
  }

  /// Pulls live Spotify playlists, liked tracks, and personalized top tracks cleanly.
  Future<String> syncSpotifyLive() async {
    if (!state.spotify.isConnected) return 'Spotify is not connected.';
    if (_syncingSpotify) return 'Spotify sync already running.';
    _syncingSpotify = true;

    state = state.copyWith(
      spotify: state.spotify.copyWith(isSyncing: true),
    );

    try {
      final sp = SpotifyMusicProvider(prefs: _prefs);
      var playlists = await sp.fetchUserPlaylists(allowWebViewFallback: false);
      var liked = await sp.fetchLikedTracks(allowWebViewFallback: false);
      final webViewPlaylistTracks = <String, List<Track>>{};

      String? resolvedName;
      String? resolvedAvatar;
      String? resolvedPlan;

      if (playlists.isEmpty && liked.isEmpty) {
        final wvSession = await sp.fetchSingleWebViewSyncSession();
        if (wvSession != null && wvSession.isSuccess) {
          if (wvSession.spotifyPlaylists.isNotEmpty) {
            playlists = SpotifyMusicProvider.playlistsFromWebViewMaps(
              wvSession.spotifyPlaylists,
            );
          }
          if (wvSession.spotifyLikedTracks.isNotEmpty) {
            liked = SpotifyMusicProvider.tracksFromWebViewMaps(
              wvSession.spotifyLikedTracks,
              isFavorite: true,
            );
          }
          for (final entry in wvSession.spotifyPlaylistTracks.entries) {
            if (entry.value.isNotEmpty) {
              webViewPlaylistTracks[entry.key] =
                  SpotifyMusicProvider.tracksFromWebViewMaps(entry.value);
            }
          }
          resolvedName = wvSession.spotifyDisplayName;
          resolvedAvatar = wvSession.spotifyAvatarUrl;
          resolvedPlan = wvSession.spotifyProduct;
        }
      }

      if (resolvedName == null || resolvedName.isEmpty) {
        final profile = await sp.fetchUserProfile();
        resolvedName = profile['displayName'];
        resolvedAvatar = profile['avatarUrl'];
        resolvedPlan = profile['product'];
      }

      if (resolvedName != null && resolvedName.isNotEmpty) {
        await _prefs.saveSpotifyUserProfile(
          resolvedName,
          resolvedAvatar,
          resolvedPlan ?? state.spotify.planBadge ?? 'SPOTIFY BRIDGE',
        );
      }

      final topTracks = await sp.fetchTopTracks();

      // Retain already hydrated tracks for playlists if we don't fetch all sequentially
      final existingById = {
        for (final p in state.spotify.playlists) p.id: p,
      };

      final hydratedPlaylists = <Playlist>[];
      int hydratedCount = 0;
      for (final pl in playlists) {
        final wvTracks = webViewPlaylistTracks[pl.id];
        if (wvTracks != null && wvTracks.isNotEmpty) {
          await _db.saveTracks(wvTracks);
          await _db.setPlaylist(pl.title, wvTracks.map((t) => t.id).toList());
          hydratedPlaylists.add(
            pl.copyWith(tracks: wvTracks, trackCount: wvTracks.length),
          );
          hydratedCount++;
          continue;
        }

        final prev = existingById[pl.id];
        if (hydratedCount < 5 && !sp.lastRequestWasRateLimited) {
          if (hydratedCount > 0) {
            await Future.delayed(const Duration(milliseconds: 100));
          }
          final tracks = await sp.fetchPlaylistTracks(
            pl.id,
            allowWebViewFallback: false,
          );
          hydratedCount++;
          if (tracks.isNotEmpty) {
            await _db.saveTracks(tracks);
            await _db.setPlaylist(pl.title, tracks.map((t) => t.id).toList());
            hydratedPlaylists.add(
              pl.copyWith(tracks: tracks, trackCount: tracks.length),
            );
            continue;
          }
        }
        hydratedPlaylists.add(
          pl.copyWith(
            tracks: prev?.tracks ?? const [],
            trackCount: (prev != null && prev.tracks.isNotEmpty)
                ? prev.tracks.length
                : pl.trackCount,
          ),
        );
      }

      if (hydratedPlaylists.isNotEmpty) {
        await _savePlaylistsCache(hydratedPlaylists, isSpotify: true);
      }
      if (liked.isNotEmpty) {
        await _db.saveTracks(liked);
        for (final t in liked) {
          if (!_db.isFavorite(t.id)) {
            await _db.toggleFavorite(t.id);
          }
        }
      }

      state = state.copyWith(
        spotify: state.spotify.copyWith(
          isSyncing: false,
          displayName: (resolvedName != null && resolvedName.isNotEmpty)
              ? resolvedName
              : state.spotify.displayName,
          avatarUrl: (resolvedAvatar != null && resolvedAvatar.isNotEmpty)
              ? resolvedAvatar
              : state.spotify.avatarUrl,
          planBadge: (resolvedPlan != null && resolvedPlan.isNotEmpty)
              ? resolvedPlan
              : state.spotify.planBadge,
          playlists: hydratedPlaylists.isNotEmpty
              ? hydratedPlaylists
              : state.spotify.playlists,
          likedTracks: liked.isNotEmpty ? liked : state.spotify.likedTracks,
          recommendedTracks:
              topTracks.isNotEmpty ? topTracks : state.spotify.recommendedTracks,
        ),
      );

      final countPl = state.spotify.playlists.length;
      final countLiked = state.spotify.likedTracks.length;
      if (countPl == 0 && countLiked == 0 && sp.lastRequestWasRateLimited) {
        return 'Spotify API rate-limited temporarily. Re-sign in via Browser if session expired.';
      }
      return 'Spotify synced: $countPl playlists & $countLiked liked songs.';
    } catch (e) {
      state = state.copyWith(
        spotify: state.spotify.copyWith(isSyncing: false),
      );
      return 'Spotify sync error: $e';
    } finally {
      _syncingSpotify = false;
    }
  }

  /// On-demand hydration when user opens a playlist whose tracks haven't been loaded yet.
  Future<Playlist?> hydratePlaylistTracks(
    MusicSource source,
    String playlistId,
  ) async {
    try {
      if (source == MusicSource.spotify) {
        final sp = SpotifyMusicProvider(prefs: _prefs);
        final tracks = await sp.fetchPlaylistTracks(
          playlistId,
          allowWebViewFallback: true,
        );
        if (tracks.isEmpty) return null;
        await _db.saveTracks(tracks);

        final updatedList = state.spotify.playlists.map((pl) {
          if (pl.id != playlistId) return pl;
          _db.setPlaylist(pl.title, tracks.map((t) => t.id).toList());
          return pl.copyWith(tracks: tracks, trackCount: tracks.length);
        }).toList();

        await _savePlaylistsCache(updatedList, isSpotify: true);
        state = state.copyWith(
          spotify: state.spotify.copyWith(playlists: updatedList),
        );
        return updatedList.firstWhere((p) => p.id == playlistId);
      } else if (source == MusicSource.youtube) {
        final yt = InnerTubeMusicProvider(prefs: _prefs);
        final tracks = await yt.fetchPlaylistTracks(playlistId);
        if (tracks.isEmpty) return null;
        await _db.saveTracks(tracks);

        final updatedList = state.youtube.playlists.map((pl) {
          if (pl.id != playlistId) return pl;
          _db.setPlaylist(pl.title, tracks.map((t) => t.id).toList());
          return pl.copyWith(tracks: tracks, trackCount: tracks.length);
        }).toList();

        await _savePlaylistsCache(updatedList, isSpotify: false);
        state = state.copyWith(
          youtube: state.youtube.copyWith(playlists: updatedList),
        );
        return updatedList.firstWhere((p) => p.id == playlistId);
      }
    } catch (_) {}
    return null;
  }

  Future<void> setActiveSource(String source) async {
    await _prefs.saveActiveSource(source);
    state = state.copyWith(activeSource: source);
  }

  Future<void> disconnectYouTube() async {
    await _prefs.saveYtCookie('');
    await _prefs.saveYtSapisid('');
    await _prefs.saveYtAuthUser('0');
    await _prefs.saveYtPlaylistsCache('');
    await _prefs.saveGoogleClientId('');
    await _prefs.saveGoogleClientSecret('');
    await _prefs.saveYtUserProfile('', null);
    await WebViewAuthBridge().clearPlatformSession('youtube');
    state = state.copyWith(
      youtube: const PlatformConnectionData(),
      activeSource: state.spotify.isConnected ? 'spotify' : 'local',
    );
    await _prefs.saveActiveSource(state.activeSource);
  }

  Future<void> disconnectSpotify() async {
    await _prefs.saveSpotifyClientId('');
    await _prefs.saveSpotifyClientSecret('');
    await _prefs.saveSpotifyAccessToken('');
    await _prefs.saveSpotifyClientToken('');
    await _prefs.saveSpotifySpDc('');
    await _prefs.saveSpotifyPathfinderHashes('');
    await _prefs.saveSpotifyPlaylistsCache('');
    await _prefs.saveSpotifyUserProfile('', null, '');
    await WebViewAuthBridge().clearPlatformSession('spotify');
    state = state.copyWith(
      spotify: const PlatformConnectionData(),
      activeSource: state.youtube.isConnected ? 'youtube' : 'local',
    );
    await _prefs.saveActiveSource(state.activeSource);
  }
}
