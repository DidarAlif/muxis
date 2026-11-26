import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';

import '../core/auth/webview_auth_bridge.dart';
import '../core/storage/preferences_service.dart';
import '../shared/models/album.dart';
import '../shared/models/playlist.dart';
import '../shared/models/track.dart';
import 'innertube_music_provider.dart';
import 'music_provider.dart';

class SpotifyMusicProvider implements MusicProvider {
  final Dio _dio;
  final PreferencesService _prefs;
  final InnerTubeMusicProvider _innerTubeBridge;

  String? _accessToken;
  DateTime? _tokenExpiry;
  String? _cachedClientToken;
  bool lastRequestWasRateLimited = false;
  static DateTime? _webApiCooldownUntil;

  static const String _webPlayerClientId = 'd8a5ed958d274c2e8ee717e6a4b0971d';
  static const String _browserUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';
  static const String _pathfinderUrl =
      'https://api-partner.spotify.com/pathfinder/v2/query';

  SpotifyMusicProvider({
    Dio? dio,
    PreferencesService? prefs,
    InnerTubeMusicProvider? innerTubeBridge,
  })  : _dio = dio ?? Dio(),
        _prefs = prefs ?? PreferencesService(),
        _innerTubeBridge = innerTubeBridge ?? InnerTubeMusicProvider();

  @override
  String get name => 'Spotify';

  @override
  MusicSource get source => MusicSource.spotify;

  /// Retrieves or refreshes Spotify access token using Browser Session Token or Client Credentials.
  Future<String?> _getAccessToken({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final userToken = await _prefs.getSpotifyAccessToken();
      if (userToken != null && userToken.isNotEmpty) {
        return userToken;
      }

      if (_accessToken != null &&
          _tokenExpiry != null &&
          DateTime.now().isBefore(_tokenExpiry!)) {
        return _accessToken;
      }
    } else {
      final refreshed = await WebViewAuthBridge().refreshSpotifyTokenSilently();
      if (refreshed != null && refreshed.isNotEmpty) {
        await _prefs.saveSpotifyAccessToken(refreshed);
        return refreshed;
      }
    }

    final clientId = await _prefs.getSpotifyClientId();
    final clientSecret = await _prefs.getSpotifyClientSecret();

    if (clientId == null ||
        clientId.isEmpty ||
        clientSecret == null ||
        clientSecret.isEmpty) {
      return null;
    }

    try {
      final basicAuth = base64Encode(utf8.encode('$clientId:$clientSecret'));
      final response = await _dio.post(
        'https://accounts.spotify.com/api/token',
        data: 'grant_type=client_credentials',
        options: Options(
          headers: {
            'Authorization': 'Basic $basicAuth',
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          validateStatus: (s) => s != null && s < 500,
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        _accessToken = data['access_token'] as String?;
        final expiresIn = (data['expires_in'] as num?)?.toInt() ?? 3600;
        _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn - 60));
        return _accessToken;
      }
    } catch (_) {}

    return null;
  }

  /// Retrieves Spotify Web Player `client-token` from persisted WebView session or clienttoken endpoint.
  Future<String?> _getClientToken({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      if (_cachedClientToken != null && _cachedClientToken!.isNotEmpty) {
        return _cachedClientToken;
      }
      final saved = await _prefs.getSpotifyClientToken();
      if (saved != null && saved.isNotEmpty) {
        _cachedClientToken = saved;
        return saved;
      }
    }

    try {
      final res = await _dio.post(
        'https://clienttoken.spotify.com/v1/clienttoken',
        data: {
          'client_data': {
            'client_version': '1.2.52.442.g35629a5e',
            'client_id': _webPlayerClientId,
            'js_sdk_data': {
              'device_brand': 'unknown',
              'device_model': 'unknown',
              'os': Platform.isAndroid ? 'android' : 'windows',
              'os_version': 'NT 10.0',
              'device_id': 'muxis-${Random().nextInt(99999999)}',
              'device_type': 'computer',
            },
          },
        },
        options: Options(
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'User-Agent': _browserUserAgent,
          },
          validateStatus: (s) => s != null && s < 500,
        ),
      );
      if (res.statusCode == 200 && res.data is Map) {
        final ct = res.data['granted_token']?['token'] as String?;
        if (ct != null && ct.isNotEmpty) {
          _cachedClientToken = ct;
          await _prefs.saveSpotifyClientToken(ct);
          return ct;
        }
      }
    } catch (_) {}

