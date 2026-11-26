import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app/theme/muxis_colors.dart';
import '../../app/theme/muxis_gradients.dart';
import '../../app/theme/muxis_typography.dart';
import '../../app/theme/theme_controller.dart';
import '../../core/auth/streaming_accounts_controller.dart';
import '../../core/auth/streaming_oauth_service.dart';
import '../../core/database/database_service.dart';
import '../../core/storage/preferences_service.dart';
import '../../shared/widgets/muxis_button.dart';
import '../../shared/widgets/muxis_glass_card.dart';
import '../../shared/widgets/muxis_liquid_surface.dart';
import '../../shared/widgets/muxis_scroll_view.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String? _ytCookie;
  String? _ytSapisid;
  String? _spotifyClientId;
  String? _spotifyClientSecret;
  String? _googleClientId;
  String? _googleClientSecret;
  String _activeSource = 'youtube';
  String _audioQuality = 'FLAC 24-bit Lossless';
  int _dbSizeBytes = 0;
  bool _isLoading = true;
  bool _isBrowserAuthRunning = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = ref.read(preferencesServiceProvider);
    final db = ref.read(databaseServiceProvider);

    final ytCookie = await prefs.getYtCookie();
    final ytSapisid = await prefs.getYtSapisid();
    final spId = await prefs.getSpotifyClientId();
    final spSec = await prefs.getSpotifyClientSecret();
    final gId = await prefs.getGoogleClientId();
    final gSec = await prefs.getGoogleClientSecret();
    final active = await prefs.getActiveSource();
    final quality = await prefs.getAudioQuality();
    final dbBytes = await db.getStorageUsageBytes();

    await ref.read(streamingAccountsProvider.notifier).refreshFromStorage();

    if (mounted) {
      setState(() {
        _ytCookie = ytCookie;
        _ytSapisid = ytSapisid;
        _spotifyClientId = spId;
        _spotifyClientSecret = spSec;
        _googleClientId = gId;
        _googleClientSecret = gSec;
        _activeSource = active;
        _audioQuality = quality;
        _dbSizeBytes = dbBytes;
        _isLoading = false;
      });
    }
  }

  Future<void> _startYouTubeDirectBrowserLogin() async {
    setState(() => _isBrowserAuthRunning = true);
    final accounts = ref.read(streamingAccountsProvider.notifier);
    final result = await accounts.connectYouTubeWithBrowser(context);
    if (!mounted) return;
    setState(() => _isBrowserAuthRunning = false);
    await _loadSettings();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.isSuccess
              ? 'Connected to YouTube Music as ${result.displayName}! Synced ${result.playlistsImported} playlists & ${result.tracksImported} tracks.'
              : (result.errorMessage ?? 'YouTube Music sign-in cancelled.'),
        ),
        backgroundColor:
            result.isSuccess ? MuxisColors.success : MuxisColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _startSpotifyDirectBrowserLogin() async {
    setState(() => _isBrowserAuthRunning = true);
    final accounts = ref.read(streamingAccountsProvider.notifier);
    final result = await accounts.connectSpotifyWithBrowser(context);
    if (!mounted) return;
    setState(() => _isBrowserAuthRunning = false);
    await _loadSettings();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.isSuccess
              ? 'Connected to Spotify as ${result.displayName}! Synced ${result.playlistsImported} playlists & ${result.tracksImported} tracks.'
              : (result.errorMessage ?? 'Spotify sign-in cancelled.'),
        ),
        backgroundColor:
            result.isSuccess ? MuxisColors.success : MuxisColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showYouTubeSignInDialog() {
    final cookieCtrl = TextEditingController(text: _ytCookie);
    final sapisidCtrl = TextEditingController(text: _ytSapisid);
    final googleIdCtrl = TextEditingController(text: _googleClientId);
    final googleSecCtrl = TextEditingController(text: _googleClientSecret);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: MuxisColors.surface(isDark),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: MuxisColors.border(isDark)),
          ),
          title: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  gradient: MuxisGradients.youtubePlatformGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.smart_display_rounded,
                  size: 20,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Connect YouTube Music',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: MuxisColors.textPrimary(isDark),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sign in through the web browser window using your regular Google / YouTube account. MUXIS handles session capture and playlist sync automatically — no manual cookies required.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: MuxisColors.textSecondary(isDark),
                    ),
                  ),
                  const SizedBox(height: 18),
                  MuxisButton(
                    label: 'Sign In via Web Browser',
                    icon: const Icon(Icons.open_in_browser_rounded, size: 20),
                    variant: MuxisButtonVariant.primary,
                    height: 46,
                    width: double.infinity,
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _startYouTubeDirectBrowserLogin();
                    },
                  ),
                  const SizedBox(height: 18),

                  // Internal / Advanced Manual Options (hidden cleanly inside accordion)
                  Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor: Colors.transparent,
                    ),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text(
                        'Internal / Advanced Options (Cookies or OAuth Keys)',
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'JetBrains Mono',
                          fontWeight: FontWeight.w600,
                          color: MuxisColors.textMuted(isDark),
                        ),
                      ),
                      children: [
                        const SizedBox(height: 8),
                        TextField(
                          controller: sapisidCtrl,
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 12,
                            color: MuxisColors.textPrimary(isDark),
                          ),
                          decoration: InputDecoration(
                            labelText: 'SAPISID Session Value (Optional)',
                            filled: true,
                            fillColor: MuxisColors.secondaryBg(isDark),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: cookieCtrl,
                          maxLines: 2,
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 10,
                            color: MuxisColors.textPrimary(isDark),
                          ),
                          decoration: InputDecoration(
                            labelText: 'Cookie Header String (Optional)',
                            filled: true,
                            fillColor: MuxisColors.secondaryBg(isDark),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onChanged: (text) {
                            final match = RegExp(
                              r'(?:SAPISID|__Secure-3PAPISID)=([^;\s]+)',
                            ).firstMatch(text);
                            if (match != null) {
                              sapisidCtrl.text = match.group(1)!.trim();
                            }
                          },
                        ),
                        const SizedBox(height: 10),
                        MuxisButton(
                          label: 'Apply Internal Session',
                          variant: MuxisButtonVariant.secondary,
                          height: 36,
                          width: double.infinity,
                          onPressed: () async {
                            final prefs = ref.read(preferencesServiceProvider);
                            final cookie = cookieCtrl.text.trim();
                            final sapisid = sapisidCtrl.text.trim();
                            if (cookie.isEmpty && sapisid.isEmpty) return;

                            await prefs.saveYtCookie(cookie);
                            await prefs.saveYtSapisid(sapisid);
                            final oauth =
                                ref.read(streamingOAuthServiceProvider);
                            await oauth.syncYouTubeInnerTubeAccount();

                            if (ctx.mounted) Navigator.of(ctx).pop();
                            _loadSettings();
                          },
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: googleIdCtrl,
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 11,
                            color: MuxisColors.textPrimary(isDark),
                          ),
                          decoration: InputDecoration(
                            labelText: 'Custom Google OAuth Client ID',
                            filled: true,
                            fillColor: MuxisColors.secondaryBg(isDark),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: googleSecCtrl,
                          obscureText: true,
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 11,
                            color: MuxisColors.textPrimary(isDark),
                          ),
                          decoration: InputDecoration(
                            labelText: 'Custom Google OAuth Client Secret',
                            filled: true,
                            fillColor: MuxisColors.secondaryBg(isDark),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        MuxisButton(
                          label: 'External Browser OAuth (Custom Keys)',
                          variant: MuxisButtonVariant.liquidGlass,
                          height: 36,
                          width: double.infinity,
                          onPressed: () async {
                            final gId = googleIdCtrl.text.trim();
                            if (gId.isEmpty) return;
                            final prefs = ref.read(preferencesServiceProvider);
                            await prefs.saveGoogleClientId(gId);
                            await prefs.saveGoogleClientSecret(
                              googleSecCtrl.text.trim(),
                            );
                            if (ctx.mounted) Navigator.of(ctx).pop();
                            final res = await ref
                                .read(streamingOAuthServiceProvider)
                                .signInWithYouTubeBrowser();
                            await _loadSettings();
                            if (mounted && !res.isSuccess && res.errorMessage != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(res.errorMessage!),
                                  backgroundColor: MuxisColors.error,
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: MuxisColors.textMuted(isDark)),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showSpotifySignInDialog() {
    final clientCtrl = TextEditingController(text: _spotifyClientId);
    final secretCtrl = TextEditingController(text: _spotifyClientSecret);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: MuxisColors.surface(isDark),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: MuxisColors.border(isDark)),
          ),
          title: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  gradient: MuxisGradients.spotifyPlatformGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.graphic_eq_rounded,
                  size: 20,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Connect Spotify',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: MuxisColors.textPrimary(isDark),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sign in through Spotify\'s official web portal. Works with both Spotify Free and Premium accounts — zero developer client setup or manual cookies needed.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: MuxisColors.textSecondary(isDark),
                    ),
                  ),
                  const SizedBox(height: 18),
                  MuxisButton(
                    label: 'Sign In via Web Browser',
                    icon: const Icon(Icons.open_in_browser_rounded, size: 20),
                    variant: MuxisButtonVariant.primary,
                    height: 46,
                    width: double.infinity,
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _startSpotifyDirectBrowserLogin();
                    },
                  ),
                  const SizedBox(height: 18),

                  // Internal / Advanced Developer Options (collapsed by default)
                  Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor: Colors.transparent,
                    ),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text(
                        'Internal / Advanced Options (Developer OAuth Keys)',
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'JetBrains Mono',
                          fontWeight: FontWeight.w600,
                          color: MuxisColors.textMuted(isDark),
                        ),
                      ),
                      children: [
                        const SizedBox(height: 8),
                        TextField(
                          controller: clientCtrl,
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 12,
                            color: MuxisColors.textPrimary(isDark),
                          ),
                          decoration: InputDecoration(
                            labelText: 'Custom Spotify Client ID',
                            filled: true,
                            fillColor: MuxisColors.secondaryBg(isDark),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: secretCtrl,
                          obscureText: true,
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 12,
                            color: MuxisColors.textPrimary(isDark),
                          ),
                          decoration: InputDecoration(
                            labelText: 'Custom Spotify Client Secret (Optional)',
                            filled: true,
                            fillColor: MuxisColors.secondaryBg(isDark),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        MuxisButton(
                          label: 'Use Custom Spotify Developer Keys',
                          variant: MuxisButtonVariant.secondary,
                          height: 36,
                          width: double.infinity,
                          onPressed: () async {
                            final id = clientCtrl.text.trim();
                            if (id.isEmpty) return;
                            final prefs = ref.read(preferencesServiceProvider);
                            await prefs.saveSpotifyClientId(id);
                            await prefs.saveSpotifyClientSecret(
                              secretCtrl.text.trim(),
                            );
                            if (ctx.mounted) Navigator.of(ctx).pop();
                            final res = await ref
                                .read(streamingOAuthServiceProvider)
                                .signInWithSpotifyBrowser();
                            await _loadSettings();
                            if (mounted && !res.isSuccess && res.errorMessage != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(res.errorMessage!),
                                  backgroundColor: MuxisColors.error,
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: MuxisColors.textMuted(isDark)),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeControllerProvider);
    final themeNotifier = ref.read(themeControllerProvider.notifier);
    final accounts = ref.watch(streamingAccountsProvider);
    final accountsNotifier = ref.read(streamingAccountsProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final hasYt = accounts.youtube.isConnected;
    final hasSp = accounts.spotify.isConnected;

    return MuxisScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Settings', style: MuxisTypography.pageTitle(isDark: isDark)),
          const SizedBox(height: 24),

          // --- SECTION 1: ACTIVE STREAMING PLATFORM ---
          _buildSectionTitle('ACTIVE STREAMING PLATFORM', isDark),
          _buildCard(
            isDark,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Choose your default search & quick-play source. Linking 1 or 2 platforms unlocks dedicated Streaming Hub sections directly in your navigation.',
                    style: TextStyle(
                      fontSize: 13,
                      color: MuxisColors.textSecondary(isDark),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      const gap = 12.0;
                      final cols = constraints.maxWidth >= 620 ? 3 : 1;
                      final itemW = cols == 1
                          ? constraints.maxWidth
                          : (constraints.maxWidth - gap * 2) / 3;
                      return Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: [
                          SizedBox(
                            width: itemW,
                            child: _buildPlatformChoice(
                              id: 'youtube',
                              title: 'YouTube Music',
                              icon: Icons.smart_display_rounded,
                              activeColor: MuxisColors.youtubeRed,
                              subtitle: hasYt
                                  ? 'Signed In • Ad-Free'
                                  : 'Anonymous • Ad-Free',
                            ),
                          ),
                          SizedBox(
                            width: itemW,
                            child: _buildPlatformChoice(
                              id: 'spotify',
                              title: 'Spotify',
                              icon: Icons.graphic_eq_rounded,
                              activeColor: MuxisColors.spotifyGreen,
                              subtitle: hasSp
                                  ? 'Connected • Ad-Free Bridge'
                                  : 'Connect via Browser',
                            ),
                          ),
                          SizedBox(
                            width: itemW,
                            child: _buildPlatformChoice(
                              id: 'local',
                              title: 'Local Library Only',
                              icon: Icons.folder_special_rounded,
                              activeColor: MuxisColors.violet(isDark),
                              subtitle: '100% Offline Playback',
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 24),

        // --- SECTION 2: STREAMING ACCOUNTS & SIGN-IN ---
        _buildSectionTitle('STREAMING ACCOUNTS & INTEGRATIONS', isDark),
        _buildCard(
          isDark,
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: MuxisGradients.youtubePlatformGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: accounts.youtube.avatarUrl != null &&
                              accounts.youtube.avatarUrl!.isNotEmpty
                          ? Image.network(
                              accounts.youtube.avatarUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.smart_display_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            )
                          : const Icon(
                              Icons.smart_display_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'YouTube Music',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: MuxisColors.textPrimary(isDark),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: hasYt
                                      ? MuxisColors.accent(isDark)
                                          .withOpacity(0.18)
                                      : MuxisColors.youtubeRed
                                          .withOpacity(0.14),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  hasYt ? 'LINKED • SYNCED' : 'NOT LINKED',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: hasYt
                                        ? MuxisColors.accent(isDark)
                                        : MuxisColors.youtubeRed,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            hasYt
                                ? '${accounts.youtube.displayName ?? 'YouTube Account'} • ${accounts.youtube.playlists.length} playlists synced'
                                : 'Log in via browser redirection to sync playlists, liked music, and stream ad-free.',
                            style: TextStyle(
                              fontSize: 12,
                              color: MuxisColors.textSecondary(isDark),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hasYt) ...[
                          IconButton(
                            icon: Icon(
                              Icons.sync_rounded,
                              size: 20,
                              color: MuxisColors.accent(isDark),
                            ),
                            tooltip: 'Sync YouTube Music',
                            onPressed: () async {
                              final msg =
                                  await accountsNotifier.syncYouTubeLive();
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(msg),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.logout_rounded,
                              size: 20,
                              color: MuxisColors.textMuted(isDark),
                            ),
                            tooltip: 'Sign Out YouTube Music',
                            onPressed: () async {
                              await accountsNotifier.disconnectYouTube();
                              await _loadSettings();
                            },
                          ),
                        ],
                        MuxisButton(
                          label: hasYt ? 'Manage' : 'Sign In via Browser',
                          variant: hasYt
                              ? MuxisButtonVariant.secondary
                              : MuxisButtonVariant.primary,
                          height: 36,
                          isLoading:
                              _isBrowserAuthRunning || accounts.youtube.isSyncing,
                          onPressed: hasYt
                              ? _showYouTubeSignInDialog
                              : _startYouTubeDirectBrowserLogin,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: MuxisColors.border(isDark)),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: MuxisGradients.spotifyPlatformGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: accounts.spotify.avatarUrl != null &&
                              accounts.spotify.avatarUrl!.isNotEmpty
                          ? Image.network(
                              accounts.spotify.avatarUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.graphic_eq_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            )
                          : const Icon(
                              Icons.graphic_eq_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Spotify',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: MuxisColors.textPrimary(isDark),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: hasSp
                                      ? MuxisColors.spotifyGreen
                                          .withOpacity(0.18)
                                      : Colors.grey.withOpacity(0.16),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  hasSp
                                      ? (accounts.spotify.planBadge ?? 'LINKED')
                                      : 'NOT LINKED',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: hasSp
                                        ? MuxisColors.spotifyGreen
                                        : MuxisColors.textMuted(isDark),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            hasSp
                                ? '${accounts.spotify.displayName ?? 'Spotify Account'} • ${accounts.spotify.playlists.length} playlists synced'
                                : 'Log in via browser redirection to import Spotify playlists & stream ad-free.',
                            style: TextStyle(
                              fontSize: 12,
                              color: MuxisColors.textSecondary(isDark),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hasSp) ...[
                          IconButton(
                            icon: const Icon(
                              Icons.sync_rounded,
                              size: 20,
                              color: MuxisColors.spotifyGreen,
                            ),
                            tooltip: 'Sync Spotify Playlists',
                            onPressed: () async {
                              final msg =
                                  await accountsNotifier.syncSpotifyLive();
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(msg),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.logout_rounded,
                              size: 20,
                              color: MuxisColors.textMuted(isDark),
                            ),
                            tooltip: 'Disconnect Spotify',
                            onPressed: () async {
                              await accountsNotifier.disconnectSpotify();
                              await _loadSettings();
                            },
                          ),
                        ],
                        MuxisButton(
                          label: hasSp ? 'Manage' : 'Sign In via Browser',
                          variant: hasSp
                              ? MuxisButtonVariant.secondary
                              : MuxisButtonVariant.primary,
                          height: 36,
                          isLoading:
                              _isBrowserAuthRunning || accounts.spotify.isSyncing,
                          onPressed: hasSp
                              ? _showSpotifySignInDialog
                              : _startSpotifyDirectBrowserLogin,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // --- SECTION 3: APPEARANCE & THEME ---
        _buildSectionTitle('APPEARANCE', isDark),
        _buildCard(
          isDark,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Theme Mode',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: MuxisColors.textPrimary(isDark),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Aligned Luminous Aurora Light Glass & Dark Obsidian Glass',
                      style: TextStyle(
                        fontSize: 12,
                        color: MuxisColors.textSecondary(isDark),
                      ),
                    ),
                  ],
                ),
                DropdownButton<ThemeMode>(
                  value: themeMode,
                  dropdownColor: MuxisColors.surface(isDark),
                  style: TextStyle(color: MuxisColors.textPrimary(isDark)),
                  underline: const SizedBox(),
                  onChanged: (mode) {
                    if (mode != null) themeNotifier.setTheme(mode);
                  },
                  items: const [
                    DropdownMenuItem(
                      value: ThemeMode.dark,
                      child: Text('Dark Obsidian'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.light,
                      child: Text('Light Aurora Glass'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.system,
                      child: Text('System Appearance'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // --- SECTION 4: AUDIO FIDELITY & ENGINE ---
        _buildSectionTitle('AUDIO FIDELITY & ENGINE', isDark),
        _buildCard(
          isDark,
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Streaming Quality',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: MuxisColors.textPrimary(isDark),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Target output audio bitrate and decoding format',
                          style: TextStyle(
                            fontSize: 12,
                            color: MuxisColors.textSecondary(isDark),
                          ),
                        ),
                      ],
                    ),
                    DropdownButton<String>(
                      value: _audioQuality,
                      dropdownColor: MuxisColors.surface(isDark),
                      style: TextStyle(color: MuxisColors.textPrimary(isDark)),
                      underline: const SizedBox(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _audioQuality = val);
                          ref
                              .read(preferencesServiceProvider)
                              .saveAudioQuality(val);
                        }
                      },
                      items: const [
                        DropdownMenuItem(
                          value: 'FLAC 24-bit Lossless',
                          child: Text('FLAC 24-bit Lossless'),
                        ),
                        DropdownMenuItem(
                          value: 'High Fidelity (AAC 256kbps / Opus)',
                          child: Text('High Fidelity (AAC 256kbps / Opus)'),
                        ),
                        DropdownMenuItem(
                          value: 'Standard (AAC 130kbps)',
                          child: Text('Standard (AAC 130kbps)'),
                        ),
                        DropdownMenuItem(
                          value: 'Data Saver (96 kbps)',
                          child: Text('Data Saver (96 kbps)'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: MuxisColors.border(isDark)),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hardware Audio Engine',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: MuxisColors.textPrimary(isDark),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Direct hardware output via JustAudio & Media Foundation',
                          style: TextStyle(
                            fontSize: 12,
                            color: MuxisColors.textSecondary(isDark),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: MuxisColors.accent(isDark).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'WASAPI / COREAUDIO ACTIVE',
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: MuxisColors.accent(isDark),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // --- SECTION 5: STORAGE & CACHE ---
        _buildSectionTitle('STORAGE & CACHE', isDark),
        _buildCard(
          isDark,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: MuxisColors.secondaryBg(isDark),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: MuxisColors.border(isDark)),
                  ),
                  child: Icon(
                    Icons.storage_rounded,
                    color: MuxisColors.accent(isDark),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Offline Database & Stream Cache',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: MuxisColors.textPrimary(isDark),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Database: ${(_dbSizeBytes / 1024).toStringAsFixed(1)} KB • Temporary streaming and artwork buffers',
                        style: TextStyle(
                          fontSize: 12,
                          color: MuxisColors.textSecondary(isDark),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                MuxisButton(
                  label: 'Clear Cache',
                  variant: MuxisButtonVariant.secondary,
                  height: 36,
                  onPressed: () async {
                    final db = ref.read(databaseServiceProvider);
                    await db.clearCache();
                    if (mounted) {
                      _loadSettings();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Temporary audio and artwork cache successfully cleared',
                          ),
                          backgroundColor: MuxisColors.success,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // --- SECTION 6: ABOUT MUXIS ---
        _buildSectionTitle('ABOUT MUXIS', isDark),
        _buildCard(
          isDark,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SvgPicture.asset(
                      isDark
                          ? 'assets/brand/muxis_monogram.svg'
                          : 'assets/brand/variants/muxis_monogram_light.svg',
                      width: 28,
                      height: 28,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'MUXIS',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                        color: MuxisColors.accent(isDark),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'v1.1.5 (Liquid Aurora Glass, Enhanced YT Sync & Wrapped Desktop UX)',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: MuxisColors.textMuted(isDark),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Cross-Platform Music Streaming & Local Player with Luminous Aurora Liquid Glass design, automatic browser authentication for YouTube Music and Spotify, dedicated per-platform streaming hubs, 10-band studio DSP, and kinetic audio spectrum visualization.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: MuxisColors.textSecondary(isDark),
                  ),
                ),
              ],
            ),
          ),
        ),
        ],
      ),
    );
  }

  Widget _buildPlatformChoice({
    required String id,
    required String title,
    required IconData icon,
    required Color activeColor,
    required String subtitle,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _activeSource == id;
    return MuxisLiquidSurface(
      onTap: () async {
        setState(() => _activeSource = id);
        await ref
            .read(streamingAccountsProvider.notifier)
            .setActiveSource(id);
      },
      enableGlass: false,
      blurSigma: 0,
      borderRadius: 12,
      accentColor: activeColor,
      padding: const EdgeInsets.all(14),
      colorOverride:
          isSelected ? activeColor.withOpacity(0.14) : Colors.transparent,
      borderOverride: Border.all(
        color: isSelected ? activeColor : MuxisColors.border(isDark),
        width: isSelected ? 1.5 : 1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 18,
                color:
                    isSelected ? activeColor : MuxisColors.textMuted(isDark),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isSelected
                        ? MuxisColors.textPrimary(isDark)
                        : MuxisColors.textSecondary(isDark),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color:
                  isSelected ? activeColor : MuxisColors.textMuted(isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontFamily: 'JetBrains Mono',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: MuxisColors.textMuted(isDark),
        ),
      ),
    );
  }

  Widget _buildCard(bool isDark, {required Widget child}) {
    return MuxisGlassCard(
      padding: EdgeInsets.zero,
      borderRadius: 16,
      child: child,
    );
  }
}
