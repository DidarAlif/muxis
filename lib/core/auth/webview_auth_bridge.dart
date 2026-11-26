import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../app/theme/muxis_colors.dart';

class WebViewAuthSession {
  final bool isSuccess;
  final bool isCancelled;
  final bool isBlockedByGoogleWebView;
  final String? sapisid;
  final String? cookieHeader;
  final String? ytAuthUser;
  final String? spotifyAccessToken;
  final String? spotifyClientToken;
  final String? spotifySpDc;
  final String? spotifyPathfinderHashesJson;
  final String? spotifyDisplayName;
  final String? spotifyAvatarUrl;
  final String? spotifyProduct;
  final List<Map<String, dynamic>> spotifyPlaylists;
  final List<Map<String, dynamic>> spotifyLikedTracks;
  final Map<String, List<Map<String, dynamic>>> spotifyPlaylistTracks;
  final String? errorMessage;

  const WebViewAuthSession({
    required this.isSuccess,
    this.isCancelled = false,
    this.isBlockedByGoogleWebView = false,
    this.sapisid,
    this.cookieHeader,
    this.ytAuthUser,
    this.spotifyAccessToken,
    this.spotifyClientToken,
    this.spotifySpDc,
    this.spotifyPathfinderHashesJson,
    this.spotifyDisplayName,
    this.spotifyAvatarUrl,
    this.spotifyProduct,
    this.spotifyPlaylists = const [],
    this.spotifyLikedTracks = const [],
    this.spotifyPlaylistTracks = const {},
    this.errorMessage,
  });
}

/// Real interactive web browser redirection bridge for YouTube Music & Spotify.
/// Opens genuine Google / Spotify login portals and captures authenticated
/// sessions & live Spotify Web Player data automatically without developer keys
/// or manual cookie copying.
class WebViewAuthBridge {
  static bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  static bool get _isMobile =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static const String _ytHookScript = r'''
(function() {
  try {
    if (window.__muxisYtHooked) return;
    window.__muxisYtHooked = true;
    window.__muxisYtAuthUser = '0';

    try {
      Object.defineProperty(navigator, 'webdriver', {
        get: function() { return undefined; }
      });
    } catch (_) {}

    const recordAuthUser = function(val) {
      try {
        if (val !== undefined && val !== null && String(val).trim().length > 0) {
          window.__muxisYtAuthUser = String(val).trim();
        }
      } catch (_) {}
    };

    if (typeof window.fetch === 'function') {
      const origFetch = window.fetch;
      window.fetch = function() {
        try {
          const cfg = arguments[1];
          if (cfg && cfg.headers) {
            if (typeof cfg.headers.get === 'function') {
              recordAuthUser(cfg.headers.get('X-Goog-AuthUser') || cfg.headers.get('x-goog-authuser'));
            } else {
              recordAuthUser(cfg.headers['X-Goog-AuthUser'] || cfg.headers['x-goog-authuser']);
            }
          }
        } catch (_) {}
        return origFetch.apply(this, arguments);
      };
    }

    if (typeof XMLHttpRequest !== 'undefined' && XMLHttpRequest.prototype) {
      const origSetHeader = XMLHttpRequest.prototype.setRequestHeader;
      XMLHttpRequest.prototype.setRequestHeader = function(name, value) {
        try {
          if (name && String(name).toLowerCase() === 'x-goog-authuser') {
            recordAuthUser(value);
          }
        } catch (_) {}
        return origSetHeader.apply(this, arguments);
      };
    }

    window.__muxisReadYtState = function() {
      try {
        const href = window.location.href || '';
        const host = window.location.hostname || '';
        let loggedIn = false;
        try {
          if (window.ytcfg && typeof window.ytcfg.get === 'function') {
            loggedIn = Boolean(window.ytcfg.get('LOGGED_IN'));
          }
        } catch (_) {}

        let blocked = false;
        try {
          if (host.indexOf('accounts.google.com') !== -1 && document.body) {
            const txt = (document.body.innerText || '').toLowerCase();
            if (txt.indexOf('browser or app may not be secure') !== -1 ||
                txt.indexOf('disallowed_useragent') !== -1) {
              blocked = true;
            }
          }
        } catch (_) {}

        return JSON.stringify({
          url: href,
          host: host,
          loggedIn: loggedIn,
          authUser: window.__muxisYtAuthUser || '0',
          cookies: document.cookie || '',
          blocked: blocked
        });
      } catch (e) {
        return JSON.stringify({
          url: window.location.href || '',
          host: window.location.hostname || '',
          loggedIn: false,
          authUser: '0',
          cookies: '',
          blocked: false
        });
      }
    };
  } catch (_) {}
})();
''';

