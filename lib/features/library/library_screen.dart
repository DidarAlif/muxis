import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/muxis_colors.dart';
import '../../app/theme/muxis_typography.dart';
import '../../core/audio/audio_playback_service.dart';
import '../../core/database/database_service.dart';
import '../../core/local_scanner/local_library_scanner.dart';
import '../../shared/widgets/muxis_button.dart';
import '../../shared/widgets/muxis_track_row.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  int _tabIndex = 0;
  bool _isScanning = false;

  void _showImportDialog() {
    final pathCtrl = TextEditingController(text: 'C:\\Users\\didar\\Music');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MuxisColors.elevatedSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: MuxisColors.subtleBorderDark),
        ),
        title: const Text(
          'Scan Local Audio Folder',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select or enter the folder path containing your audio files (FLAC, MP3, WAV, AAC, OGG):',
              style: TextStyle(
                color: MuxisColors.textSecondaryDark,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: pathCtrl,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontFamily: 'JetBrains Mono',
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: MuxisColors.deepSpace,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(
                  Icons.folder_open_rounded,
                  color: MuxisColors.electricCyan,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: MuxisColors.textMutedDark),
            ),
          ),
          MuxisButton(
            label: 'Start Scan',
            variant: MuxisButtonVariant.primary,
            height: 36,
            onPressed: () {
              Navigator.of(ctx).pop();
              _scanDirectory(pathCtrl.text.trim());
            },
          ),
        ],
      ),
    );
  }

  Future<void> _scanDirectory(String dirPath) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Directory not found: $dirPath'),
            backgroundColor: MuxisColors.error,
          ),
        );
      }
      return;
    }

    setState(() => _isScanning = true);
    final scanner = ref.read(localLibraryScannerProvider);
    final result = await scanner.scanDirectory(dir);

    if (mounted) {
      setState(() => _isScanning = false);

      if (result.validAudioFilesFound > 0) {
        final db = ref.read(databaseServiceProvider);
        await db.saveTracks(result.tracks);

        final audioService = ref.read(playbackServiceProvider.notifier);
        for (final t in result.tracks) {
          audioService.addToQueue(t);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully imported ${result.validAudioFilesFound} tracks in ${result.scanDuration.inMilliseconds}ms!',
            ),
            backgroundColor: MuxisColors.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Scanned ${result.totalFilesScanned} files, but found no supported audio files in $dirPath',
            ),
            backgroundColor: MuxisColors.warning,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final playback = ref.watch(playbackServiceProvider);
    final audioService = ref.read(playbackServiceProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      children: [
        // Header & Scan Actions
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Library',
                  style: MuxisTypography.pageTitle(isDark: isDark),
                ),
                const SizedBox(height: 4),
                Text(
                  '${playback.queue.length} Tracks In Current Session • Real-Time Local Engine',
                  style: const TextStyle(
                    fontSize: 13,
                    color: MuxisColors.textSecondaryDark,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                MuxisButton(
                  label: _isScanning ? 'Scanning...' : 'Import Music Folder',
                  icon: _isScanning
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: MuxisColors.electricCyan,
                          ),
                        )
                      : const Icon(Icons.create_new_folder_rounded, size: 18),
                  variant: MuxisButtonVariant.secondary,
                  onPressed: _isScanning ? null : _showImportDialog,
                ),
                const SizedBox(width: 12),
                MuxisButton(
                  label: 'Play All',
                  icon: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.black,
                  ),
                  variant: MuxisButtonVariant.primary,
                  onPressed: () {
                    if (playback.queue.isNotEmpty) {
                      audioService.playTrack(playback.queue[0]);
                    }
                  },
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Filter Tabs (All Tracks, Albums, Artists, Favorites)
        Row(
          children: ['All Tracks', 'Albums', 'Artists', 'Favorites']
              .asMap()
              .entries
              .map((entry) {
                final idx = entry.key;
                final title = entry.value;
                final isSelected = _tabIndex == idx;

                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: ChoiceChip(
                    label: Text(title),
                    selected: isSelected,
                    selectedColor: MuxisColors.electricCyan.withOpacity(0.2),
                    onSelected: (_) => setState(() => _tabIndex = idx),
                  ),
                );
              })
              .toList(),
        ),
        const SizedBox(height: 20),

        // Track Table
        if (playback.queue.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                'No tracks in library yet. Click "Import Music Folder" to scan local audio files.',
                style: TextStyle(color: MuxisColors.textMutedDark),
              ),
            ),
          )
        else
          ...List.generate(playback.queue.length, (i) {
            final track = playback.queue[i];
            if (_tabIndex == 3 && !track.isFavorite) {
              return const SizedBox.shrink(); // Filter to favorites only
            }

            return MuxisTrackRow(
              track: track,
              index: i,
              isPlaying:
                  playback.currentTrack?.id == track.id && playback.isPlaying,
              onTap: () => audioService.playTrack(track),
              onFavoriteTap: () => audioService.toggleFavoriteCurrentTrack(),
              onPlayNextTap: () =>
                  audioService.addToQueue(track, playNext: true),
              onAddToQueueTap: () => audioService.addToQueue(track),
            );
          }),
      ],
    );
  }
}
