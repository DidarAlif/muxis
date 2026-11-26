import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/muxis_colors.dart';
import '../../app/theme/theme_controller.dart';
import '../../core/auth/streaming_accounts_controller.dart';
import '../../core/auth/supabase_auth_service.dart';
import '../../shared/widgets/muxis_liquid_surface.dart';
import '../auth/account_dialog.dart';
import '../auth/auth_dialog.dart';

class MuxisSidebar extends ConsumerStatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onOpenAudioStudio;

  const MuxisSidebar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.onOpenAudioStudio,
  });

  @override
  ConsumerState<MuxisSidebar> createState() => _MuxisSidebarState();
}

class _MuxisSidebarState extends ConsumerState<MuxisSidebar> {
  bool _isCollapsed = false;
  final ScrollController _navScrollController = ScrollController();

  @override
  void dispose() {
    _navScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accounts = ref.watch(streamingAccountsProvider);
    final width = _isCollapsed ? 76.0 : 246.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: width,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? MuxisColors.obsidian.withOpacity(0.72)
                  : Colors.white.withOpacity(0.68),
              border: Border(
                right: BorderSide(
                  color: isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.white.withOpacity(0.88),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Brand Logo & Collapse Toggle
                Container(
                  height: 72,
                  padding: EdgeInsets.symmetric(
                    horizontal: _isCollapsed ? 14 : 20,
                  ),
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisAlignment: _isCollapsed
                        ? MainAxisAlignment.center
                        : MainAxisAlignment.spaceBetween,
                    children: [
                      if (!_isCollapsed)
                        Row(
                          children: [
                            Image.asset(
                              'assets/brand/muxis_mark.png',
                              height: 26,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                            ),
                            const SizedBox(width: 11),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'MUXIS',
                                  style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 3.6,
                                    height: 1.0,
                                    color: MuxisColors.textPrimary(isDark),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'LIQUID AUDIO',
                                  style: TextStyle(
                                    fontFamily: 'JetBrains Mono',
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.8,
                                    color: MuxisColors.accent(isDark),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        )
                      else
                        Image.asset(
                          'assets/brand/muxis_mark_square.png',
                          width: 34,
                          height: 34,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                        ),
                      if (!_isCollapsed)
                        IconButton(
                          icon: Icon(
                            Icons.keyboard_double_arrow_left_rounded,
                            size: 20,
                            color: MuxisColors.textSecondary(isDark),
                          ),
                          tooltip: 'Collapse Sidebar',
                          onPressed: () => setState(() => _isCollapsed = true),
                        ),
                    ],
                  ),
                ),

                if (_isCollapsed)
                  Center(
                    child: IconButton(
                      icon: Icon(
                        Icons.keyboard_double_arrow_right_rounded,
                        size: 20,
                        color: MuxisColors.textSecondary(isDark),
                      ),
                      tooltip: 'Expand Sidebar',
                      onPressed: () => setState(() => _isCollapsed = false),
                    ),
                  ),

                const SizedBox(height: 8),

                // Navigation Links
                Expanded(
                  child: Scrollbar(
                    controller: _navScrollController,
                    interactive: true,
                    thickness: 4,
                    radius: const Radius.circular(6),
                    child: ListView(
                      controller: _navScrollController,
                      primary: false,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      children: [
                      if (!_isCollapsed) _buildGroupHeader('DISCOVER', isDark),
                      _buildNavItem(0, Icons.home_filled, 'Home', isDark),
                      _buildNavItem(1, Icons.explore_rounded, 'Explore', isDark),
                      _buildNavItem(2, Icons.search_rounded, 'Search', isDark),
                      _buildNavItem(3, Icons.radio_rounded, 'Radio', isDark),

                      // Dynamic Linked Streaming Platform Section(s)
                      if (accounts.hasAnyConnected) ...[
                        const SizedBox(height: 18),
                        if (!_isCollapsed)
                          _buildGroupHeader('STREAM PLATFORMS', isDark),
                        if (accounts.youtube.isConnected)
                          _buildNavItem(
                            11,
                            Icons.smart_display_rounded,
                            'YouTube Music',
                            isDark,
                            accentOverride: MuxisColors.youtubeRed,
                            showLiveDot: true,
                          ),
                        if (accounts.spotify.isConnected)
                          _buildNavItem(
                            12,
                            Icons.graphic_eq_rounded,
                            'Spotify',
                            isDark,
                            accentOverride: MuxisColors.spotifyGreen,
                            showLiveDot: true,
                          ),
                      ] else if (!_isCollapsed) ...[
                        const SizedBox(height: 16),
                        _buildGroupHeader('CONNECT PLATFORMS', isDark),
                        _buildActionItem(
                          Icons.link_rounded,
                          'Link YT / Spotify',
                          isDark,
                          () => widget.onDestinationSelected(10),
                          accentOverride: MuxisColors.accent(isDark),
                        ),
                      ],

                      const SizedBox(height: 18),
                      if (!_isCollapsed)
                        _buildGroupHeader('YOUR COLLECTION', isDark),
                      _buildNavItem(
                        4,
                        Icons.library_music_rounded,
                        'Library',
                        isDark,
                      ),
                      _buildNavItem(
                        5,
                        Icons.playlist_play_rounded,
                        'Playlists',
                        isDark,
                      ),
                      _buildNavItem(6, Icons.album_rounded, 'Albums', isDark),
                      _buildNavItem(7, Icons.mic_rounded, 'Artists', isDark),
                      _buildNavItem(
                        8,
                        Icons.favorite_rounded,
                        'Favorites',
                        isDark,
                      ),
                      _buildNavItem(
                        9,
                        Icons.history_rounded,
                        'Recently Played',
                        isDark,
                      ),

                      const SizedBox(height: 18),
                      if (!_isCollapsed) _buildGroupHeader('SYSTEM', isDark),
                      _buildActionItem(
                        Icons.tune_rounded,
                        'Audio Studio',
                        isDark,
                        widget.onOpenAudioStudio,
                      ),
                      _buildNavItem(
                        10,
                        Icons.settings_rounded,
                        'Settings',
                        isDark,
                      ),
                    ],
                  ),
                ),
                ),

                // Footer Profile & Theme Toggle
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: _isCollapsed ? 12 : 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: MuxisColors.border(isDark)),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: _isCollapsed
                        ? MainAxisAlignment.center
                        : MainAxisAlignment.spaceBetween,
                    children: [
                      if (!_isCollapsed)
                        Consumer(
                          builder: (context, ref, _) {
                            final auth = ref.watch(authServiceProvider);
                            final isAuth = auth.isAuthenticated;
                            final name = isAuth
                                ? (auth.user?.displayName ?? 'Listener')
                                : 'Cloud Sign In';

                            return InkWell(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => isAuth
                                      ? const AccountDialog()
                                      : const AuthDialog(),
                                );
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: isAuth
                                        ? MuxisColors.accent(isDark)
                                            .withOpacity(0.2)
                                        : (isDark
                                            ? MuxisColors.elevatedSurface
                                            : MuxisColors.secondarySurface),
                                    child: Icon(
                                      isAuth
                                          ? Icons.person_rounded
                                          : Icons.cloud_outlined,
                                      size: 18,
                                      color: MuxisColors.accent(isDark),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: MuxisColors.textPrimary(isDark),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      IconButton(
                        icon: Icon(
                          isDark
                              ? Icons.light_mode_rounded
                              : Icons.dark_mode_rounded,
                          size: 18,
                          color: MuxisColors.accent(isDark),
                        ),
                        tooltip: isDark
                            ? 'Switch to Light Theme'
                            : 'Switch to Dark Theme',
                        onPressed: () => ref
                            .read(themeControllerProvider.notifier)
                            .toggleTheme(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 14, top: 10, bottom: 6),
      child: Text(
        title,
        style: TextStyle(
          fontFamily: 'JetBrains Mono',
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: MuxisColors.textMuted(isDark),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    String label,
    bool isDark, {
    Color? accentOverride,
    bool showLiveDot = false,
  }) {
    final isSelected = widget.selectedIndex == index;
    final activeAccent = accentOverride ?? MuxisColors.accent(isDark);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: MuxisLiquidSurface(
        onTap: () => widget.onDestinationSelected(index),
        enableGlass: false,
        blurSigma: 0,
        borderRadius: 12,
        accentColor: activeAccent,
        padding: EdgeInsets.symmetric(
          horizontal: _isCollapsed ? 12 : 14,
          vertical: 10,
        ),
        colorOverride: isSelected
            ? (isDark
                  ? activeAccent.withOpacity(0.16)
                  : Colors.white.withOpacity(0.85))
            : Colors.transparent,
        borderOverride: isSelected
            ? Border.all(
                color: activeAccent.withOpacity(isDark ? 0.48 : 0.65),
                width: 1,
              )
            : null,
        boxShadowOverride: isSelected && !isDark
            ? [
                BoxShadow(
                  color: activeAccent.withOpacity(0.16),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
        child: Row(
          mainAxisAlignment: _isCollapsed
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected
                  ? activeAccent
                  : (accentOverride?.withOpacity(0.85) ??
                      MuxisColors.textSecondary(isDark)),
            ),
            if (!_isCollapsed) ...[
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? MuxisColors.textPrimary(isDark)
                        : MuxisColors.textSecondary(isDark),
                  ),
                ),
              ),
              if (showLiveDot)
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: activeAccent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: activeAccent.withOpacity(0.6),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionItem(
    IconData icon,
    String label,
    bool isDark,
    VoidCallback onTap, {
    Color? accentOverride,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: MuxisLiquidSurface(
        onTap: onTap,
        enableGlass: false,
        blurSigma: 0,
        borderRadius: 12,
        accentColor: accentOverride,
        padding: EdgeInsets.symmetric(
          horizontal: _isCollapsed ? 12 : 14,
          vertical: 10,
        ),
        colorOverride: Colors.transparent,
        child: Row(
          mainAxisAlignment: _isCollapsed
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 20,
              color: accentOverride ?? MuxisColors.textSecondary(isDark),
            ),
            if (!_isCollapsed) ...[
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: accentOverride ?? MuxisColors.textSecondary(isDark),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
