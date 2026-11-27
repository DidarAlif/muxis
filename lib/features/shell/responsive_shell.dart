import 'package:flutter/material.dart';

import '../player/mobile_playback_bar.dart';
import '../studio/mobile_audio_studio_sheet.dart';
import 'mobile_top_bar.dart';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/muxis_colors.dart';
import '../../core/audio/audio_playback_service.dart';
import '../../core/updates/app_update_service.dart';
import '../../shared/models/track.dart';
import '../../shared/widgets/muxis_ambient_backdrop.dart';
import '../command_palette/command_palette_dialog.dart';
import '../explore/explore_screen.dart';
import '../home/home_screen.dart';
import '../library/library_screen.dart';
import '../platforms/platform_stream_screen.dart';
import '../player/aurora_now_playing.dart';
import '../player/bottom_playback_bar.dart';
import '../player/right_drawer_panel.dart';
import '../search/search_screen.dart';
import '../settings/settings_screen.dart';
import '../studio/audio_studio_sheet.dart';
import '../updates/update_available_dialog.dart';
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
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(seconds: 2), _checkForStartupUpdate);
  }

  Future<void> _checkForStartupUpdate() async {
    if (!mounted) return;
    final info = await ref
        .read(appUpdateProvider.notifier)
        .checkForUpdates(userInitiated: false);
    if (!mounted || info == null) return;
    await UpdateAvailableDialog.show(context);
  }

  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

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
      setState(() => _navIndex = 4);
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

  void _openMobileQueueSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.84,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: RightDrawerPanel(
            width: double.infinity,
            onClose: () => Navigator.of(ctx).pop(),
          ),
        ),
      ),
    );
  }

  void _openAudioStudio() {
    if (MediaQuery.sizeOf(context).width < 768) {
      MobileAudioStudioSheet.show(context);
      return;
    }
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
        return const ExploreScreen();
      case 4:
        return const LibraryScreen(initialTabIndex: 0);
      case 5:
        return const LibraryScreen(initialTabIndex: 1);
      case 6:
        return const LibraryScreen(initialTabIndex: 2);
      case 7:
        return const LibraryScreen(initialTabIndex: 3);
      case 8:
        return const LibraryScreen(initialTabIndex: 4);
      case 9:
        return const LibraryScreen(initialTabIndex: 5);
      case 10:
        return const SettingsScreen();
      case 11:
        return const PlatformStreamScreen(platform: MusicSource.youtube);
      case 12:
        return const PlatformStreamScreen(platform: MusicSource.spotify);
      default:
        return HomeScreen(onNavigate: (i) => setState(() => _navIndex = i));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(playbackServiceProvider.select((s) => s.errorMessage), (
      prev,
      next,
    ) {
      if (next != null && next.isNotEmpty && next != prev && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    });

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 768;

    if (_isNowPlayingExpanded) {
      return AuroraNowPlaying(
        onClose: () => setState(() => _isNowPlayingExpanded = false),
      );
    }

    final mobileNavIdx = _navIndex == 10
        ? 4
        : (_navIndex == 4 || (_navIndex >= 5 && _navIndex <= 9)
              ? 3
              : (_navIndex >= 11 ? 0 : _navIndex.clamp(0, 2)));

    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: MuxisAmbientBackdrop(
          primaryTint: _navIndex == 12
              ? MuxisColors.spotifyGreen
              : (_navIndex == 11 ? MuxisColors.youtubeRed : null),
          child: SafeArea(
            top: !isDesktop,
            bottom: false,
            child: Column(
              children: [
                if (!isDesktop)
                  MobileTopBar(
                    activeNavIndex: _navIndex,
                    onNavigate: (i) => setState(() => _navIndex = i),
                    onOpenQueueSheet: _openMobileQueueSheet,
                    onOpenAudioStudio: _openAudioStudio,
                  ),

                // Top Main Workspace Area
                Expanded(
                  child: Row(
                    children: [
                      if (isDesktop)
                        MuxisSidebar(
                          selectedIndex: _navIndex,
                          onDestinationSelected: (i) =>
                              setState(() => _navIndex = i),
                          onOpenAudioStudio: _openAudioStudio,
                        ),

                      Expanded(
                        child: Container(
                          color: Colors.transparent,
                          child: _buildScreen(_navIndex),
                        ),
                      ),

                      if (isDesktop && _isRightDrawerOpen)
                        RightDrawerPanel(
                          onClose: () =>
                              setState(() => _isRightDrawerOpen = false),
                        ),
                    ],
                  ),
                ),

                // Persistent Playback Console (Desktop full bar vs Mobile compact glass mini-bar)
                if (isDesktop)
                  BottomPlaybackBar(
                    onExpandNowPlaying: () =>
                        setState(() => _isNowPlayingExpanded = true),
                    onToggleRightDrawer: () => setState(
                      () => _isRightDrawerOpen = !_isRightDrawerOpen,
                    ),
                    onOpenAudioStudio: _openAudioStudio,
                    isLyricsActive: _isRightDrawerOpen,
                    isQueueActive: _isRightDrawerOpen,
                  )
                else
                  MobilePlaybackBar(
                    onExpandNowPlaying: () =>
                        setState(() => _isNowPlayingExpanded = true),
                  ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: !isDesktop
            ? NavigationBarTheme(
                data: NavigationBarThemeData(
                  labelTextStyle: WidgetStateProperty.resolveWith((states) {
                    final selected = states.contains(WidgetState.selected);
                    return TextStyle(
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? MuxisColors.accent(isDark)
                          : MuxisColors.textMuted(isDark),
                    );
                  }),
                  iconTheme: WidgetStateProperty.resolveWith((states) {
                    final selected = states.contains(WidgetState.selected);
                    return IconThemeData(
                      size: 21,
                      color: selected
                          ? MuxisColors.accent(isDark)
                          : MuxisColors.textMuted(isDark),
                    );
                  }),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: MuxisColors.border(isDark).withOpacity(0.7),
                      ),
                    ),
                  ),
                  child: NavigationBar(
                    height: 62,
                    selectedIndex: mobileNavIdx,
                    labelBehavior:
                        NavigationDestinationLabelBehavior.alwaysShow,
                    backgroundColor: isDark
                        ? MuxisColors.deepSpace.withOpacity(0.95)
                        : Colors.white.withOpacity(0.96),
                    indicatorColor: MuxisColors.accent(isDark)
                        .withOpacity(0.18),
                    onDestinationSelected: (idx) {
                      setState(() {
                        if (idx == 3) {
                          _navIndex = 4;
                        } else if (idx == 4) {
                          _navIndex = 10;
                        } else {
                          _navIndex = idx;
                        }
                      });
                    },
                    destinations: const [
                      NavigationDestination(
                        icon: Icon(Icons.home_outlined),
                        selectedIcon: Icon(Icons.home_rounded),
                        label: 'Home',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.explore_outlined),
                        selectedIcon: Icon(Icons.explore_rounded),
                        label: 'Explore',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.search_rounded),
                        selectedIcon: Icon(Icons.search_rounded),
                        label: 'Search',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.library_music_outlined),
                        selectedIcon: Icon(Icons.library_music_rounded),
                        label: 'Library',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.settings_outlined),
                        selectedIcon: Icon(Icons.settings_rounded),
                        label: 'Settings',
                      ),
                    ],
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