    return null;
  }

  Future<Map<String, String>> _getPathfinderHashes() async {
    final raw = await _prefs.getSpotifyPathfinderHashes();
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map(
          (k, v) => MapEntry(k.toString(), v?.toString() ?? ''),
        );
      }
    } catch (_) {}
    return {};
  }

  Future<Response<dynamic>?> _authorizedGet(
    String url, {
    Map<String, dynamic>? queryParameters,
  }) async {
    lastRequestWasRateLimited = false;
    final cooldown = _webApiCooldownUntil;
    if (cooldown != null && DateTime.now().isBefore(cooldown)) {
      lastRequestWasRateLimited = true;
      return null;
    }

    var token = await _getAccessToken();
    if (token == null || token.isEmpty) return null;

    final clientToken = await _getClientToken();

    Map<String, String> buildHeaders(String bearer) => {
          'Authorization': 'Bearer $bearer',
          'Accept': 'application/json',
          'User-Agent': _browserUserAgent,
          if (clientToken != null && clientToken.isNotEmpty) ...{
            'client-token': clientToken,
            'app-platform': 'WebPlayer',
            'Origin': 'https://open.spotify.com',
            'Referer': 'https://open.spotify.com/',
          },
        };

    try {
      var res = await _dio.get(
        url,
        queryParameters: queryParameters,
        options: Options(
          headers: buildHeaders(token),
          validateStatus: (s) => s != null && s < 500,
        ),
      );

      if (res.statusCode == 401) {
        final newToken = await _getAccessToken(forceRefresh: true);
        if (newToken != null && newToken.isNotEmpty) {
          token = newToken;
          res = await _dio.get(
            url,
            queryParameters: queryParameters,
            options: Options(
              headers: buildHeaders(token),
              validateStatus: (s) => s != null && s < 500,
            ),
          );
        }
      }

      if (res.statusCode == 429) {
        final retryHeader = int.tryParse(res.headers.value('retry-after') ?? '');
        final cooldownSec = (retryHeader ?? 60).clamp(30, 120);
        _webApiCooldownUntil = DateTime.now().add(Duration(seconds: cooldownSec));
        lastRequestWasRateLimited = true;
        return null;
      }

      return res;
    } catch (_) {
      return null;
    }
  }

  /// Queries Spotify Pathfinder GraphQL using dynamically harvested persistedQuery hashes.
  Future<Map<String, dynamic>?> _pathfinderPost(
    String operationName,
    Map<String, dynamic> variables,
  ) async {
    final hashes = await _getPathfinderHashes();
    final sha256Hash = hashes[operationName];
    if (sha256Hash == null || sha256Hash.isEmpty) return null;

    var token = await _getAccessToken();
    var clientToken = await _getClientToken();
    if (token == null || token.isEmpty || clientToken == null || clientToken.isEmpty) {
      return null;
    }

    try {
      final res = await _dio.post(
        _pathfinderUrl,
        data: {
          'operationName': operationName,
          'variables': variables,
          'extensions': {
            'persistedQuery': {
              'version': 1,
              'sha256Hash': sha256Hash,
            },
          },
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'client-token': clientToken,
            'app-platform': 'WebPlayer',
            'Content-Type': 'application/json;charset=UTF-8',
            'Accept': 'application/json',
            'Origin': 'https://open.spotify.com',
            'Referer': 'https://open.spotify.com/',
            'User-Agent': _browserUserAgent,
          },
          validateStatus: (s) => s != null && s < 500,
        ),
      );
      if (res.statusCode == 200 && res.data is Map<String, dynamic>) {
        return res.data as Map<String, dynamic>;
      }
      if (res.statusCode == 429) {
        lastRequestWasRateLimited = true;
      }
    } catch (_) {}
    return null;
  }

  /// Fetches Spotify profile cleanly without throwing on REST 429 rate-limits.
  Future<Map<String, String?>> fetchUserProfile() async {
    // 1. Pathfinder profileAttributes (if captured)
    final pf = await _pathfinderPost('profileAttributes', const {});
    final pfName = pf?['data']?['me']?['profile']?['name'] as String?;
    final pfSources = pf?['data']?['me']?['profile']?['avatar']?['sources'] as List?;
    final pfAvatar = (pfSources != null && pfSources.isNotEmpty)
        ? pfSources.last['url'] as String?
        : null;
    if (pfName != null && pfName.isNotEmpty) {
      return {
        'displayName': pfName,
        'avatarUrl': pfAvatar,
        'product': 'SPOTIFY BRIDGE',
      };
    }

    // 2. REST /v1/me (429-safe)
    final res = await _authorizedGet('https://api.spotify.com/v1/me');
    if (res?.statusCode == 200 && res?.data is Map<String, dynamic>) {
      final profile = res!.data as Map<String, dynamic>;
      final displayName = profile['display_name'] as String?;
      final rawProduct = profile['product'] as String?;
      final images = profile['images'] as List?;
      final avatarUrl =
          images != null && images.isNotEmpty ? images[0]['url'] as String? : null;
      return {
        if (displayName != null) 'displayName': displayName,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
        if (rawProduct != null && rawProduct.isNotEmpty)
          'product': rawProduct.toUpperCase(),
      };
    }

    return {};
  }

  /// Fetches authenticated user's Spotify playlists via Pathfinder, Web API, or hidden WebView2 fallback.
  Future<List<Playlist>> fetchUserPlaylists({bool allowWebViewFallback = true}) async {
    // 1. Pathfinder libraryV3
    final pf = await _pathfinderPost('libraryV3', {
      'filters': ['Playlists'],
      'order': null,
      'textFilter': '',
      'features': ['LIKED_SONGS', 'YOUR_EPISODES_V2'],
      'limit': 50,
      'offset': 0,
      'flatten': false,
      'expandedFolders': const [],
      'folderUri': null,
      'includeFoldersWhenFlattening': true,
    });
    final pfPlaylists = _parsePathfinderPlaylists(pf);
    if (pfPlaylists.isNotEmpty) return pfPlaylists;

    // 2. REST /v1/me/playlists (429-safe)
    final res = await _authorizedGet(
      'https://api.spotify.com/v1/me/playlists',
      queryParameters: {'limit': '50'},
    );
    if (res?.statusCode == 200 && res?.data != null) {
      final items = res!.data['items'] as List?;
      if (items != null) {
        return items.whereType<Map<String, dynamic>>().map((pl) {
          final id = pl['id'] as String? ?? '';
          final name = pl['name'] as String? ?? 'Spotify Playlist';
          final desc = pl['description'] as String?;
          final imgs = pl['images'] as List?;
          final art = imgs != null && imgs.isNotEmpty ? imgs[0]['url'] as String? : null;
          final count = (pl['tracks']?['total'] as num?)?.toInt() ?? 0;
          return Playlist(
            id: id,
            title: name,
            description: desc,
            artworkUrl: art,
            trackCount: count,
          );
        }).where((p) => p.id.isNotEmpty).toList();
      }
    }

    // 3. Desktop Windows hidden WebView2 sync fallback (uses real Web Player traffic)
    if (allowWebViewFallback && Platform.isWindows) {
      final session = await WebViewAuthBridge().syncSpotifyLibraryViaWebView();
      if (session != null && session.isSuccess) {
        await _persistSessionMetadata(session);
        if (session.spotifyPlaylists.isNotEmpty) {
          return playlistsFromWebViewMaps(session.spotifyPlaylists);
        }
      }
    }

    return [];
  }

  /// Fetches tracks inside a specific Spotify playlist via Pathfinder, REST, or hidden WebView2 fallback.
  Future<List<Track>> fetchPlaylistTracks(
    String playlistId, {
    bool allowWebViewFallback = false,
  }) async {
    // 1. Pathfinder fetchPlaylist
    final pf = await _pathfinderPost('fetchPlaylist', {
      'uri': 'spotify:playlist:$playlistId',
      'offset': 0,
      'limit': 50,
      'enableWatchFeedEntrypoint': false,
    });
    final pfTracks = _parsePathfinderPlaylistTracks(pf);
    if (pfTracks.isNotEmpty) return pfTracks;

    // 2. REST /v1/playlists/{id}/tracks
    final res = await _authorizedGet(
      'https://api.spotify.com/v1/playlists/$playlistId/tracks',
      queryParameters: {'limit': '50'},
    );
    if (res?.statusCode == 200 && res?.data != null) {
      final items = res!.data['items'] as List?;
      if (items != null) {
        final tracks = <Track>[];
        for (final item in items) {
          final t = item['track'];
          if (t is Map<String, dynamic> && t['id'] != null) {
            tracks.add(parseSpotifyTrack(t));
          }
        }
        return tracks;
      }
    }

    // 3. On-demand Windows hidden WebView2 playlist fetch (captures Spotify's own fetchPlaylist response)
    if (allowWebViewFallback && Platform.isWindows) {
      final session = await WebViewAuthBridge().syncSpotifyLibraryViaWebView(
        targetPlaylistId: playlistId,
      );
      if (session != null && session.isSuccess) {
        await _persistSessionMetadata(session);
        final list = session.spotifyPlaylistTracks[playlistId];
        if (list != null && list.isNotEmpty) {
          return tracksFromWebViewMaps(list);
        }
      }
    }

    return [];
  }

  /// Fetches authenticated user's Spotify Liked Songs via Pathfinder or /v1/me/tracks.
  Future<List<Track>> fetchLikedTracks({bool allowWebViewFallback = false}) async {
    // 1. Pathfinder fetchLibraryTracks
    final pf = await _pathfinderPost('fetchLibraryTracks', {
      'offset': 0,
      'limit': 50,
    });
    final pfLiked = _parsePathfinderLikedTracks(pf);
    if (pfLiked.isNotEmpty) return pfLiked;

    // 2. REST /v1/me/tracks
    final res = await _authorizedGet(
      'https://api.spotify.com/v1/me/tracks',
      queryParameters: {'limit': '50'},
    );
    if (res?.statusCode == 200 && res?.data != null) {
      final items = res!.data['items'] as List?;
      if (items != null) {
        final tracks = <Track>[];
        for (final item in items) {
          final t = item['track'];
          if (t is Map<String, dynamic> && t['id'] != null) {
            tracks.add(parseSpotifyTrack(t, isFavorite: true));
          }
        }
        return tracks;
      }
    }

    if (allowWebViewFallback && Platform.isWindows) {
      final session = await WebViewAuthBridge().syncSpotifyLibraryViaWebView();
      if (session != null && session.isSuccess) {
        await _persistSessionMetadata(session);
        if (session.spotifyLikedTracks.isNotEmpty) {
          return tracksFromWebViewMaps(session.spotifyLikedTracks, isFavorite: true);
        }
      }
    }

    return [];
  }

  /// Fetches personalized top tracks or falls back cleanly to catalog highlights.
  Future<List<Track>> fetchTopTracks() async {
    final res = await _authorizedGet(
      'https://api.spotify.com/v1/me/top/tracks',
      queryParameters: {'limit': '25', 'time_range': 'short_term'},
    );
    if (res?.statusCode == 200 && res?.data != null) {
      final items = res!.data['items'] as List?;
      if (items != null && items.isNotEmpty) {
        return items
            .whereType<Map<String, dynamic>>()
            .map((t) => parseSpotifyTrack(t))
            .toList();
      }
    }
    return getFeaturedTracks();
  }

  /// Runs a single hidden WebView2 sync pass on Windows and persists captured tokens + profile.
  Future<WebViewAuthSession?> fetchSingleWebViewSyncSession() async {
    if (!Platform.isWindows) return null;
    final session = await WebViewAuthBridge().syncSpotifyLibraryViaWebView();
    if (session != null && session.isSuccess) {
      await _persistSessionMetadata(session);
    }
    return session;
  }

  Future<void> _persistSessionMetadata(WebViewAuthSession session) async {
    if (session.spotifyAccessToken != null &&
        session.spotifyAccessToken!.isNotEmpty) {
      await _prefs.saveSpotifyAccessToken(session.spotifyAccessToken!);
    }
    if (session.spotifyClientToken != null &&
        session.spotifyClientToken!.isNotEmpty) {
      await _prefs.saveSpotifyClientToken(session.spotifyClientToken!);
    }
    if (session.spotifyPathfinderHashesJson != null &&
        session.spotifyPathfinderHashesJson!.isNotEmpty) {
      await _prefs.saveSpotifyPathfinderHashes(session.spotifyPathfinderHashesJson!);
    }
    if (session.spotifyDisplayName != null &&
        session.spotifyDisplayName!.isNotEmpty) {
      await _prefs.saveSpotifyUserProfile(
        session.spotifyDisplayName!,
        session.spotifyAvatarUrl,
        session.spotifyProduct ?? 'SPOTIFY BRIDGE',
      );
    }
  }

  static List<Playlist> playlistsFromWebViewMaps(
    List<Map<String, dynamic>> rawList,
  ) {
    return rawList.map((m) {
      return Playlist(
        id: m['id']?.toString() ?? '',
        title: m['title']?.toString() ?? 'Spotify Playlist',
        description: m['description']?.toString(),
        artworkUrl: m['artworkUrl']?.toString(),
        trackCount: (m['trackCount'] as num?)?.toInt() ?? 0,
      );
    }).where((p) => p.id.isNotEmpty).toList();
  }

  static List<Track> tracksFromWebViewMaps(
    List<Map<String, dynamic>> rawList, {
    bool isFavorite = false,
  }) {
    return rawList.map((m) {
      final rawId = m['id']?.toString() ?? '';
      final normalizedId = rawId.startsWith('sp-') ? rawId : 'sp-$rawId';
      return Track(
        id: normalizedId,
        title: m['title']?.toString() ?? 'Unknown Track',
        artist: m['artist']?.toString() ?? 'Unknown Artist',
        album: m['album']?.toString() ?? 'Single',
        duration: Duration(
          milliseconds: (m['durationMs'] as num?)?.toInt() ?? 200000,
        ),
        artworkUrl: m['artworkUrl']?.toString(),
        isFavorite: isFavorite || (m['isFavorite'] == true),
        source: MusicSource.spotify,
        audioFormat: 'Spotify Hi-Fi Bridge (320kbps)',
      );
    }).where((t) => t.id != 'sp-').toList();
  }

  List<Playlist> _parsePathfinderPlaylists(Map<String, dynamic>? data) {
    final items = data?['data']?['me']?['libraryV3']?['items'] as List?;
    if (items == null) return [];
    final out = <Playlist>[];
    for (final row in items) {
      if (row is! Map) continue;
      final item = row['item'];
      if (item is! Map) continue;
      final uri = (item['_uri'] ?? item['uri'] ?? '').toString();
      if (!uri.contains(':playlist:')) continue;
      final plData = (item['data'] ?? item['playlistV2']?['data'] ?? item);
      if (plData is! Map) continue;
      final name = plData['name']?.toString();
      if (name == null || name.isEmpty) continue;
      final id = uri.split(':').last;
      final imgItems = plData['images']?['items'] as List?;
      final sources = imgItems != null && imgItems.isNotEmpty
          ? imgItems[0]['sources'] as List?
          : null;
      final art = sources != null && sources.isNotEmpty
          ? sources.last['url']?.toString()
          : null;
      final count = (plData['content']?['totalCount'] as num?)?.toInt() ?? 0;
      out.add(
        Playlist(
          id: id,
          title: name,
          description: plData['description']?.toString(),
          artworkUrl: art,
          trackCount: count,
        ),
      );
    }
    return out;
  }

  List<Track> _parsePathfinderPlaylistTracks(Map<String, dynamic>? data) {
    final items = data?['data']?['playlistV2']?['content']?['items'] as List?;
    if (items == null) return [];
    final out = <Track>[];
    for (final row in items) {
      if (row is! Map) continue;
      final node = row['itemV2'] ?? row['item'] ?? row;
      final track = _parsePathfinderTrackNode(node, isFavorite: false);
      if (track != null) out.add(track);
    }
    return out;
  }

  List<Track> _parsePathfinderLikedTracks(Map<String, dynamic>? data) {
    final items = data?['data']?['me']?['library']?['tracks']?['items'] as List?;
    if (items == null) return [];
    final out = <Track>[];
    for (final row in items) {
      if (row is! Map) continue;
      final node = row['track'] ?? row;
      final track = _parsePathfinderTrackNode(node, isFavorite: true);
      if (track != null) out.add(track);
    }
    return out;
  }

  Track? _parsePathfinderTrackNode(dynamic rawNode, {bool isFavorite = false}) {
    if (rawNode is! Map) return null;
    final dynamic tr =
        (rawNode['data'] is Map && rawNode['data']?['name'] != null)
            ? rawNode['data']
            : ((rawNode['trackV2'] is Map &&
                    rawNode['trackV2']?['data'] is Map)
                ? rawNode['trackV2']['data']
                : rawNode);
    if (tr is! Map) return null;
    final name = tr['name']?.toString();
    final uri = (tr['uri'] ?? rawNode['_uri'] ?? '').toString();
    if (name == null || name.isEmpty || uri.isEmpty) return null;
    final id = uri.split(':').last;

    String artist = 'Unknown Artist';
    final artItems = (tr['artists']?['items'] ?? tr['firstArtist']?['items']) as List?;
    if (artItems != null && artItems.isNotEmpty) {
      final names = artItems
          .whereType<Map>()
          .map((a) => (a['profile']?['name'] ?? a['name'] ?? '').toString())
          .where((s) => s.isNotEmpty)
          .toList();
      if (names.isNotEmpty) artist = names.join(', ');
    }

    final alb = tr['albumOfTrack'] ?? tr['albumV2']?['data'] ?? {};
    final albMap = alb is Map ? alb : null;
    final albumName = albMap?['name']?.toString() ?? 'Single';
    final artSources = albMap?['coverArt']?['sources'] as List?;
    final artUrl = artSources != null && artSources.isNotEmpty
        ? artSources.last['url']?.toString()
        : null;
    final durMs = (tr['duration']?['totalMilliseconds'] as num? ??
                tr['trackDuration']?['totalMilliseconds'] as num?)
            ?.toInt() ??
        200000;

    return Track(
      id: 'sp-$id',
      title: name,
      artist: artist,
      album: albumName,
      duration: Duration(milliseconds: durMs),
      artworkUrl: artUrl,
      isFavorite: isFavorite,
      source: MusicSource.spotify,
      audioFormat: 'Spotify Hi-Fi Bridge (320kbps)',
    );
  }

  Track parseSpotifyTrack(Map<String, dynamic> item, {bool isFavorite = false}) {
    final id = item['id'] as String? ?? '';
    final title = item['name'] as String? ?? 'Unknown Title';
    final artistsList = item['artists'] as List?;
    final artist = artistsList != null && artistsList.isNotEmpty
        ? (artistsList[0]['name'] as String? ?? 'Unknown Artist')
        : 'Unknown Artist';
    final albumName = item['album']?['name'] as String? ?? 'Single';
    final durationMs = (item['duration_ms'] as num?)?.toInt() ?? 200000;
    final images = item['album']?['images'] as List?;
    String? thumb;
    if (images != null && images.isNotEmpty) {
      thumb = images[0]['url'] as String?;
    }

    return Track(
      id: 'sp-$id',
      title: title,
      artist: artist,
      album: albumName,
      duration: Duration(milliseconds: durationMs),
      artworkUrl: thumb,
      isFavorite: isFavorite,
      source: MusicSource.spotify,
      audioFormat: 'Spotify Hi-Fi Bridge (320kbps)',
    );
  }

  @override
  Future<List<Track>> search(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    // 1. Spotify REST Search (only if not rate-limited)
    final res = await _authorizedGet(
      'https://api.spotify.com/v1/search',
      queryParameters: {
        'q': cleanQuery,
        'type': 'track',
        'limit': '20',
      },
    );

    if (res?.statusCode == 200 && res?.data != null) {
      final items = res!.data['tracks']?['items'] as List?;
      if (items != null && items.isNotEmpty) {
        return items
            .whereType<Map<String, dynamic>>()
            .map((item) => parseSpotifyTrack(item))
            .toList();
      }
    }

    // 2. Spotify Pathfinder searchDesktop (if hash was captured during browser login)
    final pf = await _pathfinderPost('searchDesktop', {
      'searchTerm': cleanQuery,
      'offset': 0,
      'limit': 20,
      'numberOfTopResults': 5,
      'includeAudiobooks': false,
      'includeArtistHasConcertsField': false,
      'includePreReleases': false,
      'includeLocalConcertsField': false,
    });
    final pfTracks = _parsePathfinderSearchTracks(pf);
    if (pfTracks.isNotEmpty) {
      return pfTracks;
    }

    // 3. Bridge fallback: query clean InnerTube Songs catalog (returns real YT Music IDs)
    try {
      final ytResults = await _innerTubeBridge.search(cleanQuery, songsOnly: true);
      return ytResults.map((t) {
        return t.copyWith(
          id: 'sp-${t.id}',
          source: MusicSource.spotify,
          audioFormat: 'Spotify Audio Bridge (AAC 130kbps)',
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  List<Track> _parsePathfinderSearchTracks(Map<String, dynamic>? data) {
    final items = data?['data']?['searchV2']?['tracksV2']?['items'] as List?;
    if (items == null) return [];
    final out = <Track>[];
    for (final row in items) {
      if (row is! Map) continue;
      final node = row['item'] ?? row;
      final track = _parsePathfinderTrackNode(node, isFavorite: false);
      if (track != null) out.add(track);
    }
    return out;
  }

  int _scoreMatch(Track candidate, String targetTitle, String targetArtist) {
    int score = 0;
    final cTitle = candidate.title.toLowerCase();
    final cArtist = candidate.artist.toLowerCase();
    final tLower = targetTitle.toLowerCase();
    final aLower = targetArtist.toLowerCase();

    if (cTitle == tLower) score += 60;
    if (cTitle.contains(tLower) || tLower.contains(cTitle)) score += 30;
    for (final w in tLower.split(RegExp(r'[\s,]+')).where((e) => e.length >= 2)) {
      if (cTitle.contains(w)) score += 10;
    }
    for (final w in aLower.split(RegExp(r'[\s,]+')).where((e) => e.length >= 2)) {
      if (cArtist.contains(w) || cTitle.contains(w)) score += 12;
    }
    if (RegExp(r'\b(cover|karaoke|8d|slowed|reverb|nightcore|sped up|instrumental)\b')
        .hasMatch(cTitle) &&
        !RegExp(r'\b(cover|karaoke|8d|slowed|reverb|nightcore|sped up|instrumental)\b')
            .hasMatch(tLower)) {
      score -= 40;
    }
    return score;
  }

  @override
  Future<String?> resolveAudioStreamUrl(Track track) async {
    final cleanId =
        track.id.startsWith('sp-') ? track.id.replaceFirst('sp-', '') : track.id;

    if (!cleanId.startsWith('sp-') &&
        cleanId.length == 11 &&
        !cleanId.contains(' ') &&
        RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(cleanId)) {
      final direct =
          await _innerTubeBridge.resolveAudioStreamUrl(track.copyWith(id: cleanId));
      if (direct != null && direct.isNotEmpty) return direct;
    }

    try {
      final cleanTitle = track.title
          .replaceAll(
            RegExp(
              r'\s*[\(\[].*?(feat\.|ft\.|remaster|deluxe|version|live|edit|mix|radio|explicit|from).*?[\)\]]',
              caseSensitive: false,
            ),
            '',
          )
          .replaceAll(
            RegExp(r'\s*[-–]\s*(remaster|live|deluxe|single|radio).*', caseSensitive: false),
            '',
          )
          .trim();
      final effectiveTitle = cleanTitle.isNotEmpty ? cleanTitle : track.title;
      final cleanArtist = track.artist
          .replaceAll(RegExp(r'\s*\b(feat\.|ft\.)\b.*', caseSensitive: false), '')
          .split(',')
          .first
          .trim();
      final effectiveArtist = cleanArtist.isNotEmpty ? cleanArtist : track.artist;

      final searchQuery = '$effectiveArtist $effectiveTitle'.trim();
      var matches = await _innerTubeBridge.search(searchQuery, songsOnly: true);
      if (matches.isEmpty) {
        matches = await _innerTubeBridge.search('$effectiveTitle $effectiveArtist');
      }
      if (matches.isNotEmpty) {
        final ranked = List<Track>.from(matches)
          ..sort((a, b) => _scoreMatch(b, effectiveTitle, effectiveArtist)
              .compareTo(_scoreMatch(a, effectiveTitle, effectiveArtist)));
        for (final match in ranked.take(3)) {
          final resolved = await _innerTubeBridge.resolveAudioStreamUrl(match);
          if (resolved != null && resolved.isNotEmpty) {
            return resolved;
          }
        }
      }
    } catch (_) {}

    return null;
  }

  @override
  Future<List<Track>> getFeaturedTracks() async {
    return const [
      Track(
        id: 'sp-starboy',
        title: 'Starboy',
        artist: 'The Weeknd ft. Daft Punk',
        album: 'Starboy',
        duration: Duration(minutes: 3, seconds: 50),
        artworkUrl:
            'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600&auto=format&fit=crop&q=80',
        source: MusicSource.spotify,
        audioFormat: 'Spotify 320kbps Bridge',
      ),
      Track(
        id: 'sp-midnight-city',
        title: 'Midnight City',
        artist: 'M83',
        album: 'Hurry Up, We\'re Dreaming',
        duration: Duration(minutes: 4, seconds: 3),
        artworkUrl:
            'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=600&auto=format&fit=crop&q=80',
        source: MusicSource.spotify,
        audioFormat: 'Spotify 320kbps Bridge',
      ),
    ];
  }

  @override
  Future<List<Album>> getFeaturedAlbums() async {
    return const [
      Album(
        id: 'sp-alb-starboy',
        title: 'Starboy',
        artist: 'The Weeknd',
        year: 2016,
        trackCount: 18,
        artworkUrl:
            'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600&auto=format&fit=crop&q=80',
      ),
    ];
  }

  @override
  Future<List<Playlist>> getCuratedPlaylists() async {
    return const [
      Playlist(
        id: 'sp-pl-discover-weekly',
        title: 'Discover Weekly',
        description: 'Your weekly mixtape of fresh music. Updated every Monday.',
        artworkUrl:
            'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=600&auto=format&fit=crop&q=80',
        trackCount: 30,
      ),
    ];
  }

  @override
  Future<List<Track>> getRadioStation(String genreOrMood) async {
    return getFeaturedTracks();
  }
}
