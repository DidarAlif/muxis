import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/muxis_colors.dart';
import '../../app/theme/muxis_typography.dart';
import '../../core/audio/dsp/equalizer_node.dart';
import '../../core/audio/dsp/vocal_remover.dart';
import '../../shared/widgets/muxis_button.dart';
import '../../shared/widgets/muxis_slider.dart';

class AudioStudioSheet extends ConsumerWidget {
  const AudioStudioSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eq = ref.watch(equalizerProvider);
    final eqNotifier = ref.read(equalizerProvider.notifier);

    final studio = ref.watch(audioStudioProvider);
    final studioNotifier = ref.read(audioStudioProvider.notifier);

    final isDark = Theme.of(context).brightness == Brightness.dark;

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
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: MuxisColors.elevatedSurface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: MuxisColors.subtleBorderDark,
                          ),
                        ),
                        child: const Icon(
                          Icons.tune_rounded,
                          size: 22,
                          color: MuxisColors.electricCyan,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AUDIO STUDIO & DSP',
                            style: MuxisTypography.sectionHeading(
                              isDark: isDark,
                            ),
                          ),
                          const Text(
                            'Parametric Equalizer, Vocal Reducer & Spatial Acoustics',
                            style: TextStyle(
                              fontSize: 12,
                              color: MuxisColors.textMutedDark,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Content
              Expanded(
                child: ListView(
                  children: [
                    // --- SECTION 1: 5-BAND EQUALIZER ---
                    _buildSectionHeader(
                      '5-BAND MASTER EQUALIZER',
                      isDark,
                      eq.isEnabled,
                      () => eqNotifier.toggleEnabled(),
                    ),
                    const SizedBox(height: 12),

                    // Preset Selector Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children:
                            [
                                  'Prismatic Aura',
                                  'Bass Boost',
                                  'Vocal Clarity',
                                  'Electronic',
                                  'Flat',
                                ]
                                .map(
                                  (p) => Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                      label: Text(
                                        p,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      selected: eq.activePreset == p,
                                      selectedColor: MuxisColors.electricCyan
                                          .withOpacity(0.2),
                                      onSelected: (_) =>
                                          eqNotifier.applyPreset(p),
                                    ),
                                  ),
                                )
                                .toList(),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Vertical Sliders Row
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark
                            ? MuxisColors.elevatedSurface
                            : MuxisColors.secondarySurface,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: List.generate(eq.bands.length, (i) {
                          final band = eq.bands[i];
                          return Column(
                            children: [
                              Text(
                                '${band.gainDb.toStringAsFixed(1)}dB',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontFamily: 'JetBrains Mono',
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 120,
                                child: RotatedBox(
                                  quarterTurns: 3,
                                  child: Slider(
                                    value: band.gainDb,
                                    min: -12.0,
                                    max: 12.0,
                                    activeColor: MuxisColors.electricCyan,
                                    onChanged: eq.isEnabled
                                        ? (val) =>
                                              eqNotifier.setBandGain(i, val)
                                        : null,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _formatFreq(band.frequencyHz),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // --- SECTION 2: KARAOKE VOCAL REDUCTION (CENTER EXTRACTOR) ---
                    _buildSectionHeader(
                      'KARAOKE & VOCAL ISOLATION',
                      isDark,
                      studio.isKaraokeEnabled,
                      () => studioNotifier.toggleKaraoke(),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Phase-cancellation filter that attenuates centered lead vocals in stereo recordings.',
                      style: TextStyle(
                        fontSize: 12,
                        color: MuxisColors.textMutedDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text(
                          'Vocal Attenuation: ',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${(studio.vocalAttenuation * 100).toInt()}%',
                          style: const TextStyle(
                            fontFamily: 'JetBrains Mono',
                            color: MuxisColors.electricCyan,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: MuxisSlider(
                            value: studio.vocalAttenuation,
                            onChanged: studio.isKaraokeEnabled
                                ? (val) =>
                                      studioNotifier.setVocalAttenuation(val)
                                : (_) {},
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // --- SECTION 3: TEMPO & PITCH (BUNGEE DSP) ---
                    _buildSectionHeader(
                      'PITCH & TEMPO STRETCHING',
                      isDark,
                      true,
                      null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        MuxisButton(
                          label: 'Slowed + Reverb Preset',
                          icon: const Icon(Icons.waves_rounded, size: 16),
                          variant: studio.isSlowedAndReverb
                              ? MuxisButtonVariant.primary
                              : MuxisButtonVariant.secondary,
                          height: 36,
                          onPressed: () =>
                              studioNotifier.toggleSlowedAndReverb(),
                        ),
                        const SizedBox(width: 12),
                        TextButton(
                          onPressed: () => studioNotifier.resetAll(),
                          child: const Text(
                            'Reset All',
                            style: TextStyle(color: MuxisColors.error),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    bool isDark,
    bool isEnabled,
    VoidCallback? onToggle,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'JetBrains Mono',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: MuxisColors.electricCyan,
          ),
        ),
        if (onToggle != null)
          Switch(
            value: isEnabled,
            activeColor: MuxisColors.electricCyan,
            onChanged: (_) => onToggle(),
          ),
      ],
    );
  }

  String _formatFreq(int hz) {
    if (hz >= 1000) {
      return '${(hz / 1000).toStringAsFixed(1)}k';
    }
    return '${hz}Hz';
  }
}
