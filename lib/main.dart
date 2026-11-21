import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/config/app_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Safely attempt to load .env if present
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // Falls back gracefully to compile-time --dart-define or defaults
  }

  // 2. Initialize Supabase Client if configured
  if (AppConfig.isConfigured) {
    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        anonKey: AppConfig.supabaseAnonKey,
      );
    } catch (_) {
      // Offline fallback: app continues in 100% offline local mode
    }
  }

  runApp(const ProviderScope(child: MuxisApp()));
}
