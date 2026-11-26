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

  /// Hydrates linked accounts and locally persisted platform playlists/tracks immediately
  Future<void> refreshFromStorage() async {
    final ytCookie = await _prefs.getYtCookie();
    final ytSapisid = await _prefs.getYtSapisid();
    final ytName = await _prefs.getYtUserName();
    final ytAvatar = await _prefs.getYtUserAvatar();

    final spToken = await _prefs.getSpotifyAccessToken();
    final spClientId = await _prefs.getSpotifyClientId();
    final spName = await _prefs.getSpotifyUserName();
    final spAvatar = await _prefs.getSpotifyUserAvatar();
    final spProd = await _prefs.getSpotifyProduct();
    final active = await _prefs.getActiveSource();

    final hasYt = (ytCookie != null && ytCookie.isNotEmpty) ||
        (ytSapisid != null && ytSapisid.isNotEmpty) ||
        (ytName != null && ytName.isNotEmpty);
    final hasSp = (spToken != null && spToken.isNotEmpty) ||
        (spClientId != null && spClientId.isNotEmpty) ||
        (spName != null && spName.isNotEmpty);

    // Load cached playlists & tracks filtered per platform
    final allTracks = _db.getAllTracks();
    final savedPlaylists = _db.getPlaylists();
    final favs = _db.getFavoriteTracks();

    final ytPlaylists = <Playlist>[];
    final spPlaylists = <Playlist>[];
    for (final entry in savedPlaylists.entries) {
      final memberTracks = allTracks
          .where((t) => entry.value.contains(t.id) || entry.value.contains(t.localFilePath))
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
        spPlaylists.add(plObj);
      } else if (memberTracks.any((t) => t.source == MusicSource.youtube)) {
        ytPlaylists.add(plObj);
      }
    }

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

    if (hasYt && state.youtube.playlists.isEmpty) {
      syncYouTubeLive();
    }
    if (hasSp && state.spotify.playlists.isEmpty) {
      syncSpotifyLive();
    }
  }

  /// Launches genuine browser login for YouTube Music & syncs account + playlists
  Future<StreamingAuthResult> connectYouTubeWithBrowser(
    BuildContext context,
  ) async {
    state = state.copyWith(
      youtube: state.youtube.copyWith(isSyncing: true),
    );
    final res = await _oauth.signInWithYouTubeWeb(context);
    await refreshFromStorage();
    if (res.isSuccess) {
      await syncYouTubeLive();
    } else {
      state = state.copyWith(
        youtube: state.youtube.copyWith(isSyncing: false),
      );
    }
    return res;
  }

  /// Launches genuine browser login for Spotify & syncs account + playlists
  Future<StreamingAuthResult> connectSpotifyWithBrowser(
    BuildContext context,
  ) async {
    state = state.copyWith(
      spotify: state.spotify.copyWith(isSyncing: true),
    );
    final res = await _oauth.signInWithSpotifyWeb(context);
    await refreshFromStorage();
    if (res.isSuccess) {
      await syncSpotifyLive();
    } else {
      state = state.copyWith(
        spotify: state.spotify.copyWith(isSyncing: false),
      );
    }
    return res;
  }

  /// Pulls live YouTube Music recommendations, playlists, and likes via InnerTube
  Future<void> syncYouTubeLive() async {
    if (!state.youtube.isConnected) return;
    state = state.copyWith(
      youtube: state.youtube.copyWith(isSyncing: true),
    );

    try {
      final yt = InnerTubeMusicProvider(prefs: _prefs);
      final profileF = yt.fetchUserProfile();
      final playlistsF = yt.fetchUserPlaylists();
      final likedF = yt.fetchLikedTracks();
      final homeF = yt.fetchHomeRecommendations();

      final profile = await profileF;
      final playlists = await playlistsF;
      final liked = await likedF;
      final home = await homeF;

      if (profile['displayName'] != null &&
          profile['displayName']!.isNotEmpty) {
        await _prefs.saveYtUserProfile(
          profile['displayName']!,
          profile['avatarUrl'],
        );
      }

      // Hydrate top playlists with track lists cleanly
      final hydratedPlaylists = <Playlist>[];
      for (final pl in playlists.take(12)) {
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

      if (liked.isNotEmpty) {
        await _db.saveTracks(liked);
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
    } catch (_) {
      state = state.copyWith(
        youtube: state.youtube.copyWith(isSyncing: false),
      );
    }
  }

  /// Pulls live Spotify playlists, liked tracks, and personalized top tracks
  Future<void> syncSpotifyLive() async {
    if (!state.spotify.isConnected) return;
    state = state.copyWith(
      spotify: state.spotify.copyWith(isSyncing: true),
    );

    try {
      final sp = SpotifyMusicProvider(prefs: _prefs);
      final playlists = await sp.fetchUserPlaylists();
      final liked = await sp.fetchLikedTracks();
      final topTracks = await sp.fetchTopTracks();

      final hydratedPlaylists = <Playlist>[];
      for (final pl in playlists.take(12)) {
        final tracks = await sp.fetchPlaylistTracks(pl.id);
        if (tracks.isNotEmpty) {
          await _db.saveTracks(tracks);
          await _db.setPlaylist(pl.title, tracks.map((t) => t.id).toList());
        }
        hydratedPlaylists.add(
          pl.copyWith(
            tracks: tracks,
            trackCount: tracks.isNotEmpty ? tracks.length : pl.trackCount,
          ),
        );
      }

      if (liked.isNotEmpty) {
        await _db.saveTracks(liked);
      }

      state = state.copyWith(
        spotify: state.spotify.copyWith(
          isSyncing: false,
          playlists: hydratedPlaylists.isNotEmpty
              ? hydratedPlaylists
              : state.spotify.playlists,
          likedTracks: liked.isNotEmpty ? liked : state.spotify.likedTracks,
          recommendedTracks:
              topTracks.isNotEmpty ? topTracks : state.spotify.recommendedTracks,
        ),
      );
    } catch (_) {
      state = state.copyWith(
        spotify: state.spotify.copyWith(isSyncing: false),
      );
    }
  }

  Future<void> setActiveSource(String source) async {
    await _prefs.saveActiveSource(source);
    state = state.copyWith(activeSource: source);
  }

  Future<void> disconnectYouTube() async {
    await _prefs.saveYtCookie('');
    await _prefs.saveYtSapisid('');
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
    await _prefs.saveSpotifySpDc('');
    await _prefs.saveSpotifyUserProfile('', null, '');
    await WebViewAuthBridge().clearPlatformSession('spotify');
    state = state.copyWith(
      spotify: const PlatformConnectionData(),
      activeSource: state.youtube.isConnected ? 'youtube' : 'local',
    );
    await _prefs.saveActiveSource(state.activeSource);
  }
}
