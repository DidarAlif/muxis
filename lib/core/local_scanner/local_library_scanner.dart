import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../shared/models/track.dart';
import '../../shared/utils/storage_scanner_utils.dart';

final localLibraryScannerProvider = Provider<LocalLibraryScanner>((ref) {
  return LocalLibraryScanner();
});

class ScannedAudioResult {
  final List<Track> tracks;
  final int totalFilesScanned;
  final int validAudioFilesFound;
  final Duration scanDuration;
  final List<String> errors;
  final List<String> scannedRoots;
  final bool permissionDenied;

  const ScannedAudioResult({
    required this.tracks,
    required this.totalFilesScanned,
    required this.validAudioFilesFound,
    required this.scanDuration,
    this.errors = const [],
    this.scannedRoots = const [],
    this.permissionDenied = false,
  });
}

class LocalLibraryScanner {
  static const MethodChannel _storagePermChannel = MethodChannel(
    'app.muxis/storage_permissions',
  );

  static const Set<String> supportedAudioExtensions =
      StorageScannerHelper.supportedAudioExtensions;

  /// Requests Android runtime storage permission (`READ_MEDIA_AUDIO` on
  /// Android 13+, `READ_EXTERNAL_STORAGE` on Android 8-12).
  /// Returns true on iOS, Desktop, or when Android permission is granted.
  Future<bool> ensureStoragePermission() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    try {
      final res = await _storagePermChannel.invokeMethod<bool>(
        'requestAudioStoragePermission',
      );
      return res ?? true;
    } catch (_) {
      // Fallback: proceed with filesystem scan if method channel unavailable
      return true;
    }
  }

  /// Copies picked external files (such as iPhone Files / iCloud Drive picks)
  /// into `<Documents>/MUXIS_Music/` on iOS so iOS sandbox revocation never
  /// invalidates offline playback or whole-storage rescans.
  Future<List<File>> persistFilesIntoAppStorageIfNeeded(
    List<File> files,
  ) async {
    if (kIsWeb || !Platform.isIOS || files.isEmpty) {
      return files;
    }

    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final normDocs = StorageScannerHelper.normalizePathSlashes(docsDir.path);
      final musicVaultDir = Directory(p.join(docsDir.path, 'MUXIS_Music'));
      if (!await musicVaultDir.exists()) {
        await musicVaultDir.create(recursive: true);
      }

      final persisted = <File>[];
      for (final file in files) {
        if (!await file.exists()) continue;
        final normPath = StorageScannerHelper.normalizePathSlashes(file.path);
        // Keep files already inside On My iPhone -> MUXIS (`Documents`) in place
        if (normPath.startsWith('$normDocs/') &&
            !normPath.startsWith('$normDocs/tmp/')) {
          persisted.add(file);
          continue;
        }

        final baseName = p.basename(file.path);
        var destPath = p.join(musicVaultDir.path, baseName);
        if (await File(destPath).exists()) {
          final existingLen = await File(destPath).length();
          final sourceLen = await file.length();
          if (existingLen != sourceLen) {
            final stem = p.basenameWithoutExtension(baseName);
            final ext = p.extension(baseName);
            destPath = p.join(
              musicVaultDir.path,
              '${stem}_${sourceLen.abs()}$ext',
            );
          } else {
            persisted.add(File(destPath));
            continue;
          }
        }

        final copied = await file.copy(destPath);
        persisted.add(copied);
      }
      return persisted;
    } catch (_) {
      return files;
    }
  }

  /// Discovers accessible whole-device storage roots on Android phones,
  /// iPhone/iPad (app Files sandbox, Inbox, imported vault & remembered folders),
  /// or Desktop (Music & Downloads libraries).
  Future<List<Directory>> discoverWholeStorageRoots({
    List<String> extraSavedRoots = const [],
  }) async {
    final candidates = <String>[];

    if (!kIsWeb && Platform.isAndroid) {
      final hasEmulatedZero = await Directory('/storage/emulated/0').exists();
      final hasSdcardAlias = await Directory('/sdcard').exists();
      final volumeEntries = <String>[];

      for (final base in ['/storage', '/mnt/media_rw']) {
        final baseDir = Directory(base);
        try {
          if (await baseDir.exists()) {
            await for (final entity in baseDir.list(followLinks: false)) {
              if (entity is Directory) {
                volumeEntries.add(entity.path);
              }
            }
          }
        } catch (_) {}
      }

      candidates.addAll(
        StorageScannerHelper.discoverAndroidStorageRoots(
          storageVolumeDirs: volumeEntries,
          hasEmulatedZero: hasEmulatedZero,
          hasSdcardAlias: hasSdcardAlias,
        ),
      );

      // Add Flutter external storage directories if still empty (isolated envs)
      if (candidates.isEmpty) {
        try {
          final extDirs = await getExternalStorageDirectories();
          if (extDirs != null) {
            for (final d in extDirs) {
              candidates.add(d.path);
            }
          }
        } catch (_) {}
      }
      candidates.addAll(extraSavedRoots);
    } else if (!kIsWeb && Platform.isIOS) {
      final iosCandidates = <String>[];
      try {
        final docs = await getApplicationDocumentsDirectory();
        iosCandidates.add(docs.path);
        iosCandidates.add(p.join(docs.path, 'Inbox'));
        iosCandidates.add(p.join(docs.path, 'MUXIS_Music'));
      } catch (_) {}
      try {
        final support = await getApplicationSupportDirectory();
        iosCandidates.add(support.path);
      } catch (_) {}
      try {
        final downloads = await getDownloadsDirectory();
        if (downloads != null) {
          iosCandidates.add(downloads.path);
        }
      } catch (_) {}
      iosCandidates.addAll(extraSavedRoots);
      candidates.addAll(
        StorageScannerHelper.discoverIosStorageRoots(
          candidateDirs: iosCandidates,
        ),
      );
    } else if (!kIsWeb) {
      final home =
          Platform.environment['USERPROFILE'] ??
          Platform.environment['HOME'] ??
          '';
      if (home.isNotEmpty) {
        candidates.add(p.join(home, 'Music'));
        candidates.add(p.join(home, 'Downloads'));
      }
      candidates.addAll(extraSavedRoots);
    }

    final seenKeys = <String>{};
    final resultDirs = <Directory>[];
    for (final raw in candidates) {
      final clean = raw.trim();
      if (clean.isEmpty) continue;
      final dir = Directory(clean);
      try {
        if (!await dir.exists()) continue;
        final key = StorageScannerHelper.computeCanonicalTrackKey(clean);
        if (seenKeys.add(key)) {
          resultDirs.add(dir);
        }
      } catch (_) {}
    }
    return resultDirs;
  }

  /// Scans the entire accessible device storage safely using per-directory
  /// traversal (skipping restricted OS/thumbnail/cache directories cleanly).
  Future<ScannedAudioResult> scanWholeDeviceStorage({
    List<String> extraSavedRoots = const [],
    void Function(int filesScanned, int tracksFound, String currentPath)?
    onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();

    if (!kIsWeb && Platform.isAndroid) {
      final granted = await ensureStoragePermission();
      if (!granted) {
        stopwatch.stop();
        return ScannedAudioResult(
          tracks: const [],
          totalFilesScanned: 0,
          validAudioFilesFound: 0,
          scanDuration: stopwatch.elapsed,
          permissionDenied: true,
          errors: const [
            'Audio storage permission denied. Allow Music & Audio permission in Android Settings to scan phone storage.',
          ],
        );
      }
    }

    final roots = await discoverWholeStorageRoots(
      extraSavedRoots: extraSavedRoots,
    );
    if (roots.isEmpty) {
      stopwatch.stop();
      return ScannedAudioResult(
        tracks: const [],
        totalFilesScanned: 0,
        validAudioFilesFound: 0,
        scanDuration: stopwatch.elapsed,
        errors: const ['No accessible music storage roots found on device.'],
      );
    }

    return scanDirectories(
      roots,
      recursive: true,
      onDetailedProgress: onProgress,
    );
  }

  /// Asynchronously scans a single directory using resilient iterative BFS
  /// so a single OS permission-denied folder never aborts the scan.
  Future<ScannedAudioResult> scanDirectory(
    Directory directory, {
    bool recursive = true,
    void Function(String currentFilePath)? onProgress,
  }) async {
    return scanDirectories(
      [directory],
      recursive: recursive,
      onDetailedProgress: onProgress == null
          ? null
          : (_, __, currentPath) => onProgress(currentPath),
    );
  }

  /// Traverses one or more root directories safely, deduplicating canonical paths
  /// and skipping protected/cache directories (`Android/data`, `.thumbnails`).
  Future<ScannedAudioResult> scanDirectories(
    List<Directory> directories, {
    bool recursive = true,
    void Function(int filesScanned, int tracksFound, String currentPath)?
    onDetailedProgress,
  }) async {
    final stopwatch = Stopwatch()..start();
    final tracks = <Track>[];
    final errors = <String>[];
    final scannedRoots = <String>[];
    final seenTrackKeys = <String>{};
    final visitedDirKeys = <String>{};
    int totalFiles = 0;

    for (final root in directories) {
      try {
        if (!await root.exists()) {
          errors.add('Directory does not exist: ${root.path}');
          continue;
        }
      } catch (e) {
        errors.add('Cannot access ${root.path}: $e');
        continue;
      }

      scannedRoots.add(root.path);
      final queue = Queue<Directory>()..add(root);
      int yieldCounter = 0;

      while (queue.isNotEmpty) {
        final currentDir = queue.removeFirst();
        final dirKey = StorageScannerHelper.computeCanonicalTrackKey(
          currentDir.path,
        );
        if (!visitedDirKeys.add(dirKey)) continue;

        if (currentDir.path != root.path &&
            StorageScannerHelper.shouldSkipDirectory(currentDir.path)) {
          continue;
        }

        try {
          await for (final entity in currentDir.list(followLinks: false)) {
            yieldCounter++;
            if (yieldCounter >= 120) {
              yieldCounter = 0;
              await Future<void>.delayed(Duration.zero);
            }

            if (entity is Directory) {
              if (recursive &&
                  !StorageScannerHelper.shouldSkipDirectory(entity.path)) {
                queue.add(entity);
              }
            } else if (entity is File) {
              totalFiles++;
              final filePath = entity.path;
              if (totalFiles == 1 || totalFiles % 25 == 0) {
                onDetailedProgress?.call(totalFiles, tracks.length, filePath);
              }

              final ext = _getExtension(filePath);
              if (!supportedAudioExtensions.contains(ext)) continue;

              final trackKey = StorageScannerHelper.computeCanonicalTrackKey(
                filePath,
              );
              if (!seenTrackKeys.add(trackKey)) continue;

              try {
                final track = await _parseFileMetadata(entity, ext);
                tracks.add(track);
                onDetailedProgress?.call(totalFiles, tracks.length, filePath);
              } catch (e) {
                errors.add('Failed to parse $filePath: $e');
              }
            }
          }
        } catch (e) {
          // Restricted directories on Android/iOS are skipped cleanly
          errors.add('Skipped ${currentDir.path}: $e');
        }
      }
    }

    stopwatch.stop();

    return ScannedAudioResult(
      tracks: tracks,
      totalFilesScanned: totalFiles,
      validAudioFilesFound: tracks.length,
      scanDuration: stopwatch.elapsed,
      errors: errors,
      scannedRoots: scannedRoots,
    );
  }

  /// Scans an explicit list of individual audio files (e.g. from file picker or drag & drop)
  Future<ScannedAudioResult> scanFiles(List<File> files) async {
    final stopwatch = Stopwatch()..start();
    final tracks = <Track>[];
    final errors = <String>[];
    final seenTrackKeys = <String>{};

    final persistedFiles = await persistFilesIntoAppStorageIfNeeded(files);

    for (final file in persistedFiles) {
      if (!await file.exists()) continue;
      final ext = _getExtension(file.path);
      if (supportedAudioExtensions.contains(ext)) {
        final trackKey = StorageScannerHelper.computeCanonicalTrackKey(
          file.path,
        );
        if (!seenTrackKeys.add(trackKey)) continue;
        try {
          final track = await _parseFileMetadata(file, ext);
          tracks.add(track);
        } catch (e) {
          errors.add('Failed to parse ${file.path}: $e');
        }
      }
    }

    stopwatch.stop();
    return ScannedAudioResult(
      tracks: tracks,
      totalFilesScanned: persistedFiles.length,
      validAudioFilesFound: tracks.length,
      scanDuration: stopwatch.elapsed,
      errors: errors,
    );
  }

  String _getExtension(String path) {
    final dotIndex = path.lastIndexOf('.');
    if (dotIndex == -1) return '';
    return path.substring(dotIndex).toLowerCase();
  }

  Future<Track> _parseFileMetadata(File file, String ext) async {
    final fileName = file.uri.pathSegments.last;
    final nameWithoutExt = fileName.substring(0, fileName.lastIndexOf('.'));

    String artist = 'Unknown Artist';
    String title = nameWithoutExt;
    int? trackNumber;

    // Common naming patterns:
    // 1. "Artist - Title"
    // 2. "01. Artist - Title" or "01 - Title"
    if (nameWithoutExt.contains(' - ')) {
      final parts = nameWithoutExt.split(' - ');
      if (parts.length >= 2) {
        artist = parts[0].trim();
        title = parts[1].trim();

        // Check if artist part had leading track number e.g. "01. Artist"
        final match = RegExp(r'^(\d+)[\.\s]+(.*)$').firstMatch(artist);
        if (match != null) {
          trackNumber = int.tryParse(match.group(1)!);
          artist = match.group(2)!.trim();
        }
      }
    } else {
      // Check for "01 Title" or "01. Title"
      final match = RegExp(r'^(\d+)[\.\s]+(.*)$').firstMatch(nameWithoutExt);
      if (match != null) {
        trackNumber = int.tryParse(match.group(1)!);
        title = match.group(2)!.trim();
      }
    }

    final parentSegments = file.parent.uri.pathSegments
        .where((s) => s.isNotEmpty)
        .toList();
    final parentFolder = parentSegments.isNotEmpty
        ? parentSegments.last
        : 'Local Music';

    // Determine audio format label
    final formatLabel = switch (ext) {
      '.flac' => 'FLAC 24-bit',
      '.wav' => 'PCM WAV 16-bit',
      '.mp3' => '320kbps MP3',
      '.m4a' || '.aac' => 'AAC 256kbps',
      '.ogg' || '.opus' => 'Opus VBR',
      _ => ext.toUpperCase().replaceAll('.', ''),
    };

    return Track(
      id: StorageScannerHelper.computeStableLocalTrackId(file.path),
      title: title,
      artist: artist,
      album: parentFolder,
      duration: const Duration(
        minutes: 3,
        seconds: 30,
      ), // Default until tag parser extracts exact duration
      localFilePath: file.path,
      source: MusicSource.local,
      audioFormat: formatLabel,
      trackNumber: trackNumber,
    );
  }
}