  static const String _spotifyHookScript = r'''
(function() {
  try {
    if (window.__muxisHooked) return;
    window.__muxisHooked = true;

    window.__muxisSpotifyData = {
      bearer: null,
      clientToken: null,
      appVersion: null,
      hashes: {},
      profile: null,
      playlists: [],
      likedTracks: [],
      playlistTracks: {}
    };

    const st = window.__muxisSpotifyData;

    const recordHeader = function(name, value) {
      try {
        if (!name || !value) return;
        const k = String(name).toLowerCase();
        const v = String(value).trim();
        if (k === 'authorization' && v.indexOf('Bearer ') === 0 && v.length > 24) {
          st.bearer = v.substring(7).trim();
        } else if (k === 'client-token' && v.length > 10) {
          st.clientToken = v;
        } else if (k === 'spotify-app-version' && v.length > 0) {
          st.appVersion = v;
        }
      } catch (_) {}
    };

    const extractIdFromUri = function(uri, prefix) {
      if (!uri || typeof uri !== 'string') return '';
      const idx = uri.lastIndexOf(':');
      return idx >= 0 ? uri.substring(idx + 1) : uri;
    };

    const pickLargestImg = function(sources) {
      if (!Array.isArray(sources) || sources.length === 0) return null;
      let best = sources[0];
      for (let i = 0; i < sources.length; i++) {
        if ((sources[i].width || 0) >= (best.width || 0)) best = sources[i];
      }
      return best && best.url ? best.url : null;
    };

    const normalizeTrackNode = function(rawNode, isFavorite) {
      try {
        const t = (rawNode && (rawNode.trackV2 && rawNode.trackV2.data ? rawNode.trackV2.data : rawNode.trackV2)) ||
                  (rawNode && rawNode.data && rawNode.data.__typename && rawNode.data.__typename.indexOf('Track') !== -1 ? rawNode.data : null) ||
                  rawNode;
        if (!t) return null;
        const tr = (t.data && t.data.name) ? t.data : t;
        const name = tr.name;
        const uri = tr.uri || (rawNode && rawNode._uri) || '';
        if (!name) return null;
        const id = extractIdFromUri(uri) || name;

        let artist = 'Unknown Artist';
        const artItems = (tr.artists && tr.artists.items) ||
                         (tr.firstArtist && tr.firstArtist.items) || [];
        if (Array.isArray(artItems) && artItems.length > 0) {
          const names = artItems.map(function(a) {
            return (a.profile && a.profile.name) || a.name || '';
          }).filter(Boolean);
          if (names.length > 0) artist = names.join(', ');
        }

        const alb = (tr.albumOfTrack) || (tr.albumV2 && tr.albumV2.data) || (tr.album) || {};
        const albumName = alb.name || 'Single';
        const artUrl = pickLargestImg((alb.coverArt && alb.coverArt.sources) || alb.images || []);
        const durMs = (tr.duration && tr.duration.totalMilliseconds) ||
                      (tr.trackDuration && tr.trackDuration.totalMilliseconds) ||
                      tr.duration_ms || 200000;

        return {
          id: String(id),
          title: String(name),
          artist: String(artist),
          album: String(albumName),
          durationMs: Number(durMs) || 200000,
          artworkUrl: artUrl,
          isFavorite: Boolean(isFavorite)
        };
      } catch (_) {
        return null;
      }
    };

    const mergePlaylists = function(newPls) {
      if (!Array.isArray(newPls) || newPls.length === 0) return;
      const byId = {};
      for (let i = 0; i < st.playlists.length; i++) byId[st.playlists[i].id] = st.playlists[i];
      for (let i = 0; i < newPls.length; i++) byId[newPls[i].id] = newPls[i];
      st.playlists = Object.values(byId);
    };

    const inspectSpotifyResponse = function(url, data) {
      try {
        if (!data || typeof data !== 'object') return;

        // 1. Standard /v1/me profile
        if (url.indexOf('/v1/me') !== -1 && url.indexOf('/playlists') === -1 && url.indexOf('/tracks') === -1 && data.display_name) {
          st.profile = {
            displayName: data.display_name,
            avatarUrl: Array.isArray(data.images) && data.images.length > 0 ? data.images[0].url : null,
            product: data.product ? String(data.product).toUpperCase() : 'SPOTIFY BRIDGE'
          };
        }

        // 2. Pathfinder profileAttributes / accountAttributes
        if (data.data && data.data.me) {
          const me = data.data.me;
          if (me.profile && (me.profile.name || me.profile.username)) {
            const p = me.profile;
            st.profile = st.profile || {};
            if (p.name || p.username) st.profile.displayName = p.name || p.username;
            if (p.avatar && p.avatar.sources) {
              const av = pickLargestImg(p.avatar.sources);
              if (av) st.profile.avatarUrl = av;
            }
          }
          if (me.account && me.account.product) {
            st.profile = st.profile || {};
            st.profile.product = String(me.account.product).toUpperCase();
          }

          // 3. Pathfinder libraryV3 (user playlists!)
          const libItems = (me.libraryV3 && me.libraryV3.items) || (me.library && me.library.playlists && me.library.playlists.items);
          if (Array.isArray(libItems) && libItems.length > 0) {
            const extracted = [];
            for (let i = 0; i < libItems.length; i++) {
              const row = libItems[i];
              const item = row && (row.item || row);
              const uri = (item && (item._uri || item.uri)) || (row && row._uri) || '';
              if (uri.indexOf(':playlist:') === -1 && uri.indexOf(':collection') === -1 && !(item && item.__typename && item.__typename.indexOf('Playlist') !== -1)) {
                continue;
              }
              if (uri.indexOf(':collection') !== -1) continue;
              const plData = (item && item.data) || (item && item.playlistV2 && item.playlistV2.data) || item;
              if (!plData || !plData.name) continue;
              const id = extractIdFromUri(uri || plData.uri);
              if (!id) continue;
              const imgItems = plData.images && plData.images.items;
              const imgUrl = Array.isArray(imgItems) && imgItems.length > 0
                ? pickLargestImg(imgItems[0].sources || [])
                : null;
              const count = (plData.content && plData.content.totalCount) ||
                            (plData.tracks && plData.tracks.totalCount) || 0;
              extracted.push({
                id: String(id),
                title: String(plData.name),
                description: plData.description || '',
                artworkUrl: imgUrl,
                trackCount: Number(count) || 0
              });
            }
            mergePlaylists(extracted);
          }

          // 4. Pathfinder fetchLibraryTracks (Liked Songs!)
          const likedItems = (me.library && me.library.tracks && me.library.tracks.items) ||
                             (me.libraryV3 && me.libraryV3.likedTracks && me.libraryV3.likedTracks.items);
          if (Array.isArray(likedItems) && likedItems.length > 0) {
            const likedOut = [];
            for (let i = 0; i < likedItems.length; i++) {
              const t = normalizeTrackNode(likedItems[i], true);
              if (t) likedOut.push(t);
            }
            if (likedOut.length > 0) st.likedTracks = likedOut;
          }
        }

        // 5. Pathfinder fetchPlaylist / playlistV2
        if (data.data && data.data.playlistV2) {
          const pv2 = data.data.playlistV2;
          const plId = extractIdFromUri(pv2.uri || '');
          const cItems = (pv2.content && pv2.content.items) || [];
          if (plId && Array.isArray(cItems) && cItems.length > 0) {
            const trOut = [];
            for (let i = 0; i < cItems.length; i++) {
              const row = cItems[i];
              const node = (row && (row.itemV2 || row.item)) || row;
              const t = normalizeTrackNode(node, false);
              if (t) trOut.push(t);
            }
            if (trOut.length > 0) st.playlistTracks[plId] = trOut;
          }
        }

        // 6. Fallback capture if Web Player called /v1/me/playlists or /v1/me/tracks directly
        if (url.indexOf('/v1/me/playlists') !== -1 && Array.isArray(data.items)) {
          const pls = data.items.map(function(pl) {
            return {
              id: String(pl.id || ''),
              title: String(pl.name || 'Spotify Playlist'),
              description: pl.description || '',
              artworkUrl: Array.isArray(pl.images) && pl.images.length > 0 ? pl.images[0].url : null,
              trackCount: (pl.tracks && pl.tracks.total) || 0
            };
          }).filter(function(p) { return p.id.length > 0; });
          mergePlaylists(pls);
        }
        if (url.indexOf('/v1/me/tracks') !== -1 && Array.isArray(data.items)) {
          const trs = data.items.map(function(it) {
            return it && it.track ? normalizeTrackNode(it.track, true) : null;
          }).filter(Boolean);
          if (trs.length > 0) st.likedTracks = trs;
        }
      } catch (_) {}
    };

    if (typeof window.fetch === 'function') {
      const origFetch = window.fetch;
      window.fetch = function() {
        let reqUrl = '';
        try {
          const arg0 = arguments[0];
          const cfg = arguments[1];
          reqUrl = typeof arg0 === 'string' ? arg0 : (arg0 && arg0.url ? arg0.url : '');

          if (cfg && cfg.headers) {
            if (typeof cfg.headers.forEach === 'function') {
              cfg.headers.forEach(function(v, k) { recordHeader(k, v); });
            } else {
              for (const k in cfg.headers) recordHeader(k, cfg.headers[k]);
            }
          }
          if (arg0 && arg0.headers && typeof arg0.headers.forEach === 'function') {
            arg0.headers.forEach(function(v, k) { recordHeader(k, v); });
          }

          if (reqUrl.indexOf('pathfinder') !== -1 && cfg && typeof cfg.body === 'string') {
            try {
              const payload = JSON.parse(cfg.body);
              if (payload && payload.operationName && payload.extensions && payload.extensions.persistedQuery && payload.extensions.persistedQuery.sha256Hash) {
                st.hashes[payload.operationName] = payload.extensions.persistedQuery.sha256Hash;
              }
            } catch (_) {}
          }
        } catch (_) {}

        const promise = origFetch.apply(this, arguments);
        if (reqUrl && (reqUrl.indexOf('api-partner.spotify.com') !== -1 || reqUrl.indexOf('api.spotify.com/v1/') !== -1)) {
          promise.then(function(resp) {
            try {
              if (resp && resp.ok) {
                resp.clone().json().then(function(json) {
                  inspectSpotifyResponse(reqUrl, json);
                }).catch(function() {});
              }
            } catch (_) {}
          }).catch(function() {});
        }
        return promise;
      };
    }

    if (typeof XMLHttpRequest !== 'undefined' && XMLHttpRequest.prototype) {
      const origSetHeader = XMLHttpRequest.prototype.setRequestHeader;
      XMLHttpRequest.prototype.setRequestHeader = function(name, value) {
        recordHeader(name, value);
        return origSetHeader.apply(this, arguments);
      };
    }

    window.__muxisReadSession = function() {
      try {
        let token = st.bearer || null;
        if (!token) {
          const sessionEl = document.getElementById('session');
          if (sessionEl && sessionEl.textContent) {
            const parsed = JSON.parse(sessionEl.textContent);
            if (parsed && parsed.accessToken && parsed.isAnonymous === false) {
              token = parsed.accessToken;
            }
          }
        }
        return JSON.stringify({
          url: window.location.href || '',
          host: window.location.hostname || '',
          token: token,
          clientToken: st.clientToken,
          hashes: st.hashes,
          profile: st.profile,
          playlists: st.playlists,
          likedTracks: st.likedTracks,
          playlistTracks: st.playlistTracks,
          cookies: document.cookie || ''
        });
      } catch (e) {
        return JSON.stringify({ url: window.location.href || '', host: '', token: null });
      }
    };
  } catch (_) {}
})();
''';

