import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/theme/muxis_colors.dart';

class _DropletPulse {
  final Offset origin;
  final int startUs;

  const _DropletPulse(this.origin, this.startUs);
}

/// Interactive Liquid Glass surface featuring:
/// - True frosted BackdropFilter translucency with top-left specular bevels
/// - Hover water-wave shimmer & cursor-tracking liquid caustic glow
/// - Expanding concentric water-drop ripples radiating from pointer click coordinates
class MuxisLiquidSurface extends StatefulWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool enableGlass;
  final bool enableHoverWave;
  final bool enableDropRipple;
  final double blurSigma;
  final bool enableBackdropBlur;
  final Color? accentColor;
  final BoxBorder? borderOverride;
  final Gradient? gradientOverride;
  final Color? colorOverride;
  final List<BoxShadow>? boxShadowOverride;
  final bool useClickCursor;

  const MuxisLiquidSurface({
    super.key,
    required this.child,
    this.borderRadius = 18,
    this.padding = EdgeInsets.zero,
    this.onTap,
    this.enableGlass = true,
    this.enableHoverWave = true,
    this.enableDropRipple = true,
    this.blurSigma = 22,
    this.enableBackdropBlur = false,
    this.accentColor,
    this.borderOverride,
    this.gradientOverride,
    this.colorOverride,
    this.boxShadowOverride,
    this.useClickCursor = false,
  });

  @override
  State<MuxisLiquidSurface> createState() => _MuxisLiquidSurfaceState();
}

