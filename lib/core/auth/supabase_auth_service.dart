import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:url_launcher/url_launcher.dart';

import '../../shared/utils/cloud_auth_utils.dart';
import '../config/app_config.dart';
import 'auth_state.dart';

final authServiceProvider =
    StateNotifierProvider<SupabaseAuthService, AuthState>((ref) {
      return SupabaseAuthService();
    });

class SupabaseAuthService extends StateNotifier<AuthState> {
  SupabaseClient? _client;
  StreamSubscription<dynamic>? _authSub;
  HttpServer? _confirmationServer;
  StreamSubscription<HttpRequest>? _confirmationSub;
  Timer? _confirmationTimer;
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 6),
      receiveTimeout: const Duration(seconds: 8),
    ),
  );

  SupabaseAuthService() : super(const AuthState()) {
    init();
  }

  static bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  Future<void> init() async {
    if (!AppConfig.isConfigured) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        isCloudAvailable: false,
      );
      return;
    }

    try {
      _client = Supabase.instance.client;
      final session = _client!.auth.currentSession;
      if (session != null) {
        _mapUser(session.user);
      } else {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          isCloudAvailable: true,
        );
      }

      await _authSub?.cancel();
      _authSub = _client!.auth.onAuthStateChange.listen((data) {
        final nextSession = data.session;
        if (nextSession != null) {
          _mapUser(nextSession.user);
        } else {
          state = state.copyWith(
            status: AuthStatus.unauthenticated,
            clearUser: true,
            isCloudAvailable: true,
          );
        }
      });

      unawaited(refreshProviderSettings());
    } catch (_) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        isCloudAvailable: false,
      );
    }
  }

  /// Queries Supabase public `/auth/v1/settings` to detect whether Google/Apple OAuth
  /// providers are active on the project before sending the user to an external browser.
  Future<({bool google, bool apple})> refreshProviderSettings() async {
    if (!AppConfig.isConfigured) {
      return (google: false, apple: false);
    }
    try {
      final res = await _dio.get<dynamic>(
        '${AppConfig.supabaseUrl}/auth/v1/settings',
        options: Options(
          headers: {'apikey': AppConfig.supabaseAnonKey},
          validateStatus: (s) => s != null && s < 500,
        ),
      );
      if (res.statusCode == 200 && res.data != null) {
        final parsed = CloudAuthHelper.parseAuthSettings(res.data);
        state = state.copyWith(
          errorMessage: state.errorMessage,
          infoMessage: state.infoMessage,
          isGoogleOAuthEnabled: parsed.google,
          isAppleOAuthEnabled: parsed.apple,
        );
        return (google: parsed.google, apple: parsed.apple);
      }
    } catch (_) {}
    return (
      google: state.isGoogleOAuthEnabled,
      apple: state.isAppleOAuthEnabled,
    );
  }

  void clearMessages() {
    state = state.copyWith(
      errorMessage: null,
      infoMessage: null,
      needsEmailConfirmation: false,
    );
  }

  void _mapUser(User user) {
    final meta = user.userMetadata ?? {};
    final muxisUser = MuxisUser(
      id: user.id,
      email: user.email ?? '',
      displayName:
          meta['display_name'] as String? ??
          meta['full_name'] as String? ??
          meta['name'] as String? ??
          user.email?.split('@')[0] ??
          'Muxis Listener',
      avatarUrl: meta['avatar_url'] as String? ?? meta['picture'] as String?,
      subscriptionTier: meta['subscription_tier'] as String? ?? 'free',
    );
    state = state.copyWith(
      status: AuthStatus.authenticated,
      user: muxisUser,
      errorMessage: null,
      infoMessage: null,
      needsEmailConfirmation: false,
      isCloudAvailable: true,
    );
  }

  Future<bool> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final trimmedEmail = email.trim();
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

    if (_client == null) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Supabase cloud is not configured yet. Run in local offline mode or configure .env.',
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
      final res = await _client!.auth.signUp(
        email: trimmedEmail,
        password: password,
        emailRedirectTo: CloudAuthHelper.emailConfirmationRedirectUrl,
        data: {if (trimmedName.isNotEmpty) 'display_name': trimmedName},
      );

      if (res.session != null && res.user != null) {
        await _stopDesktopConfirmationListener();
        _mapUser(res.user!);
        return true;
      }

      // When email confirmation is enabled and the user already registered,
      // Supabase returns a user with empty identities without failing.
      if (res.user != null && (res.user!.identities ?? const []).isEmpty) {
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage:
              'An account with $trimmedEmail already exists. Switch to Sign In (or use Forgot Password).',
        );
        return false;
      }

      await _startDesktopConfirmationListener();
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        needsEmailConfirmation: true,
        pendingConfirmationEmail: trimmedEmail,
        infoMessage:
            'Confirmation email sent to $trimmedEmail. Open the verification link in your Gmail inbox within 1 hour (also check Spam), then sign in.',
      );
      return false;
    } on AuthException catch (e) {
      state = state.copyWith(status: AuthStatus.error, errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Connection error during registration: $e',
      );
      return false;
    }
  }

  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final trimmedEmail = email.trim();
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

    if (_client == null) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage:
            'Supabase cloud is not configured. Running in local mode.',
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
      final res = await _client!.auth.signInWithPassword(
        email: trimmedEmail,
        password: password,
      );

      if (res.user != null && res.session != null) {
        _mapUser(res.user!);
        return true;
      }

      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: 'Invalid login credentials.',
      );
      return false;
    } on AuthException catch (e) {
      final unconfirmed = e.message.toLowerCase().contains('not confirmed');
      state = state.copyWith(
        status: AuthStatus.error,
        needsEmailConfirmation: unconfirmed,
        pendingConfirmationEmail: unconfirmed ? trimmedEmail : null,
        errorMessage: unconfirmed
            ? 'Email not verified yet for $trimmedEmail. Check your Gmail inbox (and Spam) or tap Resend Confirmation Email below.'
            : e.message,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Network error: $e',
      );
      return false;
    }
  }

  Future<bool> resendConfirmationEmail([String? overrideEmail]) async {
    final target = (overrideEmail ?? state.pendingConfirmationEmail ?? '')
        .trim();
    if (_client == null || target.isEmpty) return false;

    state = state.copyWith(
      status: AuthStatus.loading,
      errorMessage: null,
      infoMessage: null,
    );
    try {
      await _client!.auth.resend(
        type: OtpType.signup,
        email: target,
        emailRedirectTo: CloudAuthHelper.emailConfirmationRedirectUrl,
      );
      await _startDesktopConfirmationListener();
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        needsEmailConfirmation: true,
        pendingConfirmationEmail: target,
        infoMessage:
            'Fresh confirmation email sent to $target. Open it within 1 hour (check Inbox & Spam).',
      );
      return true;
    } on AuthException catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        needsEmailConfirmation: true,
        pendingConfirmationEmail: target,
        errorMessage: e.message,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        needsEmailConfirmation: true,
        pendingConfirmationEmail: target,
        errorMessage: 'Unable to resend confirmation email: $e',
      );
      return false;
    }
  }

  Future<bool> signInWithGoogle() =>
      _signInWithOAuthProvider(OAuthProvider.google, 'Google');

  Future<bool> signInWithApple() =>
      _signInWithOAuthProvider(OAuthProvider.apple, 'Apple');

  Future<bool> _signInWithOAuthProvider(
    OAuthProvider provider,
    String label,
  ) async {
    if (_client == null || !AppConfig.isConfigured) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'MUXIS Cloud backend is unavailable offline. Local mode remains fully active.',
      );
      return false;
    }

    state = state.copyWith(
      status: AuthStatus.loading,
      errorMessage: null,
      infoMessage: null,
    );

    final settings = await refreshProviderSettings();
    final isEnabled = provider == OAuthProvider.google
        ? settings.google
        : settings.apple;

    if (!isEnabled) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage:
            '$label 1-Click OAuth is not enabled in this Supabase project yet. '
            'Please use Gmail + Password in the form above right now'
            '${provider == OAuthProvider.google ? ' (project owners can turn it on in Supabase -> Authentication -> Providers -> Google).' : '.'}',
      );
      return false;
    }

    if (_isDesktop) {
      return _signInWithOAuthDesktopLoopback(provider, label);
    }

    try {
      final ok = await _client!.auth.signInWithOAuth(
        provider,
        redirectTo: kIsWeb ? null : 'muxis://auth-callback',
      );
      if (!ok) {
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: 'Could not launch $label sign-in browser.',
        );
      }
      return ok;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: '$label Sign-In failed: $e',
      );
      return false;
    }
  }

  Future<bool> _signInWithOAuthDesktopLoopback(
    OAuthProvider provider,
    String label,
  ) async {
    HttpServer? server;
    try {
      for (final port in const [3000, 8080, 0]) {
        try {
          server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
          break;
        } catch (_) {}
      }
      if (server == null) {
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage:
              'Unable to bind local callback listener for $label OAuth.',
        );
        return false;
      }

      final redirectUrl = 'http://localhost:${server.port}/auth-callback';
      final oauthResponse = await _client!.auth.getOAuthSignInUrl(
        provider: provider,
        redirectTo: redirectUrl,
      );

      final launched = await launchUrl(
        Uri.parse(oauthResponse.url),
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        await server.close(force: true);
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage:
              'Unable to open your system browser for $label sign-in.',
        );
        return false;
      }

      final completer = Completer<Uri?>();
      late final StreamSubscription<HttpRequest> sub;
      sub = server.listen((request) async {
        final reqUri = request.uri;
        if (reqUri.path != '/auth-callback') {
          request.response
            ..statusCode = HttpStatus.notFound
            ..close();
          return;
        }

        final hasCodeOrToken = CloudAuthHelper.isCompletedCallbackUri(reqUri);

        request.response.headers.contentType = ContentType.html;
        if (!hasCodeOrToken) {
          // Implicit-flow tokens live in URL #fragment; convert #fragment to ?query
          request.response.write('''<!DOCTYPE html><html><body style="background:#060910;color:#fff;font-family:Segoe UI,sans-serif;display:flex;justify-content:center;align-items:center;height:100vh;">
<p>Completing MUXIS Cloud Sign-In...</p>
<script>if(location.hash&&location.hash.length>1){location.replace('/auth-callback?'+location.hash.substring(1));}</script>
</body></html>''');
          await request.response.close();
          return;
        }

        final okCallback = !reqUri.queryParameters.containsKey('error');
        request.response.write(
          okCallback
              ? '<!DOCTYPE html><html><body style="background:#060910;color:#f8fafc;font-family:Segoe UI,sans-serif;display:flex;flex-direction:column;justify-content:center;align-items:center;height:100vh;"><h2 style="color:#00ff88;margin-bottom:8px;">MUXIS Cloud Connected</h2><p>You can close this browser tab and return to MUXIS.</p></body></html>'
              : '<!DOCTYPE html><html><body style="background:#060910;color:#ef4444;font-family:Segoe UI,sans-serif;display:flex;justify-content:center;align-items:center;height:100vh;"><p>Authentication did not complete. Return to MUXIS.</p></body></html>',
        );
        await request.response.close();
        if (!completer.isCompleted) {
          completer.complete(
            Uri.parse('http://localhost:${server!.port}${reqUri.toString()}'),
          );
        }
      });

      final callbackUri = await completer.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () => null,
      );
      await sub.cancel();
      await server.close(force: true);

      if (callbackUri == null) {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          errorMessage:
              '$label sign-in timed out before completing in browser.',
        );
        return false;
      }

      if (callbackUri.queryParameters.containsKey('error')) {
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage:
              callbackUri.queryParameters['error_description'] ??
              '$label sign-in was cancelled or denied.',
        );
        return false;
      }

      final sessionRes = await _client!.auth.getSessionFromUrl(callbackUri);
      final user = sessionRes.session.user;
      _mapUser(user);
      return true;
    } catch (e) {
      try {
        await server?.close(force: true);
      } catch (_) {}
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: '$label Sign-In failed: $e',
      );
      return false;
    }
  }

  Future<void> _startDesktopConfirmationListener() async {
    if (!_isDesktop || _confirmationServer != null) return;
    try {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 3000);
      _confirmationServer = server;
      _confirmationTimer?.cancel();
      _confirmationTimer = Timer(const Duration(minutes: 15), () {
        unawaited(_stopDesktopConfirmationListener());
      });

      _confirmationSub = server.listen((request) async {
        final reqUri = request.uri;
        if (reqUri.path != '/' && reqUri.path != '/auth-callback') {
          request.response
            ..statusCode = HttpStatus.notFound
            ..close();
          return;
        }

        request.response.headers.contentType = ContentType.html;
        if (!CloudAuthHelper.isLoopbackVerificationUri(reqUri)) {
          request.response.write('''<!DOCTYPE html><html><body style="background:#060910;color:#fff;font-family:Segoe UI,sans-serif;display:flex;justify-content:center;align-items:center;height:100vh;">
<p>Completing MUXIS Email Verification...</p>
<script>if(location.hash&&location.hash.length>1){location.replace('/auth-callback?'+location.hash.substring(1));}</script>
</body></html>''');
          await request.response.close();
          return;
        }

        final hasErr =
            reqUri.queryParameters.containsKey('error') ||
            reqUri.queryParameters.containsKey('error_code');
        if (hasErr) {
          final friendlyErr = CloudAuthHelper.formatConfirmationError(reqUri);
          request.response.write(
            '<!DOCTYPE html><html><body style="background:#060910;color:#fca5a5;font-family:Segoe UI,sans-serif;display:flex;flex-direction:column;justify-content:center;align-items:center;height:100vh;text-align:center;padding:24px;"><h2 style="margin-bottom:8px;">Confirmation Link Expired</h2><p style="max-width:440px;color:#cbd5e1;">$friendlyErr</p></body></html>',
          );
          await request.response.close();
          if (mounted) {
            state = state.copyWith(
              status: AuthStatus.error,
              needsEmailConfirmation: true,
              errorMessage: friendlyErr,
            );
          }
          return;
        }

        try {
          final callbackUrl = Uri.parse(
            'http://localhost:${server.port}${reqUri.toString()}',
          );
          final sessionRes = await _client!.auth.getSessionFromUrl(callbackUrl);
          request.response.write(
            '<!DOCTYPE html><html><body style="background:#060910;color:#f8fafc;font-family:Segoe UI,sans-serif;display:flex;flex-direction:column;justify-content:center;align-items:center;height:100vh;text-align:center;padding:24px;"><h2 style="color:#00ff88;margin-bottom:8px;">MUXIS Email Confirmed</h2><p style="color:#cbd5e1;">You are signed in! Return to MUXIS.</p></body></html>',
          );
          await request.response.close();
          if (mounted) {
            _mapUser(sessionRes.session.user);
          }
          unawaited(_stopDesktopConfirmationListener());
        } catch (e) {
          request.response.write(
            '<!DOCTYPE html><html><body style="background:#060910;color:#f8fafc;font-family:Segoe UI,sans-serif;display:flex;flex-direction:column;justify-content:center;align-items:center;height:100vh;text-align:center;padding:24px;"><h2 style="color:#00f2fe;margin-bottom:8px;">Email Verified</h2><p style="color:#cbd5e1;">Return to MUXIS and sign in with your Gmail + Password.</p></body></html>',
          );
          await request.response.close();
        }
      });
    } catch (_) {
      // Port 3000 unavailable; confirmation continues seamlessly via auth-confirmed.html or sign-in
    }
  }

  Future<void> _stopDesktopConfirmationListener() async {
    _confirmationTimer?.cancel();
    _confirmationTimer = null;
    await _confirmationSub?.cancel();
    _confirmationSub = null;
    try {
      await _confirmationServer?.close(force: true);
    } catch (_) {}
    _confirmationServer = null;
  }

  Future<void> signOut() async {
    await _stopDesktopConfirmationListener();
    if (_client != null) {
      try {
        await _client!.auth.signOut();
      } catch (_) {}
    }
    state = state.copyWith(
      status: AuthStatus.unauthenticated,
      clearUser: true,
      errorMessage: null,
      infoMessage: null,
      needsEmailConfirmation: false,
    );
  }

  Future<bool> sendPasswordReset(String email) async {
    final trimmed = email.trim();
    if (_client == null || trimmed.isEmpty) return false;
    try {
      await _client!.auth.resetPasswordForEmail(
        trimmed,
        redirectTo: CloudAuthHelper.emailConfirmationRedirectUrl,
      );
      state = state.copyWith(
        infoMessage:
            'Password reset email sent to $trimmed (check Gmail Inbox and Spam).',
      );
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Password reset request failed: $e');
      return false;
    }
  }

  Future<bool> deleteAccount() async {
    if (_client == null || state.user == null) return false;
    try {
      try {
        await _client!.rpc('delete_user_account');
      } catch (_) {
        await _client!.functions.invoke('delete-account');
      }
      await signOut();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Account deletion failed: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    unawaited(_stopDesktopConfirmationListener());
    super.dispose();
  }
}
