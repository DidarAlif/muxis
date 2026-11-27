import 'dart:convert';

/// Pure-Dart helpers for MUXIS Cloud (Supabase) auth validation, provider
/// discovery, and desktop/mobile OAuth callback parsing.
class CloudAuthHelper {
  CloudAuthHelper._();

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

  /// Returns `true` when the incoming loopback OAuth callback URI carries an
  /// auth `code`, `access_token`, or OAuth `error` query parameter.
  static bool isCompletedCallbackUri(Uri uri) {
    if (uri.path != '/auth-callback') return false;
    return uri.queryParameters.containsKey('code') ||
        uri.queryParameters.containsKey('access_token') ||
        uri.queryParameters.containsKey('error');
  }
}
