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
  final String? ytDisplayName;
  final String? ytAvatarUrl;
  final List<Map<String, dynamic>> ytPlaylists;
  final List<Map<String, dynamic>> ytLikedTracks;
  final List<Map<String, dynamic>> ytRecommendedTracks;
  final List<Map<String, dynamic>> ytFeaturedSections;
  final Map<String, List<Map<String, dynamic>>> ytPlaylistTracks;
  final String? spotifyAccessToken;
  final String? spotifyClientToken;
  final String? spotifySpDc;
  final String? spotifyPathfinderHashesJson;
  final String? spotifyDisplayName;
  final String? spotifyAvatarUrl;
  final String? spotifyProduct;
  final List<Map<String, dynamic>> spotifyPlaylists;
  final List<Map<String, dynamic>> spotifyLikedTracks;
  final List<Map<String, dynamic>> spotifyFeaturedSections;
  final Map<String, List<Map<String, dynamic>>> spotifyPlaylistTracks;
  final String? scOAuthToken;
  final String? scDisplayName;
  final String? scAvatarUrl;
  final String? errorMessage;

  const WebViewAuthSession({
    required this.isSuccess,
    this.isCancelled = false,
    this.isBlockedByGoogleWebView = false,
    this.sapisid,
    this.cookieHeader,
    this.ytAuthUser,
    this.ytDisplayName,
    this.ytAvatarUrl,
    this.ytPlaylists = const [],
    this.ytLikedTracks = const [],
    this.ytRecommendedTracks = const [],
    this.ytFeaturedSections = const [],
    this.ytPlaylistTracks = const {},
    this.spotifyAccessToken,
    this.spotifyClientToken,
    this.spotifySpDc,
    this.spotifyPathfinderHashesJson,
    this.spotifyDisplayName,
    this.spotifyAvatarUrl,
    this.spotifyProduct,
    this.spotifyPlaylists = const [],
    this.spotifyLikedTracks = const [],
    this.spotifyFeaturedSections = const [],
    this.spotifyPlaylistTracks = const {},
    this.scOAuthToken,
    this.scDisplayName,
    this.scAvatarUrl,
    this.errorMessage,
  });
}

/// Real interactive web browser redirection bridge for YouTube Music & Spotify.
/// Opens genuine Google / Spotify login portals and captures authenticated
/// sessions & live Spotify Web Player data automatically without developer keys
/// or manual cookie copying.
class WebViewAuthBridge {
  static Future<void> _ytProfileLock = Future.value();
  static Future<void> _spProfileLock = Future.value();

  static Future<T> _withProfileLock<T>(
    bool isSpotify,
    Future<T> Function() action,
  ) {
    final prev = isSpotify ? _spProfileLock : _ytProfileLock;
    final completer = Completer<void>();
    if (isSpotify) {
      _spProfileLock = completer.future;
    } else {
      _ytProfileLock = completer.future;
    }

    return prev.catchError((_) {}).then((_) => action()).whenComplete(() {
      if (!completer.isCompleted) completer.complete();
    });
  }

  static String _sanitizeAscii(String raw) {
    return raw
        .replaceAll(RegExp(r'[\r\n\t]+'), ' ')
        .replaceAll(RegExp(r'[^\x20-\x7E]'), '')
        .trim();
  }

  /// Resolves a version-independent WebView2 user-data directory under AppData
  /// on Windows so login sessions persist across app updates (`v1.1.4` -> `v1.1.5+`).
  static String _resolvePersistentSessionDir(String folderName) {
    if (!Platform.isWindows) return folderName;
    try {
      final appData = Platform.environment['APPDATA'];
      if (appData != null && appData.isNotEmpty) {
        final sessionDir = Directory(
          '$appData${Platform.pathSeparator}app.muxis${Platform.pathSeparator}muxis${Platform.pathSeparator}webview_sessions${Platform.pathSeparator}$folderName',
        );
        if (!sessionDir.existsSync()) {
          sessionDir.createSync(recursive: true);
        }
        return sessionDir.path;
      }
    } catch (_) {}
    return folderName;
  }

  /// Merges `document.cookie` and `.youtube.com` HttpOnly jar cookies into a single
  /// deduplicated ASCII `Cookie:` header string without NUL bytes or conflicting duplicates.
  static ({String cookieHeader, String? sapisid, bool hasLoginCookie})
  _buildCleanYouTubeCookieBundle(
    String docCookieStr,
    List<dynamic> jarCookies,
  ) {
    final cookieMap = <String, String>{};

    void putCookie(String rawKey, String rawVal) {
      final k = _sanitizeAscii(rawKey);
      final v = _sanitizeAscii(rawVal);
      if (k.isNotEmpty && v.isNotEmpty) {
        cookieMap[k] = v;
      }
    }

    for (final pair in docCookieStr.split(';')) {
      final idx = pair.indexOf('=');
      if (idx <= 0) continue;
      putCookie(pair.substring(0, idx), pair.substring(idx + 1));
    }

    for (final c in jarCookies) {
      try {
        final domain = c.domain?.toString() ?? '';
        if (domain.contains('youtube.com')) {
          putCookie(c.name?.toString() ?? '', c.value?.toString() ?? '');
        }
      } catch (_) {}
    }

    final sapisid =
        cookieMap['SAPISID'] ??
        cookieMap['__Secure-3PAPISID'] ??
        cookieMap['__Secure-1PAPISID'];

    bool hasLoginCookie = false;
    for (final loginKey in const [
      'SID',
      'HSID',
      'SSID',
      'APISID',
      'SIDCC',
      'LOGIN_INFO',
      '__Secure-1PSID',
      '__Secure-3PSID',
    ]) {
      if ((cookieMap[loginKey] ?? '').isNotEmpty) {
        hasLoginCookie = true;
        break;
      }
    }

    final header = cookieMap.entries
        .map((e) => '${e.key}=${e.value}')
        .join('; ');
    return (
      cookieHeader: header,
      sapisid: sapisid,
      hasLoginCookie: hasLoginCookie,
    );
  }

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
      featuredSections: [],
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

