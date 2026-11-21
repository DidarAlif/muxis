import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/shell/responsive_shell.dart';
import 'theme/muxis_theme.dart';
import 'theme/theme_controller.dart';

class MuxisApp extends ConsumerWidget {
  const MuxisApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeControllerProvider);

    return MaterialApp(
      title: 'Muxis — Prismatic Aura Audio',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: MuxisTheme.lightTheme(),
      darkTheme: MuxisTheme.darkTheme(),
      home: const ResponsiveShell(),
    );
  }
}
