import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

/// Cryptographically generated PKCE pair and state nonce for SoundCloud web OAuth.
class SoundCloudPkcePair {
  final String nonce;
  final String codeVerifier;
  final String codeChallenge;

  const SoundCloudPkcePair({
    required this.nonce,
    required this.codeVerifier,
    required this.codeChallenge,
  });

  /// Creates an S256 PKCE pair from a given RFC-7636 [codeVerifier] and [nonce].
  factory SoundCloudPkcePair.fromVerifier({
    required String codeVerifier,
    required String nonce,
  }) {
    final challenge = base64UrlEncode(_sha256Bytes(ascii.encode(codeVerifier)))
        .replaceAll('=', '');
    return SoundCloudPkcePair(
      nonce: nonce,
      codeVerifier: codeVerifier,
      codeChallenge: challenge,
    );
  }

  /// Generates a fresh RFC-7636 S256 PKCE verifier/challenge and nonce.
  factory SoundCloudPkcePair.generate([Random? random]) {
    const charset =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final rng = random ?? Random.secure();
    String randomString(int len) =>
        List.generate(len, (_) => charset[rng.nextInt(charset.length)]).join();

    return SoundCloudPkcePair.fromVerifier(
      codeVerifier: randomString(64),
      nonce: randomString(32),
    );
  }

  /// Builds base64-encoded JSON OAuth `state` matching SoundCloud `signin/callback`.
  String buildStateJson(String clientId) {
    return base64Encode(
      utf8.encode(jsonEncode({'client_id': clientId, 'nonce': nonce})),
    );
  }

  /// Extracts `client_id` from SoundCloud's base64 JSON `state` query parameter.
  static String? extractClientIdFromState(String? rawState) {
    if (rawState == null || rawState.trim().isEmpty) return null;
    try {
      var normalized = rawState.trim();
      final mod = normalized.length % 4;
      if (mod != 0) {
        normalized = normalized.padRight(normalized.length + (4 - mod), '=');
      }
      final decoded = utf8.decode(base64Decode(normalized));
      final map = jsonDecode(decoded);
      if (map is Map) {
        final cid = map['client_id']?.toString().trim();
        if (cid != null && cid.isNotEmpty) return cid;
      }
    } catch (_) {}
    return null;
  }

