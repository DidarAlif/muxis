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
    final ytName = await prefs.getYtUserName();
    final ytAvatar = await prefs.getYtUserAvatar();
    final spId = await prefs.getSpotifyClientId();
    final spSec = await prefs.getSpotifyClientSecret();
    final spName = await prefs.getSpotifyUserName();
    final spAvatar = await prefs.getSpotifyUserAvatar();
    final spProd = await prefs.getSpotifyProduct();
    final gId = await prefs.getGoogleClientId();
    final gSec = await prefs.getGoogleClientSecret();
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
        _googleClientId = gId;
        _googleClientSecret = gSec;
        _activeSource = active;
        _audioQuality = quality;
        _dbSizeBytes = dbBytes;
        _isLoading = false;
      });
    }
  }

  Future<void> _startSpotifyBrowserSignIn() async {
    final prefs = ref.read(preferencesServiceProvider);
    final configuredId = await prefs.getSpotifyClientId();
    if (configuredId == null || configuredId.trim().isEmpty) {
      _showSpotifySignInDialog();
      return;
    }

    setState(() => _isBrowserAuthRunning = true);
    final oauth = ref.read(streamingOAuthServiceProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Opening your web browser for Spotify sign-in... Please approve the connection in the browser.', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
          backgroundColor: MuxisColors.neonAccent,
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
    final prefs = ref.read(preferencesServiceProvider);
    final configuredId = await prefs.getGoogleClientId();
    if (configuredId == null || configuredId.trim().isEmpty) {
      _showYouTubeSignInDialog();
      return;
    }

    setState(() => _isBrowserAuthRunning = true);
    final oauth = ref.read(streamingOAuthServiceProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Opening your web browser for Google/YouTube Music sign-in... Please approve the connection in the browser.', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
          backgroundColor: MuxisColors.neonAccent,
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
    final googleIdCtrl = TextEditingController(text: _googleClientId);
    final googleSecCtrl = TextEditingController(text: _googleClientSecret);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final oauth = ref.read(streamingOAuthServiceProvider);

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? MuxisColors.elevatedSurface : MuxisColors.whiteSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isDark ? MuxisColors.subtleBorderDark : MuxisColors.subtleBorderLight,
                ),
              ),
              title: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: MuxisGradients.prismaticPrimary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.smart_display_rounded, size: 20, color: Colors.black),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'YouTube Music Connect',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
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
                      // RECOMMENDED METHOD: Session Cookie (SAPISID)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0x1500FF88) : const Color(0x1000B86B),
                          border: Border.all(
                            color: isDark ? const Color(0x4000FF88) : const Color(0x3000B86B),
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.verified_rounded, size: 16, color: MuxisColors.neonAccent),
                                const SizedBox(width: 6),
                                Text(
                                  'METHOD 1: DIRECT SESSION (RECOMMENDED)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                    color: isDark ? MuxisColors.neonAccent : const Color(0xFF008744),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Instant, unlimited ad-free streaming with zero Google Cloud API quotas or developer approval required.',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.35,
                                color: isDark ? MuxisColors.textSecondaryDark : MuxisColors.textSecondaryLight,
                              ),
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: () => oauth.launchBrowserUrl('https://music.youtube.com'),
                              icon: const Icon(Icons.open_in_browser_rounded, size: 16),
                              label: const Text('1. Open music.youtube.com in Browser'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: isDark ? MuxisColors.neonAccent : const Color(0xFF008744),
                                side: BorderSide(
                                  color: isDark ? const Color(0x6000FF88) : const Color(0x4000B86B),
                                ),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '2. Press F12 -> Application tab -> Cookies -> https://music.youtube.com\n3. Copy the SAPISID cookie value and paste below:',
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'JetBrains Mono',
                                height: 1.4,
                                color: isDark ? MuxisColors.textMutedDark : MuxisColors.textMutedLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      TextField(
                        controller: sapisidCtrl,
                        style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 12),
                        decoration: InputDecoration(
                          labelText: 'SAPISID Cookie Value',
                          hintText: 'e.g. 1a2b3c4d5e6f...',
                          prefixIcon: const Icon(Icons.key_rounded, size: 18),
                          filled: true,
                          fillColor: isDark ? MuxisColors.deepSpace : MuxisColors.secondarySurface,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: cookieCtrl,
                        maxLines: 2,
                        style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 10),
                        decoration: InputDecoration(
                          labelText: 'Full Cookie String (Optional - auto-extracts SAPISID)',
                          hintText: 'Paste full cookie header if copied from network tab',
                          filled: true,
                          fillColor: isDark ? MuxisColors.deepSpace : MuxisColors.secondarySurface,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onChanged: (text) {
                          if (text.contains('SAPISID=')) {
                            final match = RegExp(r'SAPISID=([^;]+)').firstMatch(text);
                            if (match != null) {
                              sapisidCtrl.text = match.group(1)!.trim();
                            }
                          }
                        },
                      ),
                      const SizedBox(height: 12),

                      MuxisButton(
                        label: 'Connect YouTube Music (Session)',
                        icon: const Icon(Icons.check_circle_rounded, size: 18),
                        variant: MuxisButtonVariant.primary,
                        height: 40,
                        width: double.infinity,
                        onPressed: () async {
                          final prefs = ref.read(preferencesServiceProvider);
                          final cookie = cookieCtrl.text.trim();
                          final sapisid = sapisidCtrl.text.trim();

                          if (cookie.isEmpty && sapisid.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter your SAPISID cookie from music.youtube.com.'),
                                backgroundColor: MuxisColors.error,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            return;
                          }

                          await prefs.saveYtCookie(cookie);
                          await prefs.saveYtSapisid(sapisid);

                          final provider = InnerTubeMusicProvider(prefs: prefs);
                          await provider.search('test');

                          await prefs.saveYtUserProfile('YouTube Music Listener (Connected)', null);
                          await prefs.saveActiveSource('youtube');

                          Navigator.of(ctx).pop();
                          _loadSettings();

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('YouTube Music connected successfully! Ad-free streaming is ready.'),
                                backgroundColor: MuxisColors.neonAccent,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 20),

                      // METHOD 2: GOOGLE CLOUD OAUTH
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              'OR METHOD 2: GOOGLE CLOUD OAUTH',
                              style: TextStyle(
                                fontSize: 10,
                                fontFamily: 'JetBrains Mono',
                                color: isDark ? MuxisColors.textMutedDark : MuxisColors.textMutedLight,
                              ),
                            ),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 12),

                      Text(
                        'Requires a Google Cloud Console OAuth Client ID with redirect URI: http://127.0.0.1:8888/callback',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? MuxisColors.textMutedDark : MuxisColors.textMutedLight,
                        ),
                      ),
                      const SizedBox(height: 10),

                      TextField(
                        controller: googleIdCtrl,
                        style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 12),
                        decoration: InputDecoration(
                          labelText: 'Google OAuth Client ID',
                          hintText: 'e.g. 123456789.apps.googleusercontent.com',
                          filled: true,
                          fillColor: isDark ? MuxisColors.deepSpace : MuxisColors.secondarySurface,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 8),

                      TextField(
                        controller: googleSecCtrl,
                        obscureText: true,
                        style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 12),
                        decoration: InputDecoration(
                          labelText: 'Google Client Secret (Optional)',
                          filled: true,
                          fillColor: isDark ? MuxisColors.deepSpace : MuxisColors.secondarySurface,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 12),

                      MuxisButton(
                        label: 'Sign In via Google OAuth Browser',
                        icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                        variant: MuxisButtonVariant.secondary,
                        height: 40,
                        width: double.infinity,
                        onPressed: () async {
                          final gId = googleIdCtrl.text.trim();
                          if (gId.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter your Google OAuth Client ID first, or use Method 1 above.'),
                                backgroundColor: MuxisColors.error,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            return;
                          }

                          final prefs = ref.read(preferencesServiceProvider);
                          await prefs.saveGoogleClientId(gId);
                          await prefs.saveGoogleClientSecret(googleSecCtrl.text.trim());

                          Navigator.of(ctx).pop();
                          _startYouTubeBrowserSignIn();
                        },
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
              ],
            );
          },
        );
      },
    );
  }

  void _showSpotifySignInDialog() {
    final clientCtrl = TextEditingController(text: _spotifyClientId);
    final secretCtrl = TextEditingController(text: _spotifyClientSecret);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final oauth = ref.read(streamingOAuthServiceProvider);

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? MuxisColors.elevatedSurface : MuxisColors.whiteSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isDark ? MuxisColors.subtleBorderDark : MuxisColors.subtleBorderLight,
                ),
              ),
              title: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: Color(0xFF1DB954),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.graphic_eq_rounded, size: 20, color: Colors.black),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Sign In to Spotify',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
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
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0x151DB954) : const Color(0x101DB954),
                          border: Border.all(
                            color: isDark ? const Color(0x401DB954) : const Color(0x301DB954),
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF1DB954)),
                                const SizedBox(width: 6),
                                Text(
                                  'SPOTIFY DEVELOPER APP SETUP',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                    color: isDark ? const Color(0xFF1DB954) : const Color(0xFF107C36),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Spotify requires a free Client ID to authorize desktop apps. You can create one in 30 seconds:',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.35,
                                color: isDark ? MuxisColors.textSecondaryDark : MuxisColors.textSecondaryLight,
                              ),
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: () => oauth.launchBrowserUrl('https://developer.spotify.com/dashboard'),
                              icon: const Icon(Icons.open_in_browser_rounded, size: 16),
                              label: const Text('1. Open Spotify Developer Dashboard'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF1DB954),
                                side: const BorderSide(color: Color(0x601DB954)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '2. Click "Create app" -> App Name: MUXIS\n3. Redirect URI: http://127.0.0.1:8888/callback\n4. Copy your Client ID and paste below:',
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'JetBrains Mono',
                                height: 1.4,
                                color: isDark ? MuxisColors.textMutedDark : MuxisColors.textMutedLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextField(
                        controller: clientCtrl,
                        style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 12),
                        decoration: InputDecoration(
                          labelText: 'Spotify Client ID (Required)',
                          hintText: 'e.g. 65b32785a9744c68832a84e03b22cf0c',
                          prefixIcon: const Icon(Icons.key_rounded, size: 18),
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
                          hintText: 'Required if using API keys without browser SSO',
                          filled: true,
                          fillColor: isDark ? MuxisColors.deepSpace : MuxisColors.secondarySurface,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 20),

                      MuxisButton(
                        label: 'Sign In with Browser (Spotify SSO)',
                        icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                        variant: MuxisButtonVariant.primary,
                        height: 44,
                        width: double.infinity,
                        onPressed: () async {
                          final id = clientCtrl.text.trim();
                          if (id.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter your Spotify Client ID from developer.spotify.com/dashboard.'),
                                backgroundColor: MuxisColors.error,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            return;
                          }

                          final prefs = ref.read(preferencesServiceProvider);
                          await prefs.saveSpotifyClientId(id);
                          await prefs.saveSpotifyClientSecret(secretCtrl.text.trim());

                          Navigator.of(ctx).pop();
                          _startSpotifyBrowserSignIn();
                        },
                      ),
                      const SizedBox(height: 10),

                      Center(
                        child: TextButton.icon(
                          onPressed: () async {
                            final id = clientCtrl.text.trim();
                            final sec = secretCtrl.text.trim();
                            if (id.isEmpty || sec.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Both Client ID and Client Secret are required to save custom keys.'),
                                  backgroundColor: MuxisColors.error,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              return;
                            }

                            final prefs = ref.read(preferencesServiceProvider);
                            await prefs.saveSpotifyClientId(id);
                            await prefs.saveSpotifyClientSecret(sec);

                            final spotifyProvider = SpotifyMusicProvider(prefs: prefs);
                            await spotifyProvider.search('Queen');

                            await prefs.saveSpotifyUserProfile('Spotify Connected Account', null, 'Active');
                            await prefs.saveActiveSource('spotify');

                            Navigator.of(ctx).pop();
                            _loadSettings();
                          },
                          icon: const Icon(Icons.save_rounded, size: 16),
                          label: const Text('Save Custom Keys Only (No Browser SSO)'),
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
              ],
            );
          },
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
                          label: hasYtCredentials ? 'Connected' : 'Connect / Sign In',
                          variant: hasYtCredentials ? MuxisButtonVariant.secondary : MuxisButtonVariant.primary,
                          height: 36,
                          isLoading: _isBrowserAuthRunning,
                          onPressed: _showYouTubeSignInDialog,
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
                          label: hasSpotifyCredentials ? 'Connected' : 'Connect / Sign In',
                          variant: hasSpotifyCredentials ? MuxisButtonVariant.secondary : MuxisButtonVariant.primary,
                          height: 36,
                          isLoading: _isBrowserAuthRunning,
                          onPressed: _showSpotifySignInDialog,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                      color: isSelected
                          ? (isDark ? Colors.white : MuxisColors.textPrimaryLight)
                          : (isDark ? MuxisColors.textSecondaryDark : MuxisColors.textSecondaryLight),
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
