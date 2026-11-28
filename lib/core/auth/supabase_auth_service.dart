import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../shared/utils/cloud_auth_utils.dart';
import '../config/app_config.dart';
import '../storage/preferences_service.dart';
import 'auth_state.dart';

final authServiceProvider =
    StateNotifierProvider<SupabaseAuthService, AuthState>((ref) {
      return SupabaseAuthService();
    });

/// Primary MUXIS Cloud Authentication Service backed by Cloudflare Workers + D1
/// (`muxis-cloud-db`), providing instant Gmail/Email registration with zero broken
/// confirmation emails, PBKDF2-SHA256 credentials, backup Recovery Keys, and
/// browser Google OAuth across Windows, macOS, Linux, Android, and iOS.
class SupabaseAuthService extends StateNotifier<AuthState>
    with WidgetsBindingObserver {
  static const String _prefTokenKey = 'muxis_cloud_token';
  static const String _prefUserKey = 'muxis_cloud_user_json';
  static const String _prefRecoveryKey = 'muxis_cloud_recovery_key';

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 25),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 20),
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'User-Agent': 'MUXIS/1.2.12 (CloudAuth)',
      },
      validateStatus: (s) => s != null && s < 600,
    ),
  );

  bool _isGooglePollCancelled = false;
  Completer<void>? _resumeCompleter;

  SupabaseAuthService() : super(const AuthState()) {
    WidgetsBinding.instance.addObserver(this);
    init();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState appState) {
    if (appState == AppLifecycleState.resumed) {
      final completer = _resumeCompleter;
      if (completer != null && !completer.isCompleted) {
        completer.complete();
      }
    }
  }

  String get _baseUrl => AppConfig.cloudflareWorkerUrl;

  static bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedToken = prefs.getString(_prefTokenKey);
      final savedUserJson = prefs.getString(_prefUserKey);
      final savedRecovery = prefs.getString(_prefRecoveryKey);
      final customGoogleId = (await PreferencesService().getGoogleClientId())
          ?.trim();
      final hasCustomGoogle =
          customGoogleId != null && customGoogleId.isNotEmpty;

      if (savedToken != null &&
          savedToken.isNotEmpty &&
          savedUserJson != null &&
          savedUserJson.isNotEmpty) {
        try {
          final parsed = jsonDecode(savedUserJson) as Map<String, dynamic>;
          final user = MuxisUser.fromJson(parsed);
          state = state.copyWith(
            status: AuthStatus.authenticated,
            user: user,
            accessToken: savedToken,
            recoveryKey: savedRecovery,
            isCloudAvailable: true,
            hasCustomGoogleClient: hasCustomGoogle,
          );
          unawaited(_verifyAndRefreshSession(savedToken));
        } catch (_) {
          await _clearLocalSession();
          state = state.copyWith(
            status: AuthStatus.unauthenticated,
            isCloudAvailable: true,
            hasCustomGoogleClient: hasCustomGoogle,
          );
        }
      } else {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          isCloudAvailable: AppConfig.isCloudWorkerConfigured,
          hasCustomGoogleClient: hasCustomGoogle,
        );
      }

      unawaited(refreshProviderSettings());
    } catch (_) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        isCloudAvailable: AppConfig.isCloudWorkerConfigured,
      );
    }
  }

  Future<void> _verifyAndRefreshSession(String token) async {
    try {
      final res = await _dio.get<dynamic>(
        '$_baseUrl/api/auth/me',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (res.statusCode == 200 && res.data is Map && res.data['user'] is Map) {
        final user = MuxisUser.fromJson(
          Map<String, dynamic>.from(res.data['user'] as Map),
        );
        await _saveSession(token: token, user: user);
        if (mounted) {
          state = state.copyWith(
            status: AuthStatus.authenticated,
            user: user,
            accessToken: token,
            isCloudAvailable: true,
          );
        }
      } else if (res.statusCode == 401) {
        await signOut();
      }
    } catch (_) {
      // Offline / transient outage: preserve cached session cleanly
    }
  }

  Future<({bool google, bool apple})> refreshProviderSettings() async {
    try {
      final customId = (await PreferencesService().getGoogleClientId())?.trim();
      final hasCustomGoogle = customId != null && customId.isNotEmpty;

      final res = await _dio.get<dynamic>('$_baseUrl/api/auth/config');
      if (res.statusCode == 200 && res.data is Map) {
        final workerGoogle = res.data['google_oauth_enabled'] == true;
        if (mounted) {
          state = state.copyWith(
            errorMessage: state.errorMessage,
            infoMessage: state.infoMessage,
            isCloudAvailable: true,
            isGoogleOAuthEnabled: workerGoogle,
            hasCustomGoogleClient: hasCustomGoogle,
            isAppleOAuthEnabled: false,
          );
        }
        return (google: workerGoogle || hasCustomGoogle, apple: false);
      }
    } catch (_) {}
    return (
      google: state.isGoogleOAuthEnabled || state.hasCustomGoogleClient,
      apple: false,
    );
  }

  void clearMessages() {
    state = state.copyWith(
      errorMessage: null,
      infoMessage: null,
      needsEmailConfirmation: false,
    );
  }

  Future<void> _saveSession({
    required String token,
    required MuxisUser user,
    String? recoveryKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefTokenKey, token);
    await prefs.setString(_prefUserKey, jsonEncode(user.toJson()));
    if (recoveryKey != null && recoveryKey.isNotEmpty) {
      await prefs.setString(_prefRecoveryKey, recoveryKey);
    }
  }

  Future<void> _clearLocalSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefTokenKey);
    await prefs.remove(_prefUserKey);
    await prefs.remove(_prefRecoveryKey);
  }

  /// Instant Gmail / Email Sign-Up backed by Cloudflare D1 (no flaky verification emails).
  Future<bool> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final trimmedEmail = email.trim().toLowerCase();
    final trimmedName = displayName.trim();

    final validationErr = CloudAuthHelper.validateSignup(
      email: email,
      password: password,
    );
    if (validationErr != null) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: validationErr,
      );
      return false;
    }

    state = state.copyWith(
      status: AuthStatus.loading,
      errorMessage: null,
      infoMessage: null,
      needsEmailConfirmation: false,
    );

    try {
      final res = await _dio.post<dynamic>(
        '$_baseUrl/api/auth/register',
        data: {
          'email': trimmedEmail,
          'password': password,
          'display_name': trimmedName,
        },
      );

      if ((res.statusCode == 200 || res.statusCode == 201) &&
          res.data is Map &&
          res.data['access_token'] is String &&
          res.data['user'] is Map) {
        final token = res.data['access_token'] as String;
        final user = MuxisUser.fromJson(
          Map<String, dynamic>.from(res.data['user'] as Map),
        );
        final recoveryKey = res.data['recovery_key'] as String?;

        await _saveSession(token: token, user: user, recoveryKey: recoveryKey);
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
          accessToken: token,
          recoveryKey: recoveryKey,
          isCloudAvailable: true,
          errorMessage: null,
          infoMessage: null,
        );
        return true;
      }

      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: CloudAuthHelper.extractApiErrorMessage(
          res.data,
          res.statusCode,
          fallback: 'Registration could not complete. Please retry.',
        ),
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: CloudAuthHelper.formatNetworkError(
          e,
          fallback: 'Connection error while creating account.',
        ),
      );
      return false;
    }
  }

  /// Instant Gmail / Email Sign-In backed by Cloudflare D1.
  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final trimmedEmail = email.trim().toLowerCase();
    if (trimmedEmail.isEmpty || !trimmedEmail.contains('@')) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Please enter a valid Gmail or email address.',
      );
      return false;
    }
    if (password.isEmpty) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Please enter your password.',
      );
      return false;
    }

    state = state.copyWith(
      status: AuthStatus.loading,
      errorMessage: null,
      infoMessage: null,
      needsEmailConfirmation: false,
    );

    try {
      final res = await _dio.post<dynamic>(
        '$_baseUrl/api/auth/login',
        data: {'email': trimmedEmail, 'password': password},
      );

      if (res.statusCode == 200 &&
          res.data is Map &&
          res.data['access_token'] is String &&
          res.data['user'] is Map) {
        final token = res.data['access_token'] as String;
        final user = MuxisUser.fromJson(
          Map<String, dynamic>.from(res.data['user'] as Map),
        );
        await _saveSession(token: token, user: user);
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
          accessToken: token,
          isCloudAvailable: true,
          errorMessage: null,
          infoMessage: null,
        );
        return true;
      }

      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: CloudAuthHelper.extractApiErrorMessage(
          res.data,
          res.statusCode,
          fallback: 'Invalid email or password.',
        ),
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: CloudAuthHelper.formatNetworkError(
          e,
          fallback: 'Network error during sign-in.',
        ),
      );
      return false;
    }
  }

  /// Instant password reset via personal Backup Recovery Key (`MUXIS-XXXX-XXXX-XXXX`).
  Future<bool> resetPasswordWithRecoveryKey({
    required String email,
    required String recoveryKey,
    required String newPassword,
  }) async {
    final trimmedEmail = email.trim().toLowerCase();
    final cleanKey = CloudAuthHelper.normalizeRecoveryKey(recoveryKey);
    if (!trimmedEmail.contains('@') || cleanKey.length < 10) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Enter your account email and Backup Recovery Key (MUXIS-XXXX-XXXX-XXXX).',
      );
      return false;
    }
    if (newPassword.length < 6) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'New password must be at least 6 characters long.',
      );
      return false;
    }

    state = state.copyWith(
      status: AuthStatus.loading,
      errorMessage: null,
      infoMessage: null,
    );

    try {
      final res = await _dio.post<dynamic>(
        '$_baseUrl/api/auth/reset-password',
        data: {
          'email': trimmedEmail,
          'recovery_key': cleanKey,
          'new_password': newPassword,
        },
      );
      if (res.statusCode == 200 &&
          res.data is Map &&
          res.data['access_token'] is String &&
          res.data['user'] is Map) {
        final token = res.data['access_token'] as String;
        final user = MuxisUser.fromJson(
          Map<String, dynamic>.from(res.data['user'] as Map),
        );
        final nextKey = res.data['recovery_key'] as String?;
        await _saveSession(token: token, user: user, recoveryKey: nextKey);
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
          accessToken: token,
          recoveryKey: nextKey,
          isCloudAvailable: true,
          errorMessage: null,
          infoMessage: null,
        );
        return true;
      }
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: CloudAuthHelper.extractApiErrorMessage(
          res.data,
          res.statusCode,
          fallback: 'Could not reset password.',
        ),
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: CloudAuthHelper.formatNetworkError(
          e,
          fallback: 'Network error resetting password.',
        ),
      );
      return false;
    }
  }

  /// Generates a fresh Backup Recovery Key for the signed-in user.
  Future<String?> regenerateRecoveryKey() async {
    final token = state.accessToken;
    if (token == null || token.isEmpty) return null;
    try {
      final res = await _dio.post<dynamic>(
        '$_baseUrl/api/auth/regenerate-recovery',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (res.statusCode == 200 &&
          res.data is Map &&
          res.data['recovery_key'] is String) {
        final key = res.data['recovery_key'] as String;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefRecoveryKey, key);
        state = state.copyWith(recoveryKey: key);
        return key;
      }
    } catch (_) {}
    return null;
  }

  /// Saves a user-supplied Google OAuth Client ID (and optional secret) right from Cloud Sign-In.
  Future<void> saveCustomGoogleClient(String clientId, [String? secret]) async {
    final prefs = PreferencesService();
    await prefs.saveGoogleClientId(clientId.trim());
    if (secret != null && secret.trim().isNotEmpty) {
      await prefs.saveGoogleClientSecret(secret.trim());
    }
    state = state.copyWith(
      hasCustomGoogleClient: clientId.trim().isNotEmpty,
      errorMessage: null,
      infoMessage: clientId.trim().isNotEmpty
          ? 'Custom Google OAuth Client ID saved! Tap Continue with Google below.'
          : null,
    );
  }

  /// Launches Google OAuth via Worker server flow OR custom user Google OAuth Client ID.
  Future<bool> signInWithGoogle() async {
    final prefs = PreferencesService();
    final customClientId = (await prefs.getGoogleClientId())?.trim() ?? '';
    final customClientSecret =
        (await prefs.getGoogleClientSecret())?.trim() ?? '';

    if (state.isGoogleOAuthEnabled) {
      return _signInGoogleViaWorker();
    }
    if (customClientId.isNotEmpty) {
      return _signInGoogleViaCustomClient(customClientId, customClientSecret);
    }

    final providerState = await refreshProviderSettings();
    if (state.isGoogleOAuthEnabled) {
      return _signInGoogleViaWorker();
    }

    if (!providerState.google) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: 'Google 1-Click OAuth requires Worker configuration (or paste your Google OAuth Client ID below). Use Gmail + Password above for instant signup!',
      );
      return false;
    }
    return false;
  }

  Future<bool> _signInGoogleViaWorker() async {
    _isGooglePollCancelled = false;
    state = state.copyWith(
      status: AuthStatus.loading,
      errorMessage: null,
      infoMessage:
          'Complete Google Sign-In in your browser, then return to MUXIS...',
    );

    try {
      final rnd = Random.secure();
      final pollSecret = base64UrlEncode(
        List<int>.generate(24, (_) => rnd.nextInt(256)),
      ).replaceAll('=', '');

      Response<dynamic>? startRes;
      Object? lastStartErr;
      for (int tryIdx = 0; tryIdx < 2; tryIdx++) {
        try {
          startRes = await _dio.get<dynamic>(
            '$_baseUrl/api/auth/google/start',
            queryParameters: {
              'poll_secret': pollSecret,
              if (!kIsWeb && (Platform.isAndroid || Platform.isIOS))
                'app_redirect': 'muxis://auth-callback',
            },
            options: Options(
              headers: const {'Connection': 'close'},
              receiveTimeout: const Duration(seconds: 25),
            ),
          );
          if (startRes.statusCode == 200) break;
        } catch (e) {
          lastStartErr = e;
          if (tryIdx == 0) {
            await Future<void>.delayed(const Duration(milliseconds: 500));
          }
        }
      }

      if (startRes == null) {
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: CloudAuthHelper.formatNetworkError(
            lastStartErr ?? 'Connection timed out.',
            fallback:
                'Could not start Google Sign-In. Check internet and retry.',
          ),
        );
        return false;
      }

      if (startRes.statusCode != 200 ||
          startRes.data is! Map ||
          startRes.data['auth_url'] is! String) {
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: CloudAuthHelper.extractApiErrorMessage(
            startRes.data,
            startRes.statusCode,
            fallback: 'Unable to initiate Google Sign-In.',
          ),
        );
        return false;
      }

      final authUrl = startRes.data['auth_url'] as String;
      final oauthState = startRes.data['state'] as String;
      final launched = await launchUrl(
        Uri.parse(authUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage:
              'Could not open your system browser for Google Sign-In.',
        );
        return false;
      }

      // Resilient wall-clock poll across Android/iOS background suspension & resume.
      final deadline = DateTime.now().add(const Duration(minutes: 3));
      while (mounted &&
          !_isGooglePollCancelled &&
          DateTime.now().isBefore(deadline)) {
        _resumeCompleter = Completer<void>();
        await Future.any([
          Future<void>.delayed(const Duration(milliseconds: 1400)),
          _resumeCompleter!.future,
        ]);
        if (!mounted || _isGooglePollCancelled) return false;

        try {
          final pollRes = await _dio.post<dynamic>(
            '$_baseUrl/api/auth/google/poll',
            data: {'state': oauthState, 'poll_secret': pollSecret},
            options: Options(
              headers: const {'Connection': 'close'},
              receiveTimeout: const Duration(seconds: 20),
              sendTimeout: const Duration(seconds: 15),
            ),
          );
          if (pollRes.statusCode == 200 && pollRes.data is Map) {
            final status = pollRes.data['status'] as String?;
            if (status == 'complete' &&
                pollRes.data['access_token'] is String &&
                pollRes.data['user'] is Map) {
              final token = pollRes.data['access_token'] as String;
              final user = MuxisUser.fromJson(
                Map<String, dynamic>.from(pollRes.data['user'] as Map),
              );
              await _saveSession(token: token, user: user);
              state = state.copyWith(
                status: AuthStatus.authenticated,
                user: user,
                accessToken: token,
                isCloudAvailable: true,
                errorMessage: null,
                infoMessage: null,
              );
              return true;
            }
            if (status == 'error' || status == 'expired') {
              state = state.copyWith(
                status: AuthStatus.error,
                errorMessage:
                    (pollRes.data['error'] as String?) ??
                    'Google sign-in was cancelled or timed out.',
              );
              return false;
            }
          }
        } catch (_) {
          // Transient timeout / background socket pause while Chrome or Safari is open;
          // continue polling cleanly until completion or deadline.
        }
      }

      if (!_isGooglePollCancelled && mounted) {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          errorMessage: 'Google sign-in timed out. Please try again.',
        );
      }
      return false;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: CloudAuthHelper.formatNetworkError(
          e,
          fallback: 'Google Sign-In encountered a network error.',
        ),
      );
      return false;
    }
  }

  Future<bool> _signInGoogleViaCustomClient(
    String clientId,
    String clientSecret,
  ) async {
    if (!_isDesktop) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: 'On Android, configure GOOGLE_CLIENT_ID / GOOGLE_CLIENT_SECRET on your Cloudflare Worker for 1-Click Google Sign-In, or use Gmail + Password above.',
      );
      return false;
    }

    HttpServer? server;
    state = state.copyWith(
      status: AuthStatus.loading,
      errorMessage: null,
      infoMessage: 'Complete Google Sign-In in your browser...',
    );

    try {
      for (final port in const [8888, 8889, 43821, 51731, 0]) {
        try {
          server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
          break;
        } catch (_) {}
      }
      if (server == null) {
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: 'Unable to bind local callback listener.',
        );
        return false;
      }

      final rnd = Random.secure();
      final verifier = base64UrlEncode(
        List<int>.generate(48, (_) => rnd.nextInt(256)),
      ).replaceAll('=', '');
      final challenge = base64UrlEncode(
        sha256.convert(ascii.encode(verifier)).bytes,
      ).replaceAll('=', '');
      final redirectUri = 'http://localhost:${server.port}/callback';

      final authUri = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
        'client_id': clientId,
        'redirect_uri': redirectUri,
        'response_type': 'code',
        'scope': 'openid email profile',
        'code_challenge': challenge,
        'code_challenge_method': 'S256',
        'prompt': 'select_account',
      });

      final launched = await launchUrl(
        authUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        await server.close(force: true);
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: 'Could not open system browser for Google Sign-In.',
        );
        return false;
      }

      final completer = Completer<String?>();
      late final StreamSubscription<HttpRequest> sub;
      sub = server.listen((request) async {
        if (request.uri.path != '/callback') {
          request.response
            ..statusCode = HttpStatus.notFound
            ..close();
          return;
        }
        final code = request.uri.queryParameters['code'];
        request.response.headers.contentType = ContentType.html;
        request.response.write(
          code != null
              ? '<!DOCTYPE html><html><body style="background:#060910;color:#00FF88;font-family:Segoe UI,sans-serif;display:flex;justify-content:center;align-items:center;height:100vh;"><h2>Google Connected! Return to MUXIS.</h2></body></html>'
              : '<!DOCTYPE html><html><body style="background:#060910;color:#EF4444;font-family:Segoe UI,sans-serif;display:flex;justify-content:center;align-items:center;height:100vh;"><h2>Google Sign-In Cancelled.</h2></body></html>',
        );
        await request.response.close();
        if (!completer.isCompleted) completer.complete(code);
      });

      final code = await completer.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () => null,
      );
      await sub.cancel();
      await server.close(force: true);

      if (code == null || code.isEmpty) {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          errorMessage: 'Google sign-in timed out or was cancelled.',
        );
        return false;
      }

      final tokenResp = await _dio.post<dynamic>(
        'https://oauth2.googleapis.com/token',
        data: {
          'client_id': clientId,
          if (clientSecret.isNotEmpty) 'client_secret': clientSecret,
          'code': code,
          'code_verifier': verifier,
          'grant_type': 'authorization_code',
          'redirect_uri': redirectUri,
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );

      final idToken = tokenResp.data is Map
          ? tokenResp.data['id_token'] as String?
          : null;
      final accessToken = tokenResp.data is Map
          ? tokenResp.data['access_token'] as String?
          : null;
      if (idToken == null && accessToken == null) {
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: 'Google token exchange failed.',
        );
        return false;
      }

      final workerRes = await _dio.post<dynamic>(
        '$_baseUrl/api/auth/google/token',
        data: {
          if (idToken != null) 'id_token': idToken,
          if (accessToken != null) 'access_token': accessToken,
        },
      );
      if (workerRes.statusCode == 200 &&
          workerRes.data is Map &&
          workerRes.data['access_token'] is String &&
          workerRes.data['user'] is Map) {
        final token = workerRes.data['access_token'] as String;
        final user = MuxisUser.fromJson(
          Map<String, dynamic>.from(workerRes.data['user'] as Map),
        );
        await _saveSession(token: token, user: user);
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
          accessToken: token,
          isCloudAvailable: true,
        );
        return true;
      }

      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: CloudAuthHelper.extractApiErrorMessage(
          workerRes.data,
          workerRes.statusCode,
        ),
      );
      return false;
    } catch (e) {
      try {
        await server?.close(force: true);
      } catch (_) {}
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Google Sign-In error: $e',
      );
      return false;
    }
  }

  Future<bool> signInWithApple() async {
    state = state.copyWith(
      status: AuthStatus.unauthenticated,
      errorMessage: 'Please sign in using Gmail + Password above.',
    );
    return false;
  }

  Future<void> resendConfirmationEmail([String? overrideEmail]) async {
    state = state.copyWith(
      status: AuthStatus.unauthenticated,
      needsEmailConfirmation: false,
      infoMessage: 'Email confirmation links are no longer needed — sign up or sign in directly above for instant MUXIS Cloud sync!',
    );
  }

  Future<bool> sendPasswordReset(String email) async {
    state = state.copyWith(
      infoMessage: 'Enter your Backup Recovery Key (MUXIS-XXXX-XXXX-XXXX) in the Forgot Password form to reset your password immediately.',
    );
    return true;
  }

  Future<void> signOut() async {
    _isGooglePollCancelled = true;
    await _clearLocalSession();
    state = state.copyWith(
      status: AuthStatus.unauthenticated,
      clearUser: true,
      clearAccessToken: true,
      clearRecoveryKey: true,
      errorMessage: null,
      infoMessage: null,
      needsEmailConfirmation: false,
    );
  }

  Future<bool> deleteAccount() async {
    final token = state.accessToken;
    if (token == null || token.isEmpty) return false;
    try {
      final res = await _dio.delete<dynamic>(
        '$_baseUrl/api/auth/account',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (res.statusCode == 200) {
        await signOut();
        return true;
      }
      state = state.copyWith(
        errorMessage: CloudAuthHelper.extractApiErrorMessage(
          res.data,
          res.statusCode,
          fallback: 'Account deletion failed.',
        ),
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        errorMessage: CloudAuthHelper.formatNetworkError(
          e,
          fallback: 'Account deletion failed.',
        ),
      );
      return false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _isGooglePollCancelled = true;
    final c = _resumeCompleter;
    if (c != null && !c.isCompleted) {
      c.complete();
    }
    super.dispose();
  }
}
