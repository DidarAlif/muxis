import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/muxis_colors.dart';
import '../../app/theme/muxis_gradients.dart';
import '../../app/theme/muxis_shadows.dart';
import '../../app/theme/muxis_typography.dart';
import '../../core/audio/audio_playback_service.dart';
import '../../core/audio/dsp/equalizer_node.dart';
import '../../core/audio/playback_state.dart';
import '../../core/lyrics/lyrics_service.dart';
import '../../shared/models/lyrics_line.dart';
import '../../shared/models/track.dart';
import '../../shared/widgets/muxis_slider.dart';
import 'audio_visualizer.dart';

class AuroraNowPlaying extends ConsumerStatefulWidget {
  final VoidCallback onClose;

  const AuroraNowPlaying({super.key, required this.onClose});

  @override
  ConsumerState<AuroraNowPlaying> createState() => _AuroraNowPlayingState();
}

class _AuroraNowPlayingState extends ConsumerState<AuroraNowPlaying> {
  bool _showLyrics = true;
  bool _loadingLyrics = false;
  String? _loadedTrackId;
  List<LyricsLine> _lyrics = const [];

  @override
  void initState() {
    super.initState();
    final track = ref.read(playbackServiceProvider).currentTrack;
    if (track != null) {
      _loadLyricsForTrack(track);
    }
  }

