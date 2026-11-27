import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/shell/responsive_shell.dart';
import '../shared/widgets/muxis_scroll_view.dart';
import 'theme/muxis_colors.dart';
import 'theme/muxis_theme.dart';
import 'theme/theme_controller.dart';

class MuxisApp extends ConsumerWidget {
  const MuxisApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(muxisThemeProvider);
    MuxisColors.applyActivePresets(
      darkPresetId: themeState.darkPresetId,
      lightPresetId: themeState.lightPresetId,
      accentTasteId: themeState.accentTasteId,
    );

    return MaterialApp(
      title: 'Muxis — Liquid Aurora Audio',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const MuxisScrollBehavior(),
      themeMode: themeState.mode,
      theme: MuxisTheme.lightTheme(),
      darkTheme: MuxisTheme.darkTheme(),
      home: const ResponsiveShell(),
    );
  }
}
