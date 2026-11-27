import 'dart:convert';

/// Pure-Dart helpers for MUXIS Cloud auth validation, provider discovery,
/// recovery keys, API error parsing, and desktop/mobile OAuth callback parsing.
class CloudAuthHelper {
  CloudAuthHelper._();

  static const String emailConfirmationRedirectUrl =
      'https://didaralif.github.io/muxis/auth-confirmed.html';

  /// Parses Supabase `/auth/v1/settings` JSON payload for enabled external OAuth providers.
  static ({bool google, bool apple, bool email, bool autoconfirm})
  parseAuthSettings(dynamic raw) {
    try {
      final map = raw is String
          ? jsonDecode(raw)
          : (raw is Map ? raw : const {});
      if (map is Map) {
        final ext = map['external'];
        final extMap = ext is Map ? ext : const {};
        return (
          google: extMap['google'] == true,
          apple: extMap['apple'] == true,
          email: extMap['email'] != false,
          autoconfirm: map['mailer_autoconfirm'] == true,
        );
      }
    } catch (_) {}
    return (google: false, apple: false, email: true, autoconfirm: false);
  }

  /// Validates email & password inputs for MUXIS Cloud sign-up/sign-in.
  static String? validateSignup({
    required String email,
    required String password,
  }) {
    final trimmed = email.trim();
    if (trimmed.isEmpty ||
        !trimmed.contains('@') ||
        !trimmed.split('@').last.contains('.')) {
      return 'Please enter a valid Gmail or email address.';
    }
    if (password.length < 6) {
      return 'Password must be at least 6 characters long.';
    }
    return null;
  }

  static String normalizeRecoveryKey(String raw) => raw.trim().toUpperCase();

  static bool isValidRecoveryKey(String raw) {
    final clean = normalizeRecoveryKey(raw);
    return RegExp(r'^MUXIS-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$')
        .hasMatch(clean);
  }

  /// Extracts clean error message from Cloudflare Worker JSON error payloads.
  static String extractApiErrorMessage(
    dynamic data,
    int? statusCode, {
    String fallback = 'Authentication request failed.',
  }) {
    try {
      final map = data is String
          ? jsonDecode(data)
          : (data is Map ? data : null);
      if (map is Map) {
        final err = map['error'] ?? map['message'] ?? map['error_description'];
        if (err is String && err.trim().isNotEmpty) {
          return err.trim();
        }
      }
    } catch (_) {}
    if (statusCode != null && statusCode >= 500) {
      return 'Cloud server is temporarily unavailable (HTTP $statusCode).';
    }
    return fallback;
  }

  /// Returns `true` when the incoming loopback OAuth callback URI carries an
  /// auth `code`, `access_token`, or OAuth `error` query parameter.
  static bool isCompletedCallbackUri(Uri uri) {
    if (uri.path != '/auth-callback') return false;
    return uri.queryParameters.containsKey('code') ||
        uri.queryParameters.containsKey('access_token') ||
        uri.queryParameters.containsKey('error');
  }

  /// Returns `true` when the incoming desktop loopback URI (on `/` or `/auth-callback`)
  /// carries email confirmation tokens or Supabase verification errors.
  static bool isLoopbackVerificationUri(Uri uri) {
    if (uri.path != '/' && uri.path != '/auth-callback') return false;
    return uri.queryParameters.containsKey('code') ||
        uri.queryParameters.containsKey('access_token') ||
        uri.queryParameters.containsKey('error') ||
        uri.queryParameters.containsKey('error_code');
  }

  /// Maps Supabase redirect query errors (such as `otp_expired`) into concise copy.
  static String formatConfirmationError(Uri uri) {
    final code = (uri.queryParameters['error_code'] ?? '').trim().toLowerCase();
    if (code == 'otp_expired') {
      return 'Confirmation link expired or was already opened. Tap Resend Confirmation Email in MUXIS to get a fresh link.';
    }
    final desc = (uri.queryParameters['error_description'] ?? '').trim();
    if (desc.isNotEmpty) return desc;
    final err = (uri.queryParameters['error'] ?? '').trim();
    if (err.isNotEmpty) return err;
    return 'Email verification link was invalid or expired.';
  }
}