class _MuxisLiquidSurfaceState extends State<MuxisLiquidSurface>
    with TickerProviderStateMixin {
  late final AnimationController _waveCtrl;
  late final AnimationController _hoverBlendCtrl;
  late final AnimationController _dropTickCtrl;

  bool _isHovered = false;
  bool _isPressed = false;
  final ValueNotifier<Offset?> _hoverPosNotifier = ValueNotifier<Offset?>(null);
  Offset? _pointerDownPos;
  final List<_DropletPulse> _droplets = [];
  static const int _dropDurationUs = 820000;

  @override
  void initState() {
    super.initState();
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _hoverBlendCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _dropTickCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..addListener(_pruneDroplets);
  }

  @override
  void dispose() {
    _hoverPosNotifier.dispose();
    _waveCtrl.dispose();
    _hoverBlendCtrl.dispose();
    _dropTickCtrl.dispose();
    super.dispose();
  }

  void _pruneDroplets() {
    if (_droplets.isEmpty) {
      if (_dropTickCtrl.isAnimating) {
        _dropTickCtrl.stop();
      }
      return;
    }
    final nowUs = DateTime.now().microsecondsSinceEpoch;
    _droplets.removeWhere((d) => nowUs - d.startUs >= _dropDurationUs);
    if (_droplets.isEmpty && _dropTickCtrl.isAnimating) {
      _dropTickCtrl.stop();
      if (mounted) setState(() {});
    }
  }

  void _spawnDroplet(Offset localPos) {
    if (!widget.enableDropRipple) return;
    final nowUs = DateTime.now().microsecondsSinceEpoch;
    setState(() {
      if (_droplets.length >= 5) {
        _droplets.removeAt(0);
      }
      _droplets.add(_DropletPulse(localPos, nowUs));
    });
    if (!_dropTickCtrl.isAnimating) {
      _dropTickCtrl.repeat();
    }
  }

  void _onHoverEnter(PointerEvent event) {
    _hoverPosNotifier.value = event.localPosition;
    if (!_isHovered) {
      setState(() {
        _isHovered = true;
      });
    }
    if (widget.enableHoverWave) {
      _hoverBlendCtrl.forward();
      if (!_waveCtrl.isAnimating) {
        _waveCtrl.repeat();
      }
    }
  }

  void _onHoverMove(PointerEvent event) {
    if (!widget.enableHoverWave) return;
    _hoverPosNotifier.value = event.localPosition;
  }

  void _onHoverExit(PointerEvent event) {
    setState(() {
      _isHovered = false;
      _isPressed = false;
    });
    if (widget.enableHoverWave) {
      _hoverBlendCtrl.reverse().whenComplete(() {
        if (!_isHovered && mounted) {
          _waveCtrl.stop();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = widget.accentColor ?? MuxisColors.accent(isDark);
    final secondaryAccent = MuxisColors.teal(isDark);

    final BoxDecoration decoration;
    if (widget.enableGlass) {
      decoration = BoxDecoration(
        color:
            widget.colorOverride ??
            (isDark
                ? MuxisColors.elevatedSurface.withOpacity(
                    _isHovered ? 0.62 : 0.50,
                  )
                : Colors.white.withOpacity(_isHovered ? 0.82 : 0.68)),
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border:
            widget.borderOverride ??
            Border.all(
              color: _isHovered
                  ? accent.withOpacity(isDark ? 0.45 : 0.60)
                  : (isDark
                        ? Colors.white.withOpacity(0.14)
                        : Colors.white.withOpacity(0.95)),
              width: 1.2,
            ),
        gradient:
            widget.gradientOverride ??
            LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      Colors.white.withOpacity(_isHovered ? 0.12 : 0.08),
                      MuxisColors.elevatedSurface.withOpacity(0.56),
                      accent.withOpacity(_isHovered ? 0.08 : 0.04),
                    ]
                  : [
                      Colors.white.withOpacity(0.92),
                      const Color(0xD6EFFDFB),
                      const Color(0xC2F1ECFF),
                    ],
            ),
        boxShadow:
            widget.boxShadowOverride ??
            [
              BoxShadow(
                color: isDark
                    ? Colors.black.withOpacity(0.45)
                    : const Color(0x140F172A),
                blurRadius: _isHovered ? 28 : 22,
                offset: const Offset(0, 8),
              ),
              if (_isHovered)
                BoxShadow(
                  color: accent.withOpacity(isDark ? 0.16 : 0.14),
                  blurRadius: 20,
                  spreadRadius: 1,
                ),
            ],
      );
    } else {
      decoration = BoxDecoration(
        color: widget.colorOverride,
        gradient: widget.gradientOverride,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: widget.borderOverride,
        boxShadow: widget.boxShadowOverride,
      );
    }

    Widget surface = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      decoration: decoration,
      child: Stack(
        fit: StackFit.passthrough,
        clipBehavior: Clip.hardEdge,
        children: [
          if (widget.enableHoverWave || widget.enableDropRipple)
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: Listenable.merge([
                      _waveCtrl,
                      _hoverBlendCtrl,
                      _dropTickCtrl,
                      _hoverPosNotifier,
                    ]),
                    builder: (context, _) {
                      final hoverBlend = _hoverBlendCtrl.value;
                      if (hoverBlend <= 0.001 && _droplets.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return CustomPaint(
                        painter: _LiquidEffectsPainter(
                          wavePhase: _waveCtrl.value,
                          hoverBlend: hoverBlend,
                          hoverPos: _hoverPosNotifier.value,
                          droplets: List<_DropletPulse>.from(_droplets),
                          nowUs: DateTime.now().microsecondsSinceEpoch,
                          dropDurationUs: _dropDurationUs,
                          accent: accent,
                          secondaryAccent: secondaryAccent,
                          isDark: isDark,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          Padding(padding: widget.padding, child: widget.child),
        ],
      ),
    );

    if (widget.enableBackdropBlur &&
        widget.enableGlass &&
        widget.blurSigma > 0) {
      surface = ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: widget.blurSigma,
            sigmaY: widget.blurSigma,
          ),
          child: surface,
        ),
      );
    } else {
      surface = ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: surface,
      );
    }

    if (widget.onTap != null) {
      surface = AnimatedScale(
        scale: _isPressed ? 0.985 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: surface,
        ),
      );
    }

    final clickable = widget.onTap != null || widget.useClickCursor;
    return MouseRegion(
      cursor: clickable ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: _onHoverEnter,
      onHover: _onHoverMove,
      onExit: _onHoverExit,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (e) {
          _pointerDownPos = e.localPosition;
          if (widget.onTap != null) {
            setState(() => _isPressed = true);
          }
        },
        onPointerUp: (e) {
          if (_isPressed) setState(() => _isPressed = false);
          final down = _pointerDownPos;
          _pointerDownPos = null;
          if (down == null || (e.localPosition - down).distance <= 14.0) {
            _spawnDroplet(e.localPosition);
          }
        },
        onPointerCancel: (_) {
          _pointerDownPos = null;
          if (_isPressed) setState(() => _isPressed = false);
        },
        child: surface,
      ),
    );
  }
}

class _LiquidEffectsPainter extends CustomPainter {
  final double wavePhase;
  final double hoverBlend;
  final Offset? hoverPos;
  final List<_DropletPulse> droplets;
  final int nowUs;
  final int dropDurationUs;
  final Color accent;
  final Color secondaryAccent;
  final bool isDark;

