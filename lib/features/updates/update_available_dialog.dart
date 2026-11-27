import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/muxis_colors.dart';
import '../../app/theme/muxis_gradients.dart';
import '../../core/updates/app_update_service.dart';
import '../../shared/widgets/muxis_button.dart';

/// Liquid-glass popup modal shown whenever a newer GitHub release is available.
/// Streams the platform-native installer directly in-app with live progress,
/// SHA-256 verification, and 1-click install/relaunch.
class UpdateAvailableDialog extends ConsumerWidget {
  const UpdateAvailableDialog({super.key});

  static bool _isShowing = false;

  static Future<void> show(BuildContext context) async {
    if (_isShowing || !context.mounted) return;
    _isShowing = true;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const UpdateAvailableDialog(),
      );
    } finally {
      _isShowing = false;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updateState = ref.watch(appUpdateProvider);
    final updater = ref.read(appUpdateProvider.notifier);
    final info = updateState.availableUpdate;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = MediaQuery.sizeOf(context).width < 560;
    final accent = MuxisColors.accent(isDark);

    if (info == null) {
      return const SizedBox.shrink();
    }

    final isDownloading = updateState.phase == UpdatePhase.downloading;
    final isVerifying = updateState.phase == UpdatePhase.verifying;
    final isInstalling = updateState.phase == UpdatePhase.installing;
    final isReadyToInstall = updateState.phase == UpdatePhase.readyToInstall;
    final hasError = updateState.phase == UpdatePhase.error;
    final isBusy = isDownloading || isVerifying || isInstalling;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 36,
        vertical: isMobile ? 20 : 24,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? MuxisColors.deepSpace.withValues(alpha: 0.92)
                    : Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark
                      ? MuxisColors.neonGreen.withValues(alpha: 0.28)
                      : MuxisColors.subtleBorderLight,
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.55 : 0.16),
                    blurRadius: 32,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              padding: EdgeInsets.all(isMobile ? 18 : 24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with white-backgrounded app icon badge
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: isMobile ? 48 : 56,
                          height: isMobile ? 48 : 56,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: accent.withValues(alpha: 0.28),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.asset(
                            'assets/brand/app_icon_1024.png',
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.high,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  gradient: MuxisGradients.auroraSpectrum,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'UPDATE AVAILABLE',
                                  style: TextStyle(
                                    fontFamily: 'JetBrains Mono',
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.0,
                                    color: isDark ? Colors.black : Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                info.releaseName.isNotEmpty
                                    ? info.releaseName
                                    : 'MUXIS ${info.tagName}',
                                style: TextStyle(
                                  fontSize: isMobile ? 17 : 19,
                                  fontWeight: FontWeight.w800,
                                  color: MuxisColors.textPrimary(isDark),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!isInstalling)
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: Icon(
                              Icons.close_rounded,
                              size: 20,
                              color: MuxisColors.textMuted(isDark),
                            ),
                            tooltip: 'Close',
                            onPressed: () {
                              if (isDownloading) {
                                updater.cancelDownload();
                              }
                              updater.dismissForSession();
                              Navigator.of(context).pop();
                            },
                          ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Version comparison + binary size pills
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _MetaPill(
                          icon: Icons.system_update_alt_rounded,
                          text:
                              'v${info.currentVersion}  ->  v${info.latestVersion}',
                          color: accent,
                          isDark: isDark,
                        ),
                        _MetaPill(
                          icon: Icons.inventory_2_outlined,
                          text:
                              '${info.asset.name} (${MuxisUpdateSelector.formatBytes(info.asset.sizeBytes)})',
                          color: MuxisColors.teal(isDark),
                          isDark: isDark,
                        ),
                        if (info.expectedSha256 != null)
                          _MetaPill(
                            icon: Icons.verified_user_outlined,
                            text: 'SHA-256 Verified',
                            color: MuxisColors.violet(isDark),
                            isDark: isDark,
                          ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // What's New release notes box
                    Container(
                      width: double.infinity,
                      constraints: BoxConstraints(
                        maxHeight: isMobile ? 150 : 185,
                      ),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? MuxisColors.obsidian.withValues(alpha: 0.65)
                            : MuxisColors.secondarySurface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: MuxisColors.border(isDark)),
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "WHAT'S NEW",
                              style: TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.1,
                                color: accent,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              info.releaseNotes,
                              style: TextStyle(
                                fontSize: 12.5,
                                height: 1.45,
                                color: MuxisColors.textSecondary(isDark),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Progress / Status Area
                    if (isBusy ||
                        isReadyToInstall ||
                        updateState.statusMessage != null) ...[
                      const SizedBox(height: 14),
                      if (isBusy) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: isVerifying || isInstalling
                                ? null
                                : (updateState.progress > 0
                                      ? updateState.progress
                                      : null),
                            minHeight: 7,
                            backgroundColor: MuxisColors.border(isDark),
                            valueColor: AlwaysStoppedAnimation<Color>(accent),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Row(
                        children: [
                          if (isReadyToInstall)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Icon(
                                Icons.check_circle_rounded,
                                size: 17,
                                color: MuxisColors.success,
                              ),
                            ),
                          Expanded(
                            child: Text(
                              updateState.statusMessage ??
                                  'Preparing download...',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isReadyToInstall
                                    ? MuxisColors.success
                                    : MuxisColors.textPrimary(isDark),
                              ),
                            ),
                          ),
                          if (isDownloading && updateState.totalBytes > 0)
                            Text(
                              '${(updateState.progress * 100).round()}%',
                              style: TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: accent,
                              ),
                            ),
                        ],
                      ),
                    ],

                    // Error box
                    if (hasError && updateState.errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: MuxisColors.error.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: MuxisColors.error.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              updateState.errorMessage!,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? const Color(0xFFFCA5A5)
                                    : MuxisColors.error,
                              ),
                            ),
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: updater.openReleasePage,
                              child: Text(
                                'Open release page in browser ->',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: accent,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 18),

                    // Primary & Secondary Actions
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.end,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (!isBusy && !isReadyToInstall)
                          TextButton(
                            onPressed: () async {
                              await updater.skipVersion(info.latestVersion);
                              if (context.mounted) {
                                Navigator.of(context).pop();
                              }
                            },
                            child: Text(
                              'Skip Version',
                              style: TextStyle(
                                fontSize: 12,
                                color: MuxisColors.textMuted(isDark),
                              ),
                            ),
                          ),
                        if (isDownloading)
                          MuxisButton(
                            label: 'Cancel',
                            variant: MuxisButtonVariant.secondary,
                            height: 36,
                            onPressed: updater.cancelDownload,
                          )
                        else if (!isInstalling)
                          MuxisButton(
                            label: isReadyToInstall ? 'Done' : 'Later',
                            variant: MuxisButtonVariant.secondary,
                            height: 36,
                            onPressed: () {
                              updater.dismissForSession();
                              Navigator.of(context).pop();
                            },
                          ),
                        MuxisButton(
                          label: isDownloading
                              ? 'Downloading...'
                              : isVerifying
                              ? 'Verifying...'
                              : isInstalling
                              ? 'Installing...'
                              : isReadyToInstall
                              ? 'Launch Installer Again'
                              : hasError
                              ? 'Retry Update'
                              : 'Download & Install',
                          icon: Icon(
                            isReadyToInstall
                                ? Icons.install_desktop_rounded
                                : Icons.download_rounded,
                            size: 17,
                            color: isDark ? Colors.black : Colors.white,
                          ),
                          variant: MuxisButtonVariant.primary,
                          height: 38,
                          isLoading: isBusy,
                          onPressed: isBusy
                              ? null
                              : (isReadyToInstall
                                    ? updater.launchDownloadedInstallerAgain
                                    : updater.downloadAndInstall),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final bool isDark;

  const _MetaPill({
    required this.icon,
    required this.text,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : MuxisColors.textPrimaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