  Future<void> _loadLyricsForTrack(Track? track) async {
    final targetId = track?.id;
    _loadedTrackId = targetId;

    if (track == null) {
      if (mounted) {
        setState(() {
          _lyrics = const [];
          _loadingLyrics = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _lyrics = const [];
        _loadingLyrics = true;
      });
    }

    final lyrics = await ref.read(lyricsServiceProvider).fetchLyrics(track);
    if (!mounted || _loadedTrackId != targetId) return;

    setState(() {
      _lyrics = lyrics;
      _loadingLyrics = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final playback = ref.watch(playbackServiceProvider);
    final eq = ref.watch(equalizerProvider);
    final audioService = ref.read(playbackServiceProvider.notifier);
    final track = playback.currentTrack;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    ref.listen<String?>(
      playbackServiceProvider.select((s) => s.currentTrack?.id),
      (prevId, nextId) {
        if (prevId != nextId) {
          _loadLyricsForTrack(ref.read(playbackServiceProvider).currentTrack);
        }
      },
    );

    final hasLyrics = _lyrics.isNotEmpty;
    final showLyricsPane = hasLyrics && _showLyrics;
    final accent = MuxisColors.accent(isDark);
    final textPrimary = isDark
        ? MuxisColors.textPrimaryDark
        : MuxisColors.textPrimaryLight;
    final textSecondary = isDark
        ? MuxisColors.textSecondaryDark
        : MuxisColors.textSecondaryLight;
    final textMuted =
        isDark ? MuxisColors.textMutedDark : MuxisColors.textMutedLight;
    final bandGains =
        eq.isEnabled ? eq.bands.map((b) => b.gainDb).toList() : null;
    final effectiveVolume = playback.isMuted ? 0.0 : playback.volume;

    return Scaffold(
      backgroundColor: isDark ? MuxisColors.obsidian : MuxisColors.porcelain,
      body: Stack(
        children: [
          // Multi-layer Aurora Ambient Mesh Backdrop (aligned for Light & Dark)
          Positioned.fill(
            child: Container(
              decoration: isDark
                  ? MuxisGradients.darkAmbientBackground()
                  : MuxisGradients.lightAmbientBackground(),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: isDark
                    ? MuxisGradients.auroraAuraRadial(
                        dominantColor: MuxisColors.neonGreen,
                        secondaryColor: MuxisColors.cyberTeal,
                      )
                    : MuxisGradients.auroraAuraRadialLight(
                        dominantColor: MuxisColors.neonGreenLight,
                      ),
              ),
            ),
          ),

          // Main Expanded Console Layout
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompactWidth = constraints.maxWidth < 820;
                final horizontalPad = isCompactWidth ? 20.0 : 40.0;

                return Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPad,
                    vertical: 20,
                  ),
                  child: Column(
                    children: [
                      // Top Command Bar
                      _buildTopBar(
                        isDark: isDark,
                        accent: accent,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        hasLyrics: hasLyrics,
                        showLyricsPane: showLyricsPane,
                        eq: eq,
                      ),
                      const SizedBox(height: 18),

                      // Center Stage: Artwork + Live Synced Lyrics OR Studio Spectrum
                      Expanded(
                        child: isCompactWidth
                            ? _buildCompactCenterStage(
                                track: track,
                                playback: playback,
                                isDark: isDark,
                                accent: accent,
                                showLyricsPane: showLyricsPane,
                                bandGains: bandGains,
                                effectiveVolume: effectiveVolume,
                                eqPreset: eq.isEnabled ? eq.activePreset : 'Flat',
                              )
                            : _buildWideCenterStage(
                                track: track,
                                playback: playback,
                                isDark: isDark,
                                accent: accent,
                                showLyricsPane: showLyricsPane,
                                bandGains: bandGains,
                                effectiveVolume: effectiveVolume,
                                eq: eq,
                              ),
                      ),
                      const SizedBox(height: 16),

                      // Frosted Liquid Glass Controls Console
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isCompactWidth ? 18 : 26,
                                vertical: 18,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? MuxisColors.elevatedSurface
                                        .withValues(alpha: 0.56)
                                    : Colors.white.withValues(alpha: 0.72),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.14)
                                      : Colors.white.withValues(alpha: 0.92),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: isDark
                                        ? Colors.black.withValues(alpha: 0.42)
                                        : accent.withValues(alpha: 0.12),
                                    blurRadius: 28,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Track Title, Artist, & Favorite
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              track?.title ?? 'No track',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: MuxisTypography.pageTitle(
                                                isDark: isDark,
                                              ).copyWith(fontSize: 22),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              [
                                                track?.artist ?? 'Unknown',
                                                if (track != null &&
                                                    track.album.isNotEmpty)
                                                  track.album,
                                              ].join(' • '),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: MuxisTypography
                                                  .sectionHeading(
                                                isDark: isDark,
                                              ).copyWith(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color: textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          (track?.isFavorite ?? false)
                                              ? Icons.favorite_rounded
                                              : Icons.favorite_border_rounded,
                                          size: 26,
                                          color: (track?.isFavorite ?? false)
                                              ? (isDark
                                                  ? MuxisColors.coralPulse
                                                  : MuxisColors.coralPulseLight)
                                              : textSecondary,
                                        ),
                                        onPressed: () => audioService
                                            .toggleFavoriteCurrentTrack(),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),

                                  // Timeline Scrubber
                                  MuxisSlider(
                                    value: playback.progressFraction,
                                    bufferedValue: playback.bufferedFraction,
                                    onChanged: (frac) {
                                      final targetMs = (frac *
                                              playback.duration.inMilliseconds)
                                          .toInt();
                                      audioService.seek(
                                        Duration(milliseconds: targetMs),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 6),

                                  // Timestamps
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _formatDuration(playback.position),
                                        style: MuxisTypography.timecode(
                                          isDark: isDark,
                                        ),
                                      ),
                                      Text(
                                        _formatDuration(playback.duration),
                                        style: MuxisTypography.timecode(
                                          isDark: isDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),

                                  // Playback Transport Controls
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          Icons.shuffle_rounded,
                                          color: playback.isShuffle
                                              ? accent
                                              : textMuted,
                                        ),
                                        onPressed: () =>
                                            audioService.toggleShuffle(),
                                      ),
                                      SizedBox(width: isCompactWidth ? 12 : 24),
                                      IconButton(
                                        icon: Icon(
                                          Icons.skip_previous_rounded,
                                          size: 34,
                                          color: textPrimary,
                                        ),
                                        onPressed: () =>
                                            audioService.playPrevious(),
                                      ),
                                      SizedBox(width: isCompactWidth ? 14 : 24),
                                      GestureDetector(
                                        onTap: () => audioService.togglePlay(),
                                        child: Container(
                                          width: 60,
                                          height: 60,
                                          decoration: BoxDecoration(
                                            gradient: isDark
                                                ? MuxisGradients
                                                    .prismaticPrimary
                                                : MuxisGradients
                                                    .prismaticLightPrimary,
                                            shape: BoxShape.circle,
                                            boxShadow:
                                                MuxisShadows.prismaticGlow,
                                          ),
                                          child: Center(
                                            child: Icon(
                                              playback.isPlaying
                                                  ? Icons.pause_rounded
                                                  : Icons.play_arrow_rounded,
                                              color: isDark
                                                  ? Colors.black
                                                  : Colors.white,
                                              size: 34,
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: isCompactWidth ? 14 : 24),
                                      IconButton(
                                        icon: Icon(
                                          Icons.skip_next_rounded,
                                          size: 34,
                                          color: textPrimary,
                                        ),
                                        onPressed: () =>
                                            audioService.playNext(),
                                      ),
                                      SizedBox(width: isCompactWidth ? 12 : 24),
                                      IconButton(
                                        icon: Icon(
                                          playback.repeatMode == RepeatMode.one
                                              ? Icons.repeat_one_rounded
                                              : Icons.repeat_rounded,
                                          color: playback.repeatMode !=
                                                  RepeatMode.off
                                              ? accent
                                              : textMuted,
                                        ),
                                        onPressed: () =>
                                            audioService.cycleRepeatMode(),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
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
    );
  }

  Widget _buildTopBar({
    required bool isDark,
    required Color accent,
    required Color textPrimary,
    required Color textSecondary,
    required bool hasLyrics,
    required bool showLyricsPane,
    required EqualizerState eq,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 32,
            color: textPrimary,
          ),
          tooltip: 'Collapse',
          onPressed: widget.onClose,
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isDark
                ? MuxisColors.elevatedSurface.withValues(alpha: 0.65)
                : Colors.white.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? MuxisColors.subtleBorderDark
                  : Colors.white.withValues(alpha: 0.9),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                showLyricsPane
                    ? Icons.auto_awesome_rounded
                    : Icons.graphic_eq_rounded,
                size: 14,
                color: accent,
              ),
              const SizedBox(width: 8),
              Text(
                showLyricsPane ? 'AURORA NOW PLAYING' : 'STUDIO SPECTRUM STAGE',
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  color: accent,
                ),
              ),
            ],
          ),
        ),
        // Only show lyrics toggle when real lyrics are available!
        if (hasLyrics)
          IconButton(
            icon: Icon(
              _showLyrics
                  ? Icons.lyrics_rounded
                  : Icons.graphic_eq_rounded,
              size: 24,
              color: _showLyrics ? accent : textSecondary,
            ),
            tooltip: _showLyrics
                ? 'Switch to Studio Spectrum'
                : 'Show Synced Lyrics',
            onPressed: () => setState(() => _showLyrics = !_showLyrics),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isDark
                  ? accent.withValues(alpha: 0.14)
                  : accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accent.withValues(alpha: 0.35)),
            ),
            child: Text(
              _loadingLyrics
                  ? 'SYNCING...'
                  : (eq.isEnabled ? 'DSP ${eq.activePreset.toUpperCase()}' : 'DSP BYPASS'),
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildWideCenterStage({
    required Track? track,
    required PlaybackState playback,
    required bool isDark,
    required Color accent,
    required bool showLyricsPane,
    required List<double>? bandGains,
    required double effectiveVolume,
    required EqualizerState eq,
  }) {
    if (showLyricsPane) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Flexible(
            flex: 1,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildArtworkCard(track, size: 300, isDark: isDark, accent: accent),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: 300,
                    child: AudioVisualizer(
                      isPlaying: playback.isPlaying,
                      barCount: 44,
                      height: 48,
                      bandGains: bandGains,
                      volume: effectiveVolume,
                      position: playback.position,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Flexible(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: _buildLyricsView(playback.position, isDark, accent),
            ),
          ),
        ],
      );
    }

    // No lyrics (or user chose studio spectrum): artwork + expansive 64-band Spectrum Stage!
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          flex: 4,
          child: Center(
            child: _buildArtworkCard(
              track,
              size: 300,
              isDark: isDark,
              accent: accent,
            ),
          ),
        ),
        const SizedBox(width: 28),
        Flexible(
          flex: 6,
          child: _buildStudioSpectrumCard(
            playback: playback,
            isDark: isDark,
            accent: accent,
            bandGains: bandGains,
            effectiveVolume: effectiveVolume,
            eq: eq,
            height: 220,
          ),
        ),
      ],
    );
  }

  Widget _buildCompactCenterStage({
    required Track? track,
    required PlaybackState playback,
    required bool isDark,
    required Color accent,
    required bool showLyricsPane,
    required List<double>? bandGains,
    required double effectiveVolume,
    required String eqPreset,
  }) {
    if (showLyricsPane) {
      return Column(
        children: [
          _buildArtworkCard(track, size: 170, isDark: isDark, accent: accent),
          const SizedBox(height: 14),
          Expanded(
            child: _buildLyricsView(playback.position, isDark, accent),
          ),
        ],
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildArtworkCard(track, size: 200, isDark: isDark, accent: accent),
        const SizedBox(height: 18),
        Expanded(
          child: Center(
            child: AudioVisualizer(
              isPlaying: playback.isPlaying,
              expandedStudio: true,
              barCount: 44,
              height: 140,
              bandGains: bandGains,
              volume: effectiveVolume,
              position: playback.position,
              showMirror: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildArtworkCard(
    Track? track, {
    required double size,
    required bool isDark,
    required Color accent,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: MuxisGradients.auroraSpectrum,
        boxShadow: [
          BoxShadow(
            color: (isDark
                    ? MuxisColors.auroraViolet
                    : MuxisColors.auroraVioletLight)
                .withValues(alpha: isDark ? 0.38 : 0.25),
            blurRadius: 40,
            spreadRadius: 2,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: accent.withValues(alpha: isDark ? 0.16 : 0.12),
            blurRadius: 22,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: track?.artworkUrl != null && track!.artworkUrl!.isNotEmpty
          ? Image.network(
              track.artworkUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Center(
                child: Icon(
                  Icons.music_note_rounded,
                  size: 104,
                  color: Colors.white,
                ),
              ),
            )
          : const Center(
              child: Icon(
                Icons.music_note_rounded,
                size: 104,
                color: Colors.white,
              ),
            ),
    );
  }

  Widget _buildStudioSpectrumCard({
    required PlaybackState playback,
    required bool isDark,
    required Color accent,
    required List<double>? bandGains,
    required double effectiveVolume,
    required EqualizerState eq,
    required double height,
  }) {
    final textSecondary = isDark
        ? MuxisColors.textSecondaryDark
        : MuxisColors.textSecondaryLight;
    final textMuted =
        isDark ? MuxisColors.textMutedDark : MuxisColors.textMutedLight;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: isDark
                ? MuxisColors.elevatedSurface.withValues(alpha: 0.52)
                : Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.14)
                  : Colors.white.withValues(alpha: 0.92),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: isDark ? 0.14 : 0.10),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: playback.isPlaying ? accent : textMuted,
                          shape: BoxShape.circle,
                          boxShadow: playback.isPlaying
                              ? [
                                  BoxShadow(
                                    color: accent.withValues(alpha: 0.65),
                                    blurRadius: 8,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        playback.isPlaying
                            ? 'LIVE HARMONIC SPECTRUM'
                            : 'SPECTRUM STANDBY',
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    eq.isEnabled
                        ? 'EQ: ${eq.activePreset}'
                        : 'EQ: Bypassed',
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AudioVisualizer(
                isPlaying: playback.isPlaying,
                expandedStudio: true,
                barCount: 60,
                height: height,
                bandGains: bandGains,
                volume: effectiveVolume,
                position: playback.position,
                showMirror: true,
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: ['32Hz', '125Hz', '500Hz', '2kHz', '8kHz', '16kHz']
                    .map(
                      (hz) => Text(
                        hz,
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: textMuted,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLyricsView(
    Duration currentPosition,
    bool isDark,
    Color accent,
  ) {
    final textPrimary = isDark
        ? MuxisColors.textPrimaryDark
        : MuxisColors.textPrimaryLight;
    final textDim = isDark
        ? Colors.white.withValues(alpha: 0.36)
        : MuxisColors.textMutedLight;
    final transDim = isDark
        ? Colors.white.withValues(alpha: 0.24)
        : MuxisColors.textMutedLight.withValues(alpha: 0.72);

    return ListView.builder(
      itemCount: _lyrics.length,
      itemBuilder: (context, i) {
        final line = _lyrics[i];
        final isActive =
            currentPosition >= line.startTime &&
            (line.endTime == null || currentPosition < line.endTime!);

        return AnimatedPadding(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: isActive ? 12.0 : 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                line.text,
                style: TextStyle(
                  fontSize: isActive ? 22 : 16,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? textPrimary : textDim,
                  shadows: isActive
                      ? [
                          Shadow(
                            color: accent.withValues(alpha: isDark ? 0.85 : 0.35),
                            blurRadius: 16,
                          ),
                        ]
                      : null,
                ),
              ),
              if (line.translation != null) ...[
                const SizedBox(height: 4),
                Text(
                  line.translation!,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: isActive ? accent : transDim,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
