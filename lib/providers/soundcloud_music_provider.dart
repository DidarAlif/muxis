import 'dart:convert';

import 'package:dio/dio.dart';

import '../core/storage/preferences_service.dart';
import '../shared/models/album.dart';
import '../shared/models/featured_section.dart';
import '../shared/models/playlist.dart';
import '../shared/models/track.dart';
import 'innertube_music_provider.dart';
import 'music_provider.dart';

class SoundCloudMusicProvider implements MusicProvider {
  final Dio _dio;
  final PreferencesService _prefs;
  final InnerTubeMusicProvider _innerTubeBridge;

  static String? _cachedClientId;
  static final Map<String, ({String url, DateTime expiresAt})> _streamCache =
      {};

  static const String _apiBase = 'https://api-v2.soundcloud.com';
  static const String _webBase = 'https://soundcloud.com';
  static const String _browserUa =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

  SoundCloudMusicProvider({
    Dio? dio,
    PreferencesService? prefs,
    InnerTubeMusicProvider? innerTubeBridge,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 8),
               receiveTimeout: const Duration(seconds: 10),
             ),
           ),
       _prefs = prefs ?? PreferencesService(),
       _innerTubeBridge = innerTubeBridge ?? InnerTubeMusicProvider();

  @override
  String get name => 'SoundCloud';

  @override
  MusicSource get source => MusicSource.soundcloud;

  Future<String?> _ensureClientId({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cachedClientId != null &&
        _cachedClientId!.isNotEmpty) {
      return _cachedClientId;
    }
    if (!forceRefresh) {
      final saved = await _prefs.getScClientId();
      if (saved != null && saved.isNotEmpty) {
        _cachedClientId = saved;
        return saved;
      }
    }

    try {
      final homeRes = await _dio.get<String>(
        _webBase,
        options: Options(
          responseType: ResponseType.plain,
          headers: const {'User-Agent': _browserUa},
        ),
      );
      final html = homeRes.data ?? '';
      final scriptUrls = RegExp(r'https://a-v2\.sndcdn\.com/assets/[^"]+\.js')
          .allMatches(html)
          .map((m) => m.group(0)!)
          .toList();

      for (final scriptUrl in scriptUrls.reversed.take(8)) {
        try {
          final jsRes = await _dio.get<String>(
            scriptUrl,
            options: Options(
              responseType: ResponseType.plain,
              headers: const {'User-Agent': _browserUa},
            ),
          );
          final js = jsRes.data ?? '';
          final match = RegExp(r'client_id\s*:\s*"([a-zA-Z0-9]{20,40})"')
              .firstMatch(js);
          if (match != null) {
            final cid = match.group(1)!;
            _cachedClientId = cid;
            await _prefs.saveScClientId(cid);
            return cid;
          }
        } catch (_) {}
      }
    } catch (_) {}

    return _cachedClientId;
  }

  Future<Map<String, dynamic>?> _getV2(
    String pathOrUrl, {
    Map<String, dynamic>? query,
    bool withAuth = true,
  }) async {
    var cid = await _ensureClientId();
    if (cid == null || cid.isEmpty) return null;

    final oauth = withAuth ? await _prefs.getScOAuthToken() : null;
    final fullUrl = pathOrUrl.startsWith('http')
        ? pathOrUrl
        : '$_apiBase$pathOrUrl';

    Future<Response<dynamic>> send(String clientId) {
      final params = <String, dynamic>{...?query, 'client_id': clientId};
      return _dio.get(
        fullUrl,
        queryParameters: params,
        options: Options(
          headers: {
            'User-Agent': _browserUa,
            'Accept': 'application/json',
            'Origin': _webBase,
            'Referer': '$_webBase/',
            if (oauth != null && oauth.isNotEmpty)
              'Authorization': 'OAuth $oauth',
          },
          validateStatus: (s) => s != null && s < 500,
        ),
      );
    }

    try {
      var res = await send(cid);
      if (res.statusCode == 401 || res.statusCode == 403) {
        cid = await _ensureClientId(forceRefresh: true);
        if (cid != null && cid.isNotEmpty) {
          res = await send(cid);
        }
      }
      if (res.statusCode == 200 && res.data != null) {
        if (res.data is Map<String, dynamic>) {
          return res.data as Map<String, dynamic>;
        }
        if (res.data is Map) {
          return Map<String, dynamic>.from(res.data as Map);
        }
        if (res.data is String) {
          final decoded = jsonDecode(res.data as String);
          if (decoded is Map) return Map<String, dynamic>.from(decoded);
        }
      }
    } catch (_) {}
    return null;
  }

  static String? _upgradeArtworkUrl(String? raw, {String? avatarFallback}) {
    final chosen = (raw != null && raw.isNotEmpty) ? raw : avatarFallback;
    if (chosen == null || chosen.isEmpty) return null;
    return chosen.replaceFirst('-large.', '-t500x500.');
  }

  Track? _parseTrackMap(dynamic raw, {bool isFavorite = false}) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final inner = m['track'] is Map
        ? Map<String, dynamic>.from(m['track'] as Map)
        : m;
    final idNum = inner['id'];
    final title = inner['title']?.toString().trim();
    if (idNum == null || title == null || title.isEmpty) return null;

    final user = inner['user'] is Map ? inner['user'] as Map : const {};
    final artist = user['username']?.toString().trim() ?? 'SoundCloud Artist';
    final avatar = user['avatar_url']?.toString();
    final art = _upgradeArtworkUrl(
      inner['artwork_url']?.toString(),
      avatarFallback: avatar,
    );
    final durMs = (inner['duration'] as num?)?.toInt() ?? 180000;
    final genre = inner['genre']?.toString().trim() ?? '';
    final policy = inner['policy']?.toString().toUpperCase() ?? '';
    final isSnip = policy == 'SNIP';

    return Track(
      id: 'sc-$idNum',
      title: title,
      artist: artist.isNotEmpty ? artist : 'SoundCloud Artist',
      album: genre.isNotEmpty ? genre : 'SoundCloud',
      duration: Duration(milliseconds: durMs),
      artworkUrl: art,
      isFavorite: isFavorite,
      source: MusicSource.soundcloud,
      audioFormat: isSnip ? 'SoundCloud Bridge' : 'SoundCloud HQ',
    );
  }

  Playlist? _parsePlaylistMap(dynamic raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final inner = m['playlist'] is Map
        ? Map<String, dynamic>.from(m['playlist'] as Map)
        : m;
    final id = inner['id']?.toString() ?? '';
    final title = inner['title']?.toString().trim() ?? '';
    if (id.isEmpty || title.isEmpty) return null;

    final user = inner['user'] is Map ? inner['user'] as Map : const {};
    final rawTracks = (inner['tracks'] as List<dynamic>?) ?? const [];
    final parsedTracks = rawTracks
        .map((t) => _parseTrackMap(t))
        .whereType<Track>()
        .toList();

    final firstTrackArt = parsedTracks.isNotEmpty
        ? parsedTracks.first.artworkUrl
        : null;
    final art = _upgradeArtworkUrl(
      inner['artwork_url']?.toString(),
      avatarFallback: firstTrackArt ?? user['avatar_url']?.toString(),
    );
    final count =
        (inner['track_count'] as num?)?.toInt() ?? parsedTracks.length;

    return Playlist(
      id: id,
      title: title,
      description:
          inner['description']?.toString() ??
          user['username']?.toString() ??
          'SoundCloud Playlist',
      artworkUrl: art,
      tracks: parsedTracks,
      trackCount: count,
    );
  }

  Future<Map<String, String?>> fetchUserProfile() async {
    final data = await _getV2('/me');
    if (data == null) return {};
    final name = (data['full_name']?.toString().trim().isNotEmpty ?? false)
        ? data['full_name'].toString().trim()
        : data['username']?.toString().trim();
    final avatar = _upgradeArtworkUrl(data['avatar_url']?.toString());
    if (name == null || name.isEmpty) return {};
    return {'displayName': name, 'avatarUrl': avatar};
  }

  Future<List<Playlist>> fetchUserPlaylists() async {
    final out = <Playlist>[];
    final seenIds = <String>{};

    for (final endpoint in const ['/me/library/all', '/me/playlists']) {
      final data = await _getV2(endpoint, query: {'limit': '40'});
      final coll = (data?['collection'] as List<dynamic>?) ?? const [];
      for (final item in coll) {
        final pl = _parsePlaylistMap(item);
        if (pl != null && seenIds.add(pl.id)) {
          out.add(pl);
        }
      }
    }

    if (out.isEmpty) {
      // Also pull curated SoundCloud selections so signed-in/guest hubs still surface sets cleanly
      final sections = await fetchFeaturedSections();
      for (final sec in sections) {
        for (final pl in sec.playlists) {
          if (seenIds.add(pl.id)) out.add(pl);
        }
      }
    }
    return out;
  }

  Future<List<Track>> fetchLikedTracks() async {
    final out = <Track>[];
    final seen = <String>{};

    for (final endpoint in const ['/me/track_likes', '/me/likes/tracks']) {
      final data = await _getV2(endpoint, query: {'limit': '40'});
      final coll = (data?['collection'] as List<dynamic>?) ?? const [];
      for (final item in coll) {
        final tr = _parseTrackMap(item, isFavorite: true);
        if (tr != null && seen.add(tr.id)) {
          out.add(tr);
        }
      }
      if (out.isNotEmpty) break;
    }
    return out;
  }

  Future<List<Track>> fetchPlaylistTracks(String playlistId) async {
    final data = await _getV2(
      '/playlists/$playlistId',
      query: {'representation': 'full'},
    );
    if (data == null) return [];

    final rawTracks = (data['tracks'] as List<dynamic>?) ?? const [];
    final resolved = <Track>[];
    final missingIds = <int>[];

    for (final raw in rawTracks) {
      final t = _parseTrackMap(raw);
      if (t != null) {
        resolved.add(t);
      } else if (raw is Map && raw['id'] is num) {
        missingIds.add((raw['id'] as num).toInt());
      }
    }

    if (missingIds.isNotEmpty) {
      for (int i = 0; i < missingIds.length; i += 40) {
        final chunk = missingIds.skip(i).take(40).toList();
        final tracksData = await _getV2(
          '/tracks',
          query: {'ids': chunk.join(',')},
          withAuth: false,
        );
        // /tracks?ids=... returns a JSON array rather than Map on SoundCloud
        if (tracksData == null) {
          final list = await _fetchTracksByIds(chunk);
          resolved.addAll(list);
        }
      }
    }
    return resolved;
  }

  Future<List<Track>> _fetchTracksByIds(List<int> ids) async {
    if (ids.isEmpty) return [];
    final cid = await _ensureClientId();
    if (cid == null || cid.isEmpty) return [];
    try {
      final res = await _dio.get(
        '$_apiBase/tracks',
        queryParameters: {'ids': ids.join(','), 'client_id': cid},
        options: Options(headers: const {'User-Agent': _browserUa}),
      );
      if (res.statusCode == 200 && res.data is List) {
        return (res.data as List)
            .map((e) => _parseTrackMap(e))
            .whereType<Track>()
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// Fetches personalized Stream Feed (if logged in), SoundCloud Mixed Selections,
  /// Top Charts, and New & Hot shelves for the user's SoundCloud Hub & Home.
  Future<List<FeaturedSection>> fetchFeaturedSections() async {
    final sections = <FeaturedSection>[];

    // 1. User's Personalized Following Stream Feed
    final oauth = await _prefs.getScOAuthToken();
    if (oauth != null && oauth.isNotEmpty) {
      final streamData = await _getV2('/me/stream', query: {'limit': '25'});
      final coll = (streamData?['collection'] as List<dynamic>?) ?? const [];
      final streamTracks = <Track>[];
      final streamPls = <Playlist>[];
      final seenT = <String>{};
      final seenP = <String>{};
      for (final item in coll) {
        if (item is! Map) continue;
        if (item['track'] != null) {
          final t = _parseTrackMap(item['track']);
          if (t != null && seenT.add(t.id)) streamTracks.add(t);
        } else if (item['playlist'] != null) {
          final pl = _parsePlaylistMap(item['playlist']);
          if (pl != null && seenP.add(pl.id)) streamPls.add(pl);
        }
      }
      if (streamTracks.isNotEmpty || streamPls.isNotEmpty) {
        sections.add(
          FeaturedSection(
            id: 'sc-user-stream',
            title: 'Your SoundCloud Stream',
            subtitle: 'Latest drops & reposts from artists you follow',
            source: MusicSource.soundcloud,
            tracks: streamTracks,
            playlists: streamPls,
          ),
        );
      }
    }

    // 2. Mixed Selections ("Curated by SoundCloud", "Artists to watch", "Trending by genre")
    final mixData = await _getV2('/mixed-selections', query: {'limit': '6'});
    final mixColl = (mixData?['collection'] as List<dynamic>?) ?? const [];
    for (final rawShelf in mixColl) {
      if (rawShelf is! Map) continue;
      final shelfTitle = rawShelf['title']?.toString().trim() ?? '';
      final items =
          (rawShelf['items']?['collection'] as List<dynamic>?) ?? const [];
      if (shelfTitle.isEmpty || items.isEmpty) continue;

      final shelfTracks = <Track>[];
      final shelfPlaylists = <Playlist>[];
      for (final item in items) {
        if (item is! Map) continue;
        final kind = item['kind']?.toString() ?? '';
        if (kind == 'track') {
          final t = _parseTrackMap(item);
          if (t != null) shelfTracks.add(t);
        } else {
          final pl = _parsePlaylistMap(item);
          if (pl != null) shelfPlaylists.add(pl);
        }
      }
      if (shelfTracks.isNotEmpty || shelfPlaylists.isNotEmpty) {
        sections.add(
          FeaturedSection(
            id: rawShelf['id']?.toString() ?? 'sc-mix-${sections.length}',
            title: shelfTitle,
            subtitle: rawShelf['description']?.toString(),
            source: MusicSource.soundcloud,
            tracks: shelfTracks,
            playlists: shelfPlaylists,
          ),
        );
      }
    }

    // 3. SoundCloud Top 50 & New & Hot Charts
    final topCharts = await _getV2(
      '/charts',
      query: {
        'kind': 'top',
        'genre': 'soundcloud:genres:all-music',
        'limit': '20',
      },
      withAuth: false,
    );
    final topItems = (topCharts?['collection'] as List<dynamic>?) ?? const [];
    final topTracks = topItems
        .map((e) => _parseTrackMap(e))
        .whereType<Track>()
        .toList();
    if (topTracks.isNotEmpty) {
      sections.add(
        FeaturedSection(
          id: 'sc-charts-top',
          title: 'SoundCloud Top Charts',
          subtitle: 'Most streamed across SoundCloud',
          source: MusicSource.soundcloud,
          tracks: topTracks,
        ),
      );
    }

    final trendingCharts = await _getV2(
      '/charts',
      query: {
        'kind': 'trending',
        'genre': 'soundcloud:genres:all-music',
        'limit': '16',
      },
      withAuth: false,
    );
    final trendItems =
        (trendingCharts?['collection'] as List<dynamic>?) ?? const [];
    final trendTracks = trendItems
        .map((e) => _parseTrackMap(e))
        .whereType<Track>()
        .toList();
    if (trendTracks.isNotEmpty) {
      sections.add(
        FeaturedSection(
          id: 'sc-charts-trending',
          title: 'New & Hot on SoundCloud',
          subtitle: 'Rising independent & viral releases',
          source: MusicSource.soundcloud,
          tracks: trendTracks,
        ),
      );
    }

    return sections;
  }

  @override
  Future<List<Track>> search(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return [];
    final data = await _getV2(
      '/search/tracks',
      query: {'q': clean, 'limit': '24'},
      withAuth: true,
    );
    final coll = (data?['collection'] as List<dynamic>?) ?? const [];
    return coll.map((e) => _parseTrackMap(e)).whereType<Track>().toList();
  }

  @override
  Future<String?> resolveAudioStreamUrl(Track track) async {
    if (track.streamUrl != null && track.streamUrl!.isNotEmpty) {
      return track.streamUrl;
    }

    final cached = _streamCache[track.id];
    if (cached != null && DateTime.now().isBefore(cached.expiresAt)) {
      return cached.url;
    }

    final numericId = track.id.startsWith('sc-')
        ? track.id.substring(3)
        : track.id;

    try {
      final trackObj = await _getV2('/tracks/$numericId');
      final policy = trackObj?['policy']?.toString().toUpperCase() ?? '';
      final transcodings =
          (trackObj?['media']?['transcodings'] as List<dynamic>?) ?? const [];

      // If track is a 30s Go+ snippet (SNIP), skip directly to full catalog bridge
      if (policy != 'SNIP' && transcodings.isNotEmpty) {
        // Prefer progressive MP3 first (rock-solid across Windows Media Foundation & Android)
        final ordered = <Map<String, dynamic>>[];
        for (final t in transcodings.whereType<Map>()) {
          if (t['format']?['protocol'] == 'progressive') {
            ordered.add(Map<String, dynamic>.from(t));
          }
        }
        for (final t in transcodings.whereType<Map>()) {
          if (t['format']?['protocol'] != 'progressive') {
            ordered.add(Map<String, dynamic>.from(t));
          }
        }

        for (final trans in ordered) {
          final transUrl = trans['url']?.toString();
          if (transUrl == null || transUrl.isEmpty) continue;
          final resolved = await _getV2(transUrl);
          final finalUrl = resolved?['url']?.toString();
          if (finalUrl != null && finalUrl.isNotEmpty) {
            _streamCache[track.id] = (
              url: finalUrl,
              expiresAt: DateTime.now().add(const Duration(minutes: 45)),
            );
            return finalUrl;
          }
        }
      }
    } catch (_) {}

    // Fallback to clean InnerTube search if SoundCloud track is Go+ restricted
    try {
      final q = '${track.artist} ${track.title}'.trim();
      final ytMatches = await _innerTubeBridge.search(q, songsOnly: true);
      for (final m in ytMatches.take(2)) {
        final u = await _innerTubeBridge.resolveAudioStreamUrl(m);
        if (u != null && u.isNotEmpty) return u;
      }
    } catch (_) {}

    return null;
  }

  @override
  Future<List<Track>> getFeaturedTracks() async {
    final secs = await fetchFeaturedSections();
    for (final s in secs) {
      if (s.tracks.isNotEmpty) return s.tracks;
    }
    return const [];
  }

  @override
  Future<List<Album>> getFeaturedAlbums() async => const [];

  @override
  Future<List<Playlist>> getCuratedPlaylists() async => fetchUserPlaylists();

  @override
  Future<List<Track>> getRadioStation(String genreOrMood) async =>
      search(genreOrMood);
}