        // 6. Pathfinder Home Shelves (Made For You, Jump back in, Daily Mix, etc.)
        if (data.data && data.data.home && data.data.home.sectionContainer && data.data.home.sectionContainer.sections && Array.isArray(data.data.home.sectionContainer.sections.items)) {
          const homeSecs = [];
          const rawSecs = data.data.home.sectionContainer.sections.items;
          for (let i = 0; i < rawSecs.length; i++) {
            const rs = rawSecs[i];
            const secTitle = (rs.data && rs.data.title && (rs.data.title.transformedLabel || rs.data.title.text)) || '';
            const secItems = (rs.sectionItems && rs.sectionItems.items) || [];
            if (!secTitle || !Array.isArray(secItems) || secItems.length === 0) continue;
            const pls = [];
            const trs = [];
            for (let j = 0; j < secItems.length; j++) {
              const row = secItems[j];
              const content = (row && row.content && row.content.data) || (row && row.content) || row;
              if (!content) continue;
              const uri = (row && row.uri) || content.uri || '';
              const tn = content.__typename || '';
              if (uri.indexOf(':playlist:') !== -1 || tn.indexOf('Playlist') !== -1) {
                const pid = extractIdFromUri(uri);
                const imgItems = content.images && content.images.items;
                const art = Array.isArray(imgItems) && imgItems.length > 0 ? pickLargestImg(imgItems[0].sources || []) : null;
                if (pid && content.name) {
                  pls.push({
                    id: String(pid),
                    title: String(content.name),
                    description: content.description || '',
                    artworkUrl: art,
                    trackCount: (content.content && content.content.totalCount) || 0
                  });
                }
              } else if (uri.indexOf(':track:') !== -1 || tn.indexOf('Track') !== -1) {
                const tr = normalizeTrackNode(content, false);
                if (tr) trs.push(tr);
              }
            }
            if (pls.length > 0 || trs.length > 0) {
              homeSecs.push({
                id: 'sp-wv-' + i,
                title: String(secTitle),
                source: 'spotify',
                playlists: pls,
                tracks: trs
              });
            }
          }
          if (homeSecs.length > 0) st.featuredSections = homeSecs;
        }

