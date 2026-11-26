import 'dart:io';

import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/config/app_config.dart';
import 'core/database/database_service.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Handle sub-window title-bar process if invoked by desktop_webview_window
  if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
    if (runWebViewTitleBarWidget(args)) {
      return;
    }
  }

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

  // 3. Initialize Local Offline Database
  final databaseService = DatabaseService();
  await databaseService.init();

  runApp(
    ProviderScope(
      overrides: [
        databaseServiceProvider.overrideWithValue(databaseService),
      ],
      child: const MuxisApp(),
    ),
  );
}
