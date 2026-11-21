import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/theme/muxis_colors.dart';

class AudioVisualizer extends StatefulWidget {
  final bool isPlaying;
  final int barCount;
  final double height;
  final Color? color;

  const AudioVisualizer({
    super.key,
    required this.isPlaying,
    this.barCount = 32,
    this.height = 48,
    this.color,
  });

  @override
  State<AudioVisualizer> createState() => _AudioVisualizerState();
}

class _AudioVisualizerState extends State<AudioVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final Random _rnd = Random();
  late List<double> _heights;
  late List<double> _targets;

  @override
  void initState() {
    super.initState();
    _heights = List.generate(widget.barCount, (_) => 0.1);
    _targets = List.generate(widget.barCount, (_) => 0.2);

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    )..addListener(_updateHeights);

    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  void _updateHeights() {
    if (!widget.isPlaying) {
      for (int i = 0; i < widget.barCount; i++) {
        _heights[i] = max(0.08, _heights[i] * 0.9);
      }
      setState(() {});
      return;
    }

    for (int i = 0; i < widget.barCount; i++) {
      if ((_heights[i] - _targets[i]).abs() < 0.05) {
        // Bell-curve distribution for realistic audio spectrum
        final centerFactor =
            1.0 -
            (pow(
              (i - widget.barCount / 2) / (widget.barCount / 2),
              2,
            )).clamp(0.0, 0.85);
        _targets[i] = (_rnd.nextDouble() * 0.8 + 0.1) * centerFactor;
      }
      _heights[i] += (_targets[i] - _heights[i]) * 0.35;
    }
    setState(() {});
  }

  @override
  void didUpdateWidget(covariant AudioVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isPlaying && _controller.isAnimating) {
      _controller.stop();
      _updateHeights();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(widget.barCount, (i) {
          final hFraction = _heights[i].clamp(0.08, 1.0);
          final barHeight = hFraction * widget.height;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: Container(
              width: 3.5,
              height: barHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    widget.color ?? MuxisColors.velvetViolet,
                    widget.color ?? MuxisColors.electricCyan,
                  ],
                ),
                boxShadow: widget.isPlaying
                    ? [
                        BoxShadow(
                          color: (widget.color ?? MuxisColors.electricCyan)
                              .withOpacity(0.4),
                          blurRadius: 4,
                          offset: const Offset(0, 0),
                        ),
                      ]
                    : null,
              ),
            ),
          );
        }),
      ),
    );
  }
}