  /// Opens genuine Google / YouTube Music login portal inside integrated WebView.
  Future<WebViewAuthSession> authenticateYouTubeMusic(
    BuildContext context,
  ) async {
    const loginUrl =
        'https://accounts.google.com/ServiceLogin?service=youtube&continue=https%3A%2F%2Fmusic.youtube.com%2F&hl=en';

    if (_isDesktop) {
      return _authenticateYouTubeDesktop(loginUrl);
    } else if (_isMobile) {
      return _authenticateYouTubeMobile(context, loginUrl);
    }

    return const WebViewAuthSession(
      isSuccess: false,
      errorMessage: 'Integrated browser sign-in is unsupported on this platform.',
    );
  }

  /// Opens genuine Spotify login portal inside integrated WebView and extracts
  /// live authenticated Web Player Bearer token, client-token, and library data.
  Future<WebViewAuthSession> authenticateSpotify(BuildContext context) async {
    const loginUrl =
        'https://accounts.spotify.com/en/login?continue=https%3A%2F%2Fopen.spotify.com%2F';

    if (_isDesktop) {
      return _authenticateSpotifyDesktop(loginUrl);
    } else if (_isMobile) {
      return _authenticateSpotifyMobile(context, loginUrl);
    }

    return const WebViewAuthSession(
      isSuccess: false,
      errorMessage: 'Integrated browser sign-in is unsupported on this platform.',
    );
  }

