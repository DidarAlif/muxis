import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/muxis_colors.dart';
import '../../app/theme/muxis_gradients.dart';
import '../../core/audio/dsp/equalizer_node.dart';
import '../../core/audio/dsp/vocal_remover.dart';
import '../../shared/widgets/muxis_button.dart';
import '../../shared/widgets/muxis_liquid_surface.dart';

/// Mobile-first touch-friendly Audio Studio & 10-Band Parametric EQ bottom sheet.
/// Prevents cramped 10-column slider clipping and horizontal row overflows on phones.
class MobileAudioStudioSheet extends ConsumerWidget {
  const MobileAudioStudioSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const FractionallySizedBox(
        heightFactor: 0.88,
        child: MobileAudioStudioSheet(),
      ),
    );
  }

  static const List<String> _presets = [
    'Prismatic Neon',
    'Sub-Bass Thump',
    'Vocal Clarity',
    'Electronic & EDM',
    'Rock & Metal',
    'Jazz & Acoustic',
    'Lo-Fi Warmth',
    'Flat',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eq = ref.watch(equalizerProvider);
    final eqCtrl = ref.read(equalizerProvider.notifier);
    final studio = ref.watch(audioStudioProvider);
    final studioCtrl = ref.read(audioStudioProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = MuxisColors.accent(isDark);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? MuxisColors.deepSpace : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: MuxisColors.border(isDark)),
      ),
      child: Column(
        children: [
          // Drag handle & compact header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 12, 8),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: MuxisColors.textMuted(isDark).withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: MuxisGradients.auroraSpectrum,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.graphic_eq_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Audio Studio DSP',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: MuxisColors.textPrimary(isDark),
                            ),
                          ),
                          Text(
                            '10-Band EQ • Spatial Reverb • Pitch & Speed',
                            style: TextStyle(
                              fontSize: 11,
                              color: MuxisColors.textSecondary(isDark),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: eq.isEnabled,
                      activeColor: accent,
                      onChanged: (_) => eqCtrl.toggleEnabled(),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: MuxisColors.textMuted(isDark),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(height: 1, color: MuxisColors.border(isDark)),

          // Scrollable studio body
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
              children: [
                // 1. Preset strip
                Text(
                  'EQ PRESETS',
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: MuxisColors.textMuted(isDark),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _presets.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final name = _presets[i];
                      final selected = eq.activePreset == name;
                      return MuxisLiquidSurface(
                        onTap: () => eqCtrl.applyPreset(name),
                        enableGlass: false,
                        blurSigma: 0,
                        borderRadius: 16,
                        accentColor: accent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        colorOverride: selected
                            ? accent.withOpacity(isDark ? 0.24 : 0.16)
                            : MuxisColors.secondaryBg(isDark),
                        borderOverride: Border.all(
                          color: selected ? accent : MuxisColors.border(isDark),
                        ),
                        child: Center(
                          child: Text(
                            name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: MuxisColors.textPrimary(isDark),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 18),

                // 2. Scrollable 10-Band Vertical Rack
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? MuxisColors.obsidian.withOpacity(0.6)
                        : MuxisColors.secondarySurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: MuxisColors.border(isDark)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '10-Band Parametric EQ',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: MuxisColors.textPrimary(isDark),
                              ),
                            ),
                            TextButton(
                              onPressed: eqCtrl.resetToFlat,
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                              ),
                              child: Text(
                                'Reset Flat',
                                style: TextStyle(fontSize: 11, color: accent),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 182,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: eq.bands.length,
                          itemBuilder: (_, idx) {
                            final band = eq.bands[idx];
                            final label = band.frequencyHz >= 1000
                                ? '${(band.frequencyHz / 1000).toStringAsFixed(0)}k'
                                : '${band.frequencyHz}';
                            return SizedBox(
                              width: 52,
                              child: Column(
                                children: [
                                  Text(
                                    '${band.gainDb >= 0 ? '+' : ''}${band.gainDb.toStringAsFixed(1)}',
                                    style: TextStyle(
                                      fontFamily: 'JetBrains Mono',
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: band.gainDb.abs() > 0.2
                                          ? accent
                                          : MuxisColors.textMuted(isDark),
                                    ),
                                  ),
                                  Expanded(
                                    child: RotatedBox(
                                      quarterTurns: 3,
                                      child: Slider(
                                        value: band.gainDb,
                                        min: -12.0,
                                        max: 12.0,
                                        activeColor: accent,
                                        onChanged: eq.isEnabled
                                            ? (v) => eqCtrl.setBandGain(idx, v)
                                            : null,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    label,
                                    style: TextStyle(
                                      fontFamily: 'JetBrains Mono',
                                      fontSize: 10,
                                      color: MuxisColors.textSecondary(isDark),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // 3. Acoustic Enhancement Drives (stacked full-width mobile sliders)
                _MobileSliderCard(
                  isDark: isDark,
                  title: 'Acoustic Enhancement',
                  children: [
                    _LabeledSlider(
                      label: 'Bass Boost',
                      valueText: '${(eq.bassBoost * 100).round()}%',
                      value: eq.bassBoost,
                      min: 0.0,
                      max: 1.0,
                      accent: accent,
                      isDark: isDark,
                      onChanged: eq.isEnabled ? eqCtrl.setBassBoost : null,
                    ),
                    _LabeledSlider(
                      label: 'Treble Air',
                      valueText: '${(eq.trebleBoost * 100).round()}%',
                      value: eq.trebleBoost,
                      min: 0.0,
                      max: 1.0,
                      accent: MuxisColors.teal(isDark),
                      isDark: isDark,
                      onChanged: eq.isEnabled ? eqCtrl.setTrebleBoost : null,
                    ),
                    _LabeledSlider(
                      label: 'Spatial Stage',
                      valueText: '${(eq.virtualizer * 100).round()}%',
                      value: eq.virtualizer,
                      min: 0.0,
                      max: 1.0,
                      accent: MuxisColors.violet(isDark),
                      isDark: isDark,
                      onChanged: eq.isEnabled ? eqCtrl.setVirtualizer : null,
                    ),
                    _LabeledSlider(
                      label: 'Preamp Gain',
                      valueText:
                          '${eq.preampGainDb >= 0 ? '+' : ''}${eq.preampGainDb.toStringAsFixed(1)} dB',
                      value: eq.preampGainDb,
                      min: -6.0,
                      max: 6.0,
                      accent: MuxisColors.coral(isDark),
                      isDark: isDark,
                      onChanged: eq.isEnabled ? eqCtrl.setPreampGain : null,
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 4. Pitch, Speed & Creative FX
                _MobileSliderCard(
                  isDark: isDark,
                  title: 'Creative DSP & Reverb',
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _TogglePill(
                          label: 'Slowed + Reverb',
                          active: studio.isSlowedAndReverb,
                          accent: MuxisColors.violet(isDark),
                          isDark: isDark,
                          onTap: studioCtrl.toggleSlowedAndReverb,
                        ),
                        _TogglePill(
                          label: 'Karaoke / Vocal Cut',
                          active: studio.isKaraokeEnabled,
                          accent: MuxisColors.coral(isDark),
                          isDark: isDark,
                          onTap: studioCtrl.toggleKaraoke,
                        ),
                        _TogglePill(
                          label: 'Spatial Reverb',
                          active: studio.isReverbEnabled,
                          accent: MuxisColors.teal(isDark),
                          isDark: isDark,
                          onTap: studioCtrl.toggleReverb,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _LabeledSlider(
                      label: 'Playback Speed',
                      valueText: '${studio.playbackSpeed.toStringAsFixed(2)}x',
                      value: studio.playbackSpeed,
                      min: 0.5,
                      max: 2.0,
                      accent: accent,
                      isDark: isDark,
                      onChanged: studioCtrl.setPlaybackSpeed,
                    ),
                    _LabeledSlider(
                      label: 'Pitch Shift',
                      valueText:
                          '${studio.pitchShiftSemitones >= 0 ? '+' : ''}${studio.pitchShiftSemitones.toStringAsFixed(1)} st',
                      value: studio.pitchShiftSemitones,
                      min: -12.0,
                      max: 12.0,
                      accent: MuxisColors.coral(isDark),
                      isDark: isDark,
                      onChanged: studioCtrl.setPitchShift,
                    ),
                    if (studio.isKaraokeEnabled)
                      _LabeledSlider(
                        label: 'Vocal Attenuation',
                        valueText:
                            '${(studio.vocalAttenuation * 100).round()}%',
                        value: studio.vocalAttenuation,
                        min: 0.0,
                        max: 1.0,
                        accent: MuxisColors.coral(isDark),
                        isDark: isDark,
                        onChanged: studioCtrl.setVocalAttenuation,
                      ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: MuxisButton(
                        label: 'Reset Effects',
                        variant: MuxisButtonVariant.secondary,
                        height: 34,
                        onPressed: studioCtrl.resetAll,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileSliderCard extends StatelessWidget {
  final bool isDark;
  final String title;
  final List<Widget> children;

  const _MobileSliderCard({
    required this.isDark,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? MuxisColors.obsidian.withOpacity(0.55)
            : MuxisColors.secondarySurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MuxisColors.border(isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: MuxisColors.textPrimary(isDark),
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  final String label;
  final String valueText;
  final double value;
  final double min;
  final double max;
  final Color accent;
  final bool isDark;
  final ValueChanged<double>? onChanged;

  const _LabeledSlider({
    required this.label,
    required this.valueText,
    required this.value,
    required this.min,
    required this.max,
    required this.accent,
    required this.isDark,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: MuxisColors.textSecondary(isDark),
              ),
            ),
            Text(
              valueText,
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: accent,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 15),
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            activeColor: accent,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _TogglePill extends StatelessWidget {
  final String label;
  final bool active;
  final Color accent;
  final bool isDark;
  final VoidCallback onTap;

  const _TogglePill({
    required this.label,
    required this.active,
    required this.accent,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MuxisLiquidSurface(
      onTap: onTap,
      enableGlass: false,
      blurSigma: 0,
      borderRadius: 16,
      accentColor: accent,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      colorOverride: active
          ? accent.withOpacity(isDark ? 0.25 : 0.16)
          : MuxisColors.surface(isDark),
      borderOverride: Border.all(
        color: active ? accent : MuxisColors.border(isDark),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          color: MuxisColors.textPrimary(isDark),
        ),
      ),
    );
  }
}
