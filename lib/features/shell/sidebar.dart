import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app/theme/muxis_colors.dart';
import '../../app/theme/muxis_gradients.dart';
import '../../core/auth/supabase_auth_service.dart';
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = _isCollapsed ? 76.0 : 240.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: width,
      decoration: BoxDecoration(
        color: isDark ? MuxisColors.obsidian : MuxisColors.whiteSurface,
        border: Border(
          right: BorderSide(
            color: isDark
                ? MuxisColors.subtleBorderDark
                : MuxisColors.subtleBorderLight,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAlignment.start,
        children: [
          // Header: Brand Logo & Collapse Toggle
          Container(
            height: 72,
            padding: EdgeInsets.symmetric(horizontal: _isCollapsed ? 14 : 20),
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisAlignment: _isCollapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.spaceBetween,
              children: [
                if (!_isCollapsed)
                  Row(
                    children: [
                      // Monogram Icon
                      SvgPicture.asset(
                        'assets/brand/muxis_monogram.svg',
                        width: 32,
                        height: 32,
                      ),
                      const SizedBox(width: 12),
                      // Brand Wordmark
                      Text(
                        'MUXIS',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4.0,
                          color: isDark
                              ? Colors.white
                              : MuxisColors.textPrimaryLight,
                        ),
                      ),
                    ],
                  )
                else
                  SvgPicture.asset(
                    'assets/brand/muxis_monogram.svg',
                    width: 32,
                    height: 32,
                  ),

                if (!_isCollapsed)
                  IconButton(
                    icon: Icon(
                      Icons.keyboard_double_arrow_left_rounded,
                      size: 20,
                      color: isDark
                          ? MuxisColors.textSecondaryDark
                          : MuxisColors.textSecondaryLight,
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
                icon: const Icon(
                  Icons.keyboard_double_arrow_right_rounded,
                  size: 20,
                ),
                tooltip: 'Expand Sidebar',
                onPressed: () => setState(() => _isCollapsed = false),
              ),
            ),

          const SizedBox(height: 8),

          // Navigation Links
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: [
                if (!_isCollapsed) _buildGroupHeader('DISCOVER', isDark),
                _buildNavItem(0, Icons.home_filled, 'Home', isDark),
                _buildNavItem(1, Icons.explore_rounded, 'Explore', isDark),
                _buildNavItem(2, Icons.search_rounded, 'Search', isDark),
                _buildNavItem(3, Icons.radio_rounded, 'Radio', isDark),

                const SizedBox(height: 18),
                if (!_isCollapsed) _buildGroupHeader('YOUR COLLECTION', isDark),
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
                _buildNavItem(8, Icons.favorite_rounded, 'Favorites', isDark),
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
                _buildNavItem(10, Icons.settings_rounded, 'Settings', isDark),
              ],
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
                top: BorderSide(
                  color: isDark
                      ? MuxisColors.subtleBorderDark
                      : MuxisColors.subtleBorderLight,
                ),
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
                                  ? MuxisColors.velvetViolet.withOpacity(0.3)
                                  : MuxisColors.elevatedSurface,
                              child: Icon(
                                isAuth
                                    ? Icons.person_rounded
                                    : Icons.cloud_outlined,
                                size: 18,
                                color: MuxisColors.electricCyan,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                IconButton(
                  icon: Icon(
                    isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                    size: 18,
                    color: isDark
                        ? MuxisColors.electricCyan
                        : MuxisColors.velvetViolet,
                  ),
                  tooltip: isDark
                      ? 'Switch to Light Theme'
                      : 'Switch to Dark Theme',
                  onPressed: () =>
                      ref.read(themeControllerProvider.notifier).toggleTheme(),
                ),
              ],
            ),
          ),
        ],
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
          color: isDark
              ? MuxisColors.textMutedDark
              : MuxisColors.textMutedLight,
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, bool isDark) {
    final isSelected = widget.selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => widget.onDestinationSelected(index),
          borderRadius: BorderRadius.circular(10),
          hoverColor: isDark
              ? MuxisColors.hoverSurface
              : MuxisColors.hoverSurfaceLight,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: EdgeInsets.symmetric(
              horizontal: _isCollapsed ? 12 : 14,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDark
                        ? MuxisColors.elevatedSurface
                        : MuxisColors.secondarySurface)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: isSelected
                  ? Border.all(
                      color: MuxisColors.electricCyan.withOpacity(0.4),
                      width: 1,
                    )
                  : null,
            ),
            child: Row(
              mainAxisAlignment: _isCollapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected
                      ? MuxisColors.electricCyan
                      : (isDark
                            ? MuxisColors.textSecondaryDark
                            : MuxisColors.textSecondaryLight),
                ),
                if (!_isCollapsed) ...[
                  const SizedBox(width: 14),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: isSelected
                          ? (isDark
                                ? MuxisColors.textPrimaryDark
                                : MuxisColors.textPrimaryLight)
                          : (isDark
                                ? MuxisColors.textSecondaryDark
                                : MuxisColors.textSecondaryLight),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionItem(
    IconData icon,
    String label,
    bool isDark,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          hoverColor: isDark
              ? MuxisColors.hoverSurface
              : MuxisColors.hoverSurfaceLight,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: _isCollapsed ? 12 : 14,
              vertical: 10,
            ),
            child: Row(
              mainAxisAlignment: _isCollapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isDark
                      ? MuxisColors.textSecondaryDark
                      : MuxisColors.textSecondaryLight,
                ),
                if (!_isCollapsed) ...[
                  const SizedBox(width: 14),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? MuxisColors.textSecondaryDark
                          : MuxisColors.textSecondaryLight,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