  /// Silently refreshes Spotify Web Player token using persisted browser WebView2 session.
  Future<String?> refreshSpotifyTokenSilently() async {
    final session = await syncSpotifyLibraryViaWebView(quickTokenOnly: true);
    return session?.spotifyAccessToken;
  }

  /// Silently runs a hidden Spotify WebView2 sync reusing `muxis_sp_session` cookies
  /// to pull profile, libraryV3 playlists, liked songs, playlist tracks, and fresh tokens
  /// cleanly via Spotify Web Player's own native session without triggering REST 429s.
  Future<WebViewAuthSession?> syncSpotifyLibraryViaWebView({
    String? targetPlaylistId,
    bool quickTokenOnly = false,
  }) async {
    if (!_isDesktop || !Platform.isWindows) return null;
    try {
      if (!await WebviewWindow.isWebviewAvailable()) return null;
      final webview = await WebviewWindow.create(
        configuration: const CreateConfiguration(
          windowWidth: 960,
          windowHeight: 700,
          titleBarHeight: 0,
          title: 'MUXIS Background Sync',
          openHidden: true,
          userDataFolderWindows: 'muxis_sp_session',
        ),
      );

      webview.addScriptToExecuteOnDocumentCreated(_spotifyHookScript);
      final targetUrl = targetPlaylistId != null && targetPlaylistId.isNotEmpty
          ? 'https://open.spotify.com/playlist/$targetPlaylistId'
          : 'https://open.spotify.com/collection/tracks';
      webview.launch(targetUrl);

      final maxTicks = quickTokenOnly ? 10 : 14;
      WebViewAuthSession? captured;
      for (int i = 0; i < maxTicks; i++) {
        await Future.delayed(const Duration(milliseconds: 650));
        final raw = await webview.evaluateJavaScript(
          'window.__muxisReadSession ? window.__muxisReadSession() : null',
        );
        final decoded = _decodeEvalMap(raw);
        if (decoded == null) continue;

        final href = (decoded['url'] as String?) ?? '';
        final host = Uri.tryParse(href)?.host ?? '';
        if (host.contains('accounts.spotify.com')) {
          // User not logged into saved WebView2 profile anymore
          break;
        }

        final token = decoded['token'] as String?;
        if (token == null || token.isEmpty) continue;

        final playlists = _castMapList(decoded['playlists']);
        final liked = _castMapList(decoded['likedTracks']);
        final plTracks = _castPlaylistTracksMap(decoded['playlistTracks']);

        captured = _sessionFromDecodedSpotify(
          decoded: decoded,
          spDc: await _extractSpDcCookie(webview),
        );

        if (quickTokenOnly) break;
        if (targetPlaylistId != null &&
            plTracks.containsKey(targetPlaylistId) &&
            plTracks[targetPlaylistId]!.isNotEmpty) {
          break;
        }
        if (targetPlaylistId == null &&
            playlists.isNotEmpty &&
            liked.isNotEmpty) {
          break;
        }
      }
      webview.close();
      return captured;
    } catch (_) {
      return null;
    }
  }

