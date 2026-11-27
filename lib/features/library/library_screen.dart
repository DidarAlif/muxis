import 'dart:async';
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
import '../../shared/utils/library_filter.dart';
import '../../shared/widgets/muxis_button.dart';
import '../../shared/widgets/muxis_liquid_surface.dart';
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
  final ScrollController _scrollCtrl = ScrollController();
  final TextEditingController _filterCtrl = TextEditingController();
  Timer? _searchDebounce;
  String _searchFilter = '';
  LibrarySortOption _sortOption = LibrarySortOption.recentlyAdded;
  LibraryKeywordPreset _presetFilter = LibraryKeywordPreset.all;
  String? _selectedAlbum;
  String? _selectedArtist;
  String? _selectedPlaylist;

  int _cachedTracksRev = -1;
  int _cachedTracksTab = -1;
  String _cachedQuery = '';
  LibraryKeywordPreset _cachedPreset = LibraryKeywordPreset.all;
  LibrarySortOption _cachedSort = LibrarySortOption.recentlyAdded;
  bool _cachedAppliedSort = false;
  String? _cachedSubKey;
  List<Track> _cachedFiltered = const [];

  int _cachedGroupsRev = -1;
  List<MapEntry<String, List<Track>>> _cachedAlbumEntries = const [];
  List<MapEntry<String, List<Track>>> _cachedArtistEntries = const [];

  @override
  void initState() {
    super.initState();
    _tabIndex = widget.initialTabIndex.clamp(0, 5);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollCtrl.dispose();
    _filterCtrl.dispose();
    super.dispose();
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
      _resetScroll();
    }
  }

  void _resetScroll() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.jumpTo(0);
    }
  }

  void _ensureGroupsCached(DatabaseService db) {
    if (_cachedGroupsRev == db.revision) return;
    final allTracks = db.getAllTracks();
    final albums = <String, List<Track>>{};
    final artists = <String, List<Track>>{};
    for (final t in allTracks) {
      final alb = (t.album.isNotEmpty) ? t.album : 'Singles & Unknown';
      albums.putIfAbsent(alb, () => []).add(t);
      final art = t.artist.isNotEmpty ? t.artist : 'Unknown Artist';
      artists.putIfAbsent(art, () => []).add(t);
    }
    _cachedAlbumEntries = albums.entries.toList(growable: false);
    _cachedArtistEntries = artists.entries.toList(growable: false);
    _cachedGroupsRev = db.revision;
  }

  List<Track> _resolveDisplayedTracks({
    required DatabaseService db,
    required int tabTag,
    required String? subKey,
    required List<Track> Function() computeSource,
    required bool applySortAndPreset,
  }) {
    final matchesCache =
        _cachedTracksRev == db.revision &&
        _cachedTracksTab == tabTag &&
        _cachedSubKey == subKey &&
        _cachedAppliedSort == applySortAndPreset &&
        (!applySortAndPreset ||
            (_cachedQuery == _searchFilter &&
                _cachedPreset == _presetFilter &&
                _cachedSort == _sortOption));

    if (matchesCache) {
      return _cachedFiltered;
    }

    final raw = computeSource();
    final computed = applySortAndPreset
        ? applyLibrarySortAndFilter(
            tracks: raw,
            searchQuery: _searchFilter,
            preset: _presetFilter,
            sortOption: _sortOption,
          )
        : raw;

    _cachedTracksRev = db.revision;
    _cachedTracksTab = tabTag;
    _cachedSubKey = subKey;
    _cachedAppliedSort = applySortAndPreset;
    if (applySortAndPreset) {
      _cachedQuery = _searchFilter;
      _cachedPreset = _presetFilter;
      _cachedSort = _sortOption;
    }
    _cachedFiltered = computed;
    return computed;
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
              child: Icon(
                Icons.library_music_rounded,
                color: MuxisColors.accent(isDark),
                size: 20,
              ),
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
              style: TextStyle(
                color: MuxisColors.textMuted(isDark),
                fontSize: 12,
              ),
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
                hintStyle: TextStyle(
                  color: MuxisColors.textMuted(isDark),
                  fontSize: 12,
                ),
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
          SnackBar(
            content: Text('Folder picker error: $e'),
            backgroundColor: MuxisColors.error,
          ),
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

        await _saveAndApplyImportedTracks(
          scanResult.tracks,
          'Imported ${scanResult.validAudioFilesFound} tracks',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File picker error: $e'),
            backgroundColor: MuxisColors.error,
          ),
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
            content: Text(
              'Scanned ${result.totalFilesScanned} files, but found no supported audio files in $dirPath',
            ),
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
          await _saveAndApplyImportedTracks(
            res.tracks,
            'Imported ${res.validAudioFilesFound} tracks from ${dir.path}',
          );
        }
      }
    }

    if (filesToScan.isNotEmpty) {
      final res = await scanner.scanFiles(filesToScan);
      await _saveAndApplyImportedTracks(
        res.tracks,
        'Imported ${res.validAudioFilesFound} dropped audio files',
      );
    }

    if (mounted) setState(() => _isScanning = false);
  }

  Future<void> _saveAndApplyImportedTracks(
    List<Track> tracks,
    String successMessage,
  ) async {
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
        title: Text(
          'Create New Playlist',
          style: TextStyle(
            color: MuxisColors.textPrimary(isDark),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          style: TextStyle(color: MuxisColors.textPrimary(isDark)),
          decoration: InputDecoration(
            hintText: 'Playlist Name',
            hintStyle: TextStyle(color: MuxisColors.textMuted(isDark)),
            filled: true,
            fillColor: MuxisColors.secondaryBg(isDark),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: MuxisColors.border(isDark)),
            ),
          ),
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
    final playback = ref.watch(
      playbackServiceProvider.select(
        (s) => (currentTrack: s.currentTrack, isPlaying: s.isPlaying),
      ),
    );
    final audioService = ref.read(playbackServiceProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final isMobile = viewportWidth < 768;
    final horizontalPad = isMobile ? 16.0 : 32.0;
    final verticalTop = isMobile ? 14.0 : 24.0;
    final verticalBottom = isMobile ? 20.0 : 24.0;
    final rowExtent = (30.0 + MediaQuery.textScalerOf(context).scale(40.0))
        .clamp(70.0, 98.0);
    final physics = isMobile
        ? const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics())
        : const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics());

    final allTracks = db.getAllTracks();
    final playlists = db.getPlaylists();

    return DropTarget(
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      onDragDone: (detail) async {
        setState(() => _isDragging = false);
        await _handleDroppedFiles(detail.files);
      },
      child: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final gridWidth = (constraints.maxWidth - horizontalPad * 2)
                  .clamp(240.0, 2400.0);

              return Scrollbar(
                controller: _scrollCtrl,
                interactive: !isMobile,
                thickness: isMobile ? 3.5 : 6,
                radius: const Radius.circular(8),
                child: CustomScrollView(
                  controller: _scrollCtrl,
                  primary: false,
                  cacheExtent: 500,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  physics: physics,
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPad,
                        verticalTop,
                        horizontalPad,
                        0,
                      ),
                      sliver: SliverToBoxAdapter(
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
                                    Text(
                                      'Your Library',
                                      style: MuxisTypography.pageTitle(
                                        isDark: isDark,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${db.trackCount} Saved Tracks • ${db.playlistCount} Playlists • Offline-First Engine',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: MuxisColors.textSecondary(
                                          isDark,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 8,
                                  children: [
                                    MuxisButton(
                                      label: _isScanning
                                          ? 'Importing...'
                                          : 'Import Music',
                                      height: 36,
                                      icon: _isScanning
                                          ? const SizedBox(
                                              width: 14,
                                              height: 14,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: MuxisColors.electricCyan,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.add_circle_outline_rounded,
                                              size: 17,
                                            ),
                                      variant: MuxisButtonVariant.liquidGlass,
                                      onPressed: _isScanning
                                          ? null
                                          : _showImportDialog,
                                    ),
                                    MuxisButton(
                                      label: 'Play All',
                                      height: 36,
                                      icon: Icon(
                                        Icons.play_arrow_rounded,
                                        color: isDark
                                            ? Colors.black
                                            : Colors.white,
                                      ),
                                      variant: MuxisButtonVariant.primary,
                                      onPressed: () {
                                        if (allTracks.isNotEmpty) {
                                          audioService.playTrack(
                                            allTracks[0],
                                            newQueue: allTracks,
                                          );
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // Filter Tabs
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildTabChip(
                                  0,
                                  'All Tracks (${db.trackCount})',
                                  Icons.music_note_rounded,
                                  isDark,
                                ),
                                _buildTabChip(
                                  1,
                                  'Playlists (${db.playlistCount})',
                                  Icons.playlist_play_rounded,
                                  isDark,
                                ),
                                _buildTabChip(
                                  2,
                                  'Albums',
                                  Icons.album_rounded,
                                  isDark,
                                ),
                                _buildTabChip(
                                  3,
                                  'Artists',
                                  Icons.mic_rounded,
                                  isDark,
                                ),
                                _buildTabChip(
                                  4,
                                  'Favorites (${db.favoriteCount})',
                                  Icons.favorite_rounded,
                                  isDark,
                                ),
                                _buildTabChip(
                                  5,
                                  'Recently Played',
                                  Icons.history_rounded,
                                  isDark,
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Search, Sort Dropdown & Pre-Sorting Keyword Chips (All Tracks & Favorites)
                            if (_tabIndex == 0 || _tabIndex == 4) ...[
                              LayoutBuilder(
                                builder: (context, fieldConstraints) {
                                  final isCompact =
                                      fieldConstraints.maxWidth < 560;
                                  final searchField =
                                      ValueListenableBuilder<TextEditingValue>(
                                        valueListenable: _filterCtrl,
                                        builder: (context, textVal, _) {
                                          final hasClear =
                                              textVal.text.isNotEmpty ||
                                              _searchFilter.isNotEmpty ||
                                              _presetFilter !=
                                                  LibraryKeywordPreset.all;
                                          return TextField(
                                            controller: _filterCtrl,
                                            style: TextStyle(
                                              color: MuxisColors.textPrimary(
                                                isDark,
                                              ),
                                              fontSize: 13,
                                            ),
                                            decoration: InputDecoration(
                                              hintText: 'Filter by title, artist, album, or format...',
                                              hintStyle: TextStyle(
                                                color: MuxisColors.textMuted(
                                                  isDark,
                                                ),
                                                fontSize: 13,
                                              ),
                                              prefixIcon: Icon(
                                                Icons.search_rounded,
                                                size: 18,
                                                color: MuxisColors.accent(
                                                  isDark,
                                                ),
                                              ),
                                              suffixIcon: hasClear
                                                  ? IconButton(
                                                      icon: const Icon(
                                                        Icons.close_rounded,
                                                        size: 18,
                                                      ),
                                                      tooltip: 'Clear filters',
                                                      onPressed: () {
                                                        _searchDebounce
                                                            ?.cancel();
                                                        _filterCtrl.clear();
                                                        setState(() {
                                                          _searchFilter = '';
                                                          _presetFilter =
                                                              LibraryKeywordPreset
                                                                  .all;
                                                          _sortOption =
                                                              LibrarySortOption
                                                                  .recentlyAdded;
                                                        });
                                                      },
                                                    )
                                                  : null,
                                              filled: true,
                                              fillColor: isDark
                                                  ? MuxisColors.elevatedSurface
                                                        .withOpacity(0.75)
                                                  : Colors.white.withOpacity(
                                                      0.8,
                                                    ),
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 12,
                                                  ),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                borderSide: BorderSide(
                                                  color: MuxisColors.border(
                                                    isDark,
                                                  ),
                                                ),
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                borderSide: BorderSide(
                                                  color: MuxisColors.border(
                                                    isDark,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            onChanged: (val) {
                                              final normalized = val
                                                  .trim()
                                                  .toLowerCase();
                                              _searchDebounce?.cancel();
                                              if (normalized == _searchFilter) {
                                                return;
                                              }
                                              _searchDebounce = Timer(
                                                const Duration(
                                                  milliseconds: 110,
                                                ),
                                                () {
                                                  if (!mounted) return;
                                                  setState(
                                                    () => _searchFilter =
                                                        normalized,
                                                  );
                                                },
                                              );
                                            },
                                          );
                                        },
                                      );

                                  final sortDropdown = Container(
                                    height: 44,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? MuxisColors.elevatedSurface
                                                .withOpacity(0.82)
                                          : Colors.white.withOpacity(0.86),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: MuxisColors.border(isDark),
                                      ),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<LibrarySortOption>(
                                        value: _sortOption,
                                        dropdownColor: MuxisColors.surface(
                                          isDark,
                                        ),
                                        icon: Icon(
                                          Icons.sort_rounded,
                                          size: 18,
                                          color: MuxisColors.accent(isDark),
                                        ),
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: MuxisColors.textPrimary(
                                            isDark,
                                          ),
                                        ),
                                        items: LibrarySortOption.values
                                            .map(
                                              (opt) => DropdownMenuItem(
                                                value: opt,
                                                child: Text(opt.label),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: (opt) {
                                          if (opt != null) {
                                            setState(() => _sortOption = opt);
                                          }
                                        },
                                      ),
                                    ),
                                  );

                                  if (isCompact) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        searchField,
                                        const SizedBox(height: 10),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: sortDropdown,
                                        ),
                                      ],
                                    );
                                  }

                                  return Row(
                                    children: [
                                      Expanded(child: searchField),
                                      const SizedBox(width: 12),
                                      sortDropdown,
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: LibraryKeywordPreset.values.map((
                                  preset,
                                ) {
                                  final selected = _presetFilter == preset;
                                  final accent = MuxisColors.accent(isDark);
                                  return MuxisLiquidSurface(
                                    onTap: () {
                                      setState(() {
                                        _presetFilter = preset;
                                        if (preset ==
                                            LibraryKeywordPreset.extended) {
                                          _sortOption =
                                              LibrarySortOption.durationDesc;
                                        } else if (preset ==
                                            LibraryKeywordPreset.shortTracks) {
                                          _sortOption =
                                              LibrarySortOption.durationAsc;
                                        } else if (preset ==
                                            LibraryKeywordPreset.all) {
                                          _sortOption =
                                              LibrarySortOption.recentlyAdded;
                                        }
                                      });
                                    },
                                    enableGlass: false,
                                    blurSigma: 0,
                                    borderRadius: 16,
                                    accentColor: accent,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 11,
                                      vertical: 6,
                                    ),
                                    colorOverride: selected
                                        ? accent.withOpacity(
                                            isDark ? 0.22 : 0.16,
                                          )
                                        : (isDark
                                              ? Colors.white.withOpacity(0.05)
                                              : Colors.white.withOpacity(0.75)),
                                    borderOverride: Border.all(
                                      color: selected
                                          ? accent
                                          : MuxisColors.border(isDark),
                                      width: selected ? 1.4 : 1,
                                    ),
                                    child: Text(
                                      preset.label,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: selected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: selected
                                            ? accent
                                            : MuxisColors.textSecondary(isDark),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 16),
                            ],
                          ],
                        ),
                      ),
                    ),
                    ..._buildActiveTabSlivers(
                      isDark: isDark,
                      horizontalPad: horizontalPad,
                      verticalBottom: verticalBottom,
                      gridWidth: gridWidth,
                      rowExtent: rowExtent,
                      allTracks: allTracks,
                      playlists: playlists,
                      playback: playback,
                      audioService: audioService,
                      db: db,
                    ),
                  ],
                ),
              );
            },
          ),

          // Drag-and-drop Overlay
          if (_isDragging)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.85),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 48,
                      vertical: 36,
                    ),
                    decoration: BoxDecoration(
                      color: MuxisColors.surface(isDark),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: MuxisColors.accent(isDark),
                        width: 2,
                      ),
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
                        Icon(
                          Icons.file_download_rounded,
                          color: MuxisColors.accent(isDark),
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Drop Audio Files or Folders Here',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Muxis will instantly scan and add them to your permanent library',
                          style: TextStyle(
                            color: MuxisColors.textSecondaryDark,
                            fontSize: 13,
                          ),
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
      onTap: () {
        setState(() {
          _tabIndex = index;
          _selectedAlbum = null;
          _selectedArtist = null;
          _selectedPlaylist = null;
        });
        _resetScroll();
      },
      enableGlass: false,
      blurSigma: 0,
      borderRadius: 20,
      accentColor: accent,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      colorOverride: isSelected
          ? accent.withOpacity(isDark ? 0.20 : 0.16)
          : (isDark
                ? Colors.white.withOpacity(0.04)
                : Colors.white.withOpacity(0.72)),
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

  List<Widget> _buildActiveTabSlivers({
    required bool isDark,
    required double horizontalPad,
    required double verticalBottom,
    required double gridWidth,
    required double rowExtent,
    required List<Track> allTracks,
    required Map<String, List<String>> playlists,
    required ({Track? currentTrack, bool isPlaying}) playback,
    required AudioPlaybackService audioService,
    required DatabaseService db,
  }) {
    switch (_tabIndex) {
      case 0:
        final tracks = _resolveDisplayedTracks(
          db: db,
          tabTag: 0,
          subKey: null,
          computeSource: () => allTracks,
          applySortAndPreset: true,
        );
        return _buildTracksSlivers(
          filtered: tracks,
          hasAnySourceTracks: allTracks.isNotEmpty,
          horizontalPad: horizontalPad,
          verticalBottom: verticalBottom,
          rowExtent: rowExtent,
          playback: playback,
          audioService: audioService,
          db: db,
          applySortAndPreset: true,
        );
      case 1:
        return _buildPlaylistsSlivers(
          isDark: isDark,
          horizontalPad: horizontalPad,
          verticalBottom: verticalBottom,
          gridWidth: gridWidth,
          rowExtent: rowExtent,
          playlists: playlists,
          allTracks: allTracks,
          playback: playback,
          audioService: audioService,
          db: db,
        );
      case 2:
        return _buildAlbumsSlivers(
          isDark: isDark,
          horizontalPad: horizontalPad,
          verticalBottom: verticalBottom,
          gridWidth: gridWidth,
          rowExtent: rowExtent,
          allTracks: allTracks,
          playback: playback,
          audioService: audioService,
          db: db,
        );
      case 3:
        return _buildArtistsSlivers(
          isDark: isDark,
          horizontalPad: horizontalPad,
          verticalBottom: verticalBottom,
          gridWidth: gridWidth,
          rowExtent: rowExtent,
          allTracks: allTracks,
          playback: playback,
          audioService: audioService,
          db: db,
        );
      case 4:
        return _buildFavoritesSlivers(
          isDark: isDark,
          horizontalPad: horizontalPad,
          verticalBottom: verticalBottom,
          rowExtent: rowExtent,
          playback: playback,
          audioService: audioService,
          db: db,
        );
      case 5:
        return _buildRecentlyPlayedSlivers(
          isDark: isDark,
          horizontalPad: horizontalPad,
          verticalBottom: verticalBottom,
          rowExtent: rowExtent,
          playback: playback,
          audioService: audioService,
          db: db,
        );
      default:
        final tracks = _resolveDisplayedTracks(
          db: db,
          tabTag: 0,
          subKey: null,
          computeSource: () => allTracks,
          applySortAndPreset: true,
        );
        return _buildTracksSlivers(
          filtered: tracks,
          hasAnySourceTracks: allTracks.isNotEmpty,
          horizontalPad: horizontalPad,
          verticalBottom: verticalBottom,
          rowExtent: rowExtent,
          playback: playback,
          audioService: audioService,
          db: db,
          applySortAndPreset: true,
        );
    }
  }

  List<Widget> _buildTracksSlivers({
    required List<Track> filtered,
    required bool hasAnySourceTracks,
    required double horizontalPad,
    required double verticalBottom,
    required double rowExtent,
    required ({Track? currentTrack, bool isPlaying}) playback,
    required AudioPlaybackService audioService,
    required DatabaseService db,
    bool applySortAndPreset = false,
  }) {
    if (filtered.isEmpty) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            horizontalPad,
            32,
            horizontalPad,
            verticalBottom + 16,
          ),
          sliver: SliverToBoxAdapter(
            child: Center(
              child: Column(
                children: [
                  Icon(
                    hasAnySourceTracks
                        ? Icons.filter_list_off_rounded
                        : Icons.library_music_outlined,
                    size: 56,
                    color: MuxisColors.textMuted(isDark).withOpacity(0.55),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    hasAnySourceTracks
                        ? 'No matching tracks for current filter'
                        : 'No tracks in your library yet',
                    style: TextStyle(
                      color: MuxisColors.textPrimary(isDark),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    hasAnySourceTracks
                        ? 'Try choosing another keyword chip or reset your library filters.'
                        : (MediaQuery.sizeOf(context).width < 768
                              ? 'Tap "Import Music" to scan audio folders or files on your device.'
                              : 'Drag and drop audio files anywhere, or click "Import Music" to scan folders.'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: MuxisColors.textSecondary(isDark),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 20),
                  MuxisButton(
                    label: hasAnySourceTracks
                        ? 'Reset Filters'
                        : 'Import Music Folder',
                    icon: Icon(
                      hasAnySourceTracks
                          ? Icons.clear_all_rounded
                          : Icons.folder_open_rounded,
                      size: 18,
                    ),
                    variant: MuxisButtonVariant.primary,
                    height: 38,
                    onPressed: hasAnySourceTracks
                        ? () {
                            _searchDebounce?.cancel();
                            _filterCtrl.clear();
                            setState(() {
                              _searchFilter = '';
                              _presetFilter = LibraryKeywordPreset.all;
                              _sortOption = LibrarySortOption.recentlyAdded;
                            });
                          }
                        : _showImportDialog,
                  ),
                ],
              ),
            ),
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(
          horizontalPad,
          0,
          horizontalPad,
          verticalBottom,
        ),
        sliver: SliverFixedExtentList.builder(
          itemCount: filtered.length,
          itemExtent: rowExtent,
          addAutomaticKeepAlives: false,
          itemBuilder: (context, i) {
            final track = filtered[i];
            final isPlaying =
                playback.currentTrack?.id == track.id && playback.isPlaying;

            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: MuxisTrackRow(
                key: ValueKey(track.id),
                track: track.copyWith(isFavorite: db.isFavorite(track.id)),
                index: i,
                isPlaying: isPlaying,
                onTap: () => audioService.playTrack(track, newQueue: filtered),
                onFavoriteTap: () {
                  audioService.toggleFavoriteTrack(track);
                  if (mounted) setState(() {});
                },
                onPlayNextTap: () =>
                    audioService.addToQueue(track, playNext: true),
                onAddToQueueTap: () => audioService.addToQueue(track),
              ),
            );
          },
        ),
      ),
    ];
  }

  // --- TAB 1: PLAYLISTS ---
  List<Widget> _buildPlaylistsSlivers({
    required bool isDark,
    required double horizontalPad,
    required double verticalBottom,
    required double gridWidth,
    required double rowExtent,
    required Map<String, List<String>> playlists,
    required List<Track> allTracks,
    required ({Track? currentTrack, bool isPlaying}) playback,
    required AudioPlaybackService audioService,
    required DatabaseService db,
  }) {
    if (_selectedPlaylist != null) {
      final trackUris = (playlists[_selectedPlaylist] ?? const <String>[])
          .toSet();
      final playlistTracks = _resolveDisplayedTracks(
        db: db,
        tabTag: 1,
        subKey: _selectedPlaylist,
        computeSource: () => allTracks
            .where(
              (t) =>
                  trackUris.contains(t.id) ||
                  trackUris.contains(t.localFilePath),
            )
            .toList(growable: false),
        applySortAndPreset: false,
      );

      return [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(horizontalPad, 0, horizontalPad, 20),
          sliver: SliverToBoxAdapter(
            child: Wrap(
              spacing: 10,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.arrow_back_rounded,
                        color: isDark
                            ? Colors.white
                            : MuxisColors.textPrimaryLight,
                      ),
                      onPressed: () {
                        setState(() => _selectedPlaylist = null);
                        _resetScroll();
                      },
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedPlaylist!,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : MuxisColors.textPrimaryLight,
                            ),
                          ),
                          Text(
                            '${playlistTracks.length} tracks',
                            style: TextStyle(
                              color: MuxisColors.textSecondary(isDark),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (playlistTracks.isNotEmpty)
                      MuxisButton(
                        label: 'Play Playlist',
                        icon: Icon(
                          Icons.play_arrow_rounded,
                          color: isDark ? Colors.black : Colors.white,
                        ),
                        variant: MuxisButtonVariant.primary,
                        height: 34,
                        onPressed: () => audioService.playTrack(
                          playlistTracks.first,
                          newQueue: playlistTracks,
                        ),
                      ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.redAccent,
                        size: 20,
                      ),
                      tooltip: 'Delete Playlist',
                      onPressed: () async {
                        await db.removePlaylist(_selectedPlaylist!);
                        if (mounted) {
                          setState(() => _selectedPlaylist = null);
                          _resetScroll();
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (playlistTracks.isEmpty)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              horizontalPad,
              20,
              horizontalPad,
              verticalBottom + 20,
            ),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: Text(
                  'This playlist is empty. Add tracks from the All Tracks menu.',
                  style: TextStyle(color: MuxisColors.textMuted(isDark)),
                ),
              ),
            ),
          )
        else
          ..._buildTracksSlivers(
            filtered: playlistTracks,
            hasAnySourceTracks: true,
            horizontalPad: horizontalPad,
            verticalBottom: verticalBottom,
            rowExtent: rowExtent,
            playback: playback,
            audioService: audioService,
            db: db,
          ),
      ];
    }

    final playlistEntries = playlists.entries.toList(growable: false);
    final gridMetrics = _gridLayoutForWidth(gridWidth, 180);

    return [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(horizontalPad, 0, horizontalPad, 16),
        sliver: SliverToBoxAdapter(
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Your Playlists',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : MuxisColors.textPrimaryLight,
                ),
              ),
              MuxisButton(
                label: 'New Playlist',
                icon: const Icon(Icons.add_rounded, size: 18),
                variant: MuxisButtonVariant.liquidGlass,
                height: 34,
                onPressed: _showCreatePlaylistDialog,
              ),
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: EdgeInsets.fromLTRB(
          horizontalPad,
          0,
          horizontalPad,
          verticalBottom,
        ),
        sliver: SliverGrid.builder(
          itemCount: playlistEntries.length + 1,
          addAutomaticKeepAlives: false,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: gridMetrics.cols,
            crossAxisSpacing: gridMetrics.spacing,
            mainAxisSpacing: gridMetrics.spacing,
            childAspectRatio: 1 / 1.15,
          ),
          itemBuilder: (context, idx) {
            if (idx == 0) {
              return MuxisLiquidSurface(
                onTap: _showCreatePlaylistDialog,
                borderRadius: 16,
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_circle_outline_rounded,
                      size: 40,
                      color: MuxisColors.accent(isDark),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Create Playlist',
                      style: TextStyle(
                        color: isDark
                            ? Colors.white
                            : MuxisColors.textPrimaryLight,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              );
            }
            final pl = playlistEntries[idx - 1];
            return MuxisLiquidSurface(
              onTap: () {
                setState(() => _selectedPlaylist = pl.key);
                _resetScroll();
              },
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
                        child: Icon(
                          Icons.playlist_play_rounded,
                          size: 42,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    pl.key,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDark
                          ? Colors.white
                          : MuxisColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${pl.value.length} songs',
                    style: TextStyle(
                      color: MuxisColors.textSecondary(isDark),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ];
  }

  // --- TAB 2: ALBUMS ---
  List<Widget> _buildAlbumsSlivers({
    required bool isDark,
    required double horizontalPad,
    required double verticalBottom,
    required double gridWidth,
    required double rowExtent,
    required List<Track> allTracks,
    required ({Track? currentTrack, bool isPlaying}) playback,
    required AudioPlaybackService audioService,
    required DatabaseService db,
  }) {
    _ensureGroupsCached(db);
    final albumEntries = _cachedAlbumEntries;

    if (_selectedAlbum != null) {
      final albumTracks = _resolveDisplayedTracks(
        db: db,
        tabTag: 2,
        subKey: _selectedAlbum,
        computeSource: () {
          for (final entry in albumEntries) {
            if (entry.key == _selectedAlbum) return entry.value;
          }
          return allTracks
              .where((t) => (t.album) == _selectedAlbum)
              .toList(growable: false);
        },
        applySortAndPreset: false,
      );

      return [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(horizontalPad, 0, horizontalPad, 20),
          sliver: SliverToBoxAdapter(
            child: Wrap(
              spacing: 10,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.arrow_back_rounded,
                        color: isDark
                            ? Colors.white
                            : MuxisColors.textPrimaryLight,
                      ),
                      onPressed: () {
                        setState(() => _selectedAlbum = null);
                        _resetScroll();
                      },
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedAlbum!,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : MuxisColors.textPrimaryLight,
                            ),
                          ),
                          Text(
                            '${albumTracks.length} tracks',
                            style: TextStyle(
                              color: MuxisColors.textSecondary(isDark),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (albumTracks.isNotEmpty)
                  MuxisButton(
                    label: 'Play Album',
                    icon: Icon(
                      Icons.play_arrow_rounded,
                      color: isDark ? Colors.black : Colors.white,
                    ),
                    variant: MuxisButtonVariant.primary,
                    height: 34,
                    onPressed: () => audioService.playTrack(
                      albumTracks.first,
                      newQueue: albumTracks,
                    ),
                  ),
              ],
            ),
          ),
        ),
        ..._buildTracksSlivers(
          filtered: albumTracks,
          hasAnySourceTracks: true,
          horizontalPad: horizontalPad,
          verticalBottom: verticalBottom,
          rowExtent: rowExtent,
          playback: playback,
          audioService: audioService,
          db: db,
        ),
      ];
    }

    if (albumEntries.isEmpty) {
      return [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            horizontalPad,
            24,
            horizontalPad,
            verticalBottom + 16,
          ),
          sliver: SliverToBoxAdapter(
            child: Center(
              child: Text(
                'No albums found in your library.',
                style: TextStyle(color: MuxisColors.textMuted(isDark)),
              ),
            ),
          ),
        ),
      ];
    }

    final gridMetrics = _gridLayoutForWidth(gridWidth, 174);

    return [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(
          horizontalPad,
          0,
          horizontalPad,
          verticalBottom,
        ),
        sliver: SliverGrid.builder(
          itemCount: albumEntries.length,
          addAutomaticKeepAlives: false,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: gridMetrics.cols,
            crossAxisSpacing: gridMetrics.spacing,
            mainAxisSpacing: gridMetrics.spacing,
            childAspectRatio: 1 / 1.24,
          ),
          itemBuilder: (context, idx) {
            final entry = albumEntries[idx];
            final firstTrack = entry.value.first;
            return MuxisLiquidSurface(
              onTap: () {
                setState(() => _selectedAlbum = entry.key);
                _resetScroll();
              },
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
                              cacheWidth: 320,
                              cacheHeight: 320,
                              gaplessPlayback: true,
                              errorBuilder: (_, __, ___) => const Center(
                                child: Icon(
                                  Icons.album_rounded,
                                  size: 48,
                                  color: Colors.black45,
                                ),
                              ),
                            )
                          : const Center(
                              child: Icon(
                                Icons.album_rounded,
                                size: 48,
                                color: Colors.black45,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    entry.key,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isDark
                          ? Colors.white
                          : MuxisColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${entry.value.length} tracks • ${firstTrack.artist}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: MuxisColors.textSecondary(isDark),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ];
  }

  // --- TAB 3: ARTISTS ---
  List<Widget> _buildArtistsSlivers({
    required bool isDark,
    required double horizontalPad,
    required double verticalBottom,
    required double gridWidth,
    required double rowExtent,
    required List<Track> allTracks,
    required ({Track? currentTrack, bool isPlaying}) playback,
    required AudioPlaybackService audioService,
    required DatabaseService db,
  }) {
    _ensureGroupsCached(db);
    final artistEntries = _cachedArtistEntries;

    if (_selectedArtist != null) {
      final artistTracks = _resolveDisplayedTracks(
        db: db,
        tabTag: 3,
        subKey: _selectedArtist,
        computeSource: () {
          for (final entry in artistEntries) {
            if (entry.key == _selectedArtist) return entry.value;
          }
          return allTracks
              .where((t) => t.artist == _selectedArtist)
              .toList(growable: false);
        },
        applySortAndPreset: false,
      );

      return [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(horizontalPad, 0, horizontalPad, 20),
          sliver: SliverToBoxAdapter(
            child: Wrap(
              spacing: 10,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.arrow_back_rounded,
                        color: isDark
                            ? Colors.white
                            : MuxisColors.textPrimaryLight,
                      ),
                      onPressed: () {
                        setState(() => _selectedArtist = null);
                        _resetScroll();
                      },
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedArtist!,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : MuxisColors.textPrimaryLight,
                            ),
                          ),
                          Text(
                            '${artistTracks.length} tracks',
                            style: TextStyle(
                              color: MuxisColors.textSecondary(isDark),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (artistTracks.isNotEmpty)
                  MuxisButton(
                    label: 'Play Artist',
                    icon: Icon(
                      Icons.play_arrow_rounded,
                      color: isDark ? Colors.black : Colors.white,
                    ),
                    variant: MuxisButtonVariant.primary,
                    height: 34,
                    onPressed: () => audioService.playTrack(
                      artistTracks.first,
                      newQueue: artistTracks,
                    ),
                  ),
              ],
            ),
          ),
        ),
        ..._buildTracksSlivers(
          filtered: artistTracks,
          hasAnySourceTracks: true,
          horizontalPad: horizontalPad,
          verticalBottom: verticalBottom,
          rowExtent: rowExtent,
          playback: playback,
          audioService: audioService,
          db: db,
        ),
      ];
    }

    if (artistEntries.isEmpty) {
      return [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            horizontalPad,
            24,
            horizontalPad,
            verticalBottom + 16,
          ),
          sliver: SliverToBoxAdapter(
            child: Center(
              child: Text(
                'No artists found in your library.',
                style: TextStyle(color: MuxisColors.textMuted(isDark)),
              ),
            ),
          ),
        ),
      ];
    }

    final gridMetrics = _gridLayoutForWidth(gridWidth, 160);

    return [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(
          horizontalPad,
          0,
          horizontalPad,
          verticalBottom,
        ),
        sliver: SliverGrid.builder(
          itemCount: artistEntries.length,
          addAutomaticKeepAlives: false,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: gridMetrics.cols,
            crossAxisSpacing: gridMetrics.spacing,
            mainAxisSpacing: gridMetrics.spacing,
            childAspectRatio: 0.85,
          ),
          itemBuilder: (context, idx) {
            final entry = artistEntries[idx];
            return MuxisLiquidSurface(
              onTap: () {
                setState(() => _selectedArtist = entry.key);
                _resetScroll();
              },
              borderRadius: 16,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: MuxisGradients.auroraSpectrum,
                      border: Border.all(
                        color: MuxisColors.accent(isDark),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: MuxisColors.accent(isDark).withOpacity(0.2),
                          blurRadius: 14,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.mic_rounded,
                        size: 38,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    entry.key,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isDark
                          ? Colors.white
                          : MuxisColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${entry.value.length} songs',
                    style: TextStyle(
                      color: MuxisColors.textSecondary(isDark),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ];
  }

  static ({int cols, double spacing}) _gridLayoutForWidth(
    double availableWidth,
    double target,
  ) {
    final isCompact = availableWidth < 520;
    final spacing = isCompact ? 12.0 : 16.0;
    final effectiveTarget = isCompact
        ? (target - 18).clamp(140.0, 170.0)
        : target;
    final cols = ((availableWidth + spacing) / (effectiveTarget + spacing))
        .floor()
        .clamp(2, 7);
    return (cols: cols, spacing: spacing);
  }

  // --- TAB 4: FAVORITES ---
  List<Widget> _buildFavoritesSlivers({
    required bool isDark,
    required double horizontalPad,
    required double verticalBottom,
    required double rowExtent,
    required ({Track? currentTrack, bool isPlaying}) playback,
    required AudioPlaybackService audioService,
    required DatabaseService db,
  }) {
    if (db.favoriteCount == 0) {
      return [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            horizontalPad,
            32,
            horizontalPad,
            verticalBottom + 16,
          ),
          sliver: SliverToBoxAdapter(
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.favorite_border_rounded,
                    size: 56,
                    color: MuxisColors.accent(isDark),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No favorite tracks yet',
                    style: TextStyle(
                      color: isDark
                          ? Colors.white
                          : MuxisColors.textPrimaryLight,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the heart icon on any song to save it to your Favorites collection.',
                    style: TextStyle(
                      color: MuxisColors.textSecondary(isDark),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ];
    }

    final filtered = _resolveDisplayedTracks(
      db: db,
      tabTag: 4,
      subKey: null,
      computeSource: db.getFavoriteTracks,
      applySortAndPreset: true,
    );

    return [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(horizontalPad, 0, horizontalPad, 16),
        sliver: SliverToBoxAdapter(
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${filtered.length} Favorite Tracks',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : MuxisColors.textPrimaryLight,
                ),
              ),
              if (filtered.isNotEmpty)
                MuxisButton(
                  label: 'Play All Favorites',
                  icon: Icon(
                    Icons.play_arrow_rounded,
                    color: isDark ? Colors.black : Colors.white,
                  ),
                  variant: MuxisButtonVariant.primary,
                  height: 34,
                  onPressed: () => audioService.playTrack(
                    filtered.first,
                    newQueue: filtered,
                  ),
                ),
            ],
          ),
        ),
      ),
      ..._buildTracksSlivers(
        filtered: filtered,
        hasAnySourceTracks: true,
        horizontalPad: horizontalPad,
        verticalBottom: verticalBottom,
        rowExtent: rowExtent,
        playback: playback,
        audioService: audioService,
        db: db,
        applySortAndPreset: true,
      ),
    ];
  }

  // --- TAB 5: RECENTLY PLAYED ---
  List<Widget> _buildRecentlyPlayedSlivers({
    required bool isDark,
    required double horizontalPad,
    required double verticalBottom,
    required double rowExtent,
    required ({Track? currentTrack, bool isPlaying}) playback,
    required AudioPlaybackService audioService,
    required DatabaseService db,
  }) {
    final recents = _resolveDisplayedTracks(
      db: db,
      tabTag: 5,
      subKey: null,
      computeSource: db.getRecentlyPlayed,
      applySortAndPreset: false,
    );

    if (recents.isEmpty) {
      return [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            horizontalPad,
            32,
            horizontalPad,
            verticalBottom + 16,
          ),
          sliver: SliverToBoxAdapter(
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: 56,
                    color: MuxisColors.textMuted(isDark),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No recently played tracks',
                    style: TextStyle(
                      color: isDark
                          ? Colors.white
                          : MuxisColors.textPrimaryLight,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tracks you play will automatically appear here in historical order.',
                    style: TextStyle(
                      color: MuxisColors.textSecondary(isDark),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(horizontalPad, 0, horizontalPad, 16),
        sliver: SliverToBoxAdapter(
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${recents.length} Recently Played',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : MuxisColors.textPrimaryLight,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MuxisButton(
                    label: 'Play History',
                    icon: Icon(
                      Icons.play_arrow_rounded,
                      color: isDark ? Colors.black : Colors.white,
                    ),
                    variant: MuxisButtonVariant.primary,
                    height: 34,
                    onPressed: () => audioService.playTrack(
                      recents.first,
                      newQueue: recents,
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: Icon(
                      Icons.delete_sweep_rounded,
                      color: MuxisColors.textMuted(isDark),
                    ),
                    tooltip: 'Clear Listening History',
                    onPressed: () async {
                      await db.clearHistory();
                      if (mounted) setState(() {});
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      ..._buildTracksSlivers(
        filtered: recents,
        hasAnySourceTracks: true,
        horizontalPad: horizontalPad,
        verticalBottom: verticalBottom,
        rowExtent: rowExtent,
        playback: playback,
        audioService: audioService,
        db: db,
      ),
    ];
  }
}