  const _LiquidEffectsPainter({
    required this.wavePhase,
    required this.hoverBlend,
    required this.hoverPos,
    required this.droplets,
    required this.nowUs,
    required this.dropDurationUs,
    required this.accent,
    required this.secondaryAccent,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    // 1. Hover Water-Wave Caustics & Cursor Liquid Light Pool
    if (hoverBlend > 0.001) {
      final center = hoverPos ?? Offset(size.width * 0.5, size.height * 0.5);
      final spotRadius = math.max(size.width, size.height) * 0.65;

      final spotPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            accent.withOpacity((isDark ? 0.16 : 0.14) * hoverBlend),
            secondaryAccent.withOpacity((isDark ? 0.08 : 0.08) * hoverBlend),
            Colors.transparent,
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: spotRadius));
      canvas.drawRect(Offset.zero & size, spotPaint);

      // Dual undulating translucent water-wave bands
      final basePhase = wavePhase * math.pi * 2.0;
      for (int layer = 0; layer < 2; layer++) {
        final phase = basePhase + layer * 1.45;
        final freq = layer == 0 ? 2.4 : 3.2;
        final amp = (layer == 0 ? 9.0 : 6.0) * hoverBlend;
        final yBase =
            (center.dy.clamp(size.height * 0.18, size.height * 0.85)) +
            (layer == 0 ? -4.0 : 12.0);

        final path = Path();
        path.moveTo(0, size.height);
        for (double x = 0; x <= size.width + 12; x += 12) {
          final normX = x / math.max(1.0, size.width);
          final y =
              yBase +
              math.sin(normX * math.pi * freq + phase) * amp +
              math.cos(normX * math.pi * 1.5 - phase * 0.7) * (amp * 0.45);
          path.lineTo(x, y);
        }
        path.lineTo(size.width, size.height);
        path.close();

        final waveColor = (layer == 0 ? secondaryAccent : accent).withOpacity(
          (isDark ? 0.075 : 0.09) * hoverBlend,
        );
        canvas.drawPath(path, Paint()..color = waveColor);

        // Specular crest highlight line
        final crestPath = Path();
        for (double x = 0; x <= size.width + 12; x += 12) {
          final normX = x / math.max(1.0, size.width);
          final y =
              yBase +
              math.sin(normX * math.pi * freq + phase) * amp +
              math.cos(normX * math.pi * 1.5 - phase * 0.7) * (amp * 0.45);
          if (x == 0) {
            crestPath.moveTo(x, y);
          } else {
            crestPath.lineTo(x, y);
          }
        }
        canvas.drawPath(
          crestPath,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = Colors.white.withOpacity(
              (isDark ? 0.16 : 0.45) * hoverBlend,
            ),
        );
      }
    }

    // 2. Click / Tap Water-Drop Concentric Ripple Rings
    if (droplets.isNotEmpty) {
      final maxRadius =
          math.sqrt(size.width * size.width + size.height * size.height) * 0.82;
      for (final d in droplets) {
        final rawT = ((nowUs - d.startUs) / dropDurationUs).clamp(0.0, 1.0);
        if (rawT >= 1.0) continue;

        // Core splash flash
        if (rawT < 0.34) {
          final coreT = rawT / 0.34;
          final coreR = 6.0 + 26.0 * Curves.easeOut.transform(coreT);
          final corePaint = Paint()
            ..shader = RadialGradient(
              colors: [
                Colors.white.withOpacity((1.0 - coreT) * 0.45),
                accent.withOpacity((1.0 - coreT) * 0.30),
                Colors.transparent,
              ],
            ).createShader(Rect.fromCircle(center: d.origin, radius: coreR));
          canvas.drawCircle(d.origin, coreR, corePaint);
        }

        // Expanding concentric rings (Primary, Secondary harmonic, Outer shimmer)
        for (int ring = 0; ring < 3; ring++) {
          final delay = ring * 0.14;
          if (rawT <= delay) continue;
          final rt = ((rawT - delay) / (1.0 - delay)).clamp(0.0, 1.0);
          final eased = Curves.easeOutCubic.transform(rt);
          final r = 4.0 + (maxRadius * (1.0 - ring * 0.16)) * eased;
          final alpha = math.pow(1.0 - rt, 1.6).toDouble();
          final ringColor = ring == 0
              ? Colors.white.withOpacity((isDark ? 0.52 : 0.70) * alpha)
              : (ring == 1
                    ? secondaryAccent.withOpacity(
                        (isDark ? 0.55 : 0.50) * alpha,
                      )
                    : accent.withOpacity((isDark ? 0.40 : 0.38) * alpha));
          final strokeW = (2.6 - ring * 0.65) * (1.0 - rt * 0.55);

          canvas.drawCircle(
            d.origin,
            r,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(0.6, strokeW)
              ..color = ringColor,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LiquidEffectsPainter oldDelegate) {
    return oldDelegate.wavePhase != wavePhase ||
        oldDelegate.hoverBlend != hoverBlend ||
        oldDelegate.hoverPos != hoverPos ||
        droplets.isNotEmpty ||
        oldDelegate.droplets.isNotEmpty ||
        oldDelegate.isDark != isDark;
  }
}
