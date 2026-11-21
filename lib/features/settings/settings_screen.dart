import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/muxis_colors.dart';
import '../../app/theme/muxis_typography.dart';
import '../../app/theme/theme_controller.dart';
import '../../shared/widgets/muxis_button.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeControllerProvider);
    final themeNotifier = ref.read(themeControllerProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      children: [
        Text('Settings', style: MuxisTypography.pageTitle(isDark: isDark)),
        const SizedBox(height: 24),

        // --- SECTION 1: APPEARANCE & THEME ---
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

        // --- SECTION 2: AUDIO FIDELITY & STREAMING ---
        _buildSectionTitle('AUDIO FIDELITY', isDark),
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
                  value: 'FLAC 24-bit Lossless',
                  dropdownColor: isDark
                      ? MuxisColors.elevatedSurface
                      : MuxisColors.whiteSurface,
                  underline: const SizedBox(),
                  onChanged: (_) {},
                  items: const [
                    DropdownMenuItem(
                      value: 'FLAC 24-bit Lossless',
                      child: Text('FLAC 24-bit Lossless'),
                    ),
                    DropdownMenuItem(
                      value: '320 kbps High Quality',
                      child: Text('320 kbps High Quality'),
                    ),
                    DropdownMenuItem(
                      value: '192 kbps Standard',
                      child: Text('192 kbps Standard'),
                    ),
                    DropdownMenuItem(
                      value: 'Data Saver (96 kbps)',
                      child: Text('Data Saver (96 kbps)'),
                    ),
                  ],
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
                  'Hardware Acceleration',
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

        // --- SECTION 3: STORAGE & CACHE ---
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

        // --- SECTION 4: ABOUT MUXIS ---
        _buildSectionTitle('ABOUT MUXIS', isDark),
        _buildCard(
          isDark,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAlignment.start,
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
                      'v1.0.0 (Prismatic Aura Edition)',
                      style: TextStyle(
                        fontSize: 12,
                        color: MuxisColors.textMutedDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Cross-Platform Music Streaming & Local Player Application designed with the Prismatic Aura design system. Combines desktop-grade audio fidelity, high-precision scrub controls, synced lyrics, and advanced DSP effects.',
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
