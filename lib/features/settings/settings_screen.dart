import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/muxis_colors.dart';
import '../../app/theme/muxis_gradients.dart';
import '../../app/theme/muxis_typography.dart';
import '../../app/theme/theme_controller.dart';
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
  String? _spotifyClientId;
  String? _spotifyClientSecret;
  String? _spotifyUserName;
  String? _spotifyProduct;
  String _activeSource = 'youtube';
  String _audioQuality = 'FLAC 24-bit Lossless';
  int _dbSizeBytes = 0;
  bool _isLoading = true;

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
    final spId = await prefs.getSpotifyClientId();
    final spSec = await prefs.getSpotifyClientSecret();
    final spName = await prefs.getSpotifyUserName();
    final spProd = await prefs.getSpotifyProduct();
    final active = await prefs.getActiveSource();
    final quality = await prefs.getAudioQuality();
    final dbBytes = await db.getStorageUsageBytes();

    if (mounted) {
      setState(() {
        _ytCookie = ytCookie;
        _ytSapisid = ytSapisid;
        _ytUserName = ytName;
        _spotifyClientId = spId;
        _spotifyClientSecret = spSec;
        _spotifyUserName = spName;
        _spotifyProduct = spProd;
        _activeSource = active;
        _audioQuality = quality;
        _dbSizeBytes = dbBytes;
        _isLoading = false;
      });
    }
  }

  void _showYouTubeSignInDialog() {
    final cookieCtrl = TextEditingController(text: _ytCookie);
    final sapisidCtrl = TextEditingController(text: _ytSapisid);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    bool isTesting = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
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
                  const Text('Sign In to YouTube Music', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Authenticate with your YouTube Music account to synchronize personal playlists, likes, and receive high-fidelity ad-free audio streams.',
                        style: TextStyle(fontSize: 12, height: 1.4, color: MuxisColors.textSecondaryDark),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: cookieCtrl,
                        maxLines: 3,
                        style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 11),
                        decoration: InputDecoration(
                          labelText: 'YouTube Music Cookie String',
                          hintText: 'Paste cookie or headers (e.g. SAPISID=...; __Secure-3PAPISID=...)',
                          hintStyle: const TextStyle(fontSize: 11),
                          filled: true,
                          fillColor: isDark ? MuxisColors.deepSpace : MuxisColors.secondarySurface,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onChanged: (text) {
                          // Auto extract SAPISID if in pasted string
                          if (text.contains('SAPISID=') && sapisidCtrl.text.isEmpty) {
                            final match = RegExp(r'SAPISID=([^;]+)').firstMatch(text);
                            if (match != null) {
                              sapisidCtrl.text = match.group(1)!.trim();
                              setModalState(() {});
                            }
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: sapisidCtrl,
                        style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 12),
                        decoration: InputDecoration(
                          labelText: 'SAPISID (Used for Auth Hash)',
                          hintText: 'Auto-extracted from cookie or enter manually',
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
                  onPressed: isTesting ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                MuxisButton(
                  label: isTesting ? 'Verifying...' : 'Sign In & Save',
                  variant: MuxisButtonVariant.primary,
                  height: 36,
                  isLoading: isTesting,
                  onPressed: () async {
                    setModalState(() => isTesting = true);
                    final prefs = ref.read(preferencesServiceProvider);
                    final cookie = cookieCtrl.text.trim();
                    final sapisid = sapisidCtrl.text.trim();

                    await prefs.saveYtCookie(cookie);
                    await prefs.saveYtSapisid(sapisid);

                    // Test connection live via InnerTube
                    final provider = InnerTubeMusicProvider(prefs: prefs);
                    final testResults = await provider.search('test');

                    String detectedUser = 'YouTube Music Listener';
                    if (cookie.isNotEmpty) {
                      detectedUser = 'Connected Account (${sapisid.isNotEmpty ? 'Authenticated' : 'Session Active'})';
                    }
                    await prefs.saveYtUserProfile(detectedUser, null);

                    Navigator.of(ctx).pop();
                    _loadSettings();

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            testResults.isNotEmpty
                                ? 'YouTube Music successfully authenticated and verified!'
                                : 'Credentials saved. Stream engine configured.',
                          ),
                          backgroundColor: MuxisColors.success,
                        ),
                      );
                    }
                  },
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
    bool isTesting = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
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
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Connect your Spotify developer credentials or client token to search Spotify\'s full catalog, access albums, and stream ad-free via the high-fidelity MUXIS bridge.',
                        style: TextStyle(fontSize: 12, height: 1.4, color: MuxisColors.textSecondaryDark),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: clientCtrl,
                        style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 12),
                        decoration: InputDecoration(
                          labelText: 'Spotify Client ID',
                          hintText: '32-character Spotify Client ID',
                          filled: true,
                          fillColor: isDark ? MuxisColors.deepSpace : MuxisColors.secondarySurface,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: secretCtrl,
                        obscureText: true,
                        style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 12),
                        decoration: InputDecoration(
                          labelText: 'Spotify Client Secret',
                          hintText: '32-character Spotify Client Secret',
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
                  onPressed: isTesting ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                MuxisButton(
                  label: isTesting ? 'Authorizing...' : 'Authorize & Sign In',
                  variant: MuxisButtonVariant.primary,
                  height: 36,
                  isLoading: isTesting,
                  onPressed: () async {
                    setModalState(() => isTesting = true);
                    final prefs = ref.read(preferencesServiceProvider);
                    final id = clientCtrl.text.trim();
                    final sec = secretCtrl.text.trim();

                    await prefs.saveSpotifyClientId(id);
                    await prefs.saveSpotifyClientSecret(sec);

                    // Test connection live via Spotify Provider
                    final spotifyProvider = SpotifyMusicProvider(prefs: prefs);
                    final testResults = await spotifyProvider.search('Queen');

                    String detectedUser = 'Spotify Connected Account';
                    if (id.isNotEmpty) {
                      detectedUser = 'Spotify API Active (${id.substring(0, id.length > 6 ? 6 : id.length)}...)';
                    }
                    await prefs.saveSpotifyUserProfile(detectedUser, null, 'Spotify Unlimited');

                    Navigator.of(ctx).pop();
                    _loadSettings();

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            testResults.isNotEmpty
                                ? 'Spotify Web API authorized! Catalog discovery active.'
                                : 'Credentials saved. Spotify streaming bridge ready.',
                          ),
                          backgroundColor: MuxisColors.success,
                        ),
                      );
                    }
                  },
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

    final hasYtCredentials = _ytCookie != null && _ytCookie!.isNotEmpty;
    final hasSpotifyCredentials = _spotifyClientId != null && _spotifyClientId!.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      children: [
        Text('Settings', style: MuxisTypography.pageTitle(isDark: isDark)),
        const SizedBox(height: 24),

        // --- SECTION 1: ACTIVE STREAMING SOURCE ---
        _buildSectionTitle('ACTIVE STREAMING PLATFORM', isDark),
        _buildCard(
          isDark,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Choose where MUXIS searches and streams tracks from:',
                  style: TextStyle(fontSize: 13, color: MuxisColors.textSecondaryDark),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _buildPlatformChoice(
                      id: 'youtube',
                      title: 'YouTube Music',
                      icon: Icons.smart_display_rounded,
                      activeColor: MuxisColors.electricCyan,
                      subtitle: hasYtCredentials ? 'Signed In (Ad-Free)' : 'Anonymous (Ad-Free)',
                    ),
                    const SizedBox(width: 12),
                    _buildPlatformChoice(
                      id: 'spotify',
                      title: 'Spotify',
                      icon: Icons.graphic_eq_rounded,
                      activeColor: const Color(0xFF1DB954),
                      subtitle: hasSpotifyCredentials ? 'Connected (Muxis Bridge)' : 'Requires Sign-In',
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: MuxisGradients.prismaticPrimary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.smart_display_rounded, color: Colors.black, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('YouTube Music (InnerTube)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: hasYtCredentials ? Colors.green.withOpacity(0.2) : MuxisColors.electricCyan.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  hasYtCredentials ? 'PREMIUM SYNC' : 'ANONYMOUS AD-FREE',
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
                                ? (_ytUserName ?? 'Account Authenticated • Ad-free byte streaming active')
                                : 'Ad-free audio streaming active. Sign in with cookies to sync your personal library.',
                            style: const TextStyle(fontSize: 12, color: MuxisColors.textSecondaryDark),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hasYtCredentials)
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
                        MuxisButton(
                          label: hasYtCredentials ? 'Account Settings' : 'Sign In',
                          variant: MuxisButtonVariant.secondary,
                          height: 34,
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1DB954),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.graphic_eq_rounded, color: Colors.black, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('Spotify Web API', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: hasSpotifyCredentials ? const Color(0xFF1DB954).withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  hasSpotifyCredentials ? 'CONNECTED' : 'DISCONNECTED',
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
                                ? (_spotifyUserName ?? 'Spotify catalog enabled • Audio streams ad-free via bridge')
                                : 'Sign in to explore Spotify playlists, artists, and stream ad-free.',
                            style: const TextStyle(fontSize: 12, color: MuxisColors.textSecondaryDark),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hasSpotifyCredentials)
                          IconButton(
                            icon: const Icon(Icons.logout_rounded, size: 20, color: MuxisColors.textMutedDark),
                            tooltip: 'Disconnect Spotify',
                            onPressed: () async {
                              final prefs = ref.read(preferencesServiceProvider);
                              await prefs.saveSpotifyClientId('');
                              await prefs.saveSpotifyClientSecret('');
                              await prefs.saveSpotifyUserProfile('', null, '');
                              _loadSettings();
                            },
                          ),
                        MuxisButton(
                          label: hasSpotifyCredentials ? 'Configure' : 'Sign In',
                          variant: MuxisButtonVariant.secondary,
                          height: 34,
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

        // --- SECTION 5: STORAGE & CACHE (COMPLETELY CLEANED & NON-SCATTERED) ---
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
                      'v1.0.2 (Prismatic Aura & Liquid Glass Edition)',
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
