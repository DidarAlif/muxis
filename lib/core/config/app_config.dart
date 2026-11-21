import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  AppConfig._();

  static String get supabaseUrl {
    // 1. Try dotenv if loaded
    try {
      final envUrl = dotenv.env['SUPABASE_URL'];
      if (envUrl != null && envUrl.isNotEmpty) return envUrl;
    } catch (_) {}

    // 2. Try compile-time environment variable (--dart-define=SUPABASE_URL=...)
    const defineUrl = String.fromEnvironment('SUPABASE_URL');
    if (defineUrl.isNotEmpty) return defineUrl;

    // 3. Fallback placeholder (informs user in UI if not configured)
    return 'https://your-project.supabase.co';
  }

  static String get supabaseAnonKey {
    try {
      final envKey = dotenv.env['SUPABASE_ANON_KEY'];
      if (envKey != null && envKey.isNotEmpty) return envKey;
    } catch (_) {}

    const defineKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    if (defineKey.isNotEmpty) return defineKey;

    return 'public-anon-key-placeholder';
  }

  static String get cloudflareWorkerUrl {
    try {
      final url = dotenv.env['CLOUDFLARE_WORKER_URL'];
      if (url != null && url.isNotEmpty) return url;
    } catch (_) {}
    return 'https://api.muxis.audio';
  }

  static String get r2PublicUrl {
    try {
      final url = dotenv.env['CLOUDFLARE_R2_PUBLIC_URL'];
      if (url != null && url.isNotEmpty) return url;
    } catch (_) {}
    return 'https://cdn.muxis.audio';
  }

  static bool get isConfigured {
    final url = supabaseUrl;
    final key = supabaseAnonKey;
    return url.startsWith('https://') &&
        !url.contains('your-project') &&
        key.length > 20 &&
        !key.contains('placeholder');
  }
}
