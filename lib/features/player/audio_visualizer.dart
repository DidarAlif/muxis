import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/theme/muxis_colors.dart';

/// High-frame-rate CustomPainter audio spectrum visualizer.
///
/// Supports both a compact dock variant (`expandedStudio: false`) and a rich
/// studio console spectrum (`expandedStudio: true`) featuring floating peak-hold
/// markers, dual smooth harmonic wave ribbons, mirrored floor reflections, and
/// EQ-reactive spectral shaping synced cleanly with both Light and Dark themes.
class AudioVisualizer extends StatefulWidget {
  final bool isPlaying;
  final int barCount;
  final double height;
  final Color? color;
  final bool expandedStudio;
  final List<double>? bandGains;
  final double volume;
  final Duration position;
  final bool showMirror;

  const AudioVisualizer({
    super.key,
    required this.isPlaying,
    this.barCount = 32,
    this.height = 48,
    this.color,
    this.expandedStudio = false,
    this.bandGains,
    this.volume = 1.0,
    this.position = Duration.zero,
    this.showMirror = true,
  });

  @override
  State<AudioVisualizer> createState() => _AudioVisualizerState();
}

class _AudioVisualizerState extends State<AudioVisualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late List<double> _levels;
  late List<double> _peaks;
  late List<double> _peakHold;
  int _frameTick = 0;

  @override
  void initState() {
    super.initState();
    _initArrays(widget.barCount);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..addListener(_stepSpectrum);
    _controller.repeat();
  }

  void _initArrays(int count) {
    _levels = List<double>.filled(count, 0.08);
    _peaks = List<double>.filled(count, 0.10);
    _peakHold = List<double>.filled(count, 0.0);
  }

  @override
  void didUpdateWidget(covariant AudioVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.barCount != widget.barCount) {
      _initArrays(widget.barCount);
    }
    if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  void _stepSpectrum() {
    _frameTick++;
    final count = widget.barCount;
    final t = _frameTick * 0.045;
    final posSec = widget.position.inMilliseconds / 1000.0;
    final phase = widget.isPlaying ? (t + posSec * 0.65) : (t * 0.35);
    final volFactor = widget.isPlaying
        ? (0.42 + 0.58 * widget.volume.clamp(0.0, 1.0))
        : 0.18;

    // Beat envelopes when playing: kick (low end), snare/vocal (mid), shimmer (high)
    final kickPulse = widget.isPlaying
        ? (0.55 + 0.45 * pow(max(0.0, sin(phase * 3.15)), 4).toDouble())
        : 0.25;
    final midGroove = widget.isPlaying
        ? (0.55 + 0.45 * sin(phase * 2.25 + 0.7))
        : 0.30;
    final airPulse = widget.isPlaying
        ? (0.45 + 0.55 * pow(max(0.0, sin(phase * 5.8 + 1.4)), 2).toDouble())
        : 0.22;

    for (int i = 0; i < count; i++) {
      final u = count <= 1 ? 0.5 : i / (count - 1);

      double target;
      if (!widget.isPlaying) {
        // Serene breathing wave when paused
        final idleWave =
            0.07 + 0.06 * sin(phase * 1.4 + u * pi * 2.6) * sin(u * pi);
        target = idleWave.clamp(0.05, 0.16);
      } else {
        // Natural logarithmic audio spectrum shape: heavy low, expressive mid, airy high
        final subWeight = exp(-pow((u - 0.12) / 0.16, 2));
        final midWeight = exp(-pow((u - 0.45) / 0.28, 2));
        final highWeight = exp(-pow((u - 0.80) / 0.22, 2));

        final h1 = 0.5 + 0.5 * sin(phase * (2.6 + u * 4.8) + i * 0.41);
        final h2 = 0.5 + 0.5 * cos(phase * (4.1 - u * 2.3) + i * 0.77);
        final h3 = 0.5 + 0.5 * sin(phase * (6.7 + u * 6.2) - i * 0.29);

        final rawEnergy =
            (subWeight * kickPulse * (0.45 + 0.55 * h1) * 1.08) +
            (midWeight * midGroove * (0.35 + 0.65 * h2) * 0.96) +
            (highWeight * airPulse * (0.30 + 0.70 * h3) * 0.78) +
            0.14 * h1 * h2;

        final eqMult = _sampleEqMultiplier(u);
        target = (rawEnergy * volFactor * eqMult).clamp(0.08, 0.98);
      }

      final smoothing = target > _levels[i] ? 0.38 : 0.16;
      _levels[i] += (target - _levels[i]) * smoothing;

      // Peak-hold physics
      if (_levels[i] >= _peaks[i]) {
        _peaks[i] = _levels[i];
        _peakHold[i] = 14.0;
      } else if (_peakHold[i] > 0) {
        _peakHold[i] -= 1.0;
      } else {
        _peaks[i] = max(_levels[i], _peaks[i] - 0.014);
      }
    }
  }

  double _sampleEqMultiplier(double u) {
    final gains = widget.bandGains;
    if (gains == null || gains.isEmpty) return 1.0;
    final scaled = u * (gains.length - 1);
    final idx0 = scaled.floor().clamp(0, gains.length - 1);
    final idx1 = (idx0 + 1).clamp(0, gains.length - 1);
    final frac = scaled - idx0;
    final db = gains[idx0] * (1.0 - frac) + gains[idx1] * frac;
    // Map -12..+12 dB -> 0.52..1.42 visual amplitude factor
    return (1.0 + (db / 12.0) * 0.42).clamp(0.45, 1.45);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryAccent = Theme.of(context).colorScheme.primary;
    final palette = widget.color != null
        ? [
            widget.color!,
            Color.lerp(
                  widget.color!,
                  isDark ? MuxisColors.cyberTeal : MuxisColors.cyberTealLight,
                  0.45,
                ) ??
                widget.color!,
            Color.lerp(
                  widget.color!,
                  isDark
                      ? MuxisColors.auroraViolet
                      : MuxisColors.auroraVioletLight,
                  0.65,
                ) ??
                widget.color!,
            isDark ? MuxisColors.coralPulse : MuxisColors.coralPulseLight,
          ]
        : [
            primaryAccent,
            isDark ? MuxisColors.cyberTeal : MuxisColors.cyberTealLight,
            isDark ? MuxisColors.auroraViolet : MuxisColors.auroraVioletLight,
            isDark ? MuxisColors.coralPulse : MuxisColors.coralPulseLight,
          ];

    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fallbackWidth =
              widget.barCount * (widget.expandedStudio ? 8.5 : 5.5);
          final width = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : fallbackWidth;

          return CustomPaint(
            size: Size(width, widget.height),
            painter: _SpectrumPainter(
              repaint: _controller,
              levels: _levels,
              peaks: _peaks,
              palette: palette,
              isPlaying: widget.isPlaying,
              isDark: isDark,
              expandedStudio: widget.expandedStudio,
              showMirror: widget.showMirror,
              phaseProvider: () => _frameTick * 0.045,
            ),
          );
        },
      ),
    );
  }
}

