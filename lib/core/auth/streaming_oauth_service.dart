import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/innertube_music_provider.dart';
import '../../providers/spotify_music_provider.dart';
import '../../shared/models/playlist.dart';
import '../../shared/models/track.dart';
import '../database/database_service.dart';
import '../storage/preferences_service.dart';
import 'webview_auth_bridge.dart';

final streamingOAuthServiceProvider = Provider<StreamingOAuthService>((ref) {
  final prefs = ref.watch(preferencesServiceProvider);
  final db = ref.watch(databaseServiceProvider);
  return StreamingOAuthService(prefs: prefs, db: db);
});

class StreamingAuthResult {
  final bool isSuccess;
  final String? platform;
  final String? displayName;
  final String? email;
  final String? avatarUrl;
  final String? subscription;
  final int playlistsImported;
  final int tracksImported;
  final String? errorMessage;

  const StreamingAuthResult({
    required this.isSuccess,
    this.platform,
    this.displayName,
    this.email,
    this.avatarUrl,
    this.subscription,
    this.playlistsImported = 0,
    this.tracksImported = 0,
    this.errorMessage,
  });
}

class StreamingOAuthService {
  final PreferencesService _prefs;
  final DatabaseService _db;
  final Dio _dio;

  StreamingOAuthService({
    required PreferencesService prefs,
    required DatabaseService db,
    Dio? dio,
  })  : _prefs = prefs,
        _db = db,
        _dio = dio ?? Dio();

  // Default public OAuth clients (optional fallback)
  static const String _defaultSpotifyClientId = '';
  static const String _defaultGoogleClientId = '';

  static const List<int> _allowedPorts = [8888, 8889, 43821, 51731];