  /// Clears stored WebView cookies/session cleanly for a single platform.
  Future<void> clearPlatformSession(String platform) async {
    if (!_isDesktop || !Platform.isWindows) return;
    try {
      await WebviewWindow.clearAll(
        userDataFolderWindows:
            platform == 'spotify' ? 'muxis_sp_session' : 'muxis_yt_session',
      );
    } catch (_) {}
  }

  Future<WebViewAuthSession> _authenticateYouTubeDesktop(String loginUrl) async {
    try {
      final available = await WebviewWindow.isWebviewAvailable();
      if (!available) {
        return const WebViewAuthSession(
          isSuccess: false,
          errorMessage:
              'Microsoft Edge WebView2 runtime is not installed. Please use Internal / Advanced Options.',
        );
      }

      final webview = await WebviewWindow.create(
        configuration: const CreateConfiguration(
          windowWidth: 1020,
          windowHeight: 760,
          titleBarHeight: 0,
          title: 'MUXIS — Sign In to YouTube Music',
          userDataFolderWindows: 'muxis_yt_session',
        ),
      );

      final completer = Completer<WebViewAuthSession>();
      bool finished = false;
      bool sawGoogleBlockBanner = false;
      WebViewAuthSession? lastCapturedSession;
      Timer? poller;
      Timer? safetyTimer;

      void completeOnce(WebViewAuthSession res) {
        if (finished) return;
        finished = true;
        poller?.cancel();
        safetyTimer?.cancel();
        if (!completer.isCompleted) {
          completer.complete(res);
        }
      }

      unawaited(
        webview.onClose.then((_) {
          if (lastCapturedSession != null) {
            completeOnce(lastCapturedSession!);
            return;
          }
          if (sawGoogleBlockBanner) {
            completeOnce(
              const WebViewAuthSession(
                isSuccess: false,
                isBlockedByGoogleWebView: true,
                errorMessage:
                    'Google blocked embedded sign-in on this account ("This browser or app may not be secure"). Open Connect YouTube Music -> Internal / Advanced Options to connect via OAuth Keys or Session Cookie.',
              ),
            );
            return;
          }
          completeOnce(
            const WebViewAuthSession(
              isSuccess: false,
              isCancelled: true,
              errorMessage: 'YouTube Music sign-in was cancelled.',
            ),
          );
        }),
      );

      webview.addScriptToExecuteOnDocumentCreated(_ytHookScript);
      webview.launch(loginUrl);

      poller = Timer.periodic(const Duration(milliseconds: 750), (_) async {
        if (finished) return;
        try {
          final rawJson = await webview.evaluateJavaScript(
            'window.__muxisReadYtState ? window.__muxisReadYtState() : JSON.stringify({url: window.location.href, host: window.location.hostname, loggedIn: false})',
          );
          final stateMap = _decodeEvalMap(rawJson);
          final href = (stateMap?['url'] as String?) ?? '';
          final host =
              (stateMap?['host'] as String?) ?? Uri.tryParse(href)?.host ?? '';
          final ytLoggedIn = stateMap?['loggedIn'] == true;
          final authUser = (stateMap?['authUser'] as String?) ?? '0';
          if (stateMap?['blocked'] == true) {
            sawGoogleBlockBanner = true;
          }

          if (host.endsWith('music.youtube.com')) {
            final cookies = await webview.getAllCookies();
            String? sapisid;
            final cookiePairs = <String>[];
            bool hasLoginCookie = false;

            for (final c in cookies) {
              if (c.domain.contains('youtube.com') ||
                  c.domain.contains('google.com')) {
                if (c.value.isNotEmpty) {
                  cookiePairs.add('${c.name}=${c.value}');
                }
                if (c.name == 'SAPISID' && c.value.isNotEmpty) {
                  sapisid = c.value;
                } else if ((c.name == '__Secure-3PAPISID' ||
                        c.name == '__Secure-1PAPISID') &&
                    c.value.isNotEmpty &&
                    (sapisid == null || sapisid.isEmpty)) {
                  sapisid = c.value;
                }
                if (c.name == 'SID' ||
                    c.name == 'HSID' ||
                    c.name == 'SSID' ||
                    c.name == 'APISID' ||
                    c.name == 'SIDCC' ||
                    c.name == 'LOGIN_INFO' ||
                    c.name == '__Secure-1PSID' ||
                    c.name == '__Secure-3PSID') {
                  hasLoginCookie = true;
                }
              }
            }

            if (sapisid != null &&
                sapisid.isNotEmpty &&
                (hasLoginCookie || ytLoggedIn)) {
              final captured = WebViewAuthSession(
                isSuccess: true,
                sapisid: sapisid,
                cookieHeader: cookiePairs.join('; '),
                ytAuthUser: authUser,
              );
              lastCapturedSession = captured;
              webview.close();
              completeOnce(captured);
            }
          }
        } catch (_) {
          // Page transitioning or window closing
        }
      });

      safetyTimer = Timer(const Duration(minutes: 5), () {
        if (!finished) {
          webview.close();
          completeOnce(
            const WebViewAuthSession(
              isSuccess: false,
              isCancelled: true,
              errorMessage: 'YouTube Music sign-in timed out. Please try again.',
            ),
          );
        }
      });

      return await completer.future;
    } catch (e) {
      return WebViewAuthSession(
        isSuccess: false,
        errorMessage: 'Browser sign-in window failed to initialize: $e',
      );
    }
  }

