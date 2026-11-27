import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../player/mini_player.dart';
import '../player/mobile_playback_bar.dart';
import '../studio/mobile_audio_studio_sheet.dart';
import 'mobile_top_bar.dart';

import '../../app/theme/muxis_colors.dart';
import '../../core/audio/audio_playback_service.dart';
import '../../core/storage/preferences_service.dart';
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
import '../radio/radio_screen.dart';
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

class _ResponsiveShellState extends ConsumerState<ResponsiveShell>
    with WindowListener {
  int _navIndex = 0;
  bool _isRightDrawerOpen = false;
  bool _isNowPlayingExpanded = false;
  bool _isMiniPlayerMode = false;
  bool _bypassNextMinimizeMorph = false;
  Size _savedWindowSize = const Size(1240, 820);
  Offset? _savedWindowPos;

  final FocusNode _keyboardFocusNode = FocusNode();

  bool get _isDesktopOS =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  @override
  void initState() {
    super.initState();
    if (_isDesktopOS) {
      windowManager.addListener(this);
    }
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
    if (_isDesktopOS) {
      windowManager.removeListener(this);
    }
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  @override
  void onWindowMinimize() {
    unawaited(_handleWindowMinimize());
  }

  Future<void> _handleWindowMinimize() async {
    if (!_isDesktopOS || !mounted) return;
    if (_bypassNextMinimizeMorph) {
      _bypassNextMinimizeMorph = false;
      return;
    }
    if (_isMiniPlayerMode) return;
    final enabled = await ref
        .read(preferencesServiceProvider)
        .getMiniPlayerOnMinimize();
    if (!enabled || !mounted) return;
    await _enterMiniPlayerMode(fromMinimizeEvent: true);
  }

  Future<void> _enterMiniPlayerMode({bool fromMinimizeEvent = false}) async {
    if (!_isDesktopOS || !mounted || _isMiniPlayerMode) return;
    try {
      if (fromMinimizeEvent) {
        await windowManager.restore();
        await Future<void>.delayed(const Duration(milliseconds: 60));
      }
      _savedWindowSize = await windowManager.getSize();
      _savedWindowPos = await windowManager.getPosition();

      setState(() {
        _isNowPlayingExpanded = false;
        _isMiniPlayerMode = true;
      });

      await windowManager.setTitleBarStyle(
        TitleBarStyle.hidden,
        windowButtonVisibility: false,
      );
      await windowManager.setMinimumSize(const Size(360, 128));
      await windowManager.setSize(const Size(396, 144));
      await windowManager.setResizable(false);
      await windowManager.setAlwaysOnTop(true);
      await windowManager.setAlignment(Alignment.bottomRight);
    } catch (_) {}
  }

  Future<void> _exitMiniPlayerMode() async {
    if (!_isDesktopOS || !mounted) return;
    try {
      setState(() => _isMiniPlayerMode = false);
      await windowManager.setAlwaysOnTop(false);
      await windowManager.setResizable(true);
      await windowManager.setMinimumSize(const Size(420, 600));
      await windowManager.setTitleBarStyle(
        TitleBarStyle.normal,
        windowButtonVisibility: true,
      );
      await windowManager.setSize(_savedWindowSize);
      if (_savedWindowPos != null) {
        await windowManager.setPosition(_savedWindowPos!);
      } else {
        await windowManager.center();
      }
      await windowManager.focus();
    } catch (_) {}
  }

  Future<void> _minimizeMiniPlayerToTaskbar() async {
    if (!_isDesktopOS) return;
    _bypassNextMinimizeMorph = true;
    try {
      await windowManager.minimize();
    } catch (_) {}
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
        return const RadioScreen();
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
      case 13:
        return const PlatformStreamScreen(platform: MusicSource.soundcloud);
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

    if (_isMiniPlayerMode) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Padding(
          padding: const EdgeInsets.all(6),
          child: MuxisMiniPlayer(
            onExpandFull: _exitMiniPlayerMode,
            onMinimizeToTaskbar: _minimizeMiniPlayerToTaskbar,
          ),
        ),
      );
    }

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
              : (_navIndex == 11
                    ? MuxisColors.youtubeRed
                    : (_navIndex == 13
                          ? MuxisColors.soundcloudOrange
                          : (_navIndex == 3
                                ? MuxisColors.electricCyan
                                : null))),
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
                    onEnterMiniPlayer: _isDesktopOS
                        ? () => _enterMiniPlayerMode(fromMinimizeEvent: false)
                        : null,
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
