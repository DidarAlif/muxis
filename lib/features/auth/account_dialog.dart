import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/muxis_colors.dart';
import '../../app/theme/muxis_gradients.dart';
import '../../app/theme/muxis_typography.dart';
import '../../core/auth/supabase_auth_service.dart';
import '../../core/sync/sync_engine.dart';
import '../../core/sync/sync_models.dart';
import '../../shared/widgets/muxis_button.dart';

class AccountDialog extends ConsumerStatefulWidget {
  const AccountDialog({super.key});

  @override
  ConsumerState<AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends ConsumerState<AccountDialog> {
  bool _rotatingKey = false;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authServiceProvider);
    final authService = ref.read(authServiceProvider.notifier);
    final syncStatus = ref.watch(syncEngineProvider);
    final syncEngine = ref.read(syncEngineProvider.notifier);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = authState.user;
    final isMobile = MediaQuery.sizeOf(context).width < 520;

    return Dialog(
      backgroundColor: MuxisColors.surface(isDark),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 40,
        vertical: isMobile ? 20 : 24,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: MuxisColors.border(isDark)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 18 : 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'MUXIS ACCOUNT',
                    style: MuxisTypography.mono(
                      fontSize: 12.5,
                      letterSpacing: 1.4,
                      color: MuxisColors.accent(isDark),
                      isDark: isDark,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Profile Info
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: MuxisGradients.activePrimary(isDark),
                    ),
                    child: ClipOval(
                      child:
                          user?.avatarUrl != null &&
                              user!.avatarUrl!.startsWith('http')
                          ? Image.network(
                              user.avatarUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Center(
                                child: Text(
                                  user.displayName.isNotEmpty
                                      ? user.displayName[0].toUpperCase()
                                      : 'M',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: MuxisColors.onAccent(isDark),
                                  ),
                                ),
                              ),
                            )
                          : Center(
                              child: Text(
                                (user?.displayName.isNotEmpty ?? false)
                                    ? user!.displayName[0].toUpperCase()
                                    : 'M',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: MuxisColors.onAccent(isDark),
                                ),
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
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: MuxisColors.textPrimary(isDark),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.email ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            color: MuxisColors.textMuted(isDark),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _badge(
                              user?.subscriptionTier.toUpperCase() ?? 'FREE',
                              MuxisColors.accent(isDark),
                              isDark,
                            ),
                            _badge(
                              (user?.authProvider ?? 'email').toUpperCase(),
                              MuxisColors.violet(isDark),
                              isDark,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Cloud Sync Status Panel
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: MuxisColors.secondaryBg(isDark),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: MuxisColors.border(isDark)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        _buildSyncIcon(syncStatus, isDark),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cloud Sync (D1)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: MuxisColors.textPrimary(isDark),
                              ),
                            ),
                            Text(
                              _syncLabel(syncStatus),
                              style: TextStyle(
                                fontSize: 11,
                                color: MuxisColors.textMuted(isDark),
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

              const SizedBox(height: 12),

              // Backup Recovery Key Card (Password Reset without broken email links)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: MuxisColors.secondaryBg(isDark),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: MuxisColors.border(isDark)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.vpn_key_rounded,
                          size: 16,
                          color: MuxisColors.accent(isDark),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Backup Password Recovery Key',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: MuxisColors.textPrimary(isDark),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (authState.recoveryKey != null &&
                        authState.recoveryKey!.isNotEmpty)
                      Row(
                        children: [
                          Expanded(
                            child: SelectableText(
                              authState.recoveryKey!,
                              style: MuxisTypography.mono(
                                fontSize: 12.5,
                                color: MuxisColors.accent(isDark),
                                isDark: isDark,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.copy_rounded,
                              size: 16,
                              color: MuxisColors.textSecondary(isDark),
                            ),
                            tooltip: 'Copy Recovery Key',
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(text: authState.recoveryKey!),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Backup Recovery Key copied.'),
                                ),
                              );
                            },
                          ),
                        ],
                      )
                    else
                      Text(
                        'Generate a personal recovery key to reset your password offline without verification emails.',
                        style: TextStyle(
                          fontSize: 11,
                          color: MuxisColors.textMuted(isDark),
                        ),
                      ),
                    const SizedBox(height: 8),
                    MuxisButton(
                      label: authState.recoveryKey != null
                          ? 'Generate New Key'
                          : 'Create Backup Recovery Key',
                      variant: MuxisButtonVariant.secondary,
                      height: 32,
                      isLoading: _rotatingKey,
                      onPressed: () async {
                        setState(() => _rotatingKey = true);
                        await authService.regenerateRecoveryKey();
                        if (mounted) setState(() => _rotatingKey = false);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

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
              const SizedBox(height: 10),

              Center(
                child: TextButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: MuxisColors.surface(isDark),
                        title: const Text('Delete Muxis Account?'),
                        content: const Text(
                          'This will permanently delete your cloud account, cloud playlists, and synchronization data. Your local music files remain untouched on your device.',
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

  Widget _badge(String text, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        text,
        style: MuxisTypography.mono(
          fontSize: 9.5,
          color: color,
          isDark: isDark,
        ),
      ),
    );
  }

  Widget _buildSyncIcon(SyncStatus status, bool isDark) {
    switch (status) {
      case SyncStatus.syncing:
        return SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: MuxisColors.accent(isDark),
          ),
        );
      case SyncStatus.synced:
        return const Icon(
          Icons.cloud_done_rounded,
          color: MuxisColors.success,
          size: 20,
        );
      case SyncStatus.offline:
        return Icon(
          Icons.cloud_off_rounded,
          color: MuxisColors.textMuted(isDark),
          size: 20,
        );
      case SyncStatus.error:
        return const Icon(
          Icons.sync_problem_rounded,
          color: MuxisColors.error,
          size: 20,
        );
      case SyncStatus.idle:
        return Icon(
          Icons.cloud_queue_rounded,
          color: MuxisColors.accent(isDark),
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
        return 'Ready';
    }
  }
}