  Future<WebViewAuthSession> _authenticateSpotifyDesktop(String loginUrl) async {
    try {
      final available = await WebviewWindow.isWebviewAvailable();
      if (!available) {
        return const WebViewAuthSession(
          isSuccess: false,
          errorMessage:
              'Microsoft Edge WebView2 runtime is not installed. Please use Internal / Advanced Options.',
        );
      }

      final webview = await WebviewWindow.create(
        configuration: const CreateConfiguration(
          windowWidth: 1020,
          windowHeight: 760,
          titleBarHeight: 0,
          title: 'MUXIS — Sign In to Spotify',
          userDataFolderWindows: 'muxis_sp_session',
        ),
      );

      final completer = Completer<WebViewAuthSession>();
      bool finished = false;
      DateTime? authDetectedAt;
      bool navigatedLiked = false;
      WebViewAuthSession? lastCapturedSession;
      Timer? poller;
      Timer? safetyTimer;

      void completeOnce(WebViewAuthSession res) {
        if (finished) return;
        finished = true;
        poller?.cancel();
        safetyTimer?.cancel();
        if (!completer.isCompleted) {
          completer.complete(res);
        }
      }

      unawaited(
        webview.onClose.then((_) {
          if (lastCapturedSession != null) {
            completeOnce(lastCapturedSession!);
            return;
          }
          completeOnce(
            const WebViewAuthSession(
              isSuccess: false,
              isCancelled: true,
              errorMessage: 'Spotify sign-in was cancelled.',
            ),
          );
        }),
      );

      webview.addScriptToExecuteOnDocumentCreated(_spotifyHookScript);
      webview.launch(loginUrl);

      poller = Timer.periodic(const Duration(milliseconds: 700), (_) async {
        if (finished) return;
        try {
          final rawJson = await webview.evaluateJavaScript(
            'window.__muxisReadSession ? window.__muxisReadSession() : null',
          );
          final sessionMap = _decodeEvalMap(rawJson);
          if (sessionMap == null) return;

          final href = (sessionMap['url'] as String?) ?? '';
          final host =
              (sessionMap['host'] as String?) ?? Uri.tryParse(href)?.host ?? '';
          final bearer = sessionMap['token'] as String?;

          if (host.contains('open.spotify.com') &&
              !host.contains('accounts.spotify.com') &&
              bearer != null &&
              bearer.isNotEmpty) {
            authDetectedAt ??= DateTime.now();
            final spDc = await _extractSpDcCookie(webview);
            final captured = _sessionFromDecodedSpotify(
              decoded: sessionMap,
              spDc: spDc,
            );
            lastCapturedSession = captured;

            final elapsedMs =
                DateTime.now().difference(authDetectedAt!).inMilliseconds;

            // Let Spotify Web Player finish firing libraryV3 + profileAttributes,
            // then briefly visit /collection/tracks so Liked Songs also populate cleanly.
            if (captured.spotifyPlaylists.isNotEmpty &&
                captured.spotifyLikedTracks.isEmpty &&
                !navigatedLiked &&
                elapsedMs >= 1400) {
              navigatedLiked = true;
              webview.launch('https://open.spotify.com/collection/tracks');
              return;
            }

            final readyFull = captured.spotifyPlaylists.isNotEmpty &&
                captured.spotifyLikedTracks.isNotEmpty;
            if (readyFull || elapsedMs >= 4800) {
              webview.close();
              completeOnce(captured);
            }
          }
        } catch (_) {
          // Page transitioning or window closing
        }
      });

      safetyTimer = Timer(const Duration(minutes: 5), () {
        if (!finished) {
          webview.close();
          completeOnce(
            lastCapturedSession ??
                const WebViewAuthSession(
                  isSuccess: false,
                  isCancelled: true,
                  errorMessage: 'Spotify sign-in timed out.',
                ),
          );
        }
      });

      return await completer.future;
    } catch (e) {
      return WebViewAuthSession(
        isSuccess: false,
        errorMessage: 'Spotify browser window failed: $e',
      );
    }
  }

