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
  final String? sapisid;
  final String? cookieHeader;
  final String? spotifyAccessToken;
  final String? spotifySpDc;
  final String? errorMessage;

  const WebViewAuthSession({
    required this.isSuccess,
    this.isCancelled = false,
    this.sapisid,
    this.cookieHeader,
    this.spotifyAccessToken,
    this.spotifySpDc,
    this.errorMessage,
  });
}

/// Real interactive web browser redirection bridge for YouTube Music & Spotify.
/// Opens genuine Google / Spotify login portals and captures authenticated
/// sessions automatically without requiring developer portals or manual cookie copy.
class WebViewAuthBridge {
  static bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  static bool get _isMobile =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static const String _spotifyHookScript = r'''
(function() {
  try {
    if (window.__muxisHooked) return;
    window.__muxisHooked = true;

    const recordBearer = function(val) {
      try {
        if (typeof val === 'string' && val.indexOf('Bearer ') === 0 && val.length > 24) {
          window.__muxisSpotifyBearer = val.substring(7).trim();
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
              recordBearer(cfg.headers.get('Authorization') || cfg.headers.get('authorization'));
            } else {
              recordBearer(cfg.headers['Authorization'] || cfg.headers['authorization']);
            }
          }
          if (arguments[0] && arguments[0].headers && typeof arguments[0].headers.get === 'function') {
            recordBearer(arguments[0].headers.get('Authorization') || arguments[0].headers.get('authorization'));
          }
        } catch (_) {}
        return origFetch.apply(this, arguments);
      };
    }

    if (typeof XMLHttpRequest !== 'undefined' && XMLHttpRequest.prototype) {
      const origSetHeader = XMLHttpRequest.prototype.setRequestHeader;
      XMLHttpRequest.prototype.setRequestHeader = function(name, value) {
        try {
          if (name && String(name).toLowerCase() === 'authorization') {
            recordBearer(String(value));
          }
        } catch (_) {}
        return origSetHeader.apply(this, arguments);
      };
    }

    window.__muxisReadSession = function() {
      try {
        let token = window.__muxisSpotifyBearer || null;
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
          url: window.location.href,
          token: token,
          cookies: document.cookie || ''
        });
      } catch (e) {
        return JSON.stringify({ url: window.location.href, token: null, cookies: '' });
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
        'https://accounts.google.com/ServiceLogin?service=youtube&uilel=3&passive=true&continue=https%3A%2F%2Fmusic.youtube.com%2F&hl=en';

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
  /// live authenticated Web Player Bearer token automatically after sign-in.
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

  /// Silently refreshes Spotify Web Player token using saved browser WebView2 session
  Future<String?> refreshSpotifyTokenSilently() async {
    if (!_isDesktop || !Platform.isWindows) return null;
    try {
      if (!await WebviewWindow.isWebviewAvailable()) return null;
      final webview = await WebviewWindow.create(
        configuration: const CreateConfiguration(
          windowWidth: 800,
          windowHeight: 600,
          title: 'MUXIS Background Sync',
          openHidden: true,
          userDataFolderWindows: 'muxis_sp_session',
        ),
      );
      webview.addScriptToExecuteOnDocumentCreated(_spotifyHookScript);
      webview.launch('https://open.spotify.com/');

      for (int i = 0; i < 10; i++) {
        await Future.delayed(const Duration(milliseconds: 900));
        final raw = await webview.evaluateJavaScript(
          'window.__muxisReadSession ? window.__muxisReadSession() : null',
        );
        final decoded = _decodeEvalMap(raw);
        final token = decoded?['token'] as String?;
        if (token != null && token.isNotEmpty) {
          webview.close();
          return token;
        }
      }
      webview.close();
    } catch (_) {}
    return null;
  }

  /// Clears stored WebView cookies/session cleanly for a single platform
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
              'Microsoft Edge WebView2 runtime is not installed. Please use Internal / Advanced Options below.',
        );
      }

      final webview = await WebviewWindow.create(
        configuration: const CreateConfiguration(
          windowWidth: 1020,
          windowHeight: 740,
          title: 'MUXIS — Sign In to YouTube Music',
          userDataFolderWindows: 'muxis_yt_session',
        ),
      );

      final completer = Completer<WebViewAuthSession>();
      bool finished = false;
      Timer? poller;

      void completeOnce(WebViewAuthSession res) {
        if (finished) return;
        finished = true;
        poller?.cancel();
        if (!completer.isCompleted) {
          completer.complete(res);
        }
      }

      unawaited(
        webview.onClose.then((_) {
          completeOnce(
            const WebViewAuthSession(
              isSuccess: false,
              isCancelled: true,
              errorMessage: 'Sign-in window closed before completing authentication.',
            ),
          );
        }),
      );

      webview.launch(loginUrl);

      poller = Timer.periodic(const Duration(milliseconds: 1100), (_) async {
        if (finished) return;
        try {
          final rawHref = await webview.evaluateJavaScript(
            'window.location.href',
          );
          final href = _decodeEvalString(rawHref) ?? '';
          if (href.contains('music.youtube.com') &&
              !href.contains('accounts.google.com') &&
              !href.contains('consent.youtube.com')) {
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
                } else if (c.name == '__Secure-3PAPISID' &&
                    c.value.isNotEmpty &&
                    (sapisid == null || sapisid.isEmpty)) {
                  sapisid = c.value;
                }
                if (c.name == 'SID' ||
                    c.name == 'HSID' ||
                    c.name == 'SSID' ||
                    c.name == 'LOGIN_INFO') {
                  hasLoginCookie = true;
                }
              }
            }

            if (sapisid != null &&
                sapisid.isNotEmpty &&
                hasLoginCookie) {
              final cookieHeader = cookiePairs.join('; ');
              webview.close();
              completeOnce(
                WebViewAuthSession(
                  isSuccess: true,
                  sapisid: sapisid,
                  cookieHeader: cookieHeader,
                ),
              );
            }
          }
        } catch (_) {
          // Page transitioning or window closing
        }
      });

      // 5-minute timeout safety
      Timer(const Duration(minutes: 5), () {
        if (!finished) {
          webview.close();
          completeOnce(
            const WebViewAuthSession(
              isSuccess: false,
              isCancelled: true,
              errorMessage: 'Sign-in timed out. Please try again.',
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
              'Microsoft Edge WebView2 runtime is not installed. Please use Internal / Advanced Options below.',
        );
      }

      final webview = await WebviewWindow.create(
        configuration: const CreateConfiguration(
          windowWidth: 1020,
          windowHeight: 740,
          title: 'MUXIS — Sign In to Spotify',
          userDataFolderWindows: 'muxis_sp_session',
        ),
      );

      final completer = Completer<WebViewAuthSession>();
      bool finished = false;
      Timer? poller;

      void completeOnce(WebViewAuthSession res) {
        if (finished) return;
        finished = true;
        poller?.cancel();
        if (!completer.isCompleted) {
          completer.complete(res);
        }
      }

      unawaited(
        webview.onClose.then((_) {
          completeOnce(
            const WebViewAuthSession(
              isSuccess: false,
              isCancelled: true,
              errorMessage: 'Sign-in window closed before completing authentication.',
            ),
          );
        }),
      );

      webview.addScriptToExecuteOnDocumentCreated(_spotifyHookScript);
      webview.launch(loginUrl);

      poller = Timer.periodic(const Duration(milliseconds: 1100), (_) async {
        if (finished) return;
        try {
          final rawJson = await webview.evaluateJavaScript(
            'window.__muxisReadSession ? window.__muxisReadSession() : null',
          );
          final sessionMap = _decodeEvalMap(rawJson);
          final href = (sessionMap?['url'] as String?) ?? '';
          final bearer = sessionMap?['token'] as String?;

          if (href.contains('open.spotify.com') &&
              !href.contains('accounts.spotify.com')) {
            final cookies = await webview.getAllCookies();
            String? spDc;
            for (final c in cookies) {
              if (c.name == 'sp_dc' && c.value.isNotEmpty) {
                spDc = c.value;
                break;
              }
            }

            if (bearer != null && bearer.isNotEmpty) {
              webview.close();
              completeOnce(
                WebViewAuthSession(
                  isSuccess: true,
                  spotifyAccessToken: bearer,
                  spotifySpDc: spDc,
                ),
              );
            }
          }
        } catch (_) {
          // Page navigating
        }
      });

      Timer(const Duration(minutes: 5), () {
        if (!finished) {
          webview.close();
          completeOnce(
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
            ),
          ),
        ) ??
        const WebViewAuthSession(
          isSuccess: false,
          isCancelled: true,
          errorMessage: 'Sign-in cancelled.',
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
          errorMessage: 'Sign-in cancelled.',
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

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
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
      const Duration(milliseconds: 1200),
      (_) => _checkMobileSession(),
    );
  }

  Future<void> _checkMobileSession() async {
    if (_completed || !mounted) return;
    try {
      final url = await _controller.currentUrl() ?? '';
      if (widget.platform == 'youtube' &&
          url.contains('music.youtube.com') &&
          !url.contains('accounts.google.com')) {
        final rawCookies = await _controller.runJavaScriptReturningResult(
          'document.cookie',
        );
        final cookieStr = rawCookies.toString().replaceAll('"', '');
        final match = RegExp(
          r'(?:SAPISID|__Secure-3PAPISID)=([^;\s]+)',
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
          url.contains('open.spotify.com') &&
          !url.contains('accounts.spotify.com')) {
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