class _SpectrumPainter extends CustomPainter {
  final List<double> levels;
  final List<double> peaks;
  final List<Color> palette;
  final bool isPlaying;
  final bool isDark;
  final bool expandedStudio;
  final bool showMirror;
  final double Function() phaseProvider;

  _SpectrumPainter({
    required Listenable repaint,
    required this.levels,
    required this.peaks,
    required this.palette,
    required this.isPlaying,
    required this.isDark,
    required this.expandedStudio,
    required this.showMirror,
    required this.phaseProvider,
  }) : super(repaint: repaint);

  Color _colorAt(double t) {
    if (palette.isEmpty) return MuxisColors.neonAccent;
    if (palette.length == 1) return palette.first;
    final scaled = t.clamp(0.0, 1.0) * (palette.length - 1);
    final idx0 = scaled.floor().clamp(0, palette.length - 1);
    final idx1 = (idx0 + 1).clamp(0, palette.length - 1);
    final frac = scaled - idx0;
    return Color.lerp(palette[idx0], palette[idx1], frac) ?? palette[idx0];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final count = levels.length;
    if (count == 0 || size.width <= 0 || size.height <= 0) return;

    final phase = phaseProvider();
    final mirrorFraction = (expandedStudio && showMirror) ? 0.22 : 0.0;
    final topPadding = expandedStudio ? 10.0 : 2.0;
    final mainHeight = max(
      8.0,
      (size.height - topPadding) * (1.0 - mirrorFraction),
    );
    final baseY = topPadding + mainHeight;

    // 1. Expanded studio ambient aura & subtle telemetry grid
    if (expandedStudio) {
      final auraCenter = Offset(size.width * 0.5, baseY * 0.58);
      final auraShader =
          RadialGradient(
            colors: [
              palette.first.withValues(
                alpha: isPlaying ? (isDark ? 0.18 : 0.14) : 0.06,
              ),
              palette[1 % palette.length].withValues(
                alpha: isPlaying ? (isDark ? 0.10 : 0.08) : 0.03,
              ),
              Colors.transparent,
            ],
            stops: const [0.0, 0.55, 1.0],
          ).createShader(
            Rect.fromCircle(center: auraCenter, radius: size.width * 0.55),
          );
      canvas.drawRect(Offset.zero & size, Paint()..shader = auraShader);

      final gridPaint = Paint()
        ..color = (isDark ? Colors.white : Colors.black).withValues(
          alpha: isDark ? 0.06 : 0.06,
        )
        ..strokeWidth = 1.0;

      for (int g = 1; g <= 3; g++) {
        final gy = topPadding + mainHeight * (g / 4.0);
        canvas.drawLine(Offset(0, gy), Offset(size.width, gy), gridPaint);
      }

      // Baseline horizon line
      canvas.drawLine(
        Offset(0, baseY),
        Offset(size.width, baseY),
        Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.transparent,
              palette.first.withValues(alpha: isDark ? 0.45 : 0.38),
              palette[2 % palette.length].withValues(
                alpha: isDark ? 0.45 : 0.38,
              ),
              Colors.transparent,
            ],
          ).createShader(Rect.fromLTWH(0, baseY - 1, size.width, 2))
          ..strokeWidth = 1.25,
      );
    }

    // 2. Compute bar geometry
    final step = size.width / count;
    final gapRatio = expandedStudio ? 0.34 : 0.36;
    final barWidth = max(2.0, step * (1.0 - gapRatio));
    final radius = Radius.circular(min(4.0, barWidth / 2.0));

    // 3. Draw background smooth harmonic ribbon curve in expanded studio mode
    if (expandedStudio && count >= 4) {
      _paintHarmonicRibbon(
        canvas: canvas,
        size: size,
        baseY: baseY,
        mainHeight: mainHeight,
        step: step,
        phase: phase,
      );
    }

    // 4. Paint spectrum bars, glows, mirrored reflection, and peak caps
    for (int i = 0; i < count; i++) {
      final u = count <= 1 ? 0.5 : i / (count - 1);
      final level = levels[i].clamp(0.05, 1.0);
      final barHeight = max(3.0, level * mainHeight);
      final x = i * step + (step - barWidth) / 2.0;
      final topY = baseY - barHeight;

      final barColor = _colorAt(u);
      final topColor =
          Color.lerp(
            barColor,
            isDark ? Colors.white : barColor,
            isDark ? 0.25 : 0.0,
          ) ??
          barColor;
      final bottomColor = barColor.withValues(alpha: isDark ? 0.72 : 0.85);

      final rect = Rect.fromLTWH(x, topY, barWidth, barHeight);
      final rRect = RRect.fromRectAndCorners(
        rect,
        topLeft: radius,
        topRight: radius,
        bottomLeft: expandedStudio ? Radius.zero : radius,
        bottomRight: expandedStudio ? Radius.zero : radius,
      );

      // Soft ambient bar glow on active peaks
      if (isPlaying && level > 0.42 && (expandedStudio || i.isEven)) {
        final glowPaint = Paint()
          ..color = barColor.withValues(alpha: isDark ? 0.28 : 0.18)
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            expandedStudio ? 7.0 : 4.0,
          );
        canvas.drawRRect(rRect, glowPaint);
      }

      final barPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [bottomColor, topColor],
        ).createShader(rect);

      canvas.drawRRect(rRect, barPaint);

      // Mirrored bottom floor reflection
      if (expandedStudio && showMirror) {
        final mirrorMaxH = max(4.0, (size.height - baseY - 2.0));
        final mirrorH = (level * mirrorMaxH * 0.85).clamp(2.0, mirrorMaxH);
        final mirrorRect = Rect.fromLTWH(x, baseY + 1.5, barWidth, mirrorH);
        final mirrorPaint = Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              barColor.withValues(alpha: isDark ? 0.30 : 0.24),
              barColor.withValues(alpha: 0.0),
            ],
          ).createShader(mirrorRect);
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            mirrorRect,
            bottomLeft: radius,
            bottomRight: radius,
          ),
          mirrorPaint,
        );
      }

      // Floating peak-hold cap
      if (expandedStudio) {
        final peakLevel = peaks[i].clamp(level, 1.0);
        final peakY = max(2.0, baseY - peakLevel * mainHeight - 4.0);
        final capPaint = Paint()
          ..color = topColor.withValues(alpha: isPlaying ? 0.92 : 0.45);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, peakY, barWidth, 2.5),
            const Radius.circular(1.5),
          ),
          capPaint,
        );
      }
    }
  }

  void _paintHarmonicRibbon({
    required Canvas canvas,
    required Size size,
    required double baseY,
    required double mainHeight,
    required double step,
    required double phase,
  }) {
    final points = <Offset>[];
    final overtonePoints = <Offset>[];
    final count = levels.length;

    for (int i = 0; i < count; i++) {
      final u = i / (count - 1);
      final x = i * step + step * 0.5;
      final envY = baseY - (levels[i] * mainHeight * 0.88);
      final overtoneMod = 0.5 + 0.5 * sin(phase * 2.2 + u * pi * 3.0);
      final overY =
          baseY -
          ((levels[i] * 0.55 + (isPlaying ? 0.16 * overtoneMod : 0.04)) *
                  mainHeight)
              .clamp(4.0, mainHeight * 0.92);
      points.add(Offset(x, envY));
      overtonePoints.add(Offset(x, overY));
    }

    final envelopePath = _smoothCurve(points);
    final fillPath = Path.from(envelopePath)
      ..lineTo(size.width, baseY)
      ..lineTo(0, baseY)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader =
            LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                palette.first.withValues(alpha: isDark ? 0.14 : 0.12),
                Colors.transparent,
              ],
            ).createShader(
              Rect.fromLTWH(0, baseY - mainHeight, size.width, mainHeight),
            ),
    );

    canvas.drawPath(
      envelopePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..shader = LinearGradient(colors: palette)
            .createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..color = Colors.white.withValues(alpha: isPlaying ? 0.65 : 0.30),
    );

    final overtonePath = _smoothCurve(overtonePoints);
    canvas.drawPath(
      overtonePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = palette[1 % palette.length].withValues(
          alpha: isPlaying ? (isDark ? 0.42 : 0.34) : 0.18,
        ),
    );
  }

  Path _smoothCurve(List<Offset> pts) {
    final path = Path();
    if (pts.isEmpty) return path;
    path.moveTo(pts.first.dx, pts.first.dy);
    for (int i = 0; i < pts.length - 1; i++) {
      final p0 = pts[i];
      final p1 = pts[i + 1];
      final mid = Offset((p0.dx + p1.dx) * 0.5, (p0.dy + p1.dy) * 0.5);
      path.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
    }
    path.lineTo(pts.last.dx, pts.last.dy);
    return path;
  }

  @override
  bool shouldRepaint(covariant _SpectrumPainter oldDelegate) =>
      oldDelegate.levels != levels ||
      oldDelegate.isPlaying != isPlaying ||
      oldDelegate.isDark != isDark ||
      oldDelegate.expandedStudio != expandedStudio;
}
