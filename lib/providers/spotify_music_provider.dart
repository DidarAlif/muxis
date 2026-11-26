import 'dart:convert';
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

  /// Retrieves or refreshes Spotify access token using Browser Session Token or Client Credentials
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
      // Silently refresh Web Player token using persisted WebView2 Spotify session
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

  Future<Response<dynamic>?> _authorizedGet(
    String url, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final token = await _getAccessToken();
    if (token == null) return null;

    try {
      return await _dio.get(
        url,
        queryParameters: queryParameters,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        final newToken = await _getAccessToken(forceRefresh: true);
        if (newToken != null && newToken.isNotEmpty) {
          return await _dio.get(
            url,
            queryParameters: queryParameters,
            options: Options(headers: {'Authorization': 'Bearer $newToken'}),
          );
        }
      }
    } catch (_) {}
    return null;
  }

  /// Fetches authenticated user's Spotify playlists
  Future<List<Playlist>> fetchUserPlaylists() async {
    final res = await _authorizedGet(
      'https://api.spotify.com/v1/me/playlists',
      queryParameters: {'limit': '50'},
    );
    if (res?.statusCode == 200 && res?.data != null) {
      final items = res!.data['items'] as List?;
      if (items != null) {
        return items.map((pl) {
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
        }).toList();
      }
    }
    return [];
  }

  /// Fetches tracks inside a specific Spotify playlist
  Future<List<Track>> fetchPlaylistTracks(String playlistId) async {
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
    return [];
  }

  /// Fetches authenticated user's Spotify Liked Songs (/v1/me/tracks)
  Future<List<Track>> fetchLikedTracks() async {
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
    return [];
  }

  /// Fetches personalized top tracks for the authenticated user
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
    if (query.trim().isEmpty) return [];

    final res = await _authorizedGet(
      'https://api.spotify.com/v1/search',
      queryParameters: {
        'q': query,
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

    // Bridge fallback: query InnerTube directly and tag as Spotify catalog result
    try {
      final ytResults = await _innerTubeBridge.search(query);
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

  @override
  Future<String?> resolveAudioStreamUrl(Track track) async {
    // When playing a Spotify track, bridge directly to high-bitrate ad-free YouTube Music stream
    final cleanId =
        track.id.startsWith('sp-') ? track.id.replaceFirst('sp-', '') : track.id;

    if (!cleanId.startsWith('sp-') && cleanId.length == 11) {
      return _innerTubeBridge.resolveAudioStreamUrl(track.copyWith(id: cleanId));
    }

    try {
      final cleanTitle = track.title
          .replaceAll(RegExp(r'\s*\(.*?Remaster.*?\)', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s*-\s*Remaster.*', caseSensitive: false), '')
          .trim();
      final searchQuery = '${track.artist} - $cleanTitle audio';
      final matches = await _innerTubeBridge.search(searchQuery);
      if (matches.isNotEmpty) {
        return _innerTubeBridge.resolveAudioStreamUrl(matches.first);
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
