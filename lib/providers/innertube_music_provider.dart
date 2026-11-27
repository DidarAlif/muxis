import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import '../core/storage/preferences_service.dart';
import '../shared/models/album.dart';
import '../shared/models/featured_section.dart';
import '../shared/models/playlist.dart';
import '../shared/models/track.dart';
import 'music_provider.dart';

class InnerTubeMusicProvider implements MusicProvider {
  final Dio _dio;
  final PreferencesService _prefs;

  static final Map<String, ({String url, DateTime expiresAt})> _streamUrlCache =
      {};

  InnerTubeMusicProvider({Dio? dio, PreferencesService? prefs})
    : _dio = dio ?? Dio(),
      _prefs = prefs ?? PreferencesService();

  static const String _youtubeMusicOrigin = 'https://music.youtube.com';
  static const String _youtubeiBaseUrl =
      'https://music.youtube.com/youtubei/v1';
  static const String _youtubePlayerUrl =
      'https://www.youtube.com/youtubei/v1/player';

  static const String _androidUserAgent =
      'com.google.android.youtube/20.10.38 (Linux; U; Android 14) gzip';
  static const String _iosUserAgent =
      'com.google.ios.youtube/21.03.1 (iPhone16,2; U; CPU iOS 18_2 like Mac OS X;)';
  static const String _androidVrUserAgent =
      'com.google.android.apps.youtube.vr.oculus/1.56.21 (Linux; U; Android 12; Quest 3 Build/SQ3A.220605.009.A1) gzip';
  static const String _webRemixUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';

  @override
  String get name => 'YouTube Music (InnerTube)';

  @override
  MusicSource get source => MusicSource.youtube;

  Map<String, dynamic> get _webRemixContext => {
    'client': {
      'clientName': 'WEB_REMIX',
      'clientVersion': '1.20260114.03.00',
      'hl': 'en',
      'gl': 'US',
    },
  };

  /// Sanitizes any HTTP header value to printable ASCII to avoid dart:io HttpHeaders FormatException.
  static String sanitizeHeaderValue(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    return raw
        .replaceAll(RegExp(r'[\r\n\t]+'), ' ')
        .replaceAll(RegExp(r'[^\x20-\x7E]'), '')
        .trim();
  }

  /// Sanitizes to ASCII and deduplicates `Cookie:` key=value pairs so Google/InnerTube
  /// never downgrades requests to a signed-out shell due to duplicate cookie names or NUL bytes.
  static String sanitizeAndDeduplicateCookie(String? raw) {
    final cleaned = sanitizeHeaderValue(raw);
    if (cleaned.isEmpty) return '';
    final dedup = <String, String>{};
    for (final part in cleaned.split(';')) {
      final idx = part.indexOf('=');
      if (idx <= 0) continue;
      final k = part.substring(0, idx).trim();
      final v = part.substring(idx + 1).trim();
      if (k.isNotEmpty && v.isNotEmpty) {
        dedup[k] = v;
      }
    }
    return dedup.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }

  static String? _extractCookieValue(String cookieHeader, List<String> keys) {
    for (final key in keys) {
      final match = RegExp('(?:^|;\\s*)${RegExp.escape(key)}=([^;\\s]+)')
          .firstMatch(cookieHeader);
      if (match != null) {
        final val = match.group(1)?.trim() ?? '';
        if (val.isNotEmpty) return val;
      }
    }
    return null;
  }

  /// Builds context headers with optional user cookie and SAPISID auth.
  Future<Map<String, String>> _buildHeaders({
    bool isIos = false,
    String? userAgent,
    bool authenticated = true,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'User-Agent': userAgent ?? (isIos ? _iosUserAgent : _webRemixUserAgent),
      'Origin': _youtubeMusicOrigin,
      'Referer': '$_youtubeMusicOrigin/',
    };

    if (!authenticated) {
      return headers;
    }

    final rawCookie = await _prefs.getYtCookie();
    final rawSapisid = await _prefs.getYtSapisid();
    final rawAuthUser = await _prefs.getYtAuthUser();

    final cookie = sanitizeAndDeduplicateCookie(rawCookie);
    var sapisid = sanitizeHeaderValue(rawSapisid);
    if (sapisid.isEmpty && cookie.isNotEmpty) {
      sapisid =
          _extractCookieValue(cookie, const [
            'SAPISID',
            '__Secure-3PAPISID',
            '__Secure-1PAPISID',
          ]) ??
          '';
    }
    final authUser = RegExp(r'^\d+$').hasMatch(rawAuthUser.trim())
        ? rawAuthUser.trim()
        : '0';

    if (sapisid.isNotEmpty) {
      final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000)
          .toString();
      final authParts = <String>[];
      final sapisid1p = cookie.isNotEmpty
          ? _extractCookieValue(cookie, const ['__Secure-1PAPISID'])
          : null;
      final sapisid3p = cookie.isNotEmpty
          ? _extractCookieValue(cookie, const ['__Secure-3PAPISID'])
          : null;

      String hashFor(String sid) {
        final raw = '$timestamp $sid $_youtubeMusicOrigin';
        return sha1.convert(utf8.encode(raw)).toString();
      }

      authParts.add('SAPISIDHASH ${timestamp}_${hashFor(sapisid)}');
      if (sapisid1p != null && sapisid1p.isNotEmpty) {
        authParts.add('SAPISID1PHASH ${timestamp}_${hashFor(sapisid1p)}');
      }
      if (sapisid3p != null && sapisid3p.isNotEmpty) {
        authParts.add('SAPISID3PHASH ${timestamp}_${hashFor(sapisid3p)}');
      }

      headers['Authorization'] = authParts.join(' ');
      headers['X-Origin'] = _youtubeMusicOrigin;
      headers['X-Goog-AuthUser'] = authUser;

      if (cookie.isNotEmpty) {
        headers['Cookie'] = cookie;
      } else {
        headers['Cookie'] = 'SAPISID=$sapisid; __Secure-3PAPISID=$sapisid;';
      }
    } else if (cookie.isNotEmpty) {
      headers['Cookie'] = cookie;
      headers['X-Goog-AuthUser'] = authUser;
    }

