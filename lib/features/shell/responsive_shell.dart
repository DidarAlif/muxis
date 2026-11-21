import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/muxis_colors.dart';
import '../../app/theme/muxis_gradients.dart';
import '../../core/audio/audio_playback_service.dart';
import '../command_palette/command_palette_dialog.dart';
import '../explore/explore_screen.dart';
import '../home/home_screen.dart';
import '../library/library_screen.dart';
import '../player/aurora_now_playing.dart';
import '../player/bottom_playback_bar.dart';
import '../player/right_drawer_panel.dart';
import '../search/search_screen.dart';
import '../settings/settings_screen.dart';
import '../studio/audio_studio_sheet.dart';
import 'sidebar.dart';

class ResponsiveShell extends ConsumerStatefulWidget {
  const ResponsiveShell({super.key});

  @override
  ConsumerState<ResponsiveShell> createState() => _ResponsiveShellState();
}

class _ResponsiveShellState extends ConsumerState<ResponsiveShell> {
  int _navIndex = 0;
  bool _isRightDrawerOpen = false;
  bool _isNowPlayingExpanded = false;

  final FocusNode _keyboardFocusNode = FocusNode();

  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    // Guard: Do not intercept global shortcuts when user is typing in a text field
    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus != null && primaryFocus.context?.widget is EditableText) {
      return;
    }

    final audioService = ref.read(playbackServiceProvider.notifier);
    final isControl =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;

    if (event.logicalKey == LogicalKeyboardKey.space) {
      audioService.togglePlay();
    } else if (isControl && event.logicalKey == LogicalKeyboardKey.arrowRight) {
      audioService.playNext();
    } else if (isControl && event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      audioService.playPrevious();
    } else if (isControl && event.logicalKey == LogicalKeyboardKey.arrowUp) {
      final vol = ref.read(playbackServiceProvider).volume;
      audioService.setVolume(vol + 0.05);
    } else if (isControl && event.logicalKey == LogicalKeyboardKey.arrowDown) {
      final vol = ref.read(playbackServiceProvider).volume;
      audioService.setVolume(vol - 0.05);
    } else if (isControl &&
        (event.logicalKey == LogicalKeyboardKey.keyK ||
            event.logicalKey == LogicalKeyboardKey.keyF)) {
      _openCommandPalette();
    } else if (isControl && event.logicalKey == LogicalKeyboardKey.keyL) {
      setState(() => _navIndex = 4); // Library
    }
  }

  void _openCommandPalette() {
    showDialog(
      context: context,
      builder: (_) => CommandPaletteDialog(
        onNavigate: (idx) => setState(() => _navIndex = idx),
        onOpenStudio: _openAudioStudio,
      ),
    );
  }

  void _openAudioStudio() {
    showDialog(context: context, builder: (_) => const AudioStudioSheet());
  }

  Widget _buildScreen(int index) {
    switch (index) {
      case 0:
        return HomeScreen(onNavigate: (i) => setState(() => _navIndex = i));
      case 1:
        return const ExploreScreen();
      case 2:
        return const SearchScreen();
      case 3:
        return const ExploreScreen(); // Radio
      case 4:
        return const LibraryScreen(initialTabIndex: 0); // All Tracks
      case 5:
        return const LibraryScreen(initialTabIndex: 1); // Playlists
      case 6:
        return const LibraryScreen(initialTabIndex: 2); // Albums
      case 7:
        return const LibraryScreen(initialTabIndex: 3); // Artists
      case 8:
        return const LibraryScreen(initialTabIndex: 4); // Favorites
      case 9:
        return const LibraryScreen(initialTabIndex: 5); // Recently Played
      case 10:
        return const SettingsScreen();
      default:
        return HomeScreen(onNavigate: (i) => setState(() => _navIndex = i));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 768;

    if (_isNowPlayingExpanded) {
      return AuroraNowPlaying(
        onClose: () => setState(() => _isNowPlayingExpanded = false),
      );
    }

    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: isDark
              ? MuxisGradients.darkAmbientBackground()
              : MuxisGradients.lightAmbientBackground(),
          child: Column(
            children: [
              // Top Main Workspace Area (Sidebar + Active Screen + Optional Right Panel)
              Expanded(
                child: Row(
                  children: [
                    // Navigation Sidebar (Desktop only)
                    if (isDesktop)
                      MuxisSidebar(
                        selectedIndex: _navIndex,
                        onDestinationSelected: (i) =>
                            setState(() => _navIndex = i),
                        onOpenAudioStudio: _openAudioStudio,
                      ),

                    // Main Screen Workspace
                    Expanded(
                      child: Container(
                        color: Colors.transparent,
                        child: _buildScreen(_navIndex),
                      ),
                    ),

                    // Collapsible Right Drawer Panel (Queue & Synced Lyrics)
                    if (isDesktop && _isRightDrawerOpen)
                      RightDrawerPanel(
                        onClose: () => setState(() => _isRightDrawerOpen = false),
                      ),
                  ],
                ),
              ),

              // Bottom Playback Bar
              BottomPlaybackBar(
                onExpandNowPlaying: () =>
                    setState(() => _isNowPlayingExpanded = true),
                onToggleRightDrawer: () =>
                    setState(() => _isRightDrawerOpen = !_isRightDrawerOpen),
                onOpenAudioStudio: _openAudioStudio,
                isLyricsActive: _isRightDrawerOpen,
                isQueueActive: _isRightDrawerOpen,
              ),
            ],
          ),
        ),

        // Mobile Bottom Navigation Bar (< 768px)
        bottomNavigationBar: !isDesktop
            ? BottomNavigationBar(
                currentIndex: _navIndex.clamp(0, 4),
                onTap: (i) => setState(() => _navIndex = i),
                backgroundColor: isDark
                    ? MuxisColors.obsidian
                    : MuxisColors.whiteSurface,
                selectedItemColor: MuxisColors.electricCyan,
                unselectedItemColor: isDark
                    ? MuxisColors.textMutedDark
                    : MuxisColors.textMutedLight,
                type: BottomNavigationBarType.fixed,
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.home_filled),
                    label: 'Home',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.explore_rounded),
                    label: 'Explore',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.search_rounded),
                    label: 'Search',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.library_music_rounded),
                    label: 'Library',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.settings_rounded),
                    label: 'Settings',
                  ),
                ],
              )
            : null,
      ),
    );
  }
}
