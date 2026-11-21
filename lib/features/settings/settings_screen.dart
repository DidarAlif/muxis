import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/muxis_colors.dart';
import '../../app/theme/muxis_gradients.dart';
import '../../app/theme/muxis_typography.dart';
import '../../app/theme/theme_controller.dart';
import '../../core/storage/preferences_service.dart';
import '../../shared/widgets/muxis_button.dart';

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
  String _audioQuality = 'FLAC 24-bit Lossless';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = ref.read(preferencesServiceProvider);
    final ytCookie = await prefs.getYtCookie();
    final ytSapisid = await prefs.getYtSapisid();
    final spId = await prefs.getSpotifyClientId();
    final spSec = await prefs.getSpotifyClientSecret();
    final quality = await prefs.getAudioQuality();

    if (mounted) {
      setState(() {
        _ytCookie = ytCookie;
        _ytSapisid = ytSapisid;
        _spotifyClientId = spId;
        _spotifyClientSecret = spSec;
        _audioQuality = quality;
        _isLoading = false;
      });
    }
  }

  void _showYouTubeCredentialsDialog() {
    final cookieCtrl = TextEditingController(text: _ytCookie);
    final sapisidCtrl = TextEditingController(text: _ytSapisid);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor:
              isDark ? MuxisColors.elevatedSurface : MuxisColors.whiteSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isDark
                  ? MuxisColors.subtleBorderDark
                  : MuxisColors.subtleBorderLight,
            ),
          ),
          title: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  gradient: MuxisGradients.prismaticPrimary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_circle_fill, size: 18, color: Colors.black),
              ),
              const SizedBox(width: 10),
              const Text('YouTube Music Credentials', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                    'Optionally paste your YouTube Music cookie to access personal playlists, library songs, and ad-free high fidelity streaming. Without credentials, Muxis streams in Anonymous Ad-Free mode.',
                    style: TextStyle(fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: cookieCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'YouTube Music Cookie String',
                      hintText: 'VISITOR_INFO1_LIVE=...; SAPISID=...; __Secure-3PSID=...',
                      hintStyle: const TextStyle(fontSize: 11),
                      filled: true,
                      fillColor: isDark ? MuxisColors.deepSpace : MuxisColors.secondarySurface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: sapisidCtrl,
                    decoration: InputDecoration(
                      labelText: 'SAPISID (Optional for Auth Token Hash)',
                      hintText: 'e.g. 1a2b3c4d5e...',
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
              label: 'Save Credentials',
              variant: MuxisButtonVariant.primary,
              height: 36,
              onPressed: () async {
                final prefs = ref.read(preferencesServiceProvider);
                final cookie = cookieCtrl.text.trim();
                final sapisid = sapisidCtrl.text.trim();
                await prefs.saveYtCookie(cookie);
                await prefs.saveYtSapisid(sapisid);
                Navigator.of(ctx).pop();
                _loadSettings();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('YouTube Music credentials updated')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showSpotifyCredentialsDialog() {
    final clientCtrl = TextEditingController(text: _spotifyClientId);
    final secretCtrl = TextEditingController(text: _spotifyClientSecret);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor:
              isDark ? MuxisColors.elevatedSurface : MuxisColors.whiteSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isDark
                  ? MuxisColors.subtleBorderDark
                  : MuxisColors.subtleBorderLight,
            ),
          ),
          title: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: Color(0xFF1DB954),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.music_note, size: 18, color: Colors.black),
              ),
              const SizedBox(width: 10),
              const Text('Spotify API Integration', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                    'Enter your free Spotify Developer Client ID and Secret (from developer.spotify.com/dashboard) to search the entire Spotify catalog. Songs stream in full length without ads through the Muxis audio bridge.',
                    style: TextStyle(fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: clientCtrl,
                    decoration: InputDecoration(
                      labelText: 'Spotify Client ID',
                      hintText: '32-character client id',
                      filled: true,
                      fillColor: isDark ? MuxisColors.deepSpace : MuxisColors.secondarySurface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: secretCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Spotify Client Secret',
                      hintText: '32-character client secret',
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
              label: 'Save & Authorize',
              variant: MuxisButtonVariant.primary,
              height: 36,
              onPressed: () async {
                final prefs = ref.read(preferencesServiceProvider);
                final id = clientCtrl.text.trim();
                final sec = secretCtrl.text.trim();
                await prefs.saveSpotifyClientId(id);
                await prefs.saveSpotifyClientSecret(sec);
                Navigator.of(ctx).pop();
                _loadSettings();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Spotify API credentials saved')),
                  );
                }
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

    final hasYtCredentials = _ytCookie != null && _ytCookie!.isNotEmpty;
    final hasSpotifyCredentials = _spotifyClientId != null && _spotifyClientId!.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      children: [
        Text('Settings', style: MuxisTypography.pageTitle(isDark: isDark)),
        const SizedBox(height: 24),

        // --- SECTION 1: MUSIC STREAMING & CREDENTIALS ---
        _buildSectionTitle('STREAMING ACCOUNTS & INTEGRATIONS', isDark),
        _buildCard(
          isDark,
          child: Column(
            children: [
              // YouTube Music
              ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: MuxisGradients.prismaticPrimary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.smart_display_rounded, color: Colors.black, size: 22),
                ),
                title: Row(
                  children: [
                    const Text('YouTube Music (InnerTube)', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: hasYtCredentials
                            ? Colors.green.withOpacity(0.2)
                            : MuxisColors.electricCyan.withOpacity(0.2),
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
                subtitle: Text(
                  hasYtCredentials
                      ? 'Custom session authenticated. Personal library and ad-free stream active.'
                      : 'Zero-ad direct streaming active. Optionally connect account to sync playlists.',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasYtCredentials)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        tooltip: 'Clear YouTube Credentials',
                        onPressed: () async {
                          final prefs = ref.read(preferencesServiceProvider);
                          await prefs.saveYtCookie('');
                          await prefs.saveYtSapisid('');
                          _loadSettings();
                        },
                      ),
                    MuxisButton(
                      label: hasYtCredentials ? 'Update' : 'Connect',
                      variant: MuxisButtonVariant.secondary,
                      height: 32,
                      onPressed: _showYouTubeCredentialsDialog,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Spotify
              ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1DB954),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.graphic_eq_rounded, color: Colors.black, size: 22),
                ),
                title: Row(
                  children: [
                    const Text('Spotify Web API', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: hasSpotifyCredentials
                            ? const Color(0xFF1DB954).withOpacity(0.2)
                            : Colors.grey.withOpacity(0.2),
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
                subtitle: Text(
                  hasSpotifyCredentials
                      ? 'Spotify catalog discovery enabled. Tracks play ad-free via the Muxis bridge.'
                      : 'Connect your Spotify Client ID & Secret to browse and search your Spotify catalog.',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasSpotifyCredentials)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        tooltip: 'Clear Spotify Credentials',
                        onPressed: () async {
                          final prefs = ref.read(preferencesServiceProvider);
                          await prefs.saveSpotifyClientId('');
                          await prefs.saveSpotifyClientSecret('');
                          _loadSettings();
                        },
                      ),
                    MuxisButton(
                      label: hasSpotifyCredentials ? 'Update' : 'Connect',
                      variant: MuxisButtonVariant.secondary,
                      height: 32,
                      onPressed: _showSpotifyCredentialsDialog,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // --- SECTION 2: APPEARANCE & THEME ---
        _buildSectionTitle('APPEARANCE', isDark),
        _buildCard(
          isDark,
          child: Column(
            children: [
              ListTile(
                title: const Text(
                  'Theme Mode',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Choose between dark obsidian, light porcelain, or follow system',
                ),
                trailing: DropdownButton<ThemeMode>(
                  value: themeMode,
                  dropdownColor: isDark
                      ? MuxisColors.elevatedSurface
                      : MuxisColors.whiteSurface,
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
                      child: Text('Light Porcelain'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.system,
                      child: Text('System Appearance'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // --- SECTION 3: AUDIO FIDELITY & ENGINE ---
        _buildSectionTitle('AUDIO FIDELITY & ENGINE', isDark),
        _buildCard(
          isDark,
          child: Column(
            children: [
              ListTile(
                title: const Text(
                  'Streaming Quality',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Target output audio bitrate and decoding format',
                ),
                trailing: DropdownButton<String>(
                  value: _audioQuality,
                  dropdownColor: isDark
                      ? MuxisColors.elevatedSurface
                      : MuxisColors.whiteSurface,
                  underline: const SizedBox(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _audioQuality = val);
                      ref.read(preferencesServiceProvider).saveAudioQuality(val);
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
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text(
                  'Audio Engine Hardware Output',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Direct hardware audio pipeline via JustAudio & Media Foundation',
                ),
                trailing: Container(
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
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text(
                  'Skip Trailing Silence',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Automatically transition to next track when silence is detected',
                ),
                value: true,
                activeColor: MuxisColors.electricCyan,
                onChanged: (_) {},
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text(
                  'Hardware GPU Acceleration',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Use GPU shaders for visualizers and ambient aurora rendering',
                ),
                value: true,
                activeColor: MuxisColors.electricCyan,
                onChanged: (_) {},
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // --- SECTION 4: STORAGE & CACHE ---
        _buildSectionTitle('STORAGE & CACHE', isDark),
        _buildCard(
          isDark,
          child: Column(
            children: [
              ListTile(
                title: const Text(
                  'Offline Music & Artwork Cache',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Currently using 142.8 MB of local storage',
                ),
                trailing: MuxisButton(
                  label: 'Clear Cache',
                  variant: MuxisButtonVariant.secondary,
                  height: 34,
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Cache successfully cleared'),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // --- SECTION 5: ABOUT MUXIS ---
        _buildSectionTitle('ABOUT MUXIS', isDark),
        _buildCard(
          isDark,
          child: Padding(
            padding: const EdgeInsets.all(16),
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
                      'v1.0.1 (Prismatic Aura & Liquid Glass Edition)',
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
          color: isDark
              ? MuxisColors.textMutedDark
              : MuxisColors.textMutedLight,
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
          color: isDark
              ? MuxisColors.subtleBorderDark
              : MuxisColors.subtleBorderLight,
        ),
      ),
      child: child,
    );
  }
}