  Future<String?> _extractSpDcCookie(Webview webview) async {
    try {
      final cookies = await webview.getAllCookies();
      for (final c in cookies) {
        if (c.name == 'sp_dc' && c.value.isNotEmpty) {
          return c.value;
        }
      }
    } catch (_) {}
    return null;
  }

  WebViewAuthSession _sessionFromDecodedSpotify({
    required Map<String, dynamic> decoded,
    String? spDc,
  }) {
    final profile = decoded['profile'] is Map
        ? (decoded['profile'] as Map).cast<String, dynamic>()
        : null;
    final hashes = decoded['hashes'] is Map ? decoded['hashes'] : null;

    return WebViewAuthSession(
      isSuccess: true,
      spotifyAccessToken: decoded['token'] as String?,
      spotifyClientToken: decoded['clientToken'] as String?,
      spotifySpDc: spDc,
      spotifyPathfinderHashesJson: hashes != null ? jsonEncode(hashes) : null,
      spotifyDisplayName: profile?['displayName'] as String?,
      spotifyAvatarUrl: profile?['avatarUrl'] as String?,
      spotifyProduct: profile?['product'] as String?,
      spotifyPlaylists: _castMapList(decoded['playlists']),
      spotifyLikedTracks: _castMapList(decoded['likedTracks']),
      spotifyPlaylistTracks: _castPlaylistTracksMap(decoded['playlistTracks']),
    );
  }

