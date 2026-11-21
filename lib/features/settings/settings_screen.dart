import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/muxis_colors.dart';
import '../../app/theme/muxis_gradients.dart';
import '../../app/theme/muxis_typography.dart';
import '../../app/theme/theme_controller.dart';
import '../../core/auth/streaming_oauth_service.dart';
import '../../core/database/database_service.dart';
import '../../core/storage/preferences_service.dart';
import '../../providers/innertube_music_provider.dart';
import '../../providers/spotify_music_provider.dart';
import '../../shared/widgets/muxis_button.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String? _ytCookie;
  String? _ytSapisid;
  String? _ytUserName;
  String? _ytUserAvatar;
  String? _spotifyClientId;
  String? _spotifyClientSecret;
  String? _spotifyUserName;
  String? _spotifyUserAvatar;
  String? _spotifyProduct;
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
    final ytName = await prefs.getYtUserName();
    final ytAvatar = await prefs.getYtUserAvatar();
    final spId = await prefs.getSpotifyClientId();
    final spSec = await prefs.getSpotifyClientSecret();
    final spName = await prefs.getSpotifyUserName();
    final spAvatar = await prefs.getSpotifyUserAvatar();
    final spProd = await prefs.getSpotifyProduct();
    final active = await prefs.getActiveSource();
    final quality = await prefs.getAudioQuality();
    final dbBytes = await db.getStorageUsageBytes();

    if (mounted) {
      setState(() {
        _ytCookie = ytCookie;
        _ytSapisid = ytSapisid;
        _ytUserName = ytName;
        _ytUserAvatar = ytAvatar;
        _spotifyClientId = spId;
        _spotifyClientSecret = spSec;
        _spotifyUserName = spName;
        _spotifyUserAvatar = spAvatar;
        _spotifyProduct = spProd;
        _activeSource = active;
        _audioQuality = quality;
        _dbSizeBytes = dbBytes;
        _isLoading = false;
      });
    }
  }

  Future<void> _startSpotifyBrowserSignIn() async {
    setState(() => _isBrowserAuthRunning = true);
    final oauth = ref.read(streamingOAuthServiceProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Opening your web browser for Spotify sign-in... Please approve the connection in the browser.'),
          backgroundColor: MuxisColors.electricCyan,
          duration: Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    final result = await oauth.signInWithSpotifyBrowser();

    if (mounted) {
      setState(() => _isBrowserAuthRunning = false);
      if (result.isSuccess) {
        await _loadSettings();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully connected to Spotify as ${result.displayName}! Imported ${result.playlistsImported} playlists & ${result.tracksImported} songs.',
            ),
            backgroundColor: MuxisColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage ?? 'Spotify sign-in was cancelled.'),
            backgroundColor: MuxisColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _startYouTubeBrowserSignIn() async {
    setState(() => _isBrowserAuthRunning = true);
    final oauth = ref.read(streamingOAuthServiceProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Opening your web browser for Google/YouTube Music sign-in... Please approve the connection in the browser.'),
          backgroundColor: MuxisColors.electricCyan,
          duration: Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    final result = await oauth.signInWithYouTubeBrowser();

    if (mounted) {
      setState(() => _isBrowserAuthRunning = false);
      if (result.isSuccess) {
        await _loadSettings();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully connected to YouTube Music as ${result.displayName}! Imported ${result.playlistsImported} playlists & ${result.tracksImported} songs.',
            ),
            backgroundColor: MuxisColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage ?? 'YouTube sign-in was cancelled.'),
            backgroundColor: MuxisColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showYouTubeSignInDialog() {
    final cookieCtrl = TextEditingController(text: _ytCookie);
    final sapisidCtrl = TextEditingController(text: _ytSapisid);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? MuxisColors.elevatedSurface : MuxisColors.whiteSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isDark ? MuxisColors.subtleBorderDark : MuxisColors.subtleBorderLight,
            ),
          ),
          title: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: MuxisGradients.prismaticPrimary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.smart_display_rounded, size: 20, color: Colors.black),
              ),
              const SizedBox(width: 12),
              const Text('YouTube Music Sign-In', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Authenticate through your browser to import your YouTube Music playlists, subscriptions, and stream completely ad-free.',
                    style: TextStyle(fontSize: 13, height: 1.4, color: MuxisColors.textSecondaryDark),
                  ),
                  const SizedBox(height: 20),

                  // PRIMARY OPTION: Browser OAuth SSO
                  Center(
                    child: MuxisButton(
                      label: 'Sign In with Browser (Recommended)',
                      icon: const Icon(Icons.open_in_browser_rounded, size: 20),
                      variant: MuxisButtonVariant.primary,
                      height: 44,
                      width: double.infinity,
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _startYouTubeBrowserSignIn();
                      },
                    ),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'OR USE SESSION COOKIE',
                          style: TextStyle(fontSize: 10, fontFamily: 'JetBrains Mono', color: isDark ? MuxisColors.textMutedDark : MuxisColors.textMutedLight),
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: cookieCtrl,
                    maxLines: 2,
                    style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 11),
                    decoration: InputDecoration(
                      labelText: 'YouTube Music Cookie String',
                      hintText: 'Paste cookie string (SAPISID=...; __Secure-3PAPISID=...)',
                      hintStyle: const TextStyle(fontSize: 11),
                      filled: true,
                      fillColor: isDark ? MuxisColors.deepSpace : MuxisColors.secondarySurface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onChanged: (text) {
                      if (text.contains('SAPISID=') && sapisidCtrl.text.isEmpty) {
                        final match = RegExp(r'SAPISID=([^;]+)').firstMatch(text);
                        if (match != null) {
                          sapisidCtrl.text = match.group(1)!.trim();
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: sapisidCtrl,
                    style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 12),
                    decoration: InputDecoration(
                      labelText: 'SAPISID (Optional)',
                      hintText: 'Auto-extracted or enter manually',
                      filled: true,
                      fillColor: isDark ? MuxisColors.deepSpace : MuxisColors.secondarySurface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            MuxisButton(
              label: 'Save Session',
              variant: MuxisButtonVariant.secondary,
              height: 36,
              onPressed: () async {
                final prefs = ref.read(preferencesServiceProvider);
                final cookie = cookieCtrl.text.trim();
                final sapisid = sapisidCtrl.text.trim();

                await prefs.saveYtCookie(cookie);
                await prefs.saveYtSapisid(sapisid);

                final provider = InnerTubeMusicProvider(prefs: prefs);
                await provider.search('test');

                await prefs.saveYtUserProfile('Connected Account (Session Active)', null);
                await prefs.saveActiveSource('youtube');

                Navigator.of(ctx).pop();
                _loadSettings();
              },
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
          backgroundColor: isDark ? MuxisColors.elevatedSurface : MuxisColors.whiteSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isDark ? MuxisColors.subtleBorderDark : MuxisColors.subtleBorderLight,
            ),
          ),
          title: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Color(0xFF1DB954),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.graphic_eq_rounded, size: 20, color: Colors.black),
              ),
              const SizedBox(width: 12),
              const Text('Sign In to Spotify', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Log in with your existing Spotify account in your browser to instantly load all your playlists, saved tracks, and stream them ad-free in MUXIS.',
                    style: TextStyle(fontSize: 13, height: 1.4, color: MuxisColors.textSecondaryDark),
                  ),
                  const SizedBox(height: 20),

                  // PRIMARY OPTION: Browser OAuth SSO
                  Center(
                    child: MuxisButton(
                      label: 'Sign In with Browser (Recommended)',
                      icon: const Icon(Icons.open_in_browser_rounded, size: 20),
                      variant: MuxisButtonVariant.primary,
                      height: 44,
                      width: double.infinity,
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _startSpotifyBrowserSignIn();
                      },
                    ),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'OR CUSTOM API KEYS',
                          style: TextStyle(fontSize: 10, fontFamily: 'JetBrains Mono', color: isDark ? MuxisColors.textMutedDark : MuxisColors.textMutedLight),
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: clientCtrl,
                    style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 12),
                    decoration: InputDecoration(
                      labelText: 'Spotify Client ID (Optional custom)',
                      hintText: 'Leave empty for default built-in client',
                      filled: true,
                      fillColor: isDark ? MuxisColors.deepSpace : MuxisColors.secondarySurface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: secretCtrl,
                    obscureText: true,
                    style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 12),
                    decoration: InputDecoration(
                      labelText: 'Spotify Client Secret (Optional)',
                      hintText: 'Client Secret if using custom client',
                      filled: true,
                      fillColor: isDark ? MuxisColors.deepSpace : MuxisColors.secondarySurface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            MuxisButton(
              label: 'Save Custom Keys',
              variant: MuxisButtonVariant.secondary,
              height: 36,
              onPressed: () async {
                final prefs = ref.read(preferencesServiceProvider);
                final id = clientCtrl.text.trim();
                final sec = secretCtrl.text.trim();

                await prefs.saveSpotifyClientId(id);
                await prefs.saveSpotifyClientSecret(sec);

                final spotifyProvider = SpotifyMusicProvider(prefs: prefs);
                await spotifyProvider.search('Queen');

                await prefs.saveSpotifyUserProfile('Spotify Connected Account', null, 'Active');
                await prefs.saveActiveSource('spotify');

                Navigator.of(ctx).pop();
                _loadSettings();
              },
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final hasYtCredentials = (_ytCookie != null && _ytCookie!.isNotEmpty) || (_ytUserName != null && _ytUserName!.isNotEmpty);
    final hasSpotifyCredentials = (_spotifyClientId != null && _spotifyClientId!.isNotEmpty) || (_spotifyUserName != null && _spotifyUserName!.isNotEmpty);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
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
                const Text(
                  'Select the active platform you want to stream from. Muxis automatically uses your existing playlists, favorites, and streams ad-free:',
                  style: TextStyle(fontSize: 13, color: MuxisColors.textSecondaryDark, height: 1.4),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildPlatformChoice(
                      id: 'youtube',
                      title: 'YouTube Music',
                      icon: Icons.smart_display_rounded,
                      activeColor: MuxisColors.electricCyan,
                      subtitle: hasYtCredentials ? 'Signed In • Ad-Free' : 'Anonymous • Ad-Free',
                    ),
                    const SizedBox(width: 12),
                    _buildPlatformChoice(
                      id: 'spotify',
                      title: 'Spotify',
                      icon: Icons.graphic_eq_rounded,
                      activeColor: const Color(0xFF1DB954),
                      subtitle: hasSpotifyCredentials ? 'Connected • Ad-Free Bridge' : 'Connect via Browser',
                    ),
                    const SizedBox(width: 12),
                    _buildPlatformChoice(
                      id: 'local',
                      title: 'Local Library Only',
                      icon: Icons.folder_special_rounded,
                      activeColor: MuxisColors.velvetViolet,
                      subtitle: '100% Offline Playback',
                    ),
                  ],
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
              // YouTube Music ListTile
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: MuxisGradients.prismaticPrimary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _ytUserAvatar != null && _ytUserAvatar!.isNotEmpty
                          ? Image.network(_ytUserAvatar!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.smart_display_rounded, color: Colors.black, size: 24))
                          : const Icon(Icons.smart_display_rounded, color: Colors.black, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('YouTube Music', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: hasYtCredentials ? Colors.green.withOpacity(0.2) : MuxisColors.electricCyan.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  hasYtCredentials ? 'AUTHENTICATED' : 'ANONYMOUS AD-FREE',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: hasYtCredentials ? Colors.greenAccent : MuxisColors.electricCyan,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            hasYtCredentials
                                ? (_ytUserName ?? 'Account Authenticated • Ad-free byte stream active')
                                : 'Ad-free audio streaming active. Sign in with browser to sync your YouTube playlists & likes.',
                            style: const TextStyle(fontSize: 12, color: MuxisColors.textSecondaryDark),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hasYtCredentials) ...[
                          IconButton(
                            icon: const Icon(Icons.sync_rounded, size: 20, color: MuxisColors.electricCyan),
                            tooltip: 'Sync YouTube Playlists',
                            onPressed: _startYouTubeBrowserSignIn,
                          ),
                          IconButton(
                            icon: const Icon(Icons.logout_rounded, size: 20, color: MuxisColors.textMutedDark),
                            tooltip: 'Sign Out YouTube Music',
                            onPressed: () async {
                              final prefs = ref.read(preferencesServiceProvider);
                              await prefs.saveYtCookie('');
                              await prefs.saveYtSapisid('');
                              await prefs.saveYtUserProfile('', null);
                              _loadSettings();
                            },
                          ),
                        ],
                        MuxisButton(
                          label: hasYtCredentials ? 'Connected' : 'Sign In with Browser',
                          variant: hasYtCredentials ? MuxisButtonVariant.secondary : MuxisButtonVariant.primary,
                          height: 36,
                          isLoading: _isBrowserAuthRunning,
                          onPressed: hasYtCredentials ? _showYouTubeSignInDialog : _startYouTubeBrowserSignIn,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Spotify ListTile
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1DB954),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _spotifyUserAvatar != null && _spotifyUserAvatar!.isNotEmpty
                          ? Image.network(_spotifyUserAvatar!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.graphic_eq_rounded, color: Colors.black, size: 24))
                          : const Icon(Icons.graphic_eq_rounded, color: Colors.black, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('Spotify', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: hasSpotifyCredentials ? const Color(0xFF1DB954).withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  hasSpotifyCredentials ? (_spotifyProduct ?? 'CONNECTED') : 'DISCONNECTED',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: hasSpotifyCredentials ? const Color(0xFF1ED760) : Colors.grey,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            hasSpotifyCredentials
                                ? (_spotifyUserName ?? 'Spotify playlists and liked songs synced • Streams ad-free via Muxis bridge')
                                : 'Sign in through your browser to sync your Spotify playlists, liked tracks, and stream without ads.',
                            style: const TextStyle(fontSize: 12, color: MuxisColors.textSecondaryDark),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hasSpotifyCredentials) ...[
                          IconButton(
                            icon: const Icon(Icons.sync_rounded, size: 20, color: Color(0xFF1ED760)),
                            tooltip: 'Sync Spotify Playlists',
                            onPressed: _startSpotifyBrowserSignIn,
                          ),
                          IconButton(
                            icon: const Icon(Icons.logout_rounded, size: 20, color: MuxisColors.textMutedDark),
                            tooltip: 'Disconnect Spotify',
                            onPressed: () async {
                              final prefs = ref.read(preferencesServiceProvider);
                              await prefs.saveSpotifyClientId('');
                              await prefs.saveSpotifyClientSecret('');
                              await prefs.saveSpotifyAccessToken('');
                              await prefs.saveSpotifyUserProfile('', null, '');
                              _loadSettings();
                            },
                          ),
                        ],
                        MuxisButton(
                          label: hasSpotifyCredentials ? 'Connected' : 'Sign In with Browser',
                          variant: hasSpotifyCredentials ? MuxisButtonVariant.secondary : MuxisButtonVariant.primary,
                          height: 36,
                          isLoading: _isBrowserAuthRunning,
                          onPressed: hasSpotifyCredentials ? _showSpotifySignInDialog : _startSpotifyBrowserSignIn,
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
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Theme Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    SizedBox(height: 4),
                    Text('Choose between dark obsidian, light porcelain, or follow system', style: TextStyle(fontSize: 12, color: MuxisColors.textSecondaryDark)),
                  ],
                ),
                DropdownButton<ThemeMode>(
                  value: themeMode,
                  dropdownColor: isDark ? MuxisColors.elevatedSurface : MuxisColors.whiteSurface,
                  underline: const SizedBox(),
                  onChanged: (mode) {
                    if (mode != null) themeNotifier.setTheme(mode);
                  },
                  items: const [
                    DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark Obsidian')),
                    DropdownMenuItem(value: ThemeMode.light, child: Text('Light Porcelain')),
                    DropdownMenuItem(value: ThemeMode.system, child: Text('System Appearance')),
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Streaming Quality', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        SizedBox(height: 4),
                        Text('Target output audio bitrate and decoding format', style: TextStyle(fontSize: 12, color: MuxisColors.textSecondaryDark)),
                      ],
                    ),
                    DropdownButton<String>(
                      value: _audioQuality,
                      dropdownColor: isDark ? MuxisColors.elevatedSurface : MuxisColors.whiteSurface,
                      underline: const SizedBox(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _audioQuality = val);
                          ref.read(preferencesServiceProvider).saveAudioQuality(val);
                        }
                      },
                      items: const [
                        DropdownMenuItem(value: 'FLAC 24-bit Lossless', child: Text('FLAC 24-bit Lossless')),
                        DropdownMenuItem(value: 'High Fidelity (AAC 256kbps / Opus)', child: Text('High Fidelity (AAC 256kbps / Opus)')),
                        DropdownMenuItem(value: 'Standard (AAC 130kbps)', child: Text('Standard (AAC 130kbps)')),
                        DropdownMenuItem(value: 'Data Saver (96 kbps)', child: Text('Data Saver (96 kbps)')),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Hardware Audio Engine', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        SizedBox(height: 4),
                        Text('Direct hardware output via JustAudio & Media Foundation', style: TextStyle(fontSize: 12, color: MuxisColors.textSecondaryDark)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: MuxisColors.electricCyan.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'WASAPI / COREAUDIO ACTIVE',
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: MuxisColors.electricCyan,
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

        // --- SECTION 5: STORAGE & CACHE (ZERO TEXT SCATTERING) ---
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
                    color: isDark ? MuxisColors.deepSpace : MuxisColors.secondarySurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: MuxisColors.subtleBorderDark),
                  ),
                  child: const Icon(Icons.storage_rounded, color: MuxisColors.electricCyan, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Offline Database & Stream Cache',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Database: ${(_dbSizeBytes / 1024).toStringAsFixed(1)} KB • Temporary streaming and artwork buffers',
                        style: const TextStyle(fontSize: 12, color: MuxisColors.textSecondaryDark),
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
                          content: Text('Temporary audio and artwork cache successfully cleared'),
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
                const Row(
                  children: [
                    Text(
                      'MUXIS',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                        color: MuxisColors.electricCyan,
                      ),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'v1.0.3 (Browser SSO & Stream Platform Edition)',
                      style: TextStyle(
                        fontSize: 12,
                        color: MuxisColors.textMutedDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Cross-Platform Music Streaming & Local Player Application designed with the Prismatic Aura design system. Features real hardware audio output via JustAudio, ad-free streaming via YouTube Music InnerTube, Spotify integration with audio bridging, Apple-inspired liquid glass aesthetics, and synchronized lyrics.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: MuxisColors.textSecondaryDark,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlatformChoice({
    required String id,
    required String title,
    required IconData icon,
    required Color activeColor,
    required String subtitle,
  }) {
    final isSelected = _activeSource == id;
    return Expanded(
      child: InkWell(
        onTap: () async {
          setState(() => _activeSource = id);
          await ref.read(preferencesServiceProvider).saveActiveSource(id);
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? activeColor : MuxisColors.subtleBorderDark,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: isSelected ? activeColor : MuxisColors.textMutedDark),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isSelected ? Colors.white : MuxisColors.textSecondaryDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected ? activeColor : MuxisColors.textMutedDark,
                ),
              ),
            ],
          ),
        ),
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
          color: isDark ? MuxisColors.textMutedDark : MuxisColors.textMutedLight,
        ),
      ),
    );
  }

  Widget _buildCard(bool isDark, {required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? MuxisColors.elevatedSurface : MuxisColors.whiteSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? MuxisColors.subtleBorderDark : MuxisColors.subtleBorderLight,
        ),
      ),
      child: child,
    );
  }
}