  /// Opens the given URL in the user's default web browser
  Future<bool> launchBrowserUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (ok) return true;
      }
    } catch (_) {}

    // Desktop process fallback
    try {
      if (Platform.isWindows) {
        // rundll32 url.dll,FileProtocolHandler reliably opens any URL in default Windows browser
        final res = await Process.run('rundll32', ['url.dll,FileProtocolHandler', url]);
        if (res.exitCode == 0) return true;
        await Process.run('powershell', ['-NoProfile', '-Command', 'Start-Process', '"$url"']);
        return true;
      } else if (Platform.isMacOS) {
        await Process.run('open', [url]);
        return true;
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [url]);
        return true;
      }
    } catch (_) {}

    return false;
  }

  /// Generates a cryptographically random PKCE code verifier (43-128 chars)
  String _generateCodeVerifier() {
    final random = Random.secure();
    final values = List<int>.generate(64, (i) => random.nextInt(256));
    return base64UrlEncode(values).replaceAll('=', '');
  }

  /// Generates PKCE code challenge from verifier using SHA-256
  String _generateCodeChallenge(String verifier) {
    final bytes = ascii.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  /// Starts a temporary local HTTP loopback server to intercept the OAuth callback
  Future<Map<String, dynamic>?> _listenForOAuthCallback(int port, String platformName) async {
    HttpServer? server;
    try {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    } catch (_) {
      for (final fallbackPort in _allowedPorts) {
        if (fallbackPort == port) continue;
        try {
          server = await HttpServer.bind(InternetAddress.loopbackIPv4, fallbackPort);
          break;
        } catch (_) {}
      }
    }

    if (server == null) return null;

    final completer = Completer<Map<String, dynamic>?>();

    final sub = server.listen((HttpRequest request) async {
      final uri = request.uri;
      if (uri.path == '/callback' || uri.path == '/') {
        final params = uri.queryParameters;

        request.response.headers.contentType = ContentType.html;
        request.response.write(_buildSuccessHtml(platformName));
        await request.response.close();

        if (!completer.isCompleted) {
          completer.complete(params);
        }
      } else {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    });

    // 2-minute timeout for browser authorization
    Timer(const Duration(minutes: 2), () {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    });

    final result = await completer.future;
    await sub.cancel();
    await server.close(force: true);
    return result;
  }

  /// Primary Zero-Config Interactive Browser Login for YouTube Music.
  /// Redirects directly to Google / YouTube Music sign-in and captures
  /// session internally without requiring developer credentials or manual cookies.
  Future<StreamingAuthResult> signInWithYouTubeWeb(BuildContext context) async {
    final session = await WebViewAuthBridge().authenticateYouTubeMusic(context);
    if (!session.isSuccess ||
        (session.sapisid == null && session.cookieHeader == null)) {
      return StreamingAuthResult(
        isSuccess: false,
        platform: 'YouTube Music',
        errorMessage: session.isBlockedByGoogleWebView
            ? session.errorMessage
            : (session.isCancelled
                ? 'YouTube Music sign-in was cancelled.'
                : (session.errorMessage ?? 'Unable to connect YouTube Music.')),
      );
    }

    if (session.cookieHeader != null && session.cookieHeader!.isNotEmpty) {
      await _prefs.saveYtCookie(
        InnerTubeMusicProvider.sanitizeHeaderValue(session.cookieHeader!),
      );
    }
    if (session.sapisid != null && session.sapisid!.isNotEmpty) {
      await _prefs.saveYtSapisid(
        InnerTubeMusicProvider.sanitizeHeaderValue(session.sapisid!),
      );
    }
    if (session.ytAuthUser != null && session.ytAuthUser!.isNotEmpty) {
      await _prefs.saveYtAuthUser(session.ytAuthUser!);
    }

    return syncYouTubeInnerTubeAccount();
  }

  /// Synchronizes profile, personal playlists, and liked songs from YouTube Music InnerTube
  /// and hidden WebView2 session (when HttpOnly Google cookies are required on Windows).
  Future<StreamingAuthResult> syncYouTubeInnerTubeAccount() async {
    final ytProvider = InnerTubeMusicProvider(prefs: _prefs, dio: _dio);

    String displayName = 'YouTube Music Listener';
    String? avatarUrl;
    var playlists = <Playlist>[];
    var liked = <Track>[];
    final wvPlaylistTracks = <String, List<Track>>{};

    try {
      final profile = await ytProvider.fetchUserProfile();
      if (profile['displayName'] != null && profile['displayName']!.isNotEmpty) {
        displayName = profile['displayName']!;
      }
      avatarUrl = profile['avatarUrl'];
      playlists = await ytProvider.fetchUserPlaylists();
      liked = await ytProvider.fetchLikedTracks();
    } catch (_) {}

    // On Windows desktop, Edge WebView2 owns live HttpOnly Google cookies cleanly inside the saved profile.
    if (playlists.isEmpty ||
        liked.isEmpty ||
        displayName == 'YouTube Music Listener') {
      final wvSession = await WebViewAuthBridge().syncYouTubeLibraryViaWebView();
      if (wvSession != null && wvSession.isSuccess) {
        if (wvSession.ytDisplayName != null &&
            wvSession.ytDisplayName!.isNotEmpty) {
          displayName = wvSession.ytDisplayName!;
        }
        if (wvSession.ytAvatarUrl != null && wvSession.ytAvatarUrl!.isNotEmpty) {
          avatarUrl = wvSession.ytAvatarUrl;
        }
        if (wvSession.ytPlaylists.isNotEmpty) {
          playlists = InnerTubeMusicProvider.playlistsFromWebViewMaps(
            wvSession.ytPlaylists,
          );
        }
        if (wvSession.ytLikedTracks.isNotEmpty) {
          liked = InnerTubeMusicProvider.tracksFromWebViewMaps(
            wvSession.ytLikedTracks,
            isFavorite: true,
          );
        }
        for (final entry in wvSession.ytPlaylistTracks.entries) {
          if (entry.value.isNotEmpty) {
            wvPlaylistTracks[entry.key] =
                InnerTubeMusicProvider.tracksFromWebViewMaps(entry.value);
          }
        }
        if (wvSession.cookieHeader != null &&
            wvSession.cookieHeader!.isNotEmpty) {
          await _prefs.saveYtCookie(
            InnerTubeMusicProvider.sanitizeHeaderValue(wvSession.cookieHeader!),
          );
        }
        if (wvSession.sapisid != null && wvSession.sapisid!.isNotEmpty) {
          await _prefs.saveYtSapisid(
            InnerTubeMusicProvider.sanitizeHeaderValue(wvSession.sapisid!),
          );
        }
        if (wvSession.ytAuthUser != null && wvSession.ytAuthUser!.isNotEmpty) {
          await _prefs.saveYtAuthUser(wvSession.ytAuthUser!);
        }
      }
    }

    await _prefs.saveYtUserProfile(displayName, avatarUrl);
    await _prefs.saveActiveSource('youtube');

    int tracksCount = 0;
    final hydratedPlaylists = <Playlist>[];

    for (final pl in playlists.take(15)) {
      final tracks =
          wvPlaylistTracks[pl.id] ?? await ytProvider.fetchPlaylistTracks(pl.id);
      if (tracks.isNotEmpty) {
        tracksCount += tracks.length;
        await _db.saveTracks(tracks);
        await _db.setPlaylist(
          pl.title,
          tracks.map((t) => t.id).toList(),
        );
        hydratedPlaylists.add(
          pl.copyWith(tracks: tracks, trackCount: tracks.length),
        );
      } else {
        hydratedPlaylists.add(pl);
      }
    }
    if (playlists.length > 15) {
      hydratedPlaylists.addAll(playlists.skip(15));
    }

    if (hydratedPlaylists.isNotEmpty) {
      await _savePlaylistsCache(_prefs, hydratedPlaylists, isSpotify: false);
    }

    if (liked.isNotEmpty) {
      await _db.saveTracks(liked);
      for (final t in liked) {
        if (!_db.isFavorite(t.id)) {
          await _db.toggleFavorite(t.id);
        }
      }
      tracksCount += liked.length;
    }

    return StreamingAuthResult(
      isSuccess: true,
      platform: 'YouTube Music',
      displayName: displayName,
      avatarUrl: avatarUrl,
      subscription: 'YouTube Music Ad-Free Sync',
      playlistsImported: hydratedPlaylists.length,
      tracksImported: tracksCount,
    );
  }

  /// Primary Zero-Config Interactive Browser Login for Spotify.
  /// Redirects directly to Spotify login, captures Web Player session + live library,
  /// and synchronizes cleanly without triggering REST 429 failures.
  Future<StreamingAuthResult> signInWithSpotifyWeb(BuildContext context) async {
    final session = await WebViewAuthBridge().authenticateSpotify(context);
    if (!session.isSuccess ||
        session.spotifyAccessToken == null ||
        session.spotifyAccessToken!.isEmpty) {
      return StreamingAuthResult(
        isSuccess: false,
        platform: 'Spotify',
        errorMessage: session.isCancelled
            ? 'Spotify sign-in was cancelled.'
            : (session.errorMessage ?? 'Unable to connect Spotify.'),
      );
    }

    await _prefs.saveSpotifyAccessToken(session.spotifyAccessToken!);
    if (session.spotifyClientToken != null &&
        session.spotifyClientToken!.isNotEmpty) {
      await _prefs.saveSpotifyClientToken(session.spotifyClientToken!);
    }
    if (session.spotifySpDc != null && session.spotifySpDc!.isNotEmpty) {
      await _prefs.saveSpotifySpDc(session.spotifySpDc!);
    }
    if (session.spotifyPathfinderHashesJson != null &&
        session.spotifyPathfinderHashesJson!.isNotEmpty) {
      await _prefs.saveSpotifyPathfinderHashes(session.spotifyPathfinderHashesJson!);
    }

    int capturedPlaylistsCount = 0;
    int capturedTracksCount = 0;

    // Persist any playlists & liked tracks captured directly from Spotify Web Player in WebView
    if (session.spotifyPlaylists.isNotEmpty) {
      final playlists = SpotifyMusicProvider.playlistsFromWebViewMaps(
        session.spotifyPlaylists,
      );
      capturedPlaylistsCount = playlists.length;
      await _savePlaylistsCache(_prefs, playlists, isSpotify: true);

      for (final pl in playlists) {
        final rawTracks = session.spotifyPlaylistTracks[pl.id];
        if (rawTracks != null && rawTracks.isNotEmpty) {
          final parsed = SpotifyMusicProvider.tracksFromWebViewMaps(rawTracks);
          if (parsed.isNotEmpty) {
            capturedTracksCount += parsed.length;
            await _db.saveTracks(parsed);
            await _db.setPlaylist(pl.title, parsed.map((t) => t.id).toList());
          }
        }
      }
    }

    if (session.spotifyLikedTracks.isNotEmpty) {
      final liked = SpotifyMusicProvider.tracksFromWebViewMaps(
        session.spotifyLikedTracks,
        isFavorite: true,
      );
      if (liked.isNotEmpty) {
        await _db.saveTracks(liked);
        for (final t in liked) {
          if (!_db.isFavorite(t.id)) {
            await _db.toggleFavorite(t.id);
          }
        }
        capturedTracksCount += liked.length;
      }
    }

    return syncSpotifyWithAccessToken(
      session.spotifyAccessToken!,
      fallbackDisplayName: session.spotifyDisplayName,
      fallbackAvatarUrl: session.spotifyAvatarUrl,
      fallbackProduct: session.spotifyProduct,
      seedPlaylistsCount: capturedPlaylistsCount,
      seedTracksCount: capturedTracksCount,
    );
  }

  Future<void> _savePlaylistsCache(
    PreferencesService prefs,
    List<Playlist> playlists, {
    required bool isSpotify,
  }) async {
    final serialized = jsonEncode(
      playlists
          .map((p) => {
                'id': p.id,
                'title': p.title,
                'description': p.description,
                'artworkUrl': p.artworkUrl,
                'trackCount': p.trackCount,
              })
          .toList(),
    );
    if (isSpotify) {
      await prefs.saveSpotifyPlaylistsCache(serialized);
    } else {
      await prefs.saveYtPlaylistsCache(serialized);
    }
  }

  /// Synchronizes Spotify profile, playlists, and liked songs using Pathfinder + 429-safe Web API.
  /// Never fails a valid browser login when Spotify REST `/v1/` applies rate limits (429).
  Future<StreamingAuthResult> syncSpotifyWithAccessToken(
    String accessToken, {
    String? fallbackDisplayName,
    String? fallbackAvatarUrl,
    String? fallbackProduct,
    int seedPlaylistsCount = 0,
    int seedTracksCount = 0,
  }) async {
    final sp = SpotifyMusicProvider(prefs: _prefs, dio: _dio);

    String displayName = (fallbackDisplayName != null &&
            fallbackDisplayName.isNotEmpty)
        ? fallbackDisplayName
        : 'Spotify Listener';
    String? avatarUrl = fallbackAvatarUrl;
    String product = (fallbackProduct != null && fallbackProduct.isNotEmpty)
        ? fallbackProduct
        : 'SPOTIFY AD-FREE BRIDGE';

    if (fallbackDisplayName == null || fallbackDisplayName.isEmpty) {
      try {
        final profile = await sp.fetchUserProfile();
        if (profile['displayName'] != null &&
            profile['displayName']!.isNotEmpty) {
          displayName = profile['displayName']!;
        }
        if (profile['avatarUrl'] != null &&
            profile['avatarUrl']!.isNotEmpty) {
          avatarUrl = profile['avatarUrl'];
        }
        if (profile['product'] != null && profile['product']!.isNotEmpty) {
          product = profile['product']!;
        }
      } catch (_) {}
    }

    await _prefs.saveSpotifyUserProfile(displayName, avatarUrl, product);
    await _prefs.saveActiveSource('spotify');

    int playlistsCount = seedPlaylistsCount;
    int tracksCount = seedTracksCount;

    try {
      final playlists = await sp.fetchUserPlaylists(allowWebViewFallback: false);
      if (playlists.isNotEmpty) {
        playlistsCount = playlists.length;
        await _savePlaylistsCache(_prefs, playlists, isSpotify: true);

        // Gently hydrate top 5 playlists via Pathfinder/cached API; stop immediately on 429
        for (final pl in playlists.take(5)) {
          if (sp.lastRequestWasRateLimited) break;
          await Future.delayed(const Duration(milliseconds: 120));
          final tracks = await sp.fetchPlaylistTracks(
            pl.id,
            allowWebViewFallback: false,
          );
          if (tracks.isNotEmpty) {
            await _db.saveTracks(tracks);
            await _db.setPlaylist(
              pl.title,
              tracks.map((x) => x.id).toList(),
            );
            tracksCount += tracks.length;
          }
        }
      }
    } catch (_) {}

    if (seedTracksCount == 0 && !sp.lastRequestWasRateLimited) {
      try {
        final liked = await sp.fetchLikedTracks(allowWebViewFallback: false);
        if (liked.isNotEmpty) {
          await _db.saveTracks(liked);
          for (final track in liked) {
            if (!_db.isFavorite(track.id)) {
              await _db.toggleFavorite(track.id);
            }
          }
          tracksCount += liked.length;
        }
      } catch (_) {}
    }

    return StreamingAuthResult(
      isSuccess: true,
      platform: 'Spotify',
      displayName: displayName,
      avatarUrl: avatarUrl,
      subscription: product,
      playlistsImported: playlistsCount,
      tracksImported: tracksCount,
    );
  }

  /// Interactive Browser SSO Flow for Spotify (Internal/Custom Developer OAuth Fallback)
  Future<StreamingAuthResult> signInWithSpotifyBrowser() async {
    final configuredId = await _prefs.getSpotifyClientId();
    final clientId = (configuredId != null && configuredId.trim().isNotEmpty)
        ? configuredId.trim()
        : _defaultSpotifyClientId;

    if (clientId.isEmpty) {
      return const StreamingAuthResult(
        isSuccess: false,
        platform: 'Spotify',
        errorMessage: 'Spotify Client ID is required. Please enter your Client ID in Settings (create one in 30s at developer.spotify.com/dashboard with redirect: http://127.0.0.1:8888/callback).',
      );
    }

    final verifier = _generateCodeVerifier();
    final challenge = _generateCodeChallenge(verifier);
    const port = 8888;
    final redirectUri = 'http://127.0.0.1:$port/callback';

    final authUrl = Uri.https('accounts.spotify.com', '/authorize', {
      'client_id': clientId,
      'response_type': 'code',
      'redirect_uri': redirectUri,
      'code_challenge_method': 'S256',
      'code_challenge': challenge,
      'scope': 'user-read-private user-read-email playlist-read-private playlist-read-collaborative user-library-read user-top-read',
      'show_dialog': 'true',
    }).toString();

    // 1. Launch browser to official Spotify login
    final launched = await launchBrowserUrl(authUrl);
    if (!launched) {
      return const StreamingAuthResult(
        isSuccess: false,
        platform: 'Spotify',
        errorMessage: 'Unable to launch default web browser.',
      );
    }

    // 2. Wait for browser redirect callback
    final callbackParams = await _listenForOAuthCallback(port, 'Spotify');
    if (callbackParams == null) {
      return const StreamingAuthResult(
        isSuccess: false,
        platform: 'Spotify',
        errorMessage: 'Sign-in was cancelled or timed out in the browser.',
      );
    }

    if (callbackParams.containsKey('error')) {
      return StreamingAuthResult(
        isSuccess: false,
        platform: 'Spotify',
        errorMessage: 'Spotify authentication error: ${callbackParams['error']}',
      );
    }

    final code = callbackParams['code'];
    if (code == null || code.isEmpty) {
      return const StreamingAuthResult(
        isSuccess: false,
        platform: 'Spotify',
        errorMessage: 'No authorization code returned from Spotify.',
      );
    }

    // 3. Exchange code for Access Token
    try {
      final tokenResponse = await _dio.post(
        'https://accounts.spotify.com/api/token',
        data: {
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': redirectUri,
          'client_id': clientId,
          'code_verifier': verifier,
        },
        options: Options(
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        ),
      );

      if (tokenResponse.statusCode != 200 || tokenResponse.data == null) {
        return const StreamingAuthResult(
          isSuccess: false,
          platform: 'Spotify',
          errorMessage: 'Failed to retrieve access token from Spotify.',
        );
      }

      final tokenData = tokenResponse.data as Map<String, dynamic>;
      final accessToken = tokenData['access_token'] as String;

      await _prefs.saveSpotifyClientId(clientId);
      await _prefs.saveSpotifyAccessToken(accessToken);

      // 4. Fetch User Profile (/me)
      final profileRes = await _dio.get(
        'https://api.spotify.com/v1/me',
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );

      String displayName = 'Spotify Listener';
      String? email;
      String? avatarUrl;
      String product = 'Spotify Premium';

      if (profileRes.statusCode == 200 && profileRes.data != null) {
        final profile = profileRes.data as Map<String, dynamic>;
        displayName = profile['display_name'] as String? ?? 'Spotify Listener';
        email = profile['email'] as String?;
        product = (profile['product'] as String? ?? 'premium').toUpperCase();
        final images = profile['images'] as List?;
        if (images != null && images.isNotEmpty) {
          avatarUrl = images[0]['url'] as String?;
        }
      }

      await _prefs.saveSpotifyUserProfile(displayName, avatarUrl, product);
      await _prefs.saveActiveSource('spotify');

      // 5. Synchronize User Playlists into Muxis
      int playlistsCount = 0;
      int tracksCount = 0;

      try {
        final playlistsRes = await _dio.get(
          'https://api.spotify.com/v1/me/playlists',
          queryParameters: {'limit': '50'},
          options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
        );

        if (playlistsRes.statusCode == 200 && playlistsRes.data != null) {
          final items = playlistsRes.data['items'] as List?;
          if (items != null) {
            playlistsCount = items.length;
            for (final pl in items) {
              final plName = pl['name'] as String? ?? 'Spotify Playlist';
              final plId = pl['id'] as String?;

              // Fetch tracks inside this playlist
              if (plId != null) {
                final tracksRes = await _dio.get(
                  'https://api.spotify.com/v1/playlists/$plId/tracks',
                  queryParameters: {'limit': '50'},
                  options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
                );

                if (tracksRes.statusCode == 200 && tracksRes.data != null) {
                  final trackItems = tracksRes.data['items'] as List?;
                  if (trackItems != null) {
                    final importedTracks = <Track>[];
                    for (final item in trackItems) {
                      final t = item['track'];
                      if (t == null) continue;
                      final track = _parseSpotifyTrack(t);
                      importedTracks.add(track);
                      tracksCount++;
                    }
                    await _db.saveTracks(importedTracks);
                    await _db.setPlaylist(
                      plName,
                      importedTracks.map((x) => x.id).toList(),
                    );
                  }
                }
              }
            }
          }
        }
      } catch (_) {}

      // 6. Synchronize User Liked Songs (/me/tracks)
      try {
        final likedRes = await _dio.get(
          'https://api.spotify.com/v1/me/tracks',
          queryParameters: {'limit': '50'},
          options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
        );

        if (likedRes.statusCode == 200 && likedRes.data != null) {
          final items = likedRes.data['items'] as List?;
          if (items != null) {
            final likedTracks = <Track>[];
            for (final item in items) {
              final t = item['track'];
              if (t != null) {
                final track = _parseSpotifyTrack(t, isFavorite: true);
                likedTracks.add(track);
                await _db.toggleFavorite(track.id);
              }
            }
            await _db.saveTracks(likedTracks);
          }
        }
      } catch (_) {}

      return StreamingAuthResult(
        isSuccess: true,
        platform: 'Spotify',
        displayName: displayName,
        email: email,
        avatarUrl: avatarUrl,
        subscription: product,
        playlistsImported: playlistsCount,
        tracksImported: tracksCount,
      );
    } catch (e) {
      return StreamingAuthResult(
        isSuccess: false,
        platform: 'Spotify',
        errorMessage: 'Spotify authorization failed: $e',
      );
    }
  }

  /// Interactive Browser SSO Flow for YouTube Music
  Future<StreamingAuthResult> signInWithYouTubeBrowser() async {
    final configuredId = await _prefs.getGoogleClientId();
    final clientId = (configuredId != null && configuredId.trim().isNotEmpty)
        ? configuredId.trim()
        : _defaultGoogleClientId;

    if (clientId.isEmpty) {
      return const StreamingAuthResult(
        isSuccess: false,
        platform: 'YouTube Music',
        errorMessage: 'Google OAuth Client ID is required for Google SSO. Alternatively, use the instant 1-click Session Cookie / SAPISID option in Settings.',
      );
    }

    final clientSecret = await _prefs.getGoogleClientSecret();
    const port = 8888;
    final redirectUri = 'http://127.0.0.1:$port/callback';

    final authUrl = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'response_type': 'code',
      'scope': 'https://www.googleapis.com/auth/youtube.readonly email profile',
      'access_type': 'offline',
      'prompt': 'consent',
    }).toString();

    // 1. Launch browser to official Google/YouTube sign-in page
    final launched = await launchBrowserUrl(authUrl);
    if (!launched) {
      return const StreamingAuthResult(
        isSuccess: false,
        platform: 'YouTube Music',
        errorMessage: 'Unable to launch default web browser.',
      );
    }

    // 2. Wait for browser redirect callback
    final callbackParams = await _listenForOAuthCallback(port, 'YouTube Music');
    if (callbackParams == null) {
      return const StreamingAuthResult(
        isSuccess: false,
        platform: 'YouTube Music',
        errorMessage: 'Sign-in was cancelled or timed out in the browser.',
      );
    }

    if (callbackParams.containsKey('error')) {
      return StreamingAuthResult(
        isSuccess: false,
        platform: 'YouTube Music',
        errorMessage: 'Google authentication error: ${callbackParams['error']}',
      );
    }

    final code = callbackParams['code'];
    if (code == null || code.isEmpty) {
      return const StreamingAuthResult(
        isSuccess: false,
        platform: 'YouTube Music',
        errorMessage: 'No authorization code received from Google.',
      );
    }

    // 3. Exchange code for Google Access Token
    try {
      final tokenBody = <String, dynamic>{
        'code': code,
        'client_id': clientId,
        'redirect_uri': redirectUri,
        'grant_type': 'authorization_code',
      };
      if (clientSecret != null && clientSecret.isNotEmpty) {
        tokenBody['client_secret'] = clientSecret;
      }

      final tokenRes = await _dio.post(
        'https://oauth2.googleapis.com/token',
        data: tokenBody,
        options: Options(
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        ),
      );

      if (tokenRes.statusCode != 200 || tokenRes.data == null) {
        return const StreamingAuthResult(
          isSuccess: false,
          platform: 'YouTube Music',
          errorMessage: 'Failed to exchange authorization token with Google.',
        );
      }

      final tokenData = tokenRes.data as Map<String, dynamic>;
      final accessToken = tokenData['access_token'] as String;

      // 4. Fetch User Channel Profile
      String displayName = 'YouTube Music Listener';
      String? avatarUrl;

      try {
        final channelRes = await _dio.get(
          'https://www.googleapis.com/youtube/v3/channels',
          queryParameters: {
            'part': 'snippet,contentDetails',
            'mine': 'true',
          },
          options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
        );

        if (channelRes.statusCode == 200 && channelRes.data != null) {
          final items = channelRes.data['items'] as List?;
          if (items != null && items.isNotEmpty) {
            final snippet = items[0]['snippet'] as Map<String, dynamic>?;
            displayName = snippet?['title'] as String? ?? 'YouTube Music Listener';
            avatarUrl = snippet?['thumbnails']?['default']?['url'] as String?;
          }
        }
      } catch (_) {}

      await _prefs.saveYtUserProfile(displayName, avatarUrl);
      await _prefs.saveActiveSource('youtube');

      // 5. Fetch User YouTube Playlists
      int playlistsCount = 0;
      int tracksCount = 0;

      try {
        final playlistsRes = await _dio.get(
          'https://www.googleapis.com/youtube/v3/playlists',
          queryParameters: {
            'part': 'snippet,contentDetails',
            'mine': 'true',
            'maxResults': '50',
          },
          options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
        );

        if (playlistsRes.statusCode == 200 && playlistsRes.data != null) {
          final items = playlistsRes.data['items'] as List?;
          if (items != null) {
            playlistsCount = items.length;
            for (final pl in items) {
              final plTitle = pl['snippet']?['title'] as String? ?? 'YouTube Playlist';
              final plId = pl['id'] as String?;

              if (plId != null) {
                final itemsRes = await _dio.get(
                  'https://www.googleapis.com/youtube/v3/playlistItems',
                  queryParameters: {
                    'part': 'snippet',
                    'playlistId': plId,
                    'maxResults': '50',
                  },
                  options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
                );

                if (itemsRes.statusCode == 200 && itemsRes.data != null) {
                  final trackItems = itemsRes.data['items'] as List?;
                  if (trackItems != null) {
                    final importedTracks = <Track>[];
                    for (final item in trackItems) {
                      final snip = item['snippet'];
                      final videoId = snip?['resourceId']?['videoId'] as String?;
                      final title = snip?['title'] as String?;
                      final artist = snip?['videoOwnerChannelTitle'] as String? ?? 'YouTube Artist';
                      final thumb = snip?['thumbnails']?['high']?['url'] as String? ??
                          snip?['thumbnails']?['default']?['url'] as String?;

                      if (videoId != null && title != null && title != 'Private video') {
                        final track = Track(
                          id: videoId,
                          title: title,
                          artist: artist,
                          album: plTitle,
                          duration: const Duration(minutes: 3, seconds: 30),
                          artworkUrl: thumb,
                          source: MusicSource.youtube,
                          audioFormat: 'AAC 256kbps Ad-Free',
                        );
                        importedTracks.add(track);
                        tracksCount++;
                      }
                    }
                    await _db.saveTracks(importedTracks);
                    await _db.setPlaylist(
                      plTitle,
                      importedTracks.map((x) => x.id).toList(),
                    );
                  }
                }
              }
            }
          }
        }
      } catch (_) {}

      return StreamingAuthResult(
        isSuccess: true,
        platform: 'YouTube Music',
        displayName: displayName,
        avatarUrl: avatarUrl,
        subscription: 'YouTube Music Ad-Free Sync',
        playlistsImported: playlistsCount,
        tracksImported: tracksCount,
      );
    } catch (e) {
      return StreamingAuthResult(
        isSuccess: false,
        platform: 'YouTube Music',
        errorMessage: 'YouTube authentication failed: $e',
      );
    }
  }

  Track _parseSpotifyTrack(Map<String, dynamic> item, {bool isFavorite = false}) {
    final id = item['id'] as String? ?? '';
    final title = item['name'] as String? ?? 'Unknown Title';
    final artistsList = item['artists'] as List?;
    final artist = artistsList != null && artistsList.isNotEmpty
        ? (artistsList[0]['name'] as String? ?? 'Unknown Artist')
        : 'Unknown Artist';
    final albumName = item['album']?['name'] as String? ?? 'Single';
    final durationMs = (item['duration_ms'] as num?)?.toInt() ?? 210000;
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

  String _buildSuccessHtml(String platform) {
    return '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>MUXIS — Connected to $platform</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      background: #090B10;
      color: #FFFFFF;
      font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", "Segoe UI", Roboto, sans-serif;
      display: flex;
      align-items: center;
      justify-content: center;
      min-height: 100vh;
      overflow: hidden;
    }
    .background-aura {
      position: absolute;
      width: 500px;
      height: 500px;
      background: radial-gradient(circle, rgba(0, 242, 254, 0.2) 0%, rgba(127, 0, 255, 0.15) 50%, rgba(9, 11, 16, 0) 70%);
      filter: blur(60px);
      z-index: 1;
    }
    .card {
      position: relative;
      z-index: 2;
      background: rgba(25, 31, 45, 0.75);
      backdrop-filter: blur(30px);
      -webkit-backdrop-filter: blur(30px);
      border: 1px solid rgba(0, 242, 254, 0.35);
      border-radius: 28px;
      padding: 48px 40px;
      max-width: 440px;
      width: 90%;
      text-align: center;
      box-shadow: 0 30px 60px rgba(0, 0, 0, 0.8), 0 0 40px rgba(0, 242, 254, 0.15);
      animation: appear 0.5s cubic-bezier(0.16, 1, 0.3, 1);
    }
    @keyframes appear {
      from { opacity: 0; transform: translateY(20px) scale(0.96); }
      to { opacity: 1; transform: translateY(0) scale(1); }
    }
    .icon-wrapper {
      width: 72px;
      height: 72px;
      border-radius: 50%;
      background: linear-gradient(135deg, rgba(0, 242, 254, 0.2), rgba(127, 0, 255, 0.3));
      border: 1.5px solid rgba(0, 242, 254, 0.5);
      display: inline-flex;
      align-items: center;
      justify-content: center;
      font-size: 36px;
      color: #00F2FE;
      margin-bottom: 24px;
      box-shadow: 0 0 30px rgba(0, 242, 254, 0.3);
    }
    h1 {
      font-size: 24px;
      font-weight: 800;
      letter-spacing: 2px;
      margin-bottom: 10px;
      background: linear-gradient(135deg, #00F2FE 0%, #4FACFE 40%, #7F00FF 80%, #E100FF 100%);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
    }
    p {
      color: #94A3B8;
      font-size: 14px;
      line-height: 1.6;
      margin-bottom: 24px;
    }
    .pill {
      display: inline-block;
      padding: 6px 14px;
      background: rgba(0, 242, 254, 0.1);
      border: 1px solid rgba(0, 242, 254, 0.25);
      border-radius: 12px;
      font-family: monospace;
      font-size: 11px;
      color: #00F2FE;
      letter-spacing: 1px;
    }
  </style>
</head>
<body>
  <div class="background-aura"></div>
  <div class="card">
    <div class="icon-wrapper">&#10003;</div>
    <h1>AUTHENTICATED</h1>
    <p>Your <strong>$platform</strong> account has been successfully linked with <strong>MUXIS</strong>.<br>Your playlists, favorites, and ad-free audio stream are now ready.</p>
    <div class="pill">RETURN TO MUXIS APP</div>
  </div>
  <script>
    setTimeout(() => {
      window.close();
    }, 3500);
  </script>
</body>
</html>''';
  }
}