    return headers;
  }

  Map<String, dynamic>? _decodeJsonMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return null;
  }

  Map? _findRendererRecursive(dynamic node, String key) {
    if (node is List) {
      for (final item in node) {
        final hit = _findRendererRecursive(item, key);
        if (hit != null) return hit;
      }
    } else if (node is Map) {
      if (node[key] is Map) return node[key] as Map;
      for (final val in node.values) {
        final hit = _findRendererRecursive(val, key);
        if (hit != null) return hit;
      }
    }
    return null;
  }

  String? _extractContinuationToken(dynamic node) {
    if (node is List) {
      for (final item in node) {
        final tok = _extractContinuationToken(item);
        if (tok != null && tok.isNotEmpty) return tok;
      }
    } else if (node is Map) {
      final nextCont = node['nextContinuationData']?['continuation']
          ?.toString();
      if (nextCont != null && nextCont.isNotEmpty) return nextCont;
      final cmdCont = node['continuationCommand']?['token']?.toString();
      if (cmdCont != null && cmdCont.isNotEmpty) return cmdCont;
      for (final val in node.values) {
        final tok = _extractContinuationToken(val);
        if (tok != null && tok.isNotEmpty) return tok;
      }
    }
    return null;
  }

  /// Fetches real signed-in Google / YouTube account display name and avatar via InnerTube account_menu.
  Future<Map<String, String?>> fetchUserProfile() async {
    try {
      final headers = await _buildHeaders();
      if (!headers.containsKey('Authorization') &&
          !headers.containsKey('Cookie')) {
        return {};
      }
      final res = await _dio.post(
        '$_youtubeiBaseUrl/account/account_menu',
        data: {'context': _webRemixContext},
        options: Options(
          headers: headers,
          validateStatus: (s) => s != null && s < 500,
        ),
      );

      if (res.statusCode == 200 && res.data != null) {
        final data = _decodeJsonMap(res.data);
        if (data == null) return {};
        final actions = data['actions'] as List?;
        dynamic header;
        if (actions != null && actions.isNotEmpty) {
          header =
              actions[0]?['openPopupAction']?['popup']?['multiPageMenuRenderer']?['header']?['activeAccountHeaderRenderer'];
        }
        header ??= _findRendererRecursive(data, 'activeAccountHeaderRenderer');
        if (header is Map) {
          final nameRuns = header['accountName']?['runs'] as List?;
          final name = nameRuns != null && nameRuns.isNotEmpty
              ? nameRuns[0]['text'] as String?
              : null;
          final thumbs = header['accountPhoto']?['thumbnails'] as List?;
          String? avatar;
          if (thumbs != null && thumbs.isNotEmpty) {
            final last = thumbs.last;
            if (last is Map) {
              avatar = last['url']?.toString();
            }
          }
          return {'displayName': name, 'avatarUrl': avatar};
        }
      }
    } catch (_) {}
    return {};
  }

  /// Fetches the authenticated user's personal YouTube Music playlists.
  Future<List<Playlist>> fetchUserPlaylists() async {
    for (final browseId in const [
      'FEmusic_liked_playlists',
      'FEmusic_library_landing',
    ]) {
      try {
        final headers = await _buildHeaders();
        final res = await _dio.post(
          '$_youtubeiBaseUrl/browse',
          data: {'context': _webRemixContext, 'browseId': browseId},
          options: Options(
            headers: headers,
            validateStatus: (s) => s != null && s < 500,
          ),
        );

        if (res.statusCode == 200 && res.data != null) {
          final decoded = _decodeJsonMap(res.data);
          if (decoded != null) {
            final pls = _extractPlaylistsFromBrowse(decoded);
            if (pls.isNotEmpty) return pls;
          }
        }
      } catch (_) {}
    }
    return [];
  }

  /// Fetches tracks inside any YouTube Music playlist (`VL...`, `FE...`, or raw playlist ID),
  /// automatically following continuation tokens so larger playlists sync completely.
  Future<List<Track>> fetchPlaylistTracks(
    String playlistId, {
    int maxPages = 6,
  }) async {
    final allTracks = <Track>[];
    final seenIds = <String>{};
    final seenTokens = <String>{};

    void appendTracks(List<Track> incoming) {
      for (final t in incoming) {
        if (t.id.isNotEmpty && seenIds.add(t.id)) {
          allTracks.add(t);
        }
      }
    }

    try {
      final browseId =
          (playlistId.startsWith('VL') ||
              playlistId.startsWith('FE') ||
              playlistId.startsWith('RD') ||
              playlistId.startsWith('OLAK') ||
              playlistId.startsWith('MPRE'))
          ? playlistId
          : 'VL$playlistId';
      final headers = await _buildHeaders();
      final res = await _dio.post(
        '$_youtubeiBaseUrl/browse',
        data: {'context': _webRemixContext, 'browseId': browseId},
        options: Options(
          headers: headers,
          validateStatus: (s) => s != null && s < 500,
        ),
      );

      if (res.statusCode == 200 && res.data != null) {
        final decoded = _decodeJsonMap(res.data);
        if (decoded != null) {
          appendTracks(_extractTracksFromBrowse(decoded));
          var contToken = _extractContinuationToken(decoded);
          for (
            int page = 1;
            page < maxPages &&
                contToken != null &&
                contToken.isNotEmpty &&
                seenTokens.add(contToken);
            page++
          ) {
            final pageRes = await _dio.post(
              '$_youtubeiBaseUrl/browse',
              queryParameters: {'continuation': contToken, 'type': 'next'},
              data: {'context': _webRemixContext, 'continuation': contToken},
              options: Options(
                headers: headers,
                validateStatus: (s) => s != null && s < 500,
              ),
            );
            if (pageRes.statusCode != 200 || pageRes.data == null) break;
            final pageDecoded = _decodeJsonMap(pageRes.data);
            if (pageDecoded == null) break;
            final pageTracks = _extractTracksFromBrowse(pageDecoded);
            if (pageTracks.isEmpty) break;
            appendTracks(pageTracks);
            contToken = _extractContinuationToken(pageDecoded);
          }
        }
      }
    } catch (_) {}
    return allTracks;
  }

  /// Fetches authenticated user's Liked Music tracks.
  Future<List<Track>> fetchLikedTracks() async {
    for (final id in const ['VLLM', 'LM', 'FEmusic_liked_videos']) {
      final tracks = await fetchPlaylistTracks(id, maxPages: 4);
      if (tracks.isNotEmpty) {
        return tracks.map((t) => t.copyWith(isFavorite: true)).toList();
      }
    }
    return [];
  }

  /// Fetches personalized Home Quick Picks & Recommendations (falls back to History, Explore, Charts).
  Future<List<Track>> fetchHomeRecommendations() async {
    final collected = <Track>[];
    final seenIds = <String>{};

    void addUnique(List<Track> list) {
      for (final t in list) {
        if (t.id.isNotEmpty && seenIds.add(t.id)) {
          collected.add(t);
        }
      }
    }

    for (final browseId in const ['FEmusic_home', 'FEmusic_history']) {
      try {
        final headers = await _buildHeaders();
        final res = await _dio.post(
          '$_youtubeiBaseUrl/browse',
          data: {'context': _webRemixContext, 'browseId': browseId},
          options: Options(
            headers: headers,
            validateStatus: (s) => s != null && s < 500,
          ),
        );

        if (res.statusCode == 200 && res.data != null) {
          final decoded = _decodeJsonMap(res.data);
          if (decoded != null) {
            addUnique(_extractTracksFromBrowse(decoded));
            if (collected.length >= 12) return collected.take(30).toList();
          }
        }
      } catch (_) {}
    }

    if (collected.length >= 4) return collected;

    // Live public Explore & Charts tracks (real playable songs/MVs, never fake demo data)
    for (final browseId in const ['FEmusic_explore', 'FEmusic_charts']) {
      try {
        final headers = await _buildHeaders(authenticated: false);
        final res = await _dio.post(
          '$_youtubeiBaseUrl/browse',
          data: {'context': _webRemixContext, 'browseId': browseId},
          options: Options(
            headers: headers,
            validateStatus: (s) => s != null && s < 500,
          ),
        );
        if (res.statusCode == 200 && res.data != null) {
          final decoded = _decodeJsonMap(res.data);
          if (decoded != null) {
            addUnique(_extractTracksFromBrowse(decoded));
            if (collected.isNotEmpty) return collected.take(30).toList();
          }
        }
      } catch (_) {}
    }

    // Live Global Top chart playlist fallback
    final chartTracks = await fetchPlaylistTracks(
      'VLPL4fGSI1pDJn6t3TXLGiiJdD-sZbrG3tG0',
    );
    if (chartTracks.isNotEmpty) {
      return chartTracks.take(25).toList();
    }

    return collected;
  }

  /// Extracts main-account titled shelves from YouTube Music Home (`FEmusic_home`)
  /// & Explore (`FEmusic_explore`), preserving shelf headers like "Quick picks",
  /// "Listen again", "Mixed for you", and "Trending", with both mixes & tracks.
  Future<List<FeaturedSection>> fetchHomeFeaturedSections() async {
    final sections = <FeaturedSection>[];
    final seenSectionTitles = <String>{};

    for (final browseId in const ['FEmusic_home', 'FEmusic_explore']) {
      try {
        final headers = await _buildHeaders();
        final res = await _dio.post(
          '$_youtubeiBaseUrl/browse',
          data: {'context': _webRemixContext, 'browseId': browseId},
          options: Options(
            headers: headers,
            validateStatus: (s) => s != null && s < 500,
          ),
        );
        if (res.statusCode == 200 && res.data != null) {
          final decoded = _decodeJsonMap(res.data);
          if (decoded != null) {
            for (final sec in extractFeaturedSectionsFromBrowse(decoded)) {
              if (seenSectionTitles.add(sec.title.toLowerCase())) {
                sections.add(sec);
              }
            }
          }
        }
      } catch (_) {}
      if (sections.length >= 6) break;
    }

    return sections;
  }

  List<FeaturedSection> extractFeaturedSectionsFromBrowse(
    Map<String, dynamic> data,
  ) {
    final sections = <FeaturedSection>[];

    void walkShelves(dynamic node) {
      if (node is List) {
        for (final item in node) {
          walkShelves(item);
        }
        return;
      }
      if (node is! Map) return;

      final carousel = node['musicCarouselShelfRenderer'];
      final grid = node['musicGridRenderer'];
      final shelf = node['musicShelfRenderer'];
      final target =
          (carousel is Map ? carousel : null) ??
          (grid is Map ? grid : null) ??
          (shelf is Map ? shelf : null);

      if (target != null) {
        final headerObj = target['header'];
        final hdr =
            (headerObj is Map
                ? (headerObj['musicCarouselShelfBasicHeaderRenderer'] ??
                      headerObj['musicGridHeaderRenderer'])
                : null) ??
            target['title'];
        final dynamic rawTitleRuns = (hdr is Map && hdr['title'] is Map)
            ? hdr['title']['runs']
            : (hdr is Map ? hdr['runs'] : null);
        final titleRuns = rawTitleRuns is List ? rawTitleRuns : null;
        final title = titleRuns != null && titleRuns.isNotEmpty
            ? titleRuns.map((r) => r['text']?.toString() ?? '').join().trim()
            : '';

        if (title.isNotEmpty) {
          final rawItems =
              (target['contents'] ?? target['items']) as List? ?? const [];
          final tracks = <Track>[];
          final playlists = <Playlist>[];
          final seenTrackIds = <String>{};
          final seenPlIds = <String>{};

          for (final item in rawItems) {
            if (item is! Map) continue;
            final twoRow = item['musicTwoRowItemRenderer'];
            if (twoRow is Map) {
              final trMap = Map<String, dynamic>.from(twoRow);
              final track = _parseTwoRowTrack(trMap);
              if (track != null && seenTrackIds.add(track.id)) {
                tracks.add(track);
                continue;
              }
              final pl = _parseTwoRowPlaylist(trMap);
              if (pl != null && seenPlIds.add(pl.id)) {
                playlists.add(pl);
                continue;
              }
            }
            final resp = item['musicResponsiveListItemRenderer'];
            if (resp is Map) {
              final tr = _parseResponsiveListItem(
                Map<String, dynamic>.from(resp),
              );
              if (tr != null && seenTrackIds.add(tr.id)) {
                tracks.add(tr);
              }
            }
          }

          if (tracks.isNotEmpty || playlists.isNotEmpty) {
            sections.add(
              FeaturedSection(
                id: 'yt-sec-${sections.length}-${title.hashCode.abs()}',
                title: title,
                source: MusicSource.youtube,
                tracks: tracks,
                playlists: playlists,
              ),
            );
          }
        }
      }

      for (final val in node.values) {
        if (val is Map || val is List) walkShelves(val);
      }
    }

    walkShelves(data);
    return sections;
  }

  static List<FeaturedSection> featuredSectionsFromWebViewMaps(
    List<Map<String, dynamic>> rawSections,
  ) {
    return rawSections
        .map(FeaturedSection.fromMap)
        .where((s) => s.isNotEmpty)
        .toList();
  }

  static List<Playlist> playlistsFromWebViewMaps(
    List<Map<String, dynamic>> rawList,
  ) {
    return rawList
        .map((m) {
          return Playlist(
            id: m['id']?.toString() ?? '',
            title: m['title']?.toString() ?? 'YouTube Music Playlist',
            description: m['description']?.toString(),
            artworkUrl: m['artworkUrl']?.toString(),
            trackCount: (m['trackCount'] as num?)?.toInt() ?? 0,
          );
        })
        .where((p) => p.id.isNotEmpty)
        .toList();
  }

  static List<Track> tracksFromWebViewMaps(
    List<Map<String, dynamic>> rawList, {
    bool isFavorite = false,
  }) {
    return rawList
        .map((m) {
          final rawId = m['id']?.toString() ?? '';
          return Track(
            id: rawId,
            title: m['title']?.toString() ?? 'Unknown Track',
            artist: m['artist']?.toString() ?? 'YouTube Artist',
            album: m['album']?.toString() ?? 'YouTube Music',
            duration: Duration(
              milliseconds: (m['durationMs'] as num?)?.toInt() ?? 200000,
            ),
            artworkUrl: m['artworkUrl']?.toString(),
            isFavorite: isFavorite || (m['isFavorite'] == true),
            source: MusicSource.youtube,
            audioFormat: 'AAC 256kbps Ad-Free',
          );
        })
        .where((t) => t.id.isNotEmpty)
        .toList();
  }

  @override
  Future<List<Track>> search(String query, {bool songsOnly = false}) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    final collected = <Track>[];
    final seenIds = <String>{};

    void mergeTracks(List<Track> incoming) {
      for (final t in incoming) {
        if (t.id.isNotEmpty && seenIds.add(t.id)) {
          collected.add(t);
        }
      }
    }

    // Strategy 1: Public YouTube Music WEB_REMIX catalog search (Songs filter first for clean metadata)
    final songHits = await _searchWebRemix(cleanQuery, songsOnly: true);
    mergeTracks(songHits);

    // Strategy 2: Unfiltered WEB_REMIX catalog search if requested or songs returned sparse
    if (!songsOnly && collected.length < 4) {
      final generalHits = await _searchWebRemix(cleanQuery, songsOnly: false);
      mergeTracks(generalHits);
    }

    // Strategy 3: Fallback to standard YouTube WEB & ANDROID InnerTube search
    if (collected.isEmpty) {
      final webHits = await _searchStandardYouTube(cleanQuery);
      mergeTracks(webHits);
    }

    return collected;
  }

  Future<List<Track>> _searchWebRemix(
    String query, {
    required bool songsOnly,
  }) async {
    try {
      final headers = await _buildHeaders(authenticated: false);
      final body = <String, dynamic>{
        'context': _webRemixContext,
        'query': query,
        if (songsOnly) 'params': 'EgWKAQIIAWoMEAMQBBAJEAoQBRAV',
      };

      final response = await _dio.post(
        '$_youtubeiBaseUrl/search',
        data: body,
        options: Options(
          headers: headers,
          receiveTimeout: const Duration(seconds: 8),
          sendTimeout: const Duration(seconds: 8),
          validateStatus: (s) => s != null && s < 500,
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final rawData = _decodeJsonMap(response.data);
        if (rawData != null) {
          final tracks = <Track>[];
          _extractTracksFromSearch(rawData, tracks);
          return tracks;
        }
      }
    } catch (_) {}
    return [];
  }

  Future<List<Track>> _searchStandardYouTube(String query) async {
    for (final cfg in [
      {
        'headers': <String, String>{
          'Content-Type': 'application/json',
          'User-Agent': _androidUserAgent,
        },
        'client': {
          'clientName': 'ANDROID',
          'clientVersion': '20.10.38',
          'androidSdkVersion': 34,
          'osName': 'Android',
          'osVersion': '14',
          'hl': 'en',
          'gl': 'US',
        },
      },
      {
        'headers': <String, String>{
          'Content-Type': 'application/json',
          'User-Agent': _webRemixUserAgent,
        },
        'client': {
          'clientName': 'WEB',
          'clientVersion': '2.20250101.00.00',
          'hl': 'en',
          'gl': 'US',
        },
      },
    ]) {
      try {
        final res = await _dio.post(
          'https://www.youtube.com/youtubei/v1/search',
          data: {
            'context': {'client': cfg['client']},
            'query': '$query song',
          },
          options: Options(
            headers: cfg['headers'] as Map<String, String>,
            receiveTimeout: const Duration(seconds: 8),
            sendTimeout: const Duration(seconds: 8),
            validateStatus: (s) => s != null && s < 500,
          ),
        );
        if (res.statusCode == 200 && res.data != null) {
          final rawData = _decodeJsonMap(res.data);
          if (rawData != null) {
            final extracted = _extractStandardVideoResults(rawData);
            if (extracted.isNotEmpty) return extracted;
          }
        }
      } catch (_) {}
    }
    return [];
  }

  List<Track> _extractStandardVideoResults(Map<String, dynamic> data) {
    final results = <Track>[];
    final seenIds = <String>{};

    String runsText(dynamic field) {
      if (field is! Map) return '';
      final simple = field['simpleText']?.toString();
      if (simple != null && simple.isNotEmpty) return simple;
      final runs = field['runs'];
      if (runs is List) {
        return runs
            .whereType<Map>()
            .map((r) => r['text']?.toString() ?? '')
            .join();
      }
      return '';
    }

    void visit(dynamic node) {
      if (node is List) {
        for (final item in node) {
          visit(item);
        }
        return;
      }
      if (node is! Map) return;

      final vRenderer = node['videoRenderer'] ?? node['compactVideoRenderer'];
      if (vRenderer is Map) {
        final vid = vRenderer['videoId']?.toString() ?? '';
        final title = runsText(vRenderer['title'] ?? vRenderer['headline']);
        if (vid.isNotEmpty && title.isNotEmpty && seenIds.add(vid)) {
          final byline = runsText(
            vRenderer['longBylineText'] ??
                vRenderer['shortBylineText'] ??
                vRenderer['ownerText'],
          );
          final len = runsText(vRenderer['lengthText']);
          final thumbs = vRenderer['thumbnail']?['thumbnails'] as List?;
          String? thumbUrl;
          if (thumbs != null && thumbs.isNotEmpty) {
            final lastThumb = thumbs.last;
            if (lastThumb is Map) {
              thumbUrl = lastThumb['url']?.toString();
            }
          }
          results.add(
            Track(
              id: vid,
              title: title,
              artist: byline.isNotEmpty ? byline : 'YouTube Music',
              album: 'YouTube Music',
              duration: _parseDuration(len.isNotEmpty ? len : null),
              artworkUrl: thumbUrl,
              source: MusicSource.youtube,
              audioFormat: 'AAC 130kbps',
            ),
          );
        }
      }

      for (final value in node.values) {
        if (value is Map || value is List) {
          visit(value);
        }
      }
    }

    visit(data);
    return results;
  }

  static bool _isPlaylistBrowseId(String browseId) {
    if (browseId.isEmpty) return false;
    return browseId.startsWith('VL') ||
        browseId.startsWith('PL') ||
        browseId.startsWith('RD') ||
        browseId.startsWith('OLAK') ||
        browseId.startsWith('MPRE') ||
        browseId == 'LM';
  }

  List<Playlist> _extractPlaylistsFromBrowse(Map<String, dynamic> data) {
    final playlists = <Playlist>[];
    final seenIds = <String>{};

    void visit(dynamic node) {
      if (node is List) {
        for (final item in node) {
          visit(item);
        }
        return;
      }
      if (node is! Map) return;

      final twoRow = node['musicTwoRowItemRenderer'];
      if (twoRow is Map<String, dynamic>) {
        final pl = _parseTwoRowPlaylist(twoRow);
        if (pl != null && !seenIds.contains(pl.id)) {
          seenIds.add(pl.id);
          playlists.add(pl);
        }
      }

      final resp = node['musicResponsiveListItemRenderer'];
      if (resp is Map<String, dynamic>) {
        final navBrowse =
            resp['navigationEndpoint']?['browseEndpoint']?['browseId']
                as String?;
        final title =
            resp['flexColumns']?[0]?['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs']?[0]?['text']
                as String?;
        if (navBrowse != null &&
            _isPlaylistBrowseId(navBrowse) &&
            title != null &&
            !seenIds.contains(navBrowse)) {
          seenIds.add(navBrowse);
          playlists.add(
            Playlist(
              id: navBrowse,
              title: title,
              artworkUrl: _extractThumbnail(resp['thumbnail']),
            ),
          );
        }
      }

      for (final value in node.values) {
        if (value is Map || value is List) {
          visit(value);
        }
      }
    }

    visit(data);
    return playlists;
  }

  Playlist? _parseTwoRowPlaylist(Map<String, dynamic> twoRow) {
    try {
      final runs = twoRow['title']?['runs'] as List?;
      final title = runs != null && runs.isNotEmpty
          ? runs[0]['text'] as String?
          : null;
      final browseId =
          twoRow['navigationEndpoint']?['browseEndpoint']?['browseId']
              as String?;
      if (title == null || browseId == null || !_isPlaylistBrowseId(browseId)) {
        return null;
      }

      final subRuns = twoRow['subtitle']?['runs'] as List?;
      final subtitle = subRuns != null && subRuns.isNotEmpty
          ? subRuns.map((r) => r['text']?.toString() ?? '').join()
          : 'YouTube Music Playlist';

      final thumb = _extractThumbnail(
        twoRow['thumbnailRenderer'] ?? twoRow['thumbnail'],
      );

      return Playlist(
        id: browseId,
        title: title,
        description: subtitle,
        artworkUrl: thumb,
      );
    } catch (_) {
      return null;
    }
  }

  List<Track> _extractTracksFromBrowse(Map<String, dynamic> data) {
    final tracks = <Track>[];
    final seenIds = <String>{};

    void visit(dynamic node) {
      if (node is List) {
        for (final item in node) {
          visit(item);
        }
        return;
      }
      if (node is! Map) return;

      final resp = node['musicResponsiveListItemRenderer'];
      if (resp is Map<String, dynamic>) {
        final track = _parseResponsiveListItem(resp);
        if (track != null && !seenIds.contains(track.id)) {
          seenIds.add(track.id);
          tracks.add(track);
        }
      }

      final twoRow = node['musicTwoRowItemRenderer'];
      if (twoRow is Map<String, dynamic>) {
        final track = _parseTwoRowTrack(twoRow);
        if (track != null && !seenIds.contains(track.id)) {
          seenIds.add(track.id);
          tracks.add(track);
        }
      }

      for (final value in node.values) {
        if (value is Map || value is List) {
          visit(value);
        }
      }
    }

    visit(data);
    return tracks;
  }

  Track? _parseTwoRowTrack(Map<String, dynamic> twoRow) {
    try {
      final navWatch = twoRow['navigationEndpoint']?['watchEndpoint'];
      final overlayWatch =
          twoRow['thumbnailOverlay']?['musicItemThumbnailOverlayRenderer']?['content']?['musicPlayButtonRenderer']?['playNavigationEndpoint']?['watchEndpoint'];
      final videoId = (navWatch?['videoId'] ?? overlayWatch?['videoId'])
          ?.toString();
      if (videoId == null || videoId.isEmpty) return null;

      final titleRuns = twoRow['title']?['runs'] as List?;
      final title = titleRuns != null && titleRuns.isNotEmpty
          ? titleRuns[0]['text'] as String?
          : null;
      if (title == null || title.isEmpty) return null;

      final subRuns = twoRow['subtitle']?['runs'] as List?;
      String artist = 'YouTube Music';
      if (subRuns != null && subRuns.isNotEmpty) {
        final joined = subRuns
            .whereType<Map>()
            .map((r) => r['text']?.toString() ?? '')
            .where(
              (t) =>
                  t.trim().isNotEmpty &&
                  t.trim() != '•' &&
                  t.trim() != '·' &&
                  t.trim().toLowerCase() != 'song' &&
                  t.trim().toLowerCase() != 'video',
            )
            .toList();
        if (joined.isNotEmpty) artist = joined.first.trim();
      }

      final thumb = _extractThumbnail(
        twoRow['thumbnailRenderer'] ?? twoRow['thumbnail'],
      );

      return Track(
        id: videoId,
        title: title,
        artist: artist,
        album: 'YouTube Music',
        duration: const Duration(minutes: 3, seconds: 30),
        artworkUrl: thumb,
        source: MusicSource.youtube,
        audioFormat: 'AAC 256kbps Ad-Free',
      );
    } catch (_) {
      return null;
    }
  }

  void _extractTracksFromSearch(Map<String, dynamic> data, List<Track> tracks) {
    final seenIds = tracks.map((t) => t.id).toSet();

    try {
      final tabs = data['contents']?['tabbedSearchResultsRenderer']?['tabs'];
      final firstTab = (tabs is List && tabs.isNotEmpty) ? tabs.first : null;
      final contents =
          firstTab?['tabRenderer']?['content']?['sectionListRenderer']?['contents'];
      if (contents is! List) return;

      for (final section in contents) {
        if (section is! Map) continue;

        final card = section['musicCardShelfRenderer'];
        if (card is Map<String, dynamic>) {
          try {
            final cardRuns = card['title']?['runs'];
            final firstRun = (cardRuns is List && cardRuns.isNotEmpty)
                ? cardRuns.first
                : null;
            final videoId =
                card['onTap']?['watchEndpoint']?['videoId'] ??
                firstRun?['navigationEndpoint']?['watchEndpoint']?['videoId'];
            final title = firstRun?['text'] as String?;
            final subtitleRuns = card['subtitle']?['runs'] as List?;
            final subParts = subtitleRuns != null
                ? subtitleRuns
                      .whereType<Map>()
                      .map((r) => r['text']?.toString().trim() ?? '')
                      .where(
                        (s) =>
                            s.isNotEmpty &&
                            s != '•' &&
                            s != '·' &&
                            s.toLowerCase() != 'song' &&
                            s.toLowerCase() != 'video',
                      )
                      .toList()
                : <String>[];
            final artist = subParts.isNotEmpty
                ? subParts.first
                : 'YouTube Music';
            final thumb = _extractThumbnail(card['thumbnail']);

            if (videoId != null &&
                title != null &&
                seenIds.add(videoId.toString())) {
              tracks.add(
                Track(
                  id: videoId.toString(),
                  title: title,
                  artist: artist,
                  album: 'YouTube Music Spotlight',
                  duration: const Duration(minutes: 3, seconds: 30),
                  artworkUrl: thumb,
                  source: MusicSource.youtube,
                  audioFormat: 'AAC 130kbps / Opus',
                ),
              );
            }

            final cardItems = card['contents'];
            if (cardItems is List) {
              for (final ci in cardItems) {
                if (ci is! Map) continue;
                final r = ci['musicResponsiveListItemRenderer'];
                if (r is Map<String, dynamic>) {
                  final tr = _parseResponsiveListItem(r);
                  if (tr != null && seenIds.add(tr.id)) {
                    tracks.add(tr);
                  }
                }
              }
            }
          } catch (_) {}
        }

        final shelf =
            section['musicShelfRenderer'] ?? section['itemSectionRenderer'];
        if (shelf is Map) {
          final items = shelf['contents'];
          if (items is List) {
            for (final item in items) {
              if (item is! Map) continue;
              final renderer = item['musicResponsiveListItemRenderer'];
              if (renderer is Map<String, dynamic>) {
                final track = _parseResponsiveListItem(renderer);
                if (track != null && seenIds.add(track.id)) {
                  tracks.add(track);
                }
              }
            }
          }
        }
      }
    } catch (_) {}
  }

  Track? _parseResponsiveListItem(Map<String, dynamic> renderer) {
    try {
      final flexColumns = renderer['flexColumns'] as List?;
      if (flexColumns == null || flexColumns.isEmpty) return null;

      final col0 =
          flexColumns[0]?['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs']
              as List?;
      if (col0 == null || col0.isEmpty) return null;
      final title = col0[0]?['text'] as String?;
      final videoId =
          col0[0]?['navigationEndpoint']?['watchEndpoint']?['videoId'] ??
          renderer['playlistItemData']?['videoId'] ??
          renderer['overlay']?['musicItemThumbnailOverlayRenderer']?['content']?['musicPlayButtonRenderer']?['playNavigationEndpoint']?['watchEndpoint']?['videoId'];

      if (videoId == null || title == null) return null;

      String artist = 'YouTube Music';
      String album = 'Single';
      Duration duration = const Duration(minutes: 3, seconds: 20);

      if (flexColumns.length > 1) {
        final col1 =
            flexColumns[1]?['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs']
                as List?;
        if (col1 != null && col1.isNotEmpty) {
          final tokens = col1
              .whereType<Map>()
              .map((r) => (r['text']?.toString() ?? '').trim())
              .where(
                (t) =>
                    t.isNotEmpty &&
                    t != '•' &&
                    t != '·' &&
                    t.toLowerCase() != 'song' &&
                    t.toLowerCase() != 'video' &&
                    t.toLowerCase() != 'ep' &&
                    t.toLowerCase() != 'single' &&
                    t.toLowerCase() != 'album',
              )
              .toList();

          if (tokens.isNotEmpty) {
            final durPattern = RegExp(r'^\d+:\d{2}(:\d{2})?$');
            if (durPattern.hasMatch(tokens.last)) {
              duration = _parseDuration(tokens.last);
              tokens.removeLast();
            }
            if (tokens.isNotEmpty) {
              artist = tokens.first;
            }
            if (tokens.length > 1) {
              album = tokens[1];
            }
          }
        }
      }

      final fixedCols = renderer['fixedColumns'] as List?;
      if (fixedCols != null && fixedCols.isNotEmpty) {
        final durText =
            fixedCols[0]?['musicResponsiveListItemFixedColumnRenderer']?['text']?['runs']?[0]?['text']
                as String?;
        if (durText != null) {
          duration = _parseDuration(durText);
        }
      }

      final thumb = _extractThumbnail(renderer['thumbnail']);

      return Track(
        id: videoId.toString(),
        title: title,
        artist: artist,
        album: album,
        duration: duration,
        artworkUrl: thumb,
        source: MusicSource.youtube,
        audioFormat: 'AAC 130kbps',
      );
    } catch (_) {
      return null;
    }
  }

  String? _extractThumbnail(dynamic thumbData) {
    if (thumbData is! Map) return null;
    final thumbs =
        thumbData['musicThumbnailRenderer']?['thumbnail']?['thumbnails']
            as List? ??
        thumbData['croppedSquareThumbnailRenderer']?['thumbnail']?['thumbnails']
            as List? ??
        thumbData['thumbnails'] as List?;
    if (thumbs != null && thumbs.isNotEmpty) {
      final last = thumbs.last;
      if (last is Map) {
        return last['url']?.toString();
      }
    }
    return null;
  }

  Duration _parseDuration(String? text) {
    if (text == null) return const Duration(minutes: 3, seconds: 30);
    final parts = text.split(':');
    if (parts.length == 2) {
      final m = int.tryParse(parts[0]) ?? 3;
      final s = int.tryParse(parts[1]) ?? 30;
      return Duration(minutes: m, seconds: s);
    } else if (parts.length == 3) {
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      final s = int.tryParse(parts[2]) ?? 0;
      return Duration(hours: h, minutes: m, seconds: s);
    }
    return const Duration(minutes: 3, seconds: 30);
  }

  @override
  Future<String?> resolveAudioStreamUrl(Track track) async {
    if (track.streamUrl != null && track.streamUrl!.isNotEmpty) {
      return track.streamUrl;
    }

    final videoId = track.id.startsWith('yt-')
        ? track.id.replaceFirst('yt-', '')
        : track.id;

    final cached = _streamUrlCache[videoId];
    if (cached != null && DateTime.now().isBefore(cached.expiresAt)) {
      return cached.url;
    }

    String? cacheAndReturn(String? url) {
      if (url != null && url.isNotEmpty) {
        _streamUrlCache[videoId] = (
          url: url,
          expiresAt: DateTime.now().add(const Duration(minutes: 90)),
        );
      }
      return url;
    }

    // Strategy 1: ANDROID 20.10.38 unauthenticated progressive MP4 (itag=18)
    // Streams reliably past 1MB via bare HTTP GET without PoToken 403 errors.
    final androidUrl = await _resolveWithClient(
      videoId: videoId,
      clientName: 'ANDROID',
      clientVersion: '20.10.38',
      userAgent: _androidUserAgent,
      androidSdkVersion: 34,
      sendAuthHeaders: false,
      preferProgressiveFormats: true,
    );
    if (androidUrl != null) return cacheAndReturn(androidUrl);

    // Strategy 2: ANDROID 20.10.38 authenticated (for age/account-gated tracks)
    final androidAuthedUrl = await _resolveWithClient(
      videoId: videoId,
      clientName: 'ANDROID',
      clientVersion: '20.10.38',
      userAgent: _androidUserAgent,
      androidSdkVersion: 34,
      sendAuthHeaders: true,
      preferProgressiveFormats: true,
    );
    if (androidAuthedUrl != null) return cacheAndReturn(androidAuthedUrl);

    // Strategy 3: IOS client fallback (verified directly playable)
    final iosUrl = await _resolveWithClient(
      videoId: videoId,
      clientName: 'IOS',
      clientVersion: '21.03.1',
      userAgent: _iosUserAgent,
      sendAuthHeaders: true,
      preferProgressiveFormats: true,
    );
    if (iosUrl != null) return cacheAndReturn(iosUrl);

    // Strategy 4: ANDROID_VR fallback
    return cacheAndReturn(
      await _resolveWithClient(
        videoId: videoId,
        clientName: 'ANDROID_VR',
        clientVersion: '1.56.21',
        userAgent: _androidVrUserAgent,
        sendAuthHeaders: false,
        preferProgressiveFormats: true,
      ),
    );
  }

  Future<bool> _isUrlDirectlyPlayable(
    String url, {
    bool checkPast1Mb = false,
  }) async {
    try {
      final res = await _dio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          headers: const {'Range': 'bytes=0-1023'},
          receiveTimeout: const Duration(seconds: 4),
          sendTimeout: const Duration(seconds: 4),
          validateStatus: (s) => s != null && s < 500,
        ),
      );
      if (res.statusCode != 200 && res.statusCode != 206) {
        return false;
      }
      if (checkPast1Mb) {
        final res2 = await _dio.get<List<int>>(
          url,
          options: Options(
            responseType: ResponseType.bytes,
            headers: const {'Range': 'bytes=1048576-1049599'},
            receiveTimeout: const Duration(seconds: 4),
            sendTimeout: const Duration(seconds: 4),
            validateStatus: (s) => s != null && s < 500,
          ),
        );
        if (res2.statusCode != 206 &&
            res2.statusCode != 200 &&
            res2.statusCode != 416) {
          return false;
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<String?> _resolveWithClient({
    required String videoId,
    required String clientName,
    required String clientVersion,
    required String userAgent,
    int? androidSdkVersion,
    bool sendAuthHeaders = true,
    bool preferProgressiveFormats = false,
  }) async {
    try {
      final headers = sendAuthHeaders
          ? await _buildHeaders(userAgent: userAgent)
          : <String, String>{
              'Content-Type': 'application/json',
              'User-Agent': userAgent,
            };
      final clientMap = <String, dynamic>{
        'clientName': clientName,
        'clientVersion': clientVersion,
        'hl': 'en',
        'gl': 'US',
        if (androidSdkVersion != null) ...{
          'androidSdkVersion': androidSdkVersion,
          'osName': 'Android',
          'osVersion': '14',
        },
      };
      final body = {
        'context': {'client': clientMap},
        'videoId': videoId,
      };

      final response = await _dio.post(
        _youtubePlayerUrl,
        data: body,
        options: Options(
          headers: headers,
          validateStatus: (s) => s != null && s < 500,
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = _decodeJsonMap(response.data);
        if (data == null) return null;
        final streamingData = data['streamingData'] as Map<String, dynamic>?;
        if (streamingData == null) return null;

        if (preferProgressiveFormats) {
          final progressive = streamingData['formats'] as List?;
          if (progressive != null) {
            final mp4Candidates = <Map<String, dynamic>>[];
            for (final fmt in progressive) {
              if (fmt is Map<String, dynamic>) {
                final mime = (fmt['mimeType'] as String?) ?? '';
                final url = fmt['url'] as String?;
                if (url != null &&
                    url.isNotEmpty &&
                    (mime.contains('mp4') || fmt['itag'] == 18)) {
                  mp4Candidates.add(fmt);
                }
              }
            }
            // Prefer itag=18 (AAC + H.264 progressive MP4, fast and universally supported)
            mp4Candidates.sort((a, b) {
              final aIs18 = a['itag'] == 18;
              final bIs18 = b['itag'] == 18;
              if (aIs18 != bIs18) return aIs18 ? -1 : 1;
              final brA = (a['bitrate'] as num?)?.toInt() ?? 0;
              final brB = (b['bitrate'] as num?)?.toInt() ?? 0;
              return brA.compareTo(brB);
            });
            for (final candidate in mp4Candidates) {
              final url = candidate['url'] as String?;
              if (url != null && await _isUrlDirectlyPlayable(url)) {
                return url;
              }
            }
          }
        }

        final adaptiveFormats = streamingData['adaptiveFormats'] as List?;
        if (adaptiveFormats != null) {
          final audioStreams = <Map<String, dynamic>>[];
          for (final fmt in adaptiveFormats) {
            if (fmt is Map<String, dynamic>) {
              final mime = (fmt['mimeType'] as String?) ?? '';
              final url = fmt['url'] as String?;
              if (mime.startsWith('audio/') && url != null && url.isNotEmpty) {
                audioStreams.add(fmt);
              }
            }
          }

          if (audioStreams.isNotEmpty) {
            // Windows Media Foundation handles audio/mp4 (AAC M4A) most reliably natively
            audioStreams.sort((a, b) {
              if (Platform.isWindows) {
                final aMp4 = ((a['mimeType'] as String?) ?? '').contains(
                  'audio/mp4',
                );
                final bMp4 = ((b['mimeType'] as String?) ?? '').contains(
                  'audio/mp4',
                );
                if (aMp4 != bMp4) return aMp4 ? -1 : 1;
              }
              final brA = (a['bitrate'] as num?)?.toInt() ?? 0;
              final brB = (b['bitrate'] as num?)?.toInt() ?? 0;
              return brB.compareTo(brA);
            });
            for (final candidate in audioStreams.take(2)) {
              final url = candidate['url'] as String?;
              if (url != null &&
                  await _isUrlDirectlyPlayable(url, checkPast1Mb: true)) {
                return url;
              }
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<List<Track>> getFeaturedTracks() async {
    return fetchHomeRecommendations();
  }

  @override
  Future<List<Album>> getFeaturedAlbums() async {
    return const [];
  }

  @override
  Future<List<Playlist>> getCuratedPlaylists() async {
    for (final browseId in const ['FEmusic_charts', 'FEmusic_explore']) {
      try {
        final headers = await _buildHeaders(authenticated: false);
        final res = await _dio.post(
          '$_youtubeiBaseUrl/browse',
          data: {'context': _webRemixContext, 'browseId': browseId},
          options: Options(
            headers: headers,
            validateStatus: (s) => s != null && s < 500,
          ),
        );

        if (res.statusCode == 200 && res.data != null) {
          final decoded = _decodeJsonMap(res.data);
          if (decoded != null) {
            final playlists = _extractPlaylistsFromBrowse(decoded);
            if (playlists.isNotEmpty) return playlists.take(10).toList();
          }
        }
      } catch (_) {}
    }

    return const [];
  }

  @override
  Future<List<Track>> getRadioStation(String genreOrMood) async {
    final results = await search(genreOrMood, songsOnly: true);
    if (results.isNotEmpty) return results.take(20).toList();
    return search(genreOrMood);
  }
}
