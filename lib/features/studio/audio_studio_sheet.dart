import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/muxis_colors.dart';
import '../../app/theme/muxis_typography.dart';
import '../../core/audio/audio_playback_service.dart';
import '../../core/audio/dsp/equalizer_node.dart';
import '../../core/audio/dsp/vocal_remover.dart';
import '../../shared/widgets/muxis_button.dart';
import '../../shared/widgets/muxis_scroll_view.dart';
import '../../shared/widgets/muxis_slider.dart';

class AudioStudioSheet extends ConsumerStatefulWidget {
  const AudioStudioSheet({super.key});

  @override
  ConsumerState<AudioStudioSheet> createState() => _AudioStudioSheetState();
}

class _AudioStudioSheetState extends ConsumerState<AudioStudioSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final eq = ref.watch(equalizerProvider);
    final eqNotifier = ref.read(equalizerProvider.notifier);

    final studio = ref.watch(audioStudioProvider);
    final studioNotifier = ref.read(audioStudioProvider.notifier);

    final playback = ref.watch(playbackServiceProvider);
    final isPlaying = playback.isPlaying;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final presets = [
      'Prismatic Neon',
      'Sub-Bass Thump',
      'Vocal Clarity',
      'Electronic & EDM',
      'Rock & Metal',
      'Jazz & Acoustic',
      'Lo-Fi Warmth',
      'Flat',
    ];

    return Dialog(
      backgroundColor: isDark ? MuxisColors.obsidian : MuxisColors.whiteSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: isDark
              ? MuxisColors.subtleBorderDark
              : MuxisColors.subtleBorderLight,
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with Neon Pulse Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark
                              ? MuxisColors.elevatedSurface
                              : MuxisColors.secondarySurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: MuxisColors.accent(isDark).withOpacity(0.3),
                          ),
                          boxShadow: [
                            if (eq.isEnabled)
                              BoxShadow(
                                color: MuxisColors.accent(isDark)
                                    .withOpacity(0.2),
                                blurRadius: 12,
                                spreadRadius: 1,
                              ),
                          ],
                        ),
                        child: Icon(
                          Icons.equalizer_rounded,
                          size: 24,
                          color: MuxisColors.accent(isDark),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'AUDIO STUDIO & 10-BAND DSP',
                                style: MuxisTypography.sectionHeading(
                                  isDark: isDark,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: eq.isEnabled
                                      ? MuxisColors.accent(isDark)
                                            .withOpacity(0.15)
                                      : Colors.grey.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: eq.isEnabled
                                        ? MuxisColors.accent(isDark)
                                              .withOpacity(0.4)
                                        : Colors.grey.withOpacity(0.3),
                                  ),
                                ),
                                child: Text(
                                  eq.isEnabled ? 'ACTIVE' : 'BYPASS',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.0,
                                    color: eq.isEnabled
                                        ? MuxisColors.accent(isDark)
                                        : Colors.grey,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Parametric Curve, Sub-Bass Saturation, Spatial Virtualizer & Pitch DSP',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? MuxisColors.textMutedDark
                                  : MuxisColors.textMutedLight,
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
              const SizedBox(height: 16),

              // Content Body
              Expanded(
                child: MuxisScrollView(
                  padding: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- SECTION 1: INTERACTIVE FREQUENCY RESPONSE VISUALIZER ---
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          height: 130,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: isDark
                                ? MuxisColors.deepSpace
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark
                                  ? MuxisColors.subtleBorderDark
                                  : MuxisColors.subtleBorderLight,
                            ),
                          ),
                          child: AnimatedBuilder(
                            animation: _animController,
                            builder: (context, _) {
                              return CustomPaint(
                                painter: _FrequencyCurvePainter(
                                  bands: eq.bands,
                                  isEnabled: eq.isEnabled,
                                  isDark: isDark,
                                  animPhase: _animController.value,
                                  isPlaying: isPlaying,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // --- SECTION 2: STUDIO PRESET CHIPS ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'STUDIO PRESETS',
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              color: MuxisColors.accent(isDark),
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                'Master Bypass',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? MuxisColors.textSecondaryDark
                                      : MuxisColors.textSecondaryLight,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Switch(
                                value: eq.isEnabled,
                                activeColor: MuxisColors.accent(isDark),
                                onChanged: (_) => eqNotifier.toggleEnabled(),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: presets.map((p) {
                          final isSelected = eq.activePreset == p;
                          return ChoiceChip(
                            label: Text(
                              p,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? (isDark ? Colors.black : Colors.white)
                                    : (isDark
                                          ? MuxisColors.textPrimaryDark
                                          : MuxisColors.textPrimaryLight),
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: MuxisColors.accent(isDark),
                            backgroundColor: isDark
                                ? MuxisColors.elevatedSurface
                                : MuxisColors.secondarySurface,
                            side: BorderSide(
                              color: isSelected
                                  ? MuxisColors.accent(isDark)
                                  : (isDark
                                        ? MuxisColors.subtleBorderDark
                                        : MuxisColors.subtleBorderLight),
                            ),
                            onSelected: (_) => eqNotifier.applyPreset(p),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 18),

                      // --- SECTION 3: 10-BAND SLIDERS RACK ---
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 18,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? MuxisColors.elevatedSurface
                              : MuxisColors.whiteSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark
                                ? MuxisColors.subtleBorderDark
                                : MuxisColors.subtleBorderLight,
                          ),
                          boxShadow: isDark
                              ? null
                              : const [
                                  BoxShadow(
                                    color: Color(0x080F172A),
                                    blurRadius: 16,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(eq.bands.length, (i) {
                            final band = eq.bands[i];
                            final isBoost = band.gainDb > 0.05;
                            final isCut = band.gainDb < -0.05;

                            return Column(
                              children: [
                                // Gain dB readout
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isBoost
                                        ? MuxisColors.accent(isDark)
                                              .withOpacity(0.15)
                                        : (isCut
                                              ? Colors.red.withOpacity(0.12)
                                              : Colors.transparent),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${band.gainDb >= 0 ? '+' : ''}${band.gainDb.toStringAsFixed(1)}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontFamily: 'JetBrains Mono',
                                      fontWeight: isBoost || isCut
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isBoost
                                          ? MuxisColors.accent(isDark)
                                          : (isCut
                                                ? Colors.redAccent
                                                : (isDark
                                                      ? MuxisColors
                                                            .textMutedDark
                                                      : MuxisColors
                                                            .textMutedLight)),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),

                                // Vertical Slider
                                SizedBox(
                                  height: 130,
                                  child: RotatedBox(
                                    quarterTurns: 3,
                                    child: SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        trackHeight: 3.5,
                                        thumbShape: const RoundSliderThumbShape(
                                          enabledThumbRadius: 6,
                                        ),
                                      ),
                                      child: Slider(
                                        value: band.gainDb,
                                        min: -12.0,
                                        max: 12.0,
                                        activeColor: MuxisColors.accent(isDark),
                                        inactiveColor: isDark
                                            ? MuxisColors.subtleBorderDark
                                            : MuxisColors.subtleBorderLight,
                                        onChanged: eq.isEnabled
                                            ? (val) =>
                                                  eqNotifier.setBandGain(i, val)
                                            : null,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),

                                // Frequency Label
                                Text(
                                  _formatFreq(band.frequencyHz),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'JetBrains Mono',
                                    color: isDark
                                        ? MuxisColors.textPrimaryDark
                                        : MuxisColors.textPrimaryLight,
                                  ),
                                ),
                              ],
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // --- SECTION 4: ACOUSTIC MASTER DRIVES ---
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? MuxisColors.deepSpace
                              : MuxisColors.secondarySurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark
                                ? MuxisColors.subtleBorderDark
                                : MuxisColors.subtleBorderLight,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ACOUSTIC ENHANCEMENT DRIVES',
                              style: TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                                color: MuxisColors.accent(isDark),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                // Sub-Bass Drive
                                Expanded(
                                  child: _buildDriveSlider(
                                    label: 'SUB-BASS DRIVE',
                                    value: eq.bassBoost,
                                    display: '${(eq.bassBoost * 100).toInt()}%',
                                    icon: Icons.speaker_group_rounded,
                                    isDark: isDark,
                                    onChanged: (v) =>
                                        eqNotifier.setBassBoost(v),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Treble Air
                                Expanded(
                                  child: _buildDriveSlider(
                                    label: 'TREBLE AIR',
                                    value: eq.trebleBoost,
                                    display:
                                        '${(eq.trebleBoost * 100).toInt()}%',
                                    icon: Icons.blur_linear_rounded,
                                    isDark: isDark,
                                    onChanged: (v) =>
                                        eqNotifier.setTrebleBoost(v),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Pre-Amp Gain
                                Expanded(
                                  child: _buildDriveSlider(
                                    label: 'PRE-AMP GAIN',
                                    value: (eq.preampGainDb + 6.0) / 12.0,
                                    display:
                                        '${eq.preampGainDb >= 0 ? '+' : ''}${eq.preampGainDb.toStringAsFixed(1)} dB',
                                    icon: Icons.speed_rounded,
                                    isDark: isDark,
                                    onChanged: (v) => eqNotifier.setPreampGain(
                                      (v * 12.0) - 6.0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // --- SECTION 5: PITCH & TEMPO STRETCHING (REAL-TIME ENGINE) ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'PITCH & TEMPO (REAL-TIME MODULATION)',
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              color: MuxisColors.accent(isDark),
                            ),
                          ),
                          if (studio.playbackSpeed != 1.0 ||
                              studio.pitchShiftSemitones != 0.0)
                            TextButton(
                              onPressed: () => studioNotifier.resetAll(),
                              child: const Text('Reset Pitch/Speed'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      Row(
                        children: [
                          // Playback Speed Slider
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Speed:',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      '${studio.playbackSpeed.toStringAsFixed(2)}x',
                                      style: TextStyle(
                                        fontFamily: 'JetBrains Mono',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: MuxisColors.accent(isDark),
                                      ),
                                    ),
                                  ],
                                ),
                                Slider(
                                  value: studio.playbackSpeed,
                                  min: 0.5,
                                  max: 2.0,
                                  divisions: 30,
                                  activeColor: MuxisColors.accent(isDark),
                                  onChanged: (v) =>
                                      studioNotifier.setPlaybackSpeed(v),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),

                          // Pitch Shift Slider
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Pitch:',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      '${studio.pitchShiftSemitones >= 0 ? '+' : ''}${studio.pitchShiftSemitones.toStringAsFixed(1)} semitones',
                                      style: TextStyle(
                                        fontFamily: 'JetBrains Mono',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: MuxisColors.accent(isDark),
                                      ),
                                    ),
                                  ],
                                ),
                                Slider(
                                  value: studio.pitchShiftSemitones,
                                  min: -12.0,
                                  max: 12.0,
                                  divisions: 48,
                                  activeColor: MuxisColors.accent(isDark),
                                  onChanged: (v) =>
                                      studioNotifier.setPitchShift(v),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Quick Action Presets (Slowed + Reverb, Vocal Remover)
                      Row(
                        children: [
                          MuxisButton(
                            label: 'Slowed + Reverb Preset',
                            icon: const Icon(Icons.waves_rounded, size: 16),
                            variant: studio.isSlowedAndReverb
                                ? MuxisButtonVariant.primary
                                : MuxisButtonVariant.secondary,
                            height: 38,
                            onPressed: () =>
                                studioNotifier.toggleSlowedAndReverb(),
                          ),
                          const SizedBox(width: 12),
                          MuxisButton(
                            label: 'Reset All DSP to Default',
                            variant: MuxisButtonVariant.ghost,
                            height: 38,
                            onPressed: () {
                              eqNotifier.resetToFlat();
                              studioNotifier.resetAll();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDriveSlider({
    required String label,
    required double value,
    required String display,
    required IconData icon,
    required bool isDark,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: MuxisColors.accent(isDark)),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'JetBrains Mono',
                  ),
                ),
              ],
            ),
            Text(
              display,
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'JetBrains Mono',
                fontWeight: FontWeight.w700,
                color: MuxisColors.accent(isDark),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
          ),
          child: Slider(
            value: value.clamp(0.0, 1.0),
            activeColor: MuxisColors.accent(isDark),
            inactiveColor: isDark
                ? MuxisColors.subtleBorderDark
                : MuxisColors.subtleBorderLight,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  String _formatFreq(int hz) {
    if (hz >= 1000) {
      return '${(hz / 1000).toInt()}k';
    }
    return '$hz';
  }
}

/// CustomPainter for the Continuous Frequency Spline Curve and Background Spectrum
class _FrequencyCurvePainter extends CustomPainter {
  final List<EqualizerBand> bands;
  final bool isEnabled;
  final bool isDark;
  final double animPhase;
  final bool isPlaying;

  _FrequencyCurvePainter({
    required this.bands,
    required this.isEnabled,
    required this.isDark,
    required this.animPhase,
    required this.isPlaying,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (bands.isEmpty) return;

    final width = size.width;
    final height = size.height;
    final zeroY = height * 0.5;

    // 1. Grid reference lines (-12dB, 0dB, +12dB)
    final gridPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withOpacity(0.06)
      ..strokeWidth = 1.0;

    canvas.drawLine(
      Offset(0, height * 0.15),
      Offset(width, height * 0.15),
      gridPaint,
    );
    canvas.drawLine(Offset(0, zeroY), Offset(width, zeroY), gridPaint);
    canvas.drawLine(
      Offset(0, height * 0.85),
      Offset(width, height * 0.85),
      gridPaint,
    );

    // 2. Animated Spectrum Bars (Pulsing background bars)
    if (isPlaying && isEnabled) {
      final barCount = 28;
      final barWidth = width / barCount;
      final spectrumPaint = Paint()
        ..color = (isDark ? MuxisColors.neonGreen : MuxisColors.neonGreenLight)
            .withOpacity(0.06);

      for (int i = 0; i < barCount; i++) {
        final t = i / barCount;
        final wave = sin((t * 4 * pi) + (animPhase * 2 * pi)).abs();
        final barHeight = (height * 0.6) * wave;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              i * barWidth + 2,
              height - barHeight - 4,
              barWidth - 4,
              barHeight,
            ),
            const Radius.circular(3),
          ),
          spectrumPaint,
        );
      }
    }

    // 3. Compute Band Coordinates
    final points = <Offset>[];
    final paddingX = width * 0.05;
    final effectiveWidth = width - (paddingX * 2);

    for (int i = 0; i < bands.length; i++) {
      final x = paddingX + (i / (bands.length - 1)) * effectiveWidth;
      final gain = isEnabled ? bands[i].gainDb : 0.0;
      // gain is -12 to +12. Map to 0.85*height to 0.15*height
      final normalizedGain = (gain.clamp(-12.0, 12.0) + 12.0) / 24.0;
      final y = height * (0.85 - (normalizedGain * 0.70));
      points.add(Offset(x, y));
    }

    // 4. Draw Smooth Spline Path
    final path = Path();
    path.moveTo(0, zeroY);
    path.lineTo(points.first.dx, points.first.dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final controlPoint1 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p0.dy);
      final controlPoint2 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p1.dy);
      path.cubicTo(
        controlPoint1.dx,
        controlPoint1.dy,
        controlPoint2.dx,
        controlPoint2.dy,
        p1.dx,
        p1.dy,
      );
    }
    path.lineTo(width, zeroY);

    // 5. Fill Glow Gradient Under Curve
    final fillPath = Path.from(path)
      ..lineTo(width, height)
      ..lineTo(0, height)
      ..close();

    final fillGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        (isDark ? MuxisColors.neonGreen : MuxisColors.neonGreenLight)
            .withOpacity(isEnabled ? (isDark ? 0.28 : 0.18) : 0.04),
        Colors.transparent,
      ],
    );

    final fillPaint = Paint()
      ..shader = fillGradient.createShader(Rect.fromLTWH(0, 0, width, height));
    canvas.drawPath(fillPath, fillPaint);

    // 6. Spline Stroke
    final strokeColor = isEnabled
        ? (isDark ? MuxisColors.neonGreen : MuxisColors.neonGreenLight)
        : Colors.grey;

    final strokePaint = Paint()
      ..color = strokeColor
      ..strokeWidth = isDark ? 2.8 : 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, strokePaint);

    // 7. Glowing Band Nodes
    for (final p in points) {
      // Outer subtle halo
      if (isEnabled) {
        canvas.drawCircle(
          p,
          7.0,
          Paint()..color = strokeColor.withOpacity(0.25),
        );
      }
      // Inner crisp node
      canvas.drawCircle(
        p,
        3.5,
        Paint()..color = isDark ? Colors.black : Colors.white,
      );
      canvas.drawCircle(p, 2.5, Paint()..color = strokeColor);
    }
  }

  @override
  bool shouldRepaint(covariant _FrequencyCurvePainter oldDelegate) {
    return true;
  }
}
