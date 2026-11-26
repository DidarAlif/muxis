import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/muxis_colors.dart';
import '../../app/theme/muxis_gradients.dart';
import '../../app/theme/muxis_typography.dart';
import '../../core/audio/audio_playback_service.dart';
import '../../core/database/database_service.dart';
import '../../core/local_scanner/local_library_scanner.dart';
import '../../core/storage/preferences_service.dart';
import '../../shared/models/track.dart';
import '../../shared/widgets/muxis_button.dart';
import '../../shared/widgets/muxis_liquid_surface.dart';
import '../../shared/widgets/muxis_scroll_view.dart';
import '../../shared/widgets/muxis_track_row.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  final int initialTabIndex;

  const LibraryScreen({super.key, this.initialTabIndex = 0});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  late int _tabIndex;
  bool _isScanning = false;
  bool _isDragging = false;
  String _searchFilter = '';
  String? _selectedAlbum;
  String? _selectedArtist;
  String? _selectedPlaylist;

  @override
  void initState() {
    super.initState();
    _tabIndex = widget.initialTabIndex.clamp(0, 5);
  }

  @override
  void didUpdateWidget(LibraryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTabIndex != oldWidget.initialTabIndex) {
      setState(() {
        _tabIndex = widget.initialTabIndex.clamp(0, 5);
        _selectedAlbum = null;
        _selectedArtist = null;
        _selectedPlaylist = null;
      });
    }
  }

  Future<void> _showImportDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final prefs = ref.read(preferencesServiceProvider);
    final lastDir = await prefs.getLastScannedDir() ?? '';
    final pathCtrl = TextEditingController(text: lastDir);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MuxisColors.surface(isDark),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: MuxisColors.border(isDark)),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: MuxisColors.accent(isDark).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.library_music_rounded, color: MuxisColors.accent(isDark), size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              'Import Local Audio Files',
              style: TextStyle(
                color: MuxisColors.textPrimary(isDark),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pick a music folder or specific audio files. Supported formats: FLAC, MP3, WAV, AAC, M4A, OGG, OPUS.',
              style: TextStyle(
                color: MuxisColors.textSecondary(isDark),
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: MuxisButton(
                    label: 'Browse Folder',
                    icon: const Icon(Icons.folder_open_rounded, size: 18),
                    variant: MuxisButtonVariant.secondary,
                    height: 42,
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      await _pickAndScanDirectory();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MuxisButton(
                    label: 'Pick Audio Files',
                    icon: const Icon(Icons.audio_file_rounded, size: 18),
                    variant: MuxisButtonVariant.liquidGlass,
                    height: 42,
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      await _pickAndScanFiles();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Or enter a custom folder path manually:',
              style: TextStyle(color: MuxisColors.textMuted(isDark), fontSize: 12),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: pathCtrl,
              style: TextStyle(
                color: MuxisColors.textPrimary(isDark),
                fontSize: 13,
                fontFamily: 'JetBrains Mono',
              ),
              decoration: InputDecoration(
                hintText: r'e.g. C:\Users\Username\Music',
                hintStyle: TextStyle(color: MuxisColors.textMuted(isDark), fontSize: 12),
                filled: true,
                fillColor: MuxisColors.secondaryBg(isDark),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: MuxisColors.border(isDark)),
                ),
                prefixIcon: Icon(
                  Icons.folder_rounded,
                  color: MuxisColors.accent(isDark),
                  size: 20,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: MuxisColors.textMuted(isDark)),
            ),
          ),
          MuxisButton(
            label: 'Start Scan',
            variant: MuxisButtonVariant.primary,
            height: 38,
            onPressed: () {
              Navigator.of(ctx).pop();
              final path = pathCtrl.text.trim();
              if (path.isNotEmpty) {
                _scanDirectory(path);
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndScanDirectory() async {
    try {
      final selectedPath = await FilePicker.platform.getDirectoryPath();
      if (selectedPath != null && selectedPath.isNotEmpty) {
        await _scanDirectory(selectedPath);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Folder picker error: $e'), backgroundColor: MuxisColors.error),
        );
      }
    }
  }

  Future<void> _pickAndScanFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'flac', 'wav', 'aac', 'm4a', 'ogg', 'opus'],
        allowMultiple: true,
      );

      if (result != null && result.paths.isNotEmpty) {
        final files = result.paths
            .where((p) => p != null && p.isNotEmpty)
            .map((p) => File(p!))
            .toList();

        if (files.isEmpty) return;

        setState(() => _isScanning = true);
        final scanner = ref.read(localLibraryScannerProvider);
        final scanResult = await scanner.scanFiles(files);

        await _saveAndApplyImportedTracks(scanResult.tracks, 'Imported ${scanResult.validAudioFilesFound} tracks');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File picker error: $e'), backgroundColor: MuxisColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
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

    // Persist last scanned dir
    await ref.read(preferencesServiceProvider).saveLastScannedDir(dirPath);

    setState(() => _isScanning = true);
    final scanner = ref.read(localLibraryScannerProvider);
    final result = await scanner.scanDirectory(dir);

    if (mounted) {
      setState(() => _isScanning = false);
      if (result.validAudioFilesFound > 0) {
        await _saveAndApplyImportedTracks(
          result.tracks,
          'Successfully imported ${result.validAudioFilesFound} tracks in ${result.scanDuration.inMilliseconds}ms!',
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scanned ${result.totalFilesScanned} files, but found no supported audio files in $dirPath'),
            backgroundColor: MuxisColors.warning,
          ),
        );
      }
    }
  }

  Future<void> _handleDroppedFiles(List<dynamic> items) async {
    setState(() => _isScanning = true);
    final filesToScan = <File>[];
    final scanner = ref.read(localLibraryScannerProvider);

    for (final item in items) {
      final path = item.path as String?;
      if (path == null || path.isEmpty) continue;

      final file = File(path);
      if (await file.exists()) {
        filesToScan.add(file);
      } else {
        final dir = Directory(path);
        if (await dir.exists()) {
          final res = await scanner.scanDirectory(dir);
          await _saveAndApplyImportedTracks(res.tracks, 'Imported ${res.validAudioFilesFound} tracks from ${dir.path}');
        }
      }
    }

    if (filesToScan.isNotEmpty) {
      final res = await scanner.scanFiles(filesToScan);
      await _saveAndApplyImportedTracks(res.tracks, 'Imported ${res.validAudioFilesFound} dropped audio files');
    }

    if (mounted) setState(() => _isScanning = false);
  }

  Future<void> _saveAndApplyImportedTracks(List<Track> tracks, String successMessage) async {
    if (tracks.isEmpty) return;

    final db = ref.read(databaseServiceProvider);
    await db.saveTracks(tracks);

    final audioService = ref.read(playbackServiceProvider.notifier);
    for (final t in tracks) {
      audioService.addToQueue(t);
    }

    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage),
          backgroundColor: MuxisColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showCreatePlaylistDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MuxisColors.surface(isDark),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: MuxisColors.border(isDark)),
        ),
        title: Text('Create New Playlist', style: TextStyle(color: MuxisColors.textPrimary(isDark), fontWeight: FontWeight.bold)),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          style: TextStyle(color: MuxisColors.textPrimary(isDark)),
          decoration: InputDecoration(
            hintText: 'Playlist Name',
            hintStyle: TextStyle(color: MuxisColors.textMuted(isDark)),
            filled: true,
            fillColor: MuxisColors.secondaryBg(isDark),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: MuxisColors.border(isDark))),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: MuxisColors.textMuted(isDark))),
          ),
          MuxisButton(
            label: 'Create',
            variant: MuxisButtonVariant.primary,
            height: 36,
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isNotEmpty) {
                final db = ref.read(databaseServiceProvider);
                await db.setPlaylist(name, []);
                Navigator.of(ctx).pop();
                setState(() {});
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseServiceProvider);
    final playback = ref.watch(playbackServiceProvider);
    final audioService = ref.read(playbackServiceProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final allTracks = db.getAllTracks();
    final playlists = db.getPlaylists();
    final favoriteTracks = db.getFavoriteTracks();
    final recentTracks = db.getRecentlyPlayed();

    return DropTarget(
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      onDragDone: (detail) async {
        setState(() => _isDragging = false);
        await _handleDroppedFiles(detail.files);
      },
      child: Stack(
        children: [
          MuxisScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header & Scan Actions
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Your Library', style: MuxisTypography.pageTitle(isDark: isDark)),
                        const SizedBox(height: 4),
                        Text(
                          '${allTracks.length} Saved Tracks • ${playlists.length} Playlists • Offline-First Engine',
                          style: TextStyle(fontSize: 13, color: MuxisColors.textSecondary(isDark)),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        MuxisButton(
                          label: _isScanning ? 'Importing...' : 'Import Music',
                          icon: _isScanning
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: MuxisColors.electricCyan),
                                )
                              : const Icon(Icons.add_circle_outline_rounded, size: 18),
                          variant: MuxisButtonVariant.liquidGlass,
                          onPressed: _isScanning ? null : _showImportDialog,
                        ),
                        MuxisButton(
                          label: 'Play All',
                          icon: Icon(Icons.play_arrow_rounded, color: isDark ? Colors.black : Colors.white),
                          variant: MuxisButtonVariant.primary,
                          onPressed: () {
                            if (allTracks.isNotEmpty) {
                              audioService.playTrack(allTracks[0], newQueue: allTracks);
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              const SizedBox(height: 24),

              // Filter Tabs (All Tracks, Playlists, Albums, Artists, Favorites, Recently Played)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildTabChip(0, 'All Tracks (${allTracks.length})', Icons.music_note_rounded, isDark),
                  _buildTabChip(1, 'Playlists (${playlists.length})', Icons.playlist_play_rounded, isDark),
                  _buildTabChip(2, 'Albums', Icons.album_rounded, isDark),
                  _buildTabChip(3, 'Artists', Icons.mic_rounded, isDark),
                  _buildTabChip(4, 'Favorites (${favoriteTracks.length})', Icons.favorite_rounded, isDark),
                  _buildTabChip(5, 'Recently Played', Icons.history_rounded, isDark),
                ],
              ),
              const SizedBox(height: 20),

              // Search Filter Bar (for tracks view)
              if (_tabIndex == 0) ...[
                TextField(
                  style: TextStyle(color: MuxisColors.textPrimary(isDark), fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Filter your library by title, artist, or album...',
                    hintStyle: TextStyle(color: MuxisColors.textMuted(isDark), fontSize: 13),
                    prefixIcon: Icon(Icons.search_rounded, size: 18, color: MuxisColors.accent(isDark)),
                    filled: true,
                    fillColor: isDark
                        ? MuxisColors.elevatedSurface.withOpacity(0.75)
                        : Colors.white.withOpacity(0.8),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: MuxisColors.border(isDark)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: MuxisColors.border(isDark)),
                    ),
                  ),
                  onChanged: (val) => setState(() => _searchFilter = val.trim().toLowerCase()),
                ),
                const SizedBox(height: 16),
              ],

              // Content according to _tabIndex
              _buildActiveTabContent(
                isDark: isDark,
                allTracks: allTracks,
                playlists: playlists,
                favoriteTracks: favoriteTracks,
                recentTracks: recentTracks,
                playback: playback,
                audioService: audioService,
                db: db,
              ),
              ],
            ),
          ),

          // Drag-and-drop Overlay
          if (_isDragging)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.85),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 36),
                    decoration: BoxDecoration(
                      color: MuxisColors.surface(isDark),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: MuxisColors.accent(isDark), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: MuxisColors.accent(isDark).withOpacity(0.3),
                          blurRadius: 30,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.file_download_rounded, color: MuxisColors.accent(isDark), size: 48),
                        SizedBox(height: 16),
                        Text(
                          'Drop Audio Files or Folders Here',
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Muxis will instantly scan and add them to your permanent library',
                          style: TextStyle(color: MuxisColors.textSecondaryDark, fontSize: 13),
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
  }

  Widget _buildTabChip(int index, String label, IconData icon, bool isDark) {
    final isSelected = _tabIndex == index;
    final accent = MuxisColors.accent(isDark);
    return MuxisLiquidSurface(
      onTap: () => setState(() {
        _tabIndex = index;
        _selectedAlbum = null;
        _selectedArtist = null;
        _selectedPlaylist = null;
      }),
      enableGlass: false,
      blurSigma: 0,
      borderRadius: 20,
      accentColor: accent,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      colorOverride: isSelected
          ? accent.withOpacity(isDark ? 0.20 : 0.16)
          : (isDark ? Colors.white.withOpacity(0.04) : Colors.white.withOpacity(0.72)),
      borderOverride: Border.all(
        color: isSelected ? accent : MuxisColors.border(isDark),
        width: isSelected ? 1.5 : 1,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isSelected ? accent : MuxisColors.textMuted(isDark),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected
                  ? MuxisColors.textPrimary(isDark)
                  : MuxisColors.textSecondary(isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTabContent({
    required bool isDark,
    required List<Track> allTracks,
    required Map<String, List<String>> playlists,
    required List<Track> favoriteTracks,
    required List<Track> recentTracks,
    required dynamic playback,
    required AudioPlaybackService audioService,
    required DatabaseService db,
  }) {
    switch (_tabIndex) {
      case 0:
        return _buildTracksList(allTracks, playback, audioService);
      case 1:
        return _buildPlaylistsView(playlists, allTracks, playback, audioService, db);
      case 2:
        return _buildAlbumsView(allTracks, playback, audioService);
      case 3:
        return _buildArtistsView(allTracks, playback, audioService);
      case 4:
        return _buildFavoritesView(favoriteTracks, playback, audioService);
      case 5:
        return _buildRecentlyPlayedView(recentTracks, playback, audioService, db);
      default:
        return _buildTracksList(allTracks, playback, audioService);
    }
  }

  // --- TAB 0: ALL TRACKS ---
  Widget _buildTracksList(List<Track> tracks, dynamic playback, AudioPlaybackService audioService) {
    var filtered = tracks;
    if (_searchFilter.isNotEmpty) {
      filtered = tracks.where((t) {
        return t.title.toLowerCase().contains(_searchFilter) ||
            t.artist.toLowerCase().contains(_searchFilter) ||
            (t.album?.toLowerCase().contains(_searchFilter) ?? false);
      }).toList();
    }

    if (filtered.isEmpty) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.library_music_outlined, size: 56, color: MuxisColors.textMuted(isDark).withOpacity(0.55)),
              const SizedBox(height: 16),
              Text(
                'No tracks in your library yet',
                style: TextStyle(color: MuxisColors.textPrimary(isDark), fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Drag and drop audio files anywhere, or click "Import Music" to scan folders.',
                style: TextStyle(color: MuxisColors.textSecondary(isDark), fontSize: 13),
              ),
              const SizedBox(height: 20),
              MuxisButton(
                label: 'Import Music Folder',
                icon: const Icon(Icons.folder_open_rounded, size: 18),
                variant: MuxisButtonVariant.primary,
                height: 38,
                onPressed: _showImportDialog,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: List.generate(filtered.length, (i) {
        final track = filtered[i];
        final isPlaying = playback.currentTrack?.id == track.id && playback.isPlaying;

        return MuxisTrackRow(
          track: track,
          index: i,
          isPlaying: isPlaying,
          onTap: () => audioService.playTrack(track, newQueue: filtered),
          onFavoriteTap: () => audioService.toggleFavoriteCurrentTrack(),
          onPlayNextTap: () => audioService.addToQueue(track, playNext: true),
          onAddToQueueTap: () => audioService.addToQueue(track),
        );
      }),
    );
  }

  // --- TAB 1: PLAYLISTS ---
  Widget _buildPlaylistsView(
    Map<String, List<String>> playlists,
    List<Track> allTracks,
    dynamic playback,
    AudioPlaybackService audioService,
    DatabaseService db,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_selectedPlaylist != null) {
      final trackUris = playlists[_selectedPlaylist] ?? [];
      final playlistTracks = allTracks.where((t) => trackUris.contains(t.id) || trackUris.contains(t.localFilePath)).toList();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : MuxisColors.textPrimaryLight),
                onPressed: () => setState(() => _selectedPlaylist = null),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_selectedPlaylist!, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : MuxisColors.textPrimaryLight)),
                  Text('${playlistTracks.length} tracks', style: TextStyle(color: MuxisColors.textSecondary(isDark), fontSize: 12)),
                ],
              ),
              const Spacer(),
              if (playlistTracks.isNotEmpty)
                MuxisButton(
                  label: 'Play Playlist',
                  icon: Icon(Icons.play_arrow_rounded, color: isDark ? Colors.black : Colors.white),
                  variant: MuxisButtonVariant.primary,
                  height: 36,
                  onPressed: () => audioService.playTrack(playlistTracks.first, newQueue: playlistTracks),
                ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                tooltip: 'Delete Playlist',
                onPressed: () async {
                  await db.removePlaylist(_selectedPlaylist!);
                  setState(() => _selectedPlaylist = null);
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (playlistTracks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text('This playlist is empty. Add tracks from the All Tracks menu.', style: TextStyle(color: MuxisColors.textMuted(isDark))),
              ),
            )
          else
            _buildTracksList(playlistTracks, playback, audioService),
        ],
      );
    }

    final playlistEntries = playlists.entries.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Your Playlists', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : MuxisColors.textPrimaryLight)),
            MuxisButton(
              label: 'New Playlist',
              icon: const Icon(Icons.add_rounded, size: 18),
              variant: MuxisButtonVariant.liquidGlass,
              height: 34,
              onPressed: _showCreatePlaylistDialog,
            ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final cardW = _responsiveWrapWidth(constraints.maxWidth, 180);
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(
                  width: cardW,
                  height: cardW * 1.15,
                  child: MuxisLiquidSurface(
                    onTap: _showCreatePlaylistDialog,
                    borderRadius: 16,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_circle_outline_rounded, size: 40, color: MuxisColors.accent(isDark)),
                        const SizedBox(height: 12),
                        Text('Create Playlist', style: TextStyle(color: isDark ? Colors.white : MuxisColors.textPrimaryLight, fontWeight: FontWeight.w600, fontSize: 14)),
                      ],
                    ),
                  ),
                ),
                ...playlistEntries.map((pl) {
                  return SizedBox(
                    width: cardW,
                    height: cardW * 1.15,
                    child: MuxisLiquidSurface(
                      onTap: () => setState(() => _selectedPlaylist = pl.key),
                      borderRadius: 16,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: MuxisGradients.prismaticPrimary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(
                                child: Icon(Icons.playlist_play_rounded, size: 42, color: Colors.black),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            pl.key,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : MuxisColors.textPrimaryLight),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${pl.value.length} songs',
                            style: TextStyle(color: MuxisColors.textSecondary(isDark), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ],
    );
  }

  // --- TAB 2: ALBUMS ---
  Widget _buildAlbumsView(List<Track> allTracks, dynamic playback, AudioPlaybackService audioService) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_selectedAlbum != null) {
      final albumTracks = allTracks.where((t) => (t.album ?? 'Unknown Album') == _selectedAlbum).toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : MuxisColors.textPrimaryLight),
                onPressed: () => setState(() => _selectedAlbum = null),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_selectedAlbum!, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : MuxisColors.textPrimaryLight)),
                  Text('${albumTracks.length} tracks', style: TextStyle(color: MuxisColors.textSecondary(isDark), fontSize: 12)),
                ],
              ),
              const Spacer(),
              if (albumTracks.isNotEmpty)
                MuxisButton(
                  label: 'Play Album',
                  icon: Icon(Icons.play_arrow_rounded, color: isDark ? Colors.black : Colors.white),
                  variant: MuxisButtonVariant.primary,
                  height: 36,
                  onPressed: () => audioService.playTrack(albumTracks.first, newQueue: albumTracks),
                ),
            ],
          ),
          const SizedBox(height: 20),
          _buildTracksList(albumTracks, playback, audioService),
        ],
      );
    }

    final albums = <String, List<Track>>{};
    for (final t in allTracks) {
      final alb = t.album != null && t.album!.isNotEmpty ? t.album! : 'Singles & Unknown';
      albums.putIfAbsent(alb, () => []).add(t);
    }

    if (albums.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(child: Text('No albums found in your library.', style: TextStyle(color: MuxisColors.textMuted(isDark)))),
      );
    }

    final albumEntries = albums.entries.toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardW = _responsiveWrapWidth(constraints.maxWidth, 174);
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: albumEntries.map((entry) {
            final firstTrack = entry.value.first;
            return SizedBox(
              width: cardW,
              height: cardW * 1.24,
              child: MuxisLiquidSurface(
                onTap: () => setState(() => _selectedAlbum = entry.key),
                borderRadius: 16,
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: MuxisGradients.auroraSpectrum,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: firstTrack.artworkUrl != null
                            ? Image.network(
                                firstTrack.artworkUrl!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                errorBuilder: (_, __, ___) => const Center(
                                  child: Icon(Icons.album_rounded, size: 48, color: Colors.black45),
                                ),
                              )
                            : const Center(
                                child: Icon(Icons.album_rounded, size: 48, color: Colors.black45),
                              ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      entry.key,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : MuxisColors.textPrimaryLight),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${entry.value.length} tracks • ${firstTrack.artist}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: MuxisColors.textSecondary(isDark), fontSize: 11),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // --- TAB 3: ARTISTS ---
  Widget _buildArtistsView(List<Track> allTracks, dynamic playback, AudioPlaybackService audioService) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_selectedArtist != null) {
      final artistTracks = allTracks.where((t) => t.artist == _selectedArtist).toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : MuxisColors.textPrimaryLight),
                onPressed: () => setState(() => _selectedArtist = null),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_selectedArtist!, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : MuxisColors.textPrimaryLight)),
                  Text('${artistTracks.length} tracks', style: TextStyle(color: MuxisColors.textSecondary(isDark), fontSize: 12)),
                ],
              ),
              const Spacer(),
              if (artistTracks.isNotEmpty)
                MuxisButton(
                  label: 'Play Artist',
                  icon: Icon(Icons.play_arrow_rounded, color: isDark ? Colors.black : Colors.white),
                  variant: MuxisButtonVariant.primary,
                  height: 36,
                  onPressed: () => audioService.playTrack(artistTracks.first, newQueue: artistTracks),
                ),
            ],
          ),
          const SizedBox(height: 20),
          _buildTracksList(artistTracks, playback, audioService),
        ],
      );
    }

    final artists = <String, List<Track>>{};
    for (final t in allTracks) {
      final art = t.artist.isNotEmpty ? t.artist : 'Unknown Artist';
      artists.putIfAbsent(art, () => []).add(t);
    }

    if (artists.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(child: Text('No artists found in your library.', style: TextStyle(color: MuxisColors.textMuted(isDark)))),
      );
    }

    final artistEntries = artists.entries.toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardW = _responsiveWrapWidth(constraints.maxWidth, 160);
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: artistEntries.map((entry) {
            return SizedBox(
              width: cardW,
              child: MuxisLiquidSurface(
                onTap: () => setState(() => _selectedArtist = entry.key),
                borderRadius: 16,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: MuxisGradients.auroraSpectrum,
                        border: Border.all(color: MuxisColors.accent(isDark), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: MuxisColors.accent(isDark).withOpacity(0.2),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.mic_rounded, size: 42, color: Colors.black),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      entry.key,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : MuxisColors.textPrimaryLight),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${entry.value.length} songs',
                      style: TextStyle(color: MuxisColors.textSecondary(isDark), fontSize: 11),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  static double _responsiveWrapWidth(double availableWidth, double target) {
    const spacing = 16.0;
    final cols = ((availableWidth + spacing) / (target + spacing))
        .floor()
        .clamp(2, 7);
    return ((availableWidth - spacing * (cols - 1)) / cols).clamp(140.0, 220.0);
  }

  // --- TAB 4: FAVORITES ---
  Widget _buildFavoritesView(List<Track> favorites, dynamic playback, AudioPlaybackService audioService) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (favorites.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.favorite_border_rounded, size: 56, color: MuxisColors.accent(isDark)),
              const SizedBox(height: 16),
              Text(
                'No favorite tracks yet',
                style: TextStyle(color: isDark ? Colors.white : MuxisColors.textPrimaryLight, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap the heart icon on any song to save it to your Favorites collection.',
                style: TextStyle(color: MuxisColors.textSecondary(isDark), fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${favorites.length} Favorite Tracks', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : MuxisColors.textPrimaryLight)),
            MuxisButton(
              label: 'Play All Favorites',
              icon: Icon(Icons.play_arrow_rounded, color: isDark ? Colors.black : Colors.white),
              variant: MuxisButtonVariant.primary,
              height: 36,
              onPressed: () => audioService.playTrack(favorites.first, newQueue: favorites),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildTracksList(favorites, playback, audioService),
      ],
    );
  }

  // --- TAB 5: RECENTLY PLAYED ---
  Widget _buildRecentlyPlayedView(
    List<Track> recents,
    dynamic playback,
    AudioPlaybackService audioService,
    DatabaseService db,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (recents.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.history_rounded, size: 56, color: MuxisColors.textMuted(isDark)),
              const SizedBox(height: 16),
              Text(
                'No recently played tracks',
                style: TextStyle(color: isDark ? Colors.white : MuxisColors.textPrimaryLight, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Tracks you play will automatically appear here in historical order.',
                style: TextStyle(color: MuxisColors.textSecondary(isDark), fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${recents.length} Recently Played', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : MuxisColors.textPrimaryLight)),
            Row(
              children: [
                MuxisButton(
                  label: 'Play History',
                  icon: Icon(Icons.play_arrow_rounded, color: isDark ? Colors.black : Colors.white),
                  variant: MuxisButtonVariant.primary,
                  height: 34,
                  onPressed: () => audioService.playTrack(recents.first, newQueue: recents),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.delete_sweep_rounded, color: MuxisColors.textMuted(isDark)),
                  tooltip: 'Clear Listening History',
                  onPressed: () async {
                    await db.clearHistory();
                    setState(() {});
                  },
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildTracksList(recents, playback, audioService),
      ],
    );
  }
}
