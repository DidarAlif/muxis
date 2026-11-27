import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  AppConfig._();

  static const String _defaultCloudflareGateway =
      'https://muxis-api-worker.a-leaf-org.workers.dev';

  static String get supabaseUrl {
    try {
      final envUrl = dotenv.env['SUPABASE_URL'];
      if (envUrl != null && envUrl.isNotEmpty) return envUrl;
    } catch (_) {}

    const defineUrl = String.fromEnvironment('SUPABASE_URL');
    if (defineUrl.isNotEmpty) return defineUrl;

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
      final gateway = dotenv.env['CLOUDFLARE_API_GATEWAY'];
      if (gateway != null && gateway.isNotEmpty) {
        return gateway.replaceAll(RegExp(r'/+$'), '');
      }
      final url = dotenv.env['CLOUDFLARE_WORKER_URL'];
      if (url != null && url.isNotEmpty) {
        return url.replaceAll(RegExp(r'/+$'), '');
      }
    } catch (_) {}

    const defineGateway = String.fromEnvironment('CLOUDFLARE_API_GATEWAY');
    if (defineGateway.isNotEmpty) {
      return defineGateway.replaceAll(RegExp(r'/+$'), '');
    }

    const defineUrl = String.fromEnvironment('CLOUDFLARE_WORKER_URL');
    if (defineUrl.isNotEmpty) {
      return defineUrl.replaceAll(RegExp(r'/+$'), '');
    }

    return _defaultCloudflareGateway;
  }

  static String get r2PublicUrl {
    try {
      final url = dotenv.env['CLOUDFLARE_R2_PUBLIC_URL'];
      if (url != null && url.isNotEmpty) return url;
    } catch (_) {}
    return 'https://cdn.muxis.audio';
  }

  static bool get isSupabaseConfigured {
    final url = supabaseUrl;
    final key = supabaseAnonKey;
    return url.startsWith('https://') &&
        !url.contains('your-project') &&
        key.length > 20 &&
        !key.contains('placeholder');
  }

  static bool get isCloudWorkerConfigured =>
      cloudflareWorkerUrl.startsWith('https://');

  static bool get isConfigured =>
      isCloudWorkerConfigured || isSupabaseConfigured;
}