  List<Map<String, dynamic>> _castMapList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
  }

  Map<String, List<Map<String, dynamic>>> _castPlaylistTracksMap(dynamic raw) {
    if (raw is! Map) return const {};
    final out = <String, List<Map<String, dynamic>>>{};
    raw.forEach((key, value) {
      if (key != null && value is List) {
        out[key.toString()] = _castMapList(value);
      }
    });
    return out;
  }

  Future<WebViewAuthSession> _authenticateYouTubeMobile(
    BuildContext context,
    String loginUrl,
  ) async {
    return await Navigator.of(context).push<WebViewAuthSession>(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => _MobileWebViewAuthPage(
              title: 'Sign In to YouTube Music',
              initialUrl: loginUrl,
              platform: 'youtube',
              injectedScript: _ytHookScript,
            ),
          ),
        ) ??
        const WebViewAuthSession(
          isSuccess: false,
          isCancelled: true,
          errorMessage: 'YouTube Music sign-in was cancelled.',
        );
  }

  Future<WebViewAuthSession> _authenticateSpotifyMobile(
    BuildContext context,
    String loginUrl,
  ) async {
    return await Navigator.of(context).push<WebViewAuthSession>(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => _MobileWebViewAuthPage(
              title: 'Sign In to Spotify',
              initialUrl: loginUrl,
              platform: 'spotify',
              injectedScript: _spotifyHookScript,
            ),
          ),
        ) ??
        const WebViewAuthSession(
          isSuccess: false,
          isCancelled: true,
          errorMessage: 'Spotify sign-in was cancelled.',
        );
  }

  String? _decodeEvalString(String? raw) {
    if (raw == null || raw.isEmpty || raw == 'null') return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded?.toString();
    } catch (_) {
      return raw;
    }
  }

  Map<String, dynamic>? _decodeEvalMap(String? raw) {
    final s = _decodeEvalString(raw);
    if (s == null || s.isEmpty) return null;
    try {
      final decoded = jsonDecode(s);
      if (decoded is Map) {
        return decoded.cast<String, dynamic>();
      }
    } catch (_) {}
    return null;
  }
}

class _MobileWebViewAuthPage extends StatefulWidget {
  final String title;
  final String initialUrl;
  final String platform;
  final String? injectedScript;

  const _MobileWebViewAuthPage({
    required this.title,
    required this.initialUrl,
    required this.platform,
    this.injectedScript,
  });

  @override
  State<_MobileWebViewAuthPage> createState() => _MobileWebViewAuthPageState();
}

class _MobileWebViewAuthPageState extends State<_MobileWebViewAuthPage> {
  late final WebViewController _controller;
  Timer? _poller;
  bool _completed = false;

  static const String _mobileChromeUa =
      'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(_mobileChromeUa)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (widget.injectedScript != null) {
              _controller.runJavaScript(widget.injectedScript!);
            }
          },
          onPageFinished: (url) {
            if (widget.injectedScript != null) {
              _controller.runJavaScript(widget.injectedScript!);
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.initialUrl));

    _poller = Timer.periodic(
      const Duration(milliseconds: 1100),
      (_) => _checkMobileSession(),
    );
  }

  Future<void> _checkMobileSession() async {
    if (_completed || !mounted) return;
    try {
      final url = await _controller.currentUrl() ?? '';
      final host = Uri.tryParse(url)?.host ?? '';
      if (widget.platform == 'youtube' && host.endsWith('music.youtube.com')) {
        if (widget.injectedScript != null) {
          await _controller.runJavaScript(widget.injectedScript!);
        }
        final rawCookies = await _controller.runJavaScriptReturningResult(
          'document.cookie',
        );
        final cookieStr = rawCookies.toString().replaceAll('"', '');
        final match = RegExp(
          r'(?:SAPISID|__Secure-3PAPISID|__Secure-1PAPISID)=([^;\s]+)',
        ).firstMatch(cookieStr);
        if (match != null && match.group(1) != null) {
          _completed = true;
          _poller?.cancel();
          if (mounted) {
            Navigator.of(context).pop(
              WebViewAuthSession(
                isSuccess: true,
                sapisid: match.group(1)!.trim(),
                cookieHeader: cookieStr,
              ),
            );
          }
        }
      } else if (widget.platform == 'spotify' &&
          host.contains('open.spotify.com') &&
          !host.contains('accounts.spotify.com')) {
        if (widget.injectedScript != null) {
          await _controller.runJavaScript(widget.injectedScript!);
        }
        final raw = await _controller.runJavaScriptReturningResult(
          'window.__muxisReadSession ? window.__muxisReadSession() : ""',
        );
        var str = raw.toString();
        if (str.startsWith('"') && str.endsWith('"')) {
          str = jsonDecode(str).toString();
        }
        if (str.isNotEmpty && str != 'null') {
          final map = jsonDecode(str) as Map<String, dynamic>;
          final token = map['token'] as String?;
          if (token != null && token.isNotEmpty) {
            _completed = true;
            _poller?.cancel();
            if (mounted) {
              Navigator.of(context).pop(
                WebViewAuthSession(
                  isSuccess: true,
                  spotifyAccessToken: token,
                  spotifyClientToken: map['clientToken'] as String?,
                ),
              );
            }
          }
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _poller?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: MuxisColors.surface(isDark),
        foregroundColor: MuxisColors.textPrimary(isDark),
        title: Text(widget.title, style: const TextStyle(fontSize: 16)),
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