  /// Pure-Dart FIPS 180-4 SHA-256 digest (keeps shared/utils free of package deps).
  static Uint8List _sha256Bytes(List<int> input) {
    const k = <int>[
      0x428a2f98,
      0x71374491,
      0xb5c0fbcf,
      0xe9b5dba5,
      0x3956c25b,
      0x59f111f1,
      0x923f82a4,
      0xab1c5ed5,
      0xd807aa98,
      0x12835b01,
      0x243185be,
      0x550c7dc3,
      0x72be5d74,
      0x80deb1fe,
      0x9bdc06a7,
      0xc19bf174,
      0xe49b69c1,
      0xefbe4786,
      0x0fc19dc6,
      0x240ca1cc,
      0x2de92c6f,
      0x4a7484aa,
      0x5cb0a9dc,
      0x76f988da,
      0x983e5152,
      0xa831c66d,
      0xb00327c8,
      0xbf597fc7,
      0xc6e00bf3,
      0xd5a79147,
      0x06ca6351,
      0x14292967,
      0x27b70a85,
      0x2e1b2138,
      0x4d2c6dfc,
      0x53380d13,
      0x650a7354,
      0x766a0abb,
      0x81c2c92e,
      0x92722c85,
      0xa2bfe8a1,
      0xa81a664b,
      0xc24b8b70,
      0xc76c51a3,
      0xd192e819,
      0xd6990624,
      0xf40e3585,
      0x106aa070,
      0x19a4c116,
      0x1e376c08,
      0x2748774c,
      0x34b0bcb5,
      0x391c0cb3,
      0x4ed8aa4a,
      0x5b9cca4f,
      0x682e6ff3,
      0x748f82ee,
      0x78a5636f,
      0x84c87814,
      0x8cc70208,
      0x90befffa,
      0xa4506ceb,
      0xbef9a3f7,
      0xc67178f2,
    ];
    final h = <int>[
      0x6a09e667,
      0xbb67ae85,
      0x3c6ef372,
      0xa54ff53a,
      0x510e527f,
      0x9b05688c,
      0x1f83d9ab,
      0x5be0cd19,
    ];

    int rotr(int x, int n) =>
        ((x & 0xffffffff) >>> n) | ((x << (32 - n)) & 0xffffffff);
    int add32(int a, int b) => (a + b) & 0xffffffff;

    final bitLen = input.length * 8;
    final padLen = ((input.length + 8) ~/ 64 + 1) * 64;
    final padded = Uint8List(padLen)..setRange(0, input.length, input);
    padded[input.length] = 0x80;
    final bd = ByteData.sublistView(padded);
    bd.setUint32(padLen - 8, (bitLen >> 32) & 0xffffffff);
    bd.setUint32(padLen - 4, bitLen & 0xffffffff);

    final w = Uint32List(64);
    for (var offset = 0; offset < padLen; offset += 64) {
      for (var i = 0; i < 16; i++) {
        w[i] = bd.getUint32(offset + i * 4);
      }
      for (var i = 16; i < 64; i++) {
        final s0 = rotr(w[i - 15], 7) ^ rotr(w[i - 15], 18) ^ (w[i - 15] >>> 3);
        final s1 = rotr(w[i - 2], 17) ^ rotr(w[i - 2], 19) ^ (w[i - 2] >>> 10);
        w[i] = add32(add32(add32(w[i - 16], s0), w[i - 7]), s1);
      }

      var a = h[0], b = h[1], c = h[2], d = h[3];
      var e = h[4], f = h[5], g = h[6], hh = h[7];

      for (var i = 0; i < 64; i++) {
        final S1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25);
        final ch = (e & f) ^ ((~e) & g);
        final temp1 = add32(add32(add32(add32(hh, S1), ch), k[i]), w[i]);
        final S0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22);
        final maj = (a & b) ^ (a & c) ^ (b & c);
        final temp2 = add32(S0, maj);
        hh = g;
        g = f;
        f = e;
        e = add32(d, temp1);
        d = c;
        c = b;
        b = a;
        a = add32(temp1, temp2);
      }

      h[0] = add32(h[0], a);
      h[1] = add32(h[1], b);
      h[2] = add32(h[2], c);
      h[3] = add32(h[3], d);
      h[4] = add32(h[4], e);
      h[5] = add32(h[5], f);
      h[6] = add32(h[6], g);
      h[7] = add32(h[7], hh);
    }

    final out = Uint8List(32);
    final outBd = ByteData.sublistView(out);
    for (var i = 0; i < 8; i++) {
      outBd.setUint32(i * 4, h[i]);
    }
    return out;
  }
}

/// Pure URL, cookie, and Google WebView block helpers shared between Desktop and Mobile
/// SoundCloud authentication flows.
class SoundCloudAuthUrlHelper {
  static const String callbackUri = 'https://soundcloud.com/signin/callback';

  /// Returns `true` only for main SoundCloud web origins, excluding auth/API subdomains
  /// such as `secure.soundcloud.com` and `api-auth.soundcloud.com`.
  static bool isMainSoundCloudHost(String host) {
    final normalized = host.trim().toLowerCase();
    return normalized == 'soundcloud.com' ||
        normalized == 'www.soundcloud.com' ||
        normalized == 'm.soundcloud.com' ||
        normalized == 'mobi.soundcloud.com';
  }

  /// Returns `true` when [uri] is SoundCloud's OAuth callback with a non-empty `code`.
  static bool isSigninCallbackUri(Uri? uri) {
    if (uri == null || !isMainSoundCloudHost(uri.host)) return false;
    final path = uri.path.toLowerCase();
    if (!path.contains('/signin/callback')) return false;
    final code = uri.queryParameters['code']?.trim() ?? '';
    return code.isNotEmpty;
  }

