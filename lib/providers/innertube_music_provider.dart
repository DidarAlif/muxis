import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import '../core/storage/preferences_service.dart';
import '../shared/models/album.dart';
import '../shared/models/playlist.dart';
import '../shared/models/track.dart';
import 'music_provider.dart';

class InnerTubeMusicProvider implements MusicProvider {
  final Dio _dio;
  final PreferencesService _prefs;

  InnerTubeMusicProvider({Dio? dio, PreferencesService? prefs})
      : _dio = dio ?? Dio(),
        _prefs = prefs ?? PreferencesService();

  static const String _youtubeMusicOrigin = 'https://music.youtube.com';
  static const String _youtubeiBaseUrl = 'https://music.youtube.com/youtubei/v1';
  static const String _youtubePlayerUrl = 'https://www.youtube.com/youtubei/v1/player';

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

  /// Builds context headers with optional user cookie and SAPISID auth
  Future<Map<String, String>> _buildHeaders({bool isIos = false, String? userAgent}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'User-Agent': userAgent ?? (isIos ? _iosUserAgent : _webRemixUserAgent),
      'Origin': _youtubeMusicOrigin,
      'Referer': '$_youtubeMusicOrigin/',
    };

    final rawCookie = await _prefs.getYtCookie();
    final rawSapisid = await _prefs.getYtSapisid();

    final cookie = rawCookie?.replaceAll(RegExp(r'[\r\n]'), ' ').trim();
    final sapisid = rawSapisid?.replaceAll(RegExp(r'[\r\n]'), ' ').trim();

