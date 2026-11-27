import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/muxis_colors.dart';
import '../../app/theme/muxis_gradients.dart';
import '../../core/auth/streaming_accounts_controller.dart';
import '../../core/auth/supabase_auth_service.dart';
import '../../shared/widgets/muxis_liquid_surface.dart';
import '../auth/account_dialog.dart';
import '../auth/auth_dialog.dart';

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
    final authState = ref.watch(authServiceProvider);
    final isCloudSignedIn = authState.isAuthenticated;

    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: isDark
            ? MuxisColors.background(true).withOpacity(0.80)
            : MuxisColors.surface(false).withOpacity(0.86),
        border: Border(
          bottom: BorderSide(
            color: MuxisColors.border(isDark).withOpacity(0.7),
          ),
        ),
      ),
      child: Row(
        children: [
          // Brand Logo, Wordmark & "by A Leaf" below logo
          GestureDetector(
            onTap: () => onNavigate(0),
            behavior: HitTestBehavior.opaque,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/brand/muxis_mark.png',
                      height: 20,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                    const SizedBox(width: 7),
                    ShaderMask(
                      shaderCallback: (bounds) =>
                          MuxisGradients.activeHero(isDark)
                              .createShader(bounds),
                      child: const Text(
                        'MUXIS',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.2,
                          height: 1.0,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'by A Leaf',
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.9,
                    color: MuxisColors.accent(isDark),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Quick Streaming Hub Switchers (YT / Spotify / SC)
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

                  // MUXIS Cloud Sign-In / Account Shortcut
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: MuxisLiquidSurface(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (_) => isCloudSignedIn
                              ? const AccountDialog()
                              : const AuthDialog(),
                        );
                      },
                      enableGlass: false,
                      blurSigma: 0,
                      borderRadius: 14,
                      accentColor: MuxisColors.accent(isDark),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      colorOverride: isCloudSignedIn
                          ? MuxisColors.accent(isDark).withOpacity(0.18)
                          : (isDark
                                ? Colors.white.withOpacity(0.08)
                                : Colors.black.withOpacity(0.05)),
                      borderOverride: Border.all(
                        color: isCloudSignedIn
                            ? MuxisColors.accent(isDark)
                            : MuxisColors.border(isDark),
                        width: isCloudSignedIn ? 1.3 : 1,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isCloudSignedIn
                                ? Icons.cloud_done_rounded
                                : Icons.cloud_outlined,
                            size: 14,
                            color: MuxisColors.accent(isDark),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isCloudSignedIn
                                ? (authState.user?.displayName
                                          .split(' ')
                                          .first ??
                                      'Cloud')
                                : 'Cloud',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isCloudSignedIn
                                  ? MuxisColors.accent(isDark)
                                  : MuxisColors.textPrimary(isDark),
                            ),
                          ),
                        ],
                      ),
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
            ),
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
