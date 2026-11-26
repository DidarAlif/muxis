import 'package:flutter/material.dart';

import '../../app/theme/muxis_colors.dart';
import '../../app/theme/muxis_typography.dart';
import '../models/track.dart';
import 'muxis_badge.dart';

class MuxisTrackRow extends StatefulWidget {
  final Track track;
  final int index;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback? onFavoriteTap;
  final VoidCallback? onPlayNextTap;
  final VoidCallback? onAddToQueueTap;

  const MuxisTrackRow({
    super.key,
    required this.track,
    required this.index,
    this.isPlaying = false,
    required this.onTap,
    this.onFavoriteTap,
    this.onPlayNextTap,
    this.onAddToQueueTap,
  });

  @override
  State<MuxisTrackRow> createState() => _MuxisTrackRowState();
}

class _MuxisTrackRowState extends State<MuxisTrackRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isPlaying
                ? (isDark
                      ? MuxisColors.elevatedSurface.withOpacity(0.85)
                      : Colors.white.withOpacity(0.85))
                : (_isHovered
                      ? (isDark
                            ? MuxisColors.hoverSurface.withOpacity(0.55)
                            : Colors.white.withOpacity(0.55))
                      : Colors.transparent),
            borderRadius: BorderRadius.circular(10),
            border: widget.isPlaying
                ? Border.all(
                    color: MuxisColors.accent(isDark).withOpacity(0.45),
                    width: 1,
                  )
                : null,
          ),
          child: Row(
            children: [
              // Index or Playing Equalizer Indicator
              SizedBox(
                width: 32,
                child: widget.isPlaying
                    ? _buildEqualizerIndicator()
                    : Text(
                        '${widget.index + 1}',
                        style: MuxisTypography.timecode(isDark: isDark)
                            .copyWith(
                              color: isDark
                                  ? MuxisColors.textMutedDark
                                  : MuxisColors.textMutedLight,
                            ),
                      ),
              ),

              // Small Cover Thumbnail
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: isDark
                      ? null
                      : LinearGradient(
                          colors: [
                            MuxisColors.neonGreenLight.withOpacity(0.14),
                            MuxisColors.cyberTealLight.withOpacity(0.14),
                          ],
                        ),
                  color: isDark ? MuxisColors.deepSpace : null,
                ),
                clipBehavior: Clip.antiAlias,
                child: widget.track.artworkUrl != null &&
                        widget.track.artworkUrl!.isNotEmpty
                    ? Image.network(
                        widget.track.artworkUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Center(
                          child: Icon(
                            Icons.music_note_rounded,
                            size: 20,
                            color: widget.isPlaying
                                ? MuxisColors.accent(isDark)
                                : MuxisColors.textMuted(isDark),
                          ),
                        ),
                      )
                    : Center(
                        child: Icon(
                          Icons.music_note_rounded,
                          size: 20,
                          color: widget.isPlaying
                              ? MuxisColors.accent(isDark)
                              : MuxisColors.textMuted(isDark),
                        ),
                      ),
              ),
              const SizedBox(width: 14),

              // Title & Artist
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MuxisTypography.trackTitle(isDark: isDark)
                          .copyWith(
                            color: widget.isPlaying
                                ? MuxisColors.accent(isDark)
                                : (isDark
                                      ? MuxisColors.textPrimaryDark
                                      : MuxisColors.textPrimaryLight),
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.track.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MuxisTypography.artistSubtitle(isDark: isDark),
                    ),
                  ],
                ),
              ),

              // Album Name (Hidden on very small viewports)
              Expanded(
                flex: 3,
                child: Text(
                  widget.track.album,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MuxisTypography.caption(isDark: isDark),
                ),
              ),

              // Audio Format Badge (e.g. FLAC 24-bit)
              if (widget.track.audioFormat != null)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: MuxisBadge(label: widget.track.audioFormat!),
                ),

              // Favorite Heart Toggle
              IconButton(
                icon: Icon(
                  widget.track.isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  size: 18,
                  color: widget.track.isFavorite
                      ? MuxisColors.neonMagenta
                      : (_isHovered
                            ? (isDark
                                  ? MuxisColors.textSecondaryDark
                                  : MuxisColors.textSecondaryLight)
                            : Colors.transparent),
                ),
                onPressed: widget.onFavoriteTap,
              ),

              // Duration
              SizedBox(
                width: 48,
                child: Text(
                  _formatDuration(widget.track.duration),
                  textAlign: TextAlign.end,
                  style: MuxisTypography.timecode(
                    isDark: isDark,
                    active: widget.isPlaying,
                  ),
                ),
              ),

              // Quick Context Menu Actions
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_horiz_rounded,
                  size: 18,
                  color: _isHovered
                      ? (isDark
                            ? MuxisColors.textPrimaryDark
                            : MuxisColors.textPrimaryLight)
                      : Colors.transparent,
                ),
                color: isDark
                    ? MuxisColors.elevatedSurface
                    : MuxisColors.whiteSurface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                onSelected: (val) {
                  if (val == 'play_next') widget.onPlayNextTap?.call();
                  if (val == 'add_queue') widget.onAddToQueueTap?.call();
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'play_next',
                    child: Row(
                      children: [
                        Icon(Icons.playlist_play_rounded, size: 18),
                        SizedBox(width: 10),
                        Text('Play Next'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'add_queue',
                    child: Row(
                      children: [
                        Icon(Icons.queue_music_rounded, size: 18),
                        SizedBox(width: 10),
                        Text('Add to Queue'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEqualizerIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _eqBar(14),
        const SizedBox(width: 2),
        _eqBar(20),
        const SizedBox(width: 2),
        _eqBar(10),
      ],
    );
  }

  Widget _eqBar(double height) {
    return Container(
      width: 3,
      height: height,
      decoration: BoxDecoration(
        color: MuxisColors.electricCyan,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
