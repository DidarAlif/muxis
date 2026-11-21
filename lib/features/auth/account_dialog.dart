import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/muxis_colors.dart';
import '../../app/theme/muxis_gradients.dart';
import '../../core/auth/auth_state.dart';
import '../../core/auth/supabase_auth_service.dart';
import '../../core/sync/sync_engine.dart';
import '../../core/sync/sync_models.dart';
import '../../shared/widgets/muxis_button.dart';

class AccountDialog extends ConsumerWidget {
  const AccountDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authServiceProvider);
    final authService = ref.read(authServiceProvider.notifier);
    final syncStatus = ref.watch(syncEngineProvider);
    final syncEngine = ref.read(syncEngineProvider.notifier);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = authState.user;

    return Dialog(
      backgroundColor: isDark ? MuxisColors.obsidian : MuxisColors.whiteSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark
              ? MuxisColors.subtleBorderDark
              : MuxisColors.subtleBorderLight,
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'MUXIS ACCOUNT',
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: MuxisColors.electricCyan,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Profile Info
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: MuxisGradients.prismaticPrimary,
                    ),
                    child: Center(
                      child: Text(
                        (user?.displayName.isNotEmpty ?? false)
                            ? user!.displayName[0].toUpperCase()
                            : 'M',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.displayName ?? 'Audiophile',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.email ?? '',
                          style: const TextStyle(
                            fontSize: 12,
                            color: MuxisColors.textMutedDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: MuxisColors.velvetViolet.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            user?.subscriptionTier.toUpperCase() ?? 'FREE',
                            style: const TextStyle(
                              fontSize: 9,
                              fontFamily: 'JetBrains Mono',
                              color: MuxisColors.electricCyan,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Cloud Sync Status Panel
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark
                      ? MuxisColors.elevatedSurface
                      : MuxisColors.secondarySurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? MuxisColors.subtleBorderDark
                        : MuxisColors.subtleBorderLight,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        _buildSyncIcon(syncStatus),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Cloud Sync',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              _syncLabel(syncStatus),
                              style: const TextStyle(
                                fontSize: 11,
                                color: MuxisColors.textMutedDark,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    MuxisButton(
                      label: syncStatus == SyncStatus.syncing
                          ? 'Syncing...'
                          : 'Sync Now',
                      variant: MuxisButtonVariant.secondary,
                      height: 32,
                      onPressed: syncStatus == SyncStatus.syncing
                          ? null
                          : () => syncEngine.syncNow(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: MuxisButton(
                      label: 'Sign Out',
                      variant: MuxisButtonVariant.secondary,
                      onPressed: () async {
                        await authService.signOut();
                        if (context.mounted) Navigator.of(context).pop();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Center(
                child: TextButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: MuxisColors.elevatedSurface,
                        title: const Text('Delete Muxis Account?'),
                        content: const Text(
                          'This will permanently delete your cloud account, cloud playlists, and synchronization data. Your local music files will remain on your device.',
                          style: TextStyle(fontSize: 13),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () async {
                              Navigator.of(ctx).pop();
                              await authService.deleteAccount();
                              if (context.mounted) Navigator.of(context).pop();
                            },
                            child: const Text(
                              'Delete Forever',
                              style: TextStyle(color: MuxisColors.error),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text(
                    'Delete Account',
                    style: TextStyle(fontSize: 11, color: MuxisColors.error),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSyncIcon(SyncStatus status) {
    switch (status) {
      case SyncStatus.syncing:
        return const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: MuxisColors.electricCyan,
          ),
        );
      case SyncStatus.synced:
        return const Icon(
          Icons.cloud_done_rounded,
          color: MuxisColors.success,
          size: 20,
        );
      case SyncStatus.offline:
        return const Icon(
          Icons.cloud_off_rounded,
          color: MuxisColors.textMutedDark,
          size: 20,
        );
      case SyncStatus.error:
        return const Icon(
          Icons.sync_problem_rounded,
          color: MuxisColors.error,
          size: 20,
        );
      case SyncStatus.idle:
      default:
        return const Icon(
          Icons.cloud_queue_rounded,
          color: MuxisColors.electricCyan,
          size: 20,
        );
    }
  }

  String _syncLabel(SyncStatus status) {
    switch (status) {
      case SyncStatus.syncing:
        return 'Synchronizing changes...';
      case SyncStatus.synced:
        return 'Up to date across devices';
      case SyncStatus.offline:
        return 'Operating in offline mode';
      case SyncStatus.error:
        return 'Sync error occurred';
      case SyncStatus.idle:
      default:
        return 'Idle';
    }
  }
}
