import 'package:flutter/material.dart';

import '../../app/theme/muxis_colors.dart';
import '../../app/theme/muxis_gradients.dart';
import '../../app/theme/muxis_shadows.dart';
import 'muxis_liquid_surface.dart';

class MuxisCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final String? imageUrl;
  final VoidCallback onTap;
  final VoidCallback? onPlayTap;
  final bool isCircular; // For artists
  final double width;

  MuxisCard({
    super.key,
    required this.title,
    required this.subtitle,
    String? imageUrl,
    String? artworkUrl,
    required this.onTap,
    this.onPlayTap,
    this.isCircular = false,
    this.width = 180,
  }) : imageUrl = imageUrl ?? artworkUrl;

  @override
  State<MuxisCard> createState() => _MuxisCardState();
}

class _MuxisCardState extends State<MuxisCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: SizedBox(
        width: widget.width,
        child: MuxisLiquidSurface(
          onTap: widget.onTap,
          borderRadius: 18,
          padding: const EdgeInsets.all(12),
          blurSigma: 20,
          boxShadowOverride: _isHovered
              ? (isDark ? MuxisShadows.cardHover : MuxisShadows.cardHoverLight)
              : (isDark ? MuxisShadows.card : MuxisShadows.cardLight),
          child: Column(
            crossAxisAlignment: widget.isCircular
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Artwork / Cover Surface
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: widget.width - 24,
                    height: widget.width - 24,
                    decoration: BoxDecoration(
                      shape: widget.isCircular
                          ? BoxShape.circle
                          : BoxShape.rectangle,
                      borderRadius: widget.isCircular
                          ? null
                          : BorderRadius.circular(12),
                      gradient: MuxisGradients.auroraSpectrum,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.32),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: widget.imageUrl != null && widget.imageUrl!.isNotEmpty
                        ? Image.network(
                            widget.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildFallbackIcon(),
                          )
                        : _buildFallbackIcon(),
                  ),

                  // Quick Play Button Overlay on Hover
                  if (_isHovered && widget.onPlayTap != null)
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 180),
                        scale: _isHovered ? 1.0 : 0.0,
                        curve: Curves.easeOutBack,
                        child: GestureDetector(
                          onTap: widget.onPlayTap,
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(
                              gradient: MuxisGradients.prismaticPrimary,
                              shape: BoxShape.circle,
                              boxShadow: MuxisShadows.prismaticGlow,
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.black,
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Title
              Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: widget.isCircular
                    ? TextAlign.center
                    : TextAlign.start,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.1,
                  color: isDark
                      ? MuxisColors.textPrimaryDark
                      : MuxisColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 4),

              // Subtitle / Artist
              Text(
                widget.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: widget.isCircular
                    ? TextAlign.center
                    : TextAlign.start,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: isDark
                      ? MuxisColors.textSecondaryDark
                      : MuxisColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackIcon() {
    return Center(
      child: Icon(
        widget.isCircular ? Icons.person_rounded : Icons.album_rounded,
        size: 48,
        color: Colors.white.withOpacity(0.85),
      ),
    );
  }
}