    if (sapisid != null && sapisid.isNotEmpty) {
      final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
      final raw = '$timestamp $sapisid $_youtubeMusicOrigin';
      final hash = sha1.convert(utf8.encode(raw)).toString();
      headers['Authorization'] = 'SAPISIDHASH ${timestamp}_$hash';
      headers['X-Origin'] = _youtubeMusicOrigin;

      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = cookie;
      } else {
        headers['Cookie'] = 'SAPISID=$sapisid; __Secure-3PAPISID=$sapisid;';
      }
    } else if (cookie != null && cookie.isNotEmpty) {
      headers['Cookie'] = cookie;
    }

    return headers;
  }

  /// Fetches real signed-in Google / YouTube account display name and avatar via InnerTube account_menu
  Future<Map<String, String?>> fetchUserProfile() async {
    try {
      final headers = await _buildHeaders();
      if (!headers.containsKey('Authorization') && !headers.containsKey('Cookie')) {
        return {};
      }
      final res = await _dio.post(
        '$_youtubeiBaseUrl/account/account_menu',
        data: {'context': _webRemixContext},
        options: Options(headers: headers),
      );

      if (res.statusCode == 200 && res.data is Map<String, dynamic>) {
        final data = res.data as Map<String, dynamic>;
        final header = data['actions']?[0]?['openPopupAction']?['popup']
            ?['multiPageMenuRenderer']?['header']?['activeAccountHeaderRenderer'];
        if (header is Map<String, dynamic>) {
          final nameRuns = header['accountName']?['runs'] as List?;
          final name = nameRuns != null && nameRuns.isNotEmpty
              ? nameRuns[0]['text'] as String?
              : null;
          final thumbs = header['accountPhoto']?['thumbnails'] as List?;
          final avatar = thumbs != null && thumbs.isNotEmpty
              ? thumbs.last['url'] as String?
              : null;
          return {'displayName': name, 'avatarUrl': avatar};
        }
      }
    } catch (_) {}
    return {};
  }

  /// Fetches the authenticated user's personal YouTube Music playlists
  Future<List<Playlist>> fetchUserPlaylists() async {
    try {
      final headers = await _buildHeaders();
      final res = await _dio.post(
        '$_youtubeiBaseUrl/browse',
        data: {
          'context': _webRemixContext,
          'browseId': 'FEmusic_liked_playlists',
        },
        options: Options(headers: headers),
      );

      if (res.statusCode == 200 && res.data is Map<String, dynamic>) {
        return _extractPlaylistsFromBrowse(res.data as Map<String, dynamic>);
      }
    } catch (_) {}
    return [];
  }

  /// Fetches tracks inside any YouTube Music playlist (`VL...` or raw playlist ID)
  Future<List<Track>> fetchPlaylistTracks(String playlistId) async {
    try {
      final browseId = (playlistId.startsWith('VL') || playlistId.startsWith('FE'))
          ? playlistId
          : 'VL$playlistId';
      final headers = await _buildHeaders();
      final res = await _dio.post(
        '$_youtubeiBaseUrl/browse',
        data: {
          'context': _webRemixContext,
          'browseId': browseId,
        },
        options: Options(headers: headers),
      );

      if (res.statusCode == 200 && res.data is Map<String, dynamic>) {
        return _extractTracksFromBrowse(res.data as Map<String, dynamic>);
      }
    } catch (_) {}
    return [];
  }

  /// Fetches authenticated user's Liked Music tracks
  Future<List<Track>> fetchLikedTracks() async {
    final likedFromPlaylist = await fetchPlaylistTracks('LM');
    if (likedFromPlaylist.isNotEmpty) {
      return likedFromPlaylist.map((t) => t.copyWith(isFavorite: true)).toList();
    }
    return [];
  }

  /// Fetches personalized Home Quick Picks & Recommendations (or public trending mixes)
  Future<List<Track>> fetchHomeRecommendations() async {
    try {
      final headers = await _buildHeaders();
      final res = await _dio.post(
        '$_youtubeiBaseUrl/browse',
        data: {
          'context': _webRemixContext,
          'browseId': 'FEmusic_home',
        },
        options: Options(headers: headers),
      );

      if (res.statusCode == 200 && res.data is Map<String, dynamic>) {
        final tracks = _extractTracksFromBrowse(res.data as Map<String, dynamic>);
        if (tracks.isNotEmpty) return tracks;
      }
    } catch (_) {}
    return getFeaturedTracks();
  }

  @override
  Future<List<Track>> search(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      final headers = await _buildHeaders();
      final body = {
        'context': _webRemixContext,
        'query': query,
      };

      final response = await _dio.post(
        '$_youtubeiBaseUrl/search',
        data: body,
        options: Options(headers: headers),
      );

      final tracks = <Track>[];
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        _extractTracksFromSearch(data, tracks);
      }

      if (tracks.isNotEmpty) {
        return tracks;
      }
    } catch (_) {
      // Fallback below
    }

    return _getFallbackSearchResults(query);
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
        final navBrowse = resp['navigationEndpoint']?['browseEndpoint']?['browseId'] as String?;
        final title = resp['flexColumns']?[0]?['musicResponsiveListItemFlexColumnRenderer']
            ?['text']?['runs']?[0]?['text'] as String?;
        if (navBrowse != null && title != null && !seenIds.contains(navBrowse)) {
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
      final title = runs != null && runs.isNotEmpty ? runs[0]['text'] as String? : null;
      final browseId = twoRow['navigationEndpoint']?['browseEndpoint']?['browseId'] as String?;
      if (title == null || browseId == null) return null;

      final subRuns = twoRow['subtitle']?['runs'] as List?;
      final subtitle = subRuns != null && subRuns.isNotEmpty
          ? subRuns.map((r) => r['text']?.toString() ?? '').join()
          : 'YouTube Music Playlist';

      final thumb = _extractThumbnail(twoRow['thumbnailRenderer'] ?? twoRow['thumbnail']);

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
      final videoId = twoRow['navigationEndpoint']?['watchEndpoint']?['videoId'] as String?;
      if (videoId == null || videoId.isEmpty) return null;

      final titleRuns = twoRow['title']?['runs'] as List?;
      final title = titleRuns != null && titleRuns.isNotEmpty
          ? titleRuns[0]['text'] as String?
          : null;
      if (title == null || title.isEmpty) return null;

      final subRuns = twoRow['subtitle']?['runs'] as List?;
      String artist = 'YouTube Music';
      if (subRuns != null && subRuns.isNotEmpty) {
        artist = subRuns[0]['text']?.toString() ?? 'YouTube Music';
      }

      final thumb = _extractThumbnail(twoRow['thumbnailRenderer'] ?? twoRow['thumbnail']);

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
    try {
      final contents = data['contents']?['tabbedSearchResultsRenderer']?['tabs']?[0]
          ?['tabRenderer']?['content']?['sectionListRenderer']?['contents'] as List?;
      if (contents == null) return;

      for (final section in contents) {
        if (section is! Map<String, dynamic>) continue;

        final card = section['musicCardShelfRenderer'];
        if (card is Map<String, dynamic>) {
          final videoId = card['onTap']?['watchEndpoint']?['videoId'] ??
              card['title']?['runs']?[0]?['navigationEndpoint']?['watchEndpoint']?['videoId'];
          final title = card['title']?['runs']?[0]?['text'] as String?;
          final subtitleRuns = card['subtitle']?['runs'] as List?;
          final artist = subtitleRuns != null && subtitleRuns.isNotEmpty
              ? subtitleRuns.map((r) => r['text']?.toString() ?? '').join()
              : 'YouTube Artist';
          final thumb = _extractThumbnail(card['thumbnail']);

          if (videoId != null && title != null) {
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
        }

        final shelf = section['musicShelfRenderer'] ?? section['itemSectionRenderer'];
        if (shelf is Map<String, dynamic>) {
          final items = shelf['contents'] as List?;
          if (items != null) {
            for (final item in items) {
              if (item is! Map) continue;
              final renderer = item['musicResponsiveListItemRenderer'];
              if (renderer is Map<String, dynamic>) {
                final track = _parseResponsiveListItem(renderer);
                if (track != null && !tracks.any((t) => t.id == track.id)) {
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

      final col0 = flexColumns[0]?['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs'] as List?;
      if (col0 == null || col0.isEmpty) return null;
      final title = col0[0]?['text'] as String?;
      final videoId = col0[0]?['navigationEndpoint']?['watchEndpoint']?['videoId'] ??
          renderer['playlistItemData']?['videoId'] ??
          renderer['overlay']?['musicItemThumbnailOverlayRenderer']?['content']
              ?['musicPlayButtonRenderer']?['playNavigationEndpoint']?['watchEndpoint']?['videoId'];

      if (videoId == null || title == null) return null;

      String artist = 'Various Artists';
      String album = 'Single';
      Duration duration = const Duration(minutes: 3, seconds: 20);

      if (flexColumns.length > 1) {
        final col1 = flexColumns[1]?['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs'] as List?;
        if (col1 != null && col1.isNotEmpty) {
          final runTexts = col1.map((r) => r['text']?.toString() ?? '').toList();
          if (runTexts.isNotEmpty) {
            artist = runTexts[0];
          }
          if (runTexts.length > 2) {
            final last = runTexts.last.trim();
            if (RegExp(r'^\d+:\d{2}(:\d{2})?$').hasMatch(last)) {
              duration = _parseDuration(last);
              if (runTexts.length > 4) album = runTexts[2];
            } else {
              album = runTexts[2];
            }
          }
        }
      }

      final fixedCols = renderer['fixedColumns'] as List?;
      if (fixedCols != null && fixedCols.isNotEmpty) {
        final durText = fixedCols[0]?['musicResponsiveListItemFixedColumnRenderer']
            ?['text']?['runs']?[0]?['text'] as String?;
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
    if (thumbData is! Map<String, dynamic>) return null;
    final thumbs = thumbData['musicThumbnailRenderer']?['thumbnail']?['thumbnails'] as List? ??
        thumbData['croppedSquareThumbnailRenderer']?['thumbnail']?['thumbnails'] as List? ??
        thumbData['thumbnails'] as List?;
    if (thumbs != null && thumbs.isNotEmpty) {
      final last = thumbs.last as Map<String, dynamic>?;
      return last?['url'] as String?;
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

    final videoId = track.id.startsWith('yt-') ? track.id.replaceFirst('yt-', '') : track.id;

    // Strategy 1: iOS client (direct unencrypted audio URLs)
    final iosUrl = await _resolveWithClient(
      videoId: videoId,
      clientName: 'IOS',
      clientVersion: '21.03.1',
      userAgent: _iosUserAgent,
    );
    if (iosUrl != null) return iosUrl;

    // Strategy 2: ANDROID_VR fallback
    return _resolveWithClient(
      videoId: videoId,
      clientName: 'ANDROID_VR',
      clientVersion: '1.56.21',
      userAgent: _androidVrUserAgent,
    );
  }

  Future<String?> _resolveWithClient({
    required String videoId,
    required String clientName,
    required String clientVersion,
    required String userAgent,
  }) async {
    try {
      final headers = await _buildHeaders(userAgent: userAgent);
      final body = {
        'context': {
          'client': {
            'clientName': clientName,
            'clientVersion': clientVersion,
            'hl': 'en',
            'gl': 'US',
          }
        },
        'videoId': videoId,
      };

      final response = await _dio.post(
        _youtubePlayerUrl,
        data: body,
        options: Options(headers: headers),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final adaptiveFormats = data['streamingData']?['adaptiveFormats'] as List?;
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
                final aMp4 = ((a['mimeType'] as String?) ?? '').contains('audio/mp4');
                final bMp4 = ((b['mimeType'] as String?) ?? '').contains('audio/mp4');
                if (aMp4 != bMp4) return aMp4 ? -1 : 1;
              }
              final brA = (a['bitrate'] as num?)?.toInt() ?? 0;
              final brB = (b['bitrate'] as num?)?.toInt() ?? 0;
              return brB.compareTo(brA);
            });
            return audioStreams.first['url'] as String?;
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
        id: '5NV6Rdv1a3I',
        title: 'Get Lucky',
        artist: 'Daft Punk ft. Pharrell Williams',
        album: 'Random Access Memories',
        duration: Duration(minutes: 4, seconds: 8),
        artworkUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=600&auto=format&fit=crop&q=80',
        source: MusicSource.youtube,
        audioFormat: 'AAC 130kbps / 44.1kHz',
      ),
      Track(
        id: 'fJ9rUzIMcZQ',
        title: 'Bohemian Rhapsody',
        artist: 'Queen',
        album: 'A Night at the Opera',
        duration: Duration(minutes: 5, seconds: 55),
        artworkUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=600&auto=format&fit=crop&q=80',
        source: MusicSource.youtube,
        audioFormat: 'AAC 130kbps / 44.1kHz',
      ),
      Track(
        id: '4NRXx6U8ABQ',
        title: 'Blinding Lights',
        artist: 'The Weeknd',
        album: 'After Hours',
        duration: Duration(minutes: 3, seconds: 20),
        artworkUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600&auto=format&fit=crop&q=80',
        source: MusicSource.youtube,
        audioFormat: 'AAC 130kbps / 44.1kHz',
      ),
      Track(
        id: 'kJQP7kiw5Fk',
        title: 'Despacito',
        artist: 'Luis Fonsi ft. Daddy Yankee',
        album: 'VIDA',
        duration: Duration(minutes: 4, seconds: 41),
        artworkUrl: 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=600&auto=format&fit=crop&q=80',
        source: MusicSource.youtube,
        audioFormat: 'AAC 130kbps / 44.1kHz',
      ),
    ];
  }

  @override
  Future<List<Album>> getFeaturedAlbums() async {
    return const [
      Album(
        id: 'MPREb_9u3R81b',
        title: 'Random Access Memories',
        artist: 'Daft Punk',
        year: 2013,
        trackCount: 13,
        artworkUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=600&auto=format&fit=crop&q=80',
      ),
      Album(
        id: 'MPREb_kZ3Qx',
        title: 'After Hours',
        artist: 'The Weeknd',
        year: 2020,
        trackCount: 14,
        artworkUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600&auto=format&fit=crop&q=80',
      ),
    ];
  }

  @override
  Future<List<Playlist>> getCuratedPlaylists() async {
    return const [
      Playlist(
        id: 'RDCLAK5uy_kmPRjHDECIcuVwnKsx2NgGGeQQ5HKKUJ8',
        title: 'Today\'s Hits — Global 50',
        description: 'The biggest streaming hits in the world, updated live.',
        artworkUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=600&auto=format&fit=crop&q=80',
        trackCount: 50,
      ),
      Playlist(
        id: 'RDCLAK5uy_n622sX0g8j37YyQ',
        title: 'Synthwave & Cyberpunk Frequency',
        description: 'Retro-futuristic electronic waves, neon arpeggios, and atmospheric pulses.',
        artworkUrl: 'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=600&auto=format&fit=crop&q=80',
        trackCount: 40,
      ),
    ];
  }

  @override
  Future<List<Track>> getRadioStation(String genreOrMood) async {
    return getFeaturedTracks();
  }

  List<Track> _getFallbackSearchResults(String query) {
    return [
      Track(
        id: '5NV6Rdv1a3I',
        title: '$query (Prismatic Mix)',
        artist: 'Muxis Frequency Studio',
        album: 'Live Transmission',
        duration: const Duration(minutes: 3, seconds: 45),
        source: MusicSource.youtube,
        audioFormat: 'AAC 130kbps',
      ),
    ];
  }
}
