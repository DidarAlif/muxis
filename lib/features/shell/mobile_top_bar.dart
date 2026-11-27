import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/muxis_colors.dart';
import '../../core/auth/streaming_accounts_controller.dart';
import '../../shared/widgets/muxis_liquid_surface.dart';

/// Sleek frosted top navigation bar rendered on mobile (`< 768px`) so Android
/// and phone users get 1-tap access to YT Music, Spotify, Audio Studio DSP,
/// and the Queue / Lyrics sheet without bloated sidebar chrome.
class MobileTopBar extends ConsumerWidget {
  final int activeNavIndex;
  final ValueChanged<int> onNavigate;
  final VoidCallback onOpenQueueSheet;
  final VoidCallback onOpenAudioStudio;

  const MobileTopBar({
    super.key,
    required this.activeNavIndex,
    required this.onNavigate,
    required this.onOpenQueueSheet,
    required this.onOpenAudioStudio,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accounts = ref.watch(streamingAccountsProvider);

    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: isDark
            ? MuxisColors.obsidian.withOpacity(0.76)
            : Colors.white.withOpacity(0.84),
        border: Border(
          bottom: BorderSide(
            color: MuxisColors.border(isDark).withOpacity(0.7),
          ),
        ),
      ),
      child: Row(
        children: [
          // Brand Logo & Wordmark (backgroundless 3D M wave floats cleanly on glass)
          GestureDetector(
            onTap: () => onNavigate(0),
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/brand/muxis_mark.png',
                  height: 22,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
                const SizedBox(width: 8),
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [
                      MuxisColors.neonGreen,
                      MuxisColors.cyberTeal,
                      MuxisColors.coralPulse,
                    ],
                  ).createShader(bounds),
                  child: const Text(
                    'MUXIS',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.2,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Quick Streaming Hub Switchers (YT / Spotify)
          if (accounts.youtube.isConnected || activeNavIndex == 11)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _PlatformPill(
                label: 'YT',
                active: activeNavIndex == 11,
                color: MuxisColors.youtubeRed,
                isDark: isDark,
                onTap: () => onNavigate(11),
              ),
            ),
          if (accounts.spotify.isConnected || activeNavIndex == 12)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _PlatformPill(
                label: 'Spotify',
                active: activeNavIndex == 12,
                color: MuxisColors.spotifyGreen,
                isDark: isDark,
                onTap: () => onNavigate(12),
              ),
            ),
          if (accounts.soundcloud.isConnected || activeNavIndex == 13)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _PlatformPill(
                label: 'SC',
                active: activeNavIndex == 13,
                color: MuxisColors.soundcloudOrange,
                isDark: isDark,
                onTap: () => onNavigate(13),
              ),
            ),

          // World Radio Tuner Shortcut
          _ActionIcon(
            icon: Icons.radio_rounded,
            tooltip: 'Global Radio Tuner',
            isDark: isDark,
            onTap: () => onNavigate(3),
          ),
          const SizedBox(width: 6),

          // Audio Studio DSP Button
          _ActionIcon(
            icon: Icons.tune_rounded,
            tooltip: 'Audio Studio & 10-Band EQ',
            isDark: isDark,
            onTap: onOpenAudioStudio,
          ),
          const SizedBox(width: 6),

          // Queue & Lyrics Button
          _ActionIcon(
            icon: Icons.queue_music_rounded,
            tooltip: 'Up Next & Lyrics',
            isDark: isDark,
            onTap: onOpenQueueSheet,
          ),
        ],
      ),
    );
  }
}

class _PlatformPill extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _PlatformPill({
    required this.label,
    required this.active,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MuxisLiquidSurface(
      onTap: onTap,
      enableGlass: false,
      blurSigma: 0,
      borderRadius: 14,
      accentColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      colorOverride: active
          ? color.withOpacity(isDark ? 0.28 : 0.18)
          : (isDark
                ? Colors.white.withOpacity(0.06)
                : Colors.black.withOpacity(0.04)),
      borderOverride: Border.all(
        color: active ? color : MuxisColors.border(isDark),
        width: active ? 1.3 : 1,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: active ? color : MuxisColors.textSecondary(isDark),
        ),
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isDark;
  final VoidCallback onTap;

  const _ActionIcon({
    required this.icon,
    required this.tooltip,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: MuxisLiquidSurface(
        onTap: onTap,
        enableGlass: false,
        blurSigma: 0,
        borderRadius: 10,
        padding: const EdgeInsets.all(7),
        colorOverride: isDark
            ? Colors.white.withOpacity(0.07)
            : Colors.black.withOpacity(0.04),
        borderOverride: Border.all(color: MuxisColors.border(isDark)),
        child: Icon(icon, size: 18, color: MuxisColors.textPrimary(isDark)),
      ),
    );
  }
}