        // 7. Fallback capture if Web Player called /v1/me/playlists or /v1/me/tracks directly
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
        // Also scan rendered Spotify Home DOM shelves when GraphQL interception missed cached SSR
        let featuredSections = Array.isArray(st.featuredSections) ? st.featuredSections.slice() : [];
        if (featuredSections.length === 0 && (window.location.pathname === '/' || window.location.pathname === '')) {
          try {
            const shelves = document.querySelectorAll('section[aria-label], section[data-testid="component-shelf"]');
            for (let i = 0; i < shelves.length && featuredSections.length < 8; i++) {
              const sEl = shelves[i];
              const hEl = sEl.querySelector('h2, a[href*="/section/"]');
              const sTitle = (hEl && hEl.textContent) || sEl.getAttribute('aria-label') || '';
              if (!sTitle) continue;
              const links = sEl.querySelectorAll('a[href*="/playlist/"]');
              const pls = [];
              const seenP = {};
              for (let j = 0; j < links.length; j++) {
                const href = links[j].getAttribute('href') || '';
                const m = href.match(/\/playlist\/([A-Za-z0-9]+)/);
                if (!m || seenP[m[1]]) continue;
                seenP[m[1]] = true;
                const card = links[j].closest('[data-testid="card"], .Card, div') || links[j].parentElement;
                const img = card ? card.querySelector('img') : null;
                const tTxt = (links[j].textContent || links[j].getAttribute('title') || '').trim();
                if (tTxt) {
                  pls.push({
                    id: m[1],
                    title: tTxt,
                    artworkUrl: img ? img.src : null,
                    trackCount: 0
                  });
                }
              }
              if (pls.length > 0) {
                featuredSections.push({
                  id: 'sp-dom-' + i,
                  title: sTitle.trim(),
                  source: 'spotify',
                  playlists: pls,
                  tracks: []
                });
              }
            }
          } catch (_) {}
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
          featuredSections: featuredSections,
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
      errorMessage:
          'Integrated browser sign-in is unsupported on this platform.',
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
      errorMessage:
          'Integrated browser sign-in is unsupported on this platform.',
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
    return _withProfileLock<WebViewAuthSession?>(true, () async {
      try {
        if (!await WebviewWindow.isWebviewAvailable()) return null;
        final webview = await WebviewWindow.create(
          configuration: CreateConfiguration(
            windowWidth: 960,
            windowHeight: 700,
            titleBarHeight: 0,
            title: 'MUXIS Background Sync',
            openHidden: true,
            userDataFolderWindows: _resolvePersistentSessionDir(
              'muxis_sp_session',
            ),
          ),
        );

        webview.addScriptToExecuteOnDocumentCreated(_spotifyHookScript);
        final targetUrl =
            targetPlaylistId != null && targetPlaylistId.isNotEmpty
            ? 'https://open.spotify.com/playlist/$targetPlaylistId'
            : 'https://open.spotify.com/';
        webview.launch(targetUrl);

        final maxTicks = quickTokenOnly ? 6 : 12;
        bool navigatedLiked = false;
        WebViewAuthSession? captured;
        for (int i = 0; i < maxTicks; i++) {
          await Future.delayed(const Duration(milliseconds: 450));
          final raw = await webview.evaluateJavaScript(
            'window.__muxisReadSession ? window.__muxisReadSession() : null',
          );
          final decoded = _decodeEvalMap(raw);
          if (decoded == null) continue;

          final href = (decoded['url'] as String?) ?? '';
          final host = Uri.tryParse(href)?.host ?? '';
          if (host.contains('accounts.spotify.com')) {
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
          if (targetPlaylistId == null && !navigatedLiked && i >= 3) {
            navigatedLiked = true;
            if (!href.contains('/collection/tracks')) {
              webview.launch('https://open.spotify.com/collection/tracks');
            }
          }
          if (targetPlaylistId == null && i >= 7 && captured != null) {
            break;
          }
        }
        webview.close();
        await Future.delayed(const Duration(milliseconds: 350));
        return captured;
      } catch (_) {
        return null;
      }
    });
  }

  /// Silently runs a hidden YouTube Music WebView2 sync reusing `muxis_yt_session` cookies
  /// (including HttpOnly SID/__Secure-1PSID/__Secure-3PSID) to fetch genuine profile,
  /// personal playlists, liked tracks, personalized Home picks, or any private playlist.
  Future<WebViewAuthSession?> syncYouTubeLibraryViaWebView({
    String? targetPlaylistId,
  }) async {
    if (!_isDesktop || !Platform.isWindows) return null;
    return _withProfileLock<WebViewAuthSession?>(false, () async {
      try {
        await Future.delayed(const Duration(milliseconds: 350));
        if (!await WebviewWindow.isWebviewAvailable()) return null;
        final webview = await WebviewWindow.create(
          configuration: CreateConfiguration(
            windowWidth: 960,
            windowHeight: 700,
            titleBarHeight: 0,
            title: 'MUXIS YouTube Background Sync',
            openHidden: true,
            userDataFolderWindows: _resolvePersistentSessionDir(
              'muxis_yt_session',
            ),
          ),
        );

        final targetPl = (targetPlaylistId ?? '').replaceAll(
          RegExp(r'[^A-Za-z0-9_-]'),
          '',
        );
        final startUrl = targetPl.isNotEmpty
            ? 'https://music.youtube.com/playlist?list=${targetPl.startsWith('VL') ? targetPl.substring(2) : targetPl}'
            : 'https://music.youtube.com/';
        webview.launch(startUrl);

        final ytSyncBootstrap =
            '''
(function() {
  try {
    if (window.__muxisYtSyncStarted) return JSON.stringify(window.__muxisYtSyncResult || { done: false });
    if (!window.ytcfg || typeof window.ytcfg.get !== 'function') return JSON.stringify({ done: false, waiting: true });
    var loggedIn = Boolean(window.ytcfg.get('LOGGED_IN'));
    if (!loggedIn) return JSON.stringify({ done: false, loggedIn: false });
    window.__muxisYtSyncStarted = true;
    window.__muxisYtSyncResult = { done: false };

    (async function() {
      try {
        var ctx = window.ytcfg.get('INNERTUBE_CONTEXT') || {
          client: { clientName: 'WEB_REMIX', clientVersion: '1.20260114.03.00', hl: 'en', gl: 'US' }
        };
        var apiKey = window.ytcfg.get('INNERTUBE_API_KEY') || '';
        var authUser = String(window.ytcfg.get('SESSION_INDEX') || '0');
        var cookieStr = document.cookie || '';
        var readCookie = function(name) {
          var rx = new RegExp('(?:^|;\\\\s*)' + name.replace(/[.*+?^\${}()|[\\]\\\\]/g, '\\\\\$&') + '=([^;]+)');
          var mm = cookieStr.match(rx);
          return mm ? mm[1] : '';
        };
        var sapisid = readCookie('SAPISID') || readCookie('__Secure-3PAPISID') || readCookie('__Secure-1PAPISID');
        var sapisid1p = readCookie('__Secure-1PAPISID');
        var sapisid3p = readCookie('__Secure-3PAPISID');

        var hdrs = {
          'Content-Type': 'application/json',
          'X-Origin': 'https://music.youtube.com',
          'X-Goog-AuthUser': authUser
        };
        if (ctx && ctx.client && ctx.client.visitorData) {
          hdrs['X-Goog-Visitor-Id'] = ctx.client.visitorData;
        }
        var makeSapisidHash = async function(sid) {
          var ts = Math.floor(Date.now() / 1000);
          var raw = ts + ' ' + sid + ' https://music.youtube.com';
          var buf = await window.crypto.subtle.digest('SHA-1', new TextEncoder().encode(raw));
          var hex = Array.from(new Uint8Array(buf)).map(function(b) { return b.toString(16).padStart(2, '0'); }).join('');
          return ts + '_' + hex;
        };
        if (sapisid) {
          var parts = ['SAPISIDHASH ' + (await makeSapisidHash(sapisid))];
          if (sapisid1p) parts.push('SAPISID1PHASH ' + (await makeSapisidHash(sapisid1p)));
          if (sapisid3p) parts.push('SAPISID3PHASH ' + (await makeSapisidHash(sapisid3p)));
          hdrs['Authorization'] = parts.join(' ');
        }

        var yti = async function(path, payload) {
          var url = 'https://music.youtube.com/youtubei/v1/' + path + (apiKey ? ('?key=' + encodeURIComponent(apiKey)) : '');
          var resp = await fetch(url, {
            method: 'POST',
            credentials: 'include',
            headers: hdrs,
            body: JSON.stringify(Object.assign({ context: ctx }, payload || {}))
          });
          if (!resp.ok) return null;
          return await resp.json();
        };

        var parseDur = function(str) {
          if (!str) return 200000;
          var p = String(str).trim().split(':').map(Number);
          if (p.length === 2 && !isNaN(p[0]) && !isNaN(p[1])) return (p[0] * 60 + p[1]) * 1000;
          if (p.length === 3 && !isNaN(p[0]) && !isNaN(p[1]) && !isNaN(p[2])) return ((p[0] * 3600) + (p[1] * 60) + p[2]) * 1000;
          return 200000;
        };

        var pickThumb = function(tData) {
          if (!tData) return null;
          var list = (tData.musicThumbnailRenderer && tData.musicThumbnailRenderer.thumbnail && tData.musicThumbnailRenderer.thumbnail.thumbnails) ||
                     (tData.croppedSquareThumbnailRenderer && tData.croppedSquareThumbnailRenderer.thumbnail && tData.croppedSquareThumbnailRenderer.thumbnail.thumbnails) ||
                     tData.thumbnails;
          if (Array.isArray(list) && list.length > 0) return list[list.length - 1].url || null;
          return null;
        };

        var isPlId = function(bid) {
          if (!bid || typeof bid !== 'string') return false;
          return bid.indexOf('VL') === 0 || bid.indexOf('PL') === 0 || bid.indexOf('RDCLAK') === 0 || bid === 'LM';
        };

        var extractPlaylists = function(data) {
          var out = [];
          var seen = {};
          var walk = function(n) {
            if (!n || typeof n !== 'object') return;
            if (Array.isArray(n)) { n.forEach(walk); return; }
            if (n.musicTwoRowItemRenderer) {
              var tr = n.musicTwoRowItemRenderer;
              var bid = tr.navigationEndpoint && tr.navigationEndpoint.browseEndpoint && tr.navigationEndpoint.browseEndpoint.browseId;
              var title = tr.title && tr.title.runs && tr.title.runs[0] && tr.title.runs[0].text;
              if (bid && title && !seen[bid] && isPlId(bid)) {
                seen[bid] = true;
                var sub = Array.isArray(tr.subtitle && tr.subtitle.runs) ? tr.subtitle.runs.map(function(r){ return r.text || ''; }).join('') : 'YouTube Music Playlist';
                out.push({ id: bid, title: title, description: sub, artworkUrl: pickThumb(tr.thumbnailRenderer || tr.thumbnail), trackCount: 0 });
              }
            }
            if (n.musicResponsiveListItemRenderer) {
              var rr = n.musicResponsiveListItemRenderer;
              var nb = rr.navigationEndpoint && rr.navigationEndpoint.browseEndpoint && rr.navigationEndpoint.browseEndpoint.browseId;
              var fc = rr.flexColumns && rr.flexColumns[0] && rr.flexColumns[0].musicResponsiveListItemFlexColumnRenderer;
              var rt = fc && fc.text && fc.text.runs && fc.text.runs[0] && fc.text.runs[0].text;
              if (nb && rt && !seen[nb] && isPlId(nb)) {
                seen[nb] = true;
                out.push({ id: nb, title: rt, description: 'YouTube Music Playlist', artworkUrl: pickThumb(rr.thumbnail), trackCount: 0 });
              }
            }
            Object.values(n).forEach(walk);
          };
          walk(data);
          return out;
        };

        var extractTracks = function(data, fav) {
          var out = [];
          var seen = {};
          var walk = function(n) {
            if (!n || typeof n !== 'object') return;
            if (Array.isArray(n)) { n.forEach(walk); return; }
            if (n.musicResponsiveListItemRenderer) {
              try {
                var rr = n.musicResponsiveListItemRenderer;
                var fc = rr.flexColumns || [];
                var c0 = fc[0] && fc[0].musicResponsiveListItemFlexColumnRenderer && fc[0].musicResponsiveListItemFlexColumnRenderer.text && fc[0].musicResponsiveListItemFlexColumnRenderer.text.runs;
                var title = c0 && c0[0] && c0[0].text;
                var vid = (c0 && c0[0] && c0[0].navigationEndpoint && c0[0].navigationEndpoint.watchEndpoint && c0[0].navigationEndpoint.watchEndpoint.videoId) ||
                          (rr.playlistItemData && rr.playlistItemData.videoId) ||
                          (rr.overlay && rr.overlay.musicItemThumbnailOverlayRenderer && rr.overlay.musicItemThumbnailOverlayRenderer.content && rr.overlay.musicItemThumbnailOverlayRenderer.content.musicPlayButtonRenderer && rr.overlay.musicItemThumbnailOverlayRenderer.content.musicPlayButtonRenderer.playNavigationEndpoint && rr.overlay.musicItemThumbnailOverlayRenderer.content.musicPlayButtonRenderer.playNavigationEndpoint.watchEndpoint && rr.overlay.musicItemThumbnailOverlayRenderer.content.musicPlayButtonRenderer.playNavigationEndpoint.watchEndpoint.videoId);
                if (vid && title && !seen[vid]) {
                  seen[vid] = true;
                  var artist = 'YouTube Music';
                  var album = 'YouTube Music';
                  var durMs = 200000;
                  var c1 = fc[1] && fc[1].musicResponsiveListItemFlexColumnRenderer && fc[1].musicResponsiveListItemFlexColumnRenderer.text && fc[1].musicResponsiveListItemFlexColumnRenderer.text.runs;
                  if (Array.isArray(c1)) {
                    var toks = c1.map(function(r){ return (r.text || '').trim(); }).filter(function(s){
                      var lo = s.toLowerCase();
                      return s && s !== '•' && s !== '·' && lo !== 'song' && lo !== 'video' && lo !== 'ep' && lo !== 'single' && lo !== 'album';
                    });
                    if (toks.length && /^\\d+:\\d{2}(:\\d{2})?\$/.test(toks[toks.length - 1])) durMs = parseDur(toks.pop());
                    if (toks.length) artist = toks[0];
                    if (toks.length > 1) album = toks[1];
                  }
                  var fx = rr.fixedColumns && rr.fixedColumns[0] && rr.fixedColumns[0].musicResponsiveListItemFixedColumnRenderer && rr.fixedColumns[0].musicResponsiveListItemFixedColumnRenderer.text && rr.fixedColumns[0].musicResponsiveListItemFixedColumnRenderer.text.runs;
                  if (fx && fx[0] && fx[0].text) durMs = parseDur(fx[0].text);
                  out.push({ id: String(vid), title: String(title), artist: String(artist), album: String(album), durationMs: durMs, artworkUrl: pickThumb(rr.thumbnail), isFavorite: Boolean(fav) });
                }
              } catch (_) {}
            }
            if (n.musicTwoRowItemRenderer) {
              try {
                var tr = n.musicTwoRowItemRenderer;
                var vid2 = (tr.navigationEndpoint && tr.navigationEndpoint.watchEndpoint && tr.navigationEndpoint.watchEndpoint.videoId) ||
                           (tr.thumbnailOverlay && tr.thumbnailOverlay.musicItemThumbnailOverlayRenderer && tr.thumbnailOverlay.musicItemThumbnailOverlayRenderer.content && tr.thumbnailOverlay.musicItemThumbnailOverlayRenderer.content.musicPlayButtonRenderer && tr.thumbnailOverlay.musicItemThumbnailOverlayRenderer.content.musicPlayButtonRenderer.playNavigationEndpoint && tr.thumbnailOverlay.musicItemThumbnailOverlayRenderer.content.musicPlayButtonRenderer.playNavigationEndpoint.watchEndpoint && tr.thumbnailOverlay.musicItemThumbnailOverlayRenderer.content.musicPlayButtonRenderer.playNavigationEndpoint.watchEndpoint.videoId);
                var title2 = tr.title && tr.title.runs && tr.title.runs[0] && tr.title.runs[0].text;
                if (vid2 && title2 && !seen[vid2]) {
                  seen[vid2] = true;
                  var artist2 = 'YouTube Music';
                  var sub = tr.subtitle && tr.subtitle.runs;
                  if (Array.isArray(sub)) {
                    var toks2 = sub.map(function(r){ return (r.text || '').trim(); }).filter(function(s){
                      var lo = s.toLowerCase();
                      return s && s !== '•' && s !== '·' && lo !== 'song' && lo !== 'video';
                    });
                    if (toks2.length) artist2 = toks2[0];
                  }
                  out.push({ id: String(vid2), title: String(title2), artist: String(artist2), album: 'YouTube Music', durationMs: 210000, artworkUrl: pickThumb(tr.thumbnailRenderer || tr.thumbnail), isFavorite: Boolean(fav) });
                }
              } catch (_) {}
            }
            Object.values(n).forEach(walk);
          };
          walk(data);
          return out;
        };

        var findCont = function(n) {
          if (!n || typeof n !== 'object') return null;
          if (Array.isArray(n)) {
            for (var i = 0; i < n.length; i++) {
              var c = findCont(n[i]);
              if (c) return c;
            }
            return null;
          }
          if (n.nextContinuationData && n.nextContinuationData.continuation) return String(n.nextContinuationData.continuation);
          if (n.continuationCommand && n.continuationCommand.token) return String(n.continuationCommand.token);
          var vals = Object.values(n);
          for (var j = 0; j < vals.length; j++) {
            var c2 = findCont(vals[j]);
            if (c2) return c2;
          }
          return null;
        };

        var fetchAllPlaylistTracks = async function(bid, fav, maxPages) {
          var first = await yti('browse', { browseId: bid });
          if (!first) return [];
          var all = extractTracks(first, fav);
          var seenIds = {};
          all.forEach(function(t) { seenIds[t.id] = true; });
          var seenToks = {};
          var cont = findCont(first);
          for (var pg = 1; pg < (maxPages || 4) && cont && !seenToks[cont]; pg++) {
            seenToks[cont] = true;
            var nxt = await yti('browse?continuation=' + encodeURIComponent(cont) + '&type=next', { continuation: cont });
            if (!nxt) break;
            var more = extractTracks(nxt, fav);
            if (!more.length) break;
            more.forEach(function(t) {
              if (!seenIds[t.id]) {
                seenIds[t.id] = true;
                all.push(t);
              }
            });
            cont = findCont(nxt);
          }
          return all;
        };

        var targetPid = '$targetPl';
        if (targetPid) {
          var bid = (targetPid.indexOf('VL') === 0 || targetPid.indexOf('FE') === 0) ? targetPid : ('VL' + targetPid);
          var plTracks = await fetchAllPlaylistTracks(bid, false, 6);
          var plMap = {};
          plMap[targetPid] = plTracks;
          window.__muxisYtSyncResult = { done: true, playlists: [], likedTracks: [], recommendedTracks: [], playlistTracks: plMap, sapisid: sapisid, authUser: authUser, cookies: cookieStr };
          return;
        }

        var results = await Promise.all([
          yti('account/account_menu', {}),
          yti('browse', { browseId: 'FEmusic_liked_playlists' }),
          fetchAllPlaylistTracks('VLLM', true, 4),
          yti('browse', { browseId: 'FEmusic_home' })
        ]);

        var acc = results[0];
        var displayName = null;
        var avatarUrl = null;
        try {
          var hdr = acc.actions[0].openPopupAction.popup.multiPageMenuRenderer.header.activeAccountHeaderRenderer;
          if (hdr.accountName && hdr.accountName.runs && hdr.accountName.runs[0]) displayName = hdr.accountName.runs[0].text;
          var thumbs = hdr.accountPhoto && hdr.accountPhoto.thumbnails;
          if (Array.isArray(thumbs) && thumbs.length) avatarUrl = thumbs[thumbs.length - 1].url;
        } catch (_) {}

        var pls = results[1] ? extractPlaylists(results[1]) : [];
        if (pls.length === 0) {
          var libLanding = await yti('browse', { browseId: 'FEmusic_library_landing' });
          if (libLanding) pls = extractPlaylists(libLanding);
        }
        var liked = Array.isArray(results[2]) ? results[2] : [];
        if (liked.length === 0) {
          liked = await fetchAllPlaylistTracks('FEmusic_liked_videos', true, 4);
        }
        var home = results[3] ? extractTracks(results[3], false) : [];
        if (home.length < 6) {
          var hist = await yti('browse', { browseId: 'FEmusic_history' });
          if (hist) {
            var hTracks = extractTracks(hist, false);
            if (hTracks.length > home.length) home = hTracks;
          }
        }
        if (home.length < 4) {
          var explore = await yti('browse', { browseId: 'FEmusic_explore' });
          if (explore) {
            var exTracks = extractTracks(explore, false);
            if (exTracks.length > home.length) home = exTracks;
          }
        }

        var plTracksMap = {};
        if (pls.length > 0) {
          var topPls = pls.slice(0, 8);
          var plResponses = await Promise.all(topPls.map(function(p) {
            var b = (p.id.indexOf('VL') === 0 || p.id.indexOf('FE') === 0) ? p.id : ('VL' + p.id);
            return fetchAllPlaylistTracks(b, false, 4);
          }));
          for (var j = 0; j < topPls.length; j++) {
            var trList = plResponses[j] || [];
            if (trList.length > 0) {
              plTracksMap[topPls[j].id] = trList;
              topPls[j].trackCount = trList.length;
            }
          }
        }

        window.__muxisYtSyncResult = {
          done: true,
          displayName: displayName,
          avatarUrl: avatarUrl,
          playlists: pls,
          likedTracks: liked,
          recommendedTracks: home,
          playlistTracks: plTracksMap,
          sapisid: sapisid,
          authUser: authUser,
          cookies: cookieStr
        };
      } catch (e) {
        window.__muxisYtSyncResult = { done: true, playlists: [], likedTracks: [], recommendedTracks: [], playlistTracks: {} };
      }
    })();
    return JSON.stringify({ done: false });
  } catch (_) {
    return JSON.stringify({ done: true, playlists: [], likedTracks: [], recommendedTracks: [], playlistTracks: {} });
  }
})()
''';

        WebViewAuthSession? captured;
        for (int i = 0; i < 24; i++) {
          await Future.delayed(const Duration(milliseconds: 500));
          final raw = await webview.evaluateJavaScript(ytSyncBootstrap);
          final decoded = _decodeEvalMap(raw);
          if (decoded == null) continue;
          if (decoded['loggedIn'] == false && i >= 10) {
            break;
          }
          if (decoded['done'] == true) {
            List<dynamic> jarCookies = const [];
            try {
              jarCookies = await webview.getAllCookies();
            } catch (_) {}
            final bundle = _buildCleanYouTubeCookieBundle(
              decoded['cookies']?.toString() ?? '',
              jarCookies,
            );
            final rawSap = _sanitizeAscii(decoded['sapisid']?.toString() ?? '');
            captured = WebViewAuthSession(
              isSuccess: true,
              sapisid: rawSap.isNotEmpty ? rawSap : bundle.sapisid,
              cookieHeader: bundle.cookieHeader,
              ytAuthUser: decoded['authUser']?.toString() ?? '0',
              ytDisplayName: decoded['displayName']?.toString(),
              ytAvatarUrl: decoded['avatarUrl']?.toString(),
              ytPlaylists: _castMapList(decoded['playlists']),
              ytLikedTracks: _castMapList(decoded['likedTracks']),
              ytRecommendedTracks: _castMapList(decoded['recommendedTracks']),
              ytPlaylistTracks: _castPlaylistTracksMap(
                decoded['playlistTracks'],
              ),
            );
            break;
          }
        }
        webview.close();
        await Future.delayed(const Duration(milliseconds: 350));
        return captured;
      } catch (_) {
        return null;
      }
    });
  }

  /// Clears stored WebView cookies/session cleanly for a single platform.
  Future<void> clearPlatformSession(String platform) async {
    if (!_isDesktop || !Platform.isWindows) return;
    final folder = platform == 'spotify'
        ? 'muxis_sp_session'
        : 'muxis_yt_session';
    for (final dir in <String>[_resolvePersistentSessionDir(folder), folder]) {
      try {
        await WebviewWindow.clearAll(userDataFolderWindows: dir);
      } catch (_) {}
    }
  }

  Future<WebViewAuthSession> _authenticateYouTubeDesktop(
    String loginUrl,
  ) async {
    return _withProfileLock<WebViewAuthSession>(false, () async {
      try {
        final available = await WebviewWindow.isWebviewAvailable();
        if (!available) {
          return const WebViewAuthSession(
            isSuccess: false,
            errorMessage: 'Microsoft Edge WebView2 runtime is not installed. Please use Internal / Advanced Options.',
          );
        }

        final webview = await WebviewWindow.create(
          configuration: CreateConfiguration(
            windowWidth: 1020,
            windowHeight: 760,
            titleBarHeight: 0,
            title: 'MUXIS — Sign In to YouTube Music',
            userDataFolderWindows: _resolvePersistentSessionDir(
              'muxis_yt_session',
            ),
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
                  errorMessage: 'Google blocked embedded sign-in on this account ("This browser or app may not be secure"). Open Connect YouTube Music -> Internal / Advanced Options to connect via OAuth Keys or Session Cookie.',
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

        const inlineYtProbe = r'''
(function() {
  try {
    if (window.__muxisReadYtState) return window.__muxisReadYtState();
    var href = window.location.href || '';
    var host = window.location.hostname || '';
    var loggedIn = false;
    try {
      if (window.ytcfg && typeof window.ytcfg.get === 'function') {
        loggedIn = Boolean(window.ytcfg.get('LOGGED_IN'));
      }
    } catch (_) {}
    if (!loggedIn && host.indexOf('music.youtube.com') !== -1 && document.body) {
      var hasAvatar = Boolean(document.querySelector('#avatar-btn, ytmusic-settings-button, img.yt-img-shadow[src*="googleusercontent"], button[aria-label*="Account"]'));
      var hasSignIn = Boolean(document.querySelector('a.sign-in-link, a[href*="accounts.google.com/ServiceLogin"]'));
      if (hasAvatar && !hasSignIn) loggedIn = true;
    }
    var blocked = false;
    if (host.indexOf('accounts.google.com') !== -1 && document.body) {
      var txt = (document.body.innerText || '').toLowerCase();
      if (txt.indexOf('browser or app may not be secure') !== -1 ||
          txt.indexOf('disallowed_useragent') !== -1) {
        blocked = true;
      }
    }
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
})()
''';

        poller = Timer.periodic(const Duration(milliseconds: 550), (_) async {
          if (finished) return;
          try {
            final rawJson = await webview.evaluateJavaScript(inlineYtProbe);
            final stateMap = _decodeEvalMap(rawJson);
            final href = (stateMap?['url'] as String?) ?? '';
            final host =
                (stateMap?['host'] as String?) ??
                Uri.tryParse(href)?.host ??
                '';
            final ytLoggedIn = stateMap?['loggedIn'] == true;
            final authUser = (stateMap?['authUser'] as String?) ?? '0';
            final docCookieStr = (stateMap?['cookies'] as String?) ?? '';
            if (stateMap?['blocked'] == true) {
              sawGoogleBlockBanner = true;
            }

            if (host.endsWith('music.youtube.com')) {
              List<dynamic> jarCookies = const [];
              try {
                jarCookies = await webview.getAllCookies();
              } catch (_) {}
              final bundle = _buildCleanYouTubeCookieBundle(
                docCookieStr,
                jarCookies,
              );
              final sapisid = bundle.sapisid;

              final signedInConfirmed =
                  ((sapisid != null && sapisid.isNotEmpty) &&
                      (bundle.hasLoginCookie || ytLoggedIn)) ||
                  (ytLoggedIn && bundle.cookieHeader.isNotEmpty);

              if (signedInConfirmed) {
                try {
                  await webview.evaluateJavaScript(
                    "document.querySelectorAll('video,audio').forEach(function(m){try{m.pause();m.src='';}catch(_){}});",
                  );
                } catch (_) {}

                final captured = WebViewAuthSession(
                  isSuccess: true,
                  sapisid: sapisid,
                  cookieHeader: bundle.cookieHeader,
                  ytAuthUser: authUser,
                );
                lastCapturedSession = captured;
                webview.close();
                await Future.delayed(const Duration(milliseconds: 350));
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
                errorMessage:
                    'YouTube Music sign-in timed out. Please try again.',
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
    });
  }

  Future<WebViewAuthSession> _authenticateSpotifyDesktop(
    String loginUrl,
  ) async {
    return _withProfileLock<WebViewAuthSession>(true, () async {
      try {
        final available = await WebviewWindow.isWebviewAvailable();
        if (!available) {
          return const WebViewAuthSession(
            isSuccess: false,
            errorMessage: 'Microsoft Edge WebView2 runtime is not installed. Please use Internal / Advanced Options.',
          );
        }

        final webview = await WebviewWindow.create(
          configuration: CreateConfiguration(
            windowWidth: 1020,
            windowHeight: 760,
            titleBarHeight: 0,
            title: 'MUXIS — Sign In to Spotify',
            userDataFolderWindows: _resolvePersistentSessionDir(
              'muxis_sp_session',
            ),
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

        poller = Timer.periodic(const Duration(milliseconds: 450), (_) async {
          if (finished) return;
          try {
            final rawJson = await webview.evaluateJavaScript(
              'window.__muxisReadSession ? window.__muxisReadSession() : null',
            );
            final sessionMap = _decodeEvalMap(rawJson);
            if (sessionMap == null) return;

            final href = (sessionMap['url'] as String?) ?? '';
            final host =
                (sessionMap['host'] as String?) ??
                Uri.tryParse(href)?.host ??
                '';
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

              final elapsedMs = DateTime.now()
                  .difference(authDetectedAt!)
                  .inMilliseconds;

              if (captured.spotifyPlaylists.isNotEmpty &&
                  captured.spotifyLikedTracks.isEmpty &&
                  !navigatedLiked &&
                  elapsedMs >= 750) {
                navigatedLiked = true;
                webview.launch('https://open.spotify.com/collection/tracks');
                return;
              }

              final readyFull =
                  captured.spotifyPlaylists.isNotEmpty &&
                  captured.spotifyLikedTracks.isNotEmpty;
              if (readyFull || elapsedMs >= 3200) {
                webview.close();
                await Future.delayed(const Duration(milliseconds: 350));
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
    });
  }

  Future<String?> _extractSpDcCookie(Webview webview) async {
    try {
      final cookies = await webview.getAllCookies();
      for (final c in cookies) {
        final name = _sanitizeAscii(c.name);
        final val = _sanitizeAscii(c.value);
        if (name == 'sp_dc' && val.isNotEmpty) {
          return val;
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
      spotifyFeaturedSections: _castMapList(decoded['featuredSections']),
      spotifyPlaylistTracks: _castPlaylistTracksMap(decoded['playlistTracks']),
    );
  }

  /// Opens genuine SoundCloud login portal (`https://soundcloud.com/signin`) and
  /// extracts authenticated `oauth_token` cookie cleanly across Desktop WebView2 & Mobile WebView.
  Future<WebViewAuthSession> authenticateSoundCloud(
    BuildContext context,
  ) async {
    const loginUrl = 'https://soundcloud.com/signin';
    if (_isDesktop) {
      return _authenticateSoundCloudDesktop(loginUrl);
    } else if (_isMobile) {
      return _authenticateSoundCloudMobile(context, loginUrl);
    }
    return const WebViewAuthSession(
      isSuccess: false,
      errorMessage:
          'Integrated browser sign-in is unsupported on this platform.',
    );
  }

  Future<WebViewAuthSession> _authenticateSoundCloudDesktop(
    String loginUrl,
  ) async {
    try {
      final available = await WebviewWindow.isWebviewAvailable();
      if (!available) {
        return const WebViewAuthSession(
          isSuccess: false,
          errorMessage: 'Microsoft Edge WebView2 runtime is not installed.',
        );
      }

      final webview = await WebviewWindow.create(
        configuration: CreateConfiguration(
          windowWidth: 1020,
          windowHeight: 760,
          titleBarHeight: 0,
          title: 'MUXIS — Sign In to SoundCloud',
          userDataFolderWindows: _resolvePersistentSessionDir(
            'muxis_sc_session',
          ),
        ),
      );

      final completer = Completer<WebViewAuthSession>();
      bool finished = false;
      WebViewAuthSession? lastCaptured;
      Timer? poller;
      Timer? safetyTimer;

      void completeOnce(WebViewAuthSession res) {
        if (finished) return;
        finished = true;
        poller?.cancel();
        safetyTimer?.cancel();
        if (!completer.isCompleted) completer.complete(res);
      }

      unawaited(
        webview.onClose.then((_) {
          if (lastCaptured != null) {
            completeOnce(lastCaptured!);
            return;
          }
          completeOnce(
            const WebViewAuthSession(
              isSuccess: false,
              isCancelled: true,
              errorMessage: 'SoundCloud sign-in was cancelled.',
            ),
          );
        }),
      );

      webview.launch(loginUrl);

      poller = Timer.periodic(const Duration(milliseconds: 550), (_) async {
        if (finished) return;
        try {
          final rawJson = await webview.evaluateJavaScript('''
(function(){
  try {
    var href = window.location.href || '';
    var btn = document.querySelector('.header__userNavUsernameButton, a[href="/you/library"]');
    var avatar = document.querySelector('.header__userNavItem img, span.sc-artwork[style*="url("]');
    var uname = btn ? (btn.textContent || '').trim() : '';
    return JSON.stringify({
      url: href,
      loggedIn: Boolean(btn) && href.indexOf('/signin') === -1 && href.indexOf('/login') === -1,
      displayName: uname,
      cookies: document.cookie || ''
    });
  } catch (e) { return JSON.stringify({ url: '', loggedIn: false, cookies: '' }); }
})()
''');
          final map = _decodeEvalMap(rawJson);
          if (map == null) return;
          final href = (map['url'] as String?) ?? '';
          final uri = Uri.tryParse(href);
          final onScHome =
              uri != null &&
              uri.host.contains('soundcloud.com') &&
              !uri.path.contains('signin') &&
              !uri.path.contains('login');
          if (!onScHome) return;

          String? oauthToken;
          final docCookies = (map['cookies'] as String?) ?? '';
          final docMatch = RegExp(r'(?:^|;\s*)oauth_token=([^;\s]+)')
              .firstMatch(docCookies);
          if (docMatch != null) {
            oauthToken = _sanitizeAscii(docMatch.group(1) ?? '');
          }
          if (oauthToken == null || oauthToken.isEmpty) {
            try {
              final jarCookies = await webview.getAllCookies();
              for (final c in jarCookies) {
                if (_sanitizeAscii(c.name) == 'oauth_token') {
                  final v = _sanitizeAscii(c.value);
                  if (v.isNotEmpty) {
                    oauthToken = v;
                    break;
                  }
                }
              }
            } catch (_) {}
          }

          if ((oauthToken != null && oauthToken.isNotEmpty) ||
              map['loggedIn'] == true) {
            final name = (map['displayName'] as String?)?.trim();
            final captured = WebViewAuthSession(
              isSuccess: true,
              scOAuthToken: oauthToken,
              scDisplayName: (name != null && name.isNotEmpty)
                  ? name
                  : 'SoundCloud User',
            );
            lastCaptured = captured;
            webview.close();
            await Future.delayed(const Duration(milliseconds: 300));
            completeOnce(captured);
          }
        } catch (_) {}
      });

      safetyTimer = Timer(const Duration(minutes: 5), () {
        if (!finished) {
          webview.close();
          completeOnce(
            const WebViewAuthSession(
              isSuccess: false,
              isCancelled: true,
              errorMessage: 'SoundCloud sign-in timed out.',
            ),
          );
        }
      });

      return await completer.future;
    } catch (e) {
      return WebViewAuthSession(
        isSuccess: false,
        errorMessage: 'SoundCloud browser window failed: $e',
      );
    }
  }

  Future<WebViewAuthSession> _authenticateSoundCloudMobile(
    BuildContext context,
    String loginUrl,
  ) async {
    return await Navigator.of(context).push<WebViewAuthSession>(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => _MobileWebViewAuthPage(
              title: 'Sign In to SoundCloud',
              initialUrl: loginUrl,
              platform: 'soundcloud',
            ),
          ),
        ) ??
        const WebViewAuthSession(
          isSuccess: false,
          isCancelled: true,
          errorMessage: 'SoundCloud sign-in was cancelled.',
        );
  }

  List<Map<String, dynamic>> _castMapList(dynamic raw) {
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
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
      } else if (widget.platform == 'soundcloud' &&
          host.contains('soundcloud.com') &&
          !url.contains('/signin') &&
          !url.contains('/login')) {
        final rawCookies = await _controller.runJavaScriptReturningResult(
          'document.cookie',
        );
        final cookieStr = rawCookies.toString().replaceAll('"', '');
        final tokMatch = RegExp(r'(?:^|;\s*)oauth_token=([^;\s]+)')
            .firstMatch(cookieStr);
        final oauthToken = tokMatch?.group(1)?.trim();
        final loggedRaw = await _controller.runJavaScriptReturningResult(
          "Boolean(document.querySelector('.header__userNavUsernameButton, a[href=\"/you/library\"], a[href*=\"/you\"]'))",
        );
        final domLoggedIn = loggedRaw.toString().contains('true');
        if ((oauthToken != null && oauthToken.isNotEmpty) || domLoggedIn) {
          _completed = true;
          _poller?.cancel();
          if (mounted) {
            Navigator.of(context).pop(
              WebViewAuthSession(
                isSuccess: true,
                scOAuthToken: oauthToken,
                scDisplayName: 'SoundCloud Listener',
              ),
            );
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