  /// Returns `true` when [uri] has landed on an authenticated main SoundCloud page.
  static bool isSignedInHomeUri(Uri? uri) {
    if (uri == null || !isMainSoundCloudHost(uri.host)) return false;
    final path = uri.path.toLowerCase();
    return !path.contains('signin') &&
        !path.contains('login') &&
        !path.contains('connect');
  }

  /// Rewrites an embedded `secure.soundcloud.com/web-auth` URL into top-level standalone
  /// same-window redirect mode (`app_id=3152&stand_alone=true`) with known PKCE challenge.
  /// Returns `null` if [webAuthUri] is not a rewritable `web-auth` page or already carries
  /// `provider_params` from a returning federated OAuth login.
  static Uri? rewriteWebAuthToStandAlone(
    Uri webAuthUri,
    SoundCloudPkcePair pkce,
  ) {
    final host = webAuthUri.host.toLowerCase();
    if (!host.contains('secure.soundcloud.com') ||
        !webAuthUri.path.toLowerCase().contains('/web-auth')) {
      return null;
    }

    final existingProviderParams =
        webAuthUri.queryParameters['provider_params']?.trim() ?? '';
    if (existingProviderParams.isNotEmpty) {
      return null;
    }

    final qp = Map<String, String>.from(webAuthUri.queryParameters);
    final alreadyRewritten =
        qp['app_id'] == '3152' &&
        qp['stand_alone'] == 'true' &&
        !qp.containsKey('embedded_in_iframe') &&
        qp['code_challenge'] == pkce.codeChallenge;
    if (alreadyRewritten) return null;

    qp.remove('embedded_in_iframe');
    qp['stand_alone'] = 'true';
    qp['app_id'] = '3152';
    qp['code_challenge'] = pkce.codeChallenge;
    qp['code_challenge_method'] = 'S256';
    final cid = qp['client_id']?.trim() ?? '';
    if (cid.isNotEmpty) {
      qp['state'] = pkce.buildStateJson(cid);
    }

    return webAuthUri.replace(queryParameters: qp);
  }

  /// Extracts a clean ASCII `oauth_token` value from a `document.cookie` or header string.
  static String? extractOAuthTokenFromCookies(String cookieHeader) {
    final match = RegExp(r'(?:^|;\s*)oauth_token=([^;\s]+)')
        .firstMatch(cookieHeader);
    if (match == null) return null;
    var raw = (match.group(1) ?? '').trim();
    if (raw.startsWith('"') && raw.endsWith('"') && raw.length >= 2) {
      raw = raw.substring(1, raw.length - 1);
    }
    try {
      if (raw.contains('%')) {
        raw = Uri.decodeComponent(raw);
      }
    } catch (_) {}
    final clean = raw
        .replaceAll(RegExp(r'[\r\n\t]+'), ' ')
        .replaceAll(RegExp(r'[^\x20-\x7E]'), '')
        .trim();
    return clean.isEmpty ? null : clean;
  }

  /// Normalizes a user-pasted manual SoundCloud `oauth_token` (stripping optional
  /// `oauth_token=` or `OAuth ` prefixes).
  static String normalizeManualOAuthToken(String rawInput) {
    var clean = rawInput
        .replaceAll(RegExp(r'[\r\n\t]+'), ' ')
        .replaceAll(RegExp(r'[^\x20-\x7E]'), '')
        .trim();
    if (clean.toLowerCase().startsWith('oauth_token=')) {
      clean = clean.substring('oauth_token='.length).split(';').first.trim();
    } else if (clean.toLowerCase().startsWith('oauth ')) {
      clean = clean.substring('oauth '.length).trim();
    }
    return clean;
  }

  /// Detects Google's embedded WebView rejection screen on `accounts.google.com`.
  static bool looksLikeGoogleWebViewBlock({
    required String url,
    required String bodyText,
  }) {
    final lowerUrl = url.toLowerCase();
    final lowerBody = bodyText.toLowerCase();
    if (!lowerUrl.contains('accounts.google.com') &&
        !lowerUrl.contains('disallowed_useragent')) {
      return false;
    }
    return lowerUrl.contains('disallowed_useragent') ||
        lowerBody.contains('browser or app may not be secure') ||
        lowerBody.contains('disallowed_useragent');
  }
}
