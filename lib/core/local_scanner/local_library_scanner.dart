import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/track.dart';

final localLibraryScannerProvider = Provider<LocalLibraryScanner>((ref) {
  return LocalLibraryScanner();
});

class ScannedAudioResult {
  final List<Track> tracks;
  final int totalFilesScanned;
  final int validAudioFilesFound;
  final Duration scanDuration;
  final List<String> errors;

  const ScannedAudioResult({
    required this.tracks,
    required this.totalFilesScanned,
    required this.validAudioFilesFound,
    required this.scanDuration,
    this.errors = const [],
  });
}

class LocalLibraryScanner {
  static const Set<String> supportedAudioExtensions = {
    '.mp3',
    '.flac',
    '.wav',
    '.m4a',
    '.aac',
    '.ogg',
    '.opus',
  };

  /// Asynchronously scans a directory on the local filesystem
  Future<ScannedAudioResult> scanDirectory(
    Directory directory, {
    bool recursive = true,
    void Function(String currentFilePath)? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();
    final tracks = <Track>[];
    final errors = <String>[];
    int totalFiles = 0;

    try {
      if (!await directory.exists()) {
        return ScannedAudioResult(
          tracks: const [],
          totalFilesScanned: 0,
          validAudioFilesFound: 0,
          scanDuration: Duration.zero,
          errors: ['Directory does not exist: ${directory.path}'],
        );
      }

      await for (final entity in directory.list(
        recursive: recursive,
        followLinks: false,
      )) {
        totalFiles++;
        if (entity is File) {
          final filePath = entity.path;
          onProgress?.call(filePath);

          final ext = _getExtension(filePath);
          if (supportedAudioExtensions.contains(ext)) {
            try {
              final track = await _parseFileMetadata(entity, ext);
              tracks.add(track);
            } catch (e) {
              errors.add('Failed to parse ${entity.path}: $e');
            }
          }
        }
      }
    } catch (e) {
      errors.add('Directory scanning error: $e');
    }

    stopwatch.stop();

    return ScannedAudioResult(
      tracks: tracks,
      totalFilesScanned: totalFiles,
      validAudioFilesFound: tracks.length,
      scanDuration: stopwatch.elapsed,
      errors: errors,
    );
  }

  /// Scans an explicit list of individual audio files (e.g. from file picker or drag & drop)
  Future<ScannedAudioResult> scanFiles(List<File> files) async {
    final stopwatch = Stopwatch()..start();
    final tracks = <Track>[];
    final errors = <String>[];

    for (final file in files) {
      if (!await file.exists()) continue;
      final ext = _getExtension(file.path);
      if (supportedAudioExtensions.contains(ext)) {
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
      totalFilesScanned: files.length,
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

    final parentFolder = file.parent.uri.pathSegments
        .where((s) => s.isNotEmpty)
        .last;

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
      id: 'local-${file.path.hashCode}',
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
