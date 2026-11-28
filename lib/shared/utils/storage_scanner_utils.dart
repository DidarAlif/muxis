/// Pure-Dart helpers for cross-platform whole-storage music discovery,
/// restricted/cache directory pruning, canonical path deduplication,
/// and iOS sandbox container path rebinding.

class StorageScannerHelper {
  StorageScannerHelper._();

  static const Set<String> supportedAudioExtensions = {
    '.mp3',
    '.flac',
    '.wav',
    '.m4a',
    '.aac',
    '.ogg',
    '.opus',
  };

  static const Set<String> _skippedLeafDirectoryNames = {
    '.android_secure',
    '.thumbnails',
    '.thumb',
    '.trash',
    '.trashed',
    '.cache',
    'caches',
    '.git',
    '.dart_tool',
    'node_modules',
    'lost+found',
    'system volume information',
    r'$recycle.bin',
    '__macosx',
    '.spotlight-v100',
    '.fseventsd',
    'albumthumbs',
  };

  /// Returns true when [filePath] has a supported audio extension.
  static bool isSupportedAudioFile(String filePath) {
    final lower = filePath.toLowerCase();
    final dotIdx = lower.lastIndexOf('.');
    if (dotIdx == -1 || dotIdx >= lower.length - 1) return false;
    final ext = lower.substring(dotIdx);
    return supportedAudioExtensions.contains(ext);
  }

  /// Normalizes directory separators to `/` for cross-platform path analysis.
  static String normalizePathSlashes(String rawPath) {
    var normalized = rawPath.trim().replaceAll('\\', '/');
    while (normalized.length > 1 && normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  /// Returns true if [dirPath] is an OS restricted, system-internal, or
  /// thumbnail/cache folder that should never be traversed during storage scans.
  static bool shouldSkipDirectory(String dirPath) {
    final normalized = normalizePathSlashes(dirPath);
    if (normalized.isEmpty) return true;
    final lower = normalized.toLowerCase();

    // Android scoped-storage protected directories & virtual OS roots
    if (lower.endsWith('/android/data') ||
        lower.contains('/android/data/') ||
        lower.endsWith('/android/obb') ||
        lower.contains('/android/obb/') ||
        lower.endsWith('/android/.trash') ||
        lower.endsWith('/.statuses') ||
        lower.contains('/.statuses/')) {
      return true;
    }

    // Kernel/virtual filesystems if scanning near root on POSIX
    if (lower == '/proc' ||
        lower.startsWith('/proc/') ||
        lower == '/sys' ||
        lower.startsWith('/sys/') ||
        lower == '/dev' ||
        lower.startsWith('/dev/')) {
      return true;
    }

    final segments = normalized.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) return false;

    final leaf = segments.last.toLowerCase();
    if (_skippedLeafDirectoryNames.contains(leaf)) {
      return true;
    }

    // Skip hidden dot-directories (e.g. .thumbnails, .cache) everywhere
    if (leaf.startsWith('.') && leaf != '.' && leaf != '..') {
      return true;
    }

    return false;
  }

  /// Computes a canonical comparison key to deduplicate symlinked mount points
  /// (e.g., `/sdcard/Music/a.mp3` vs `/storage/emulated/0/Music/a.mp3`).
  static String computeCanonicalTrackKey(String filePath) {
    var normalized = normalizePathSlashes(filePath);
    if (normalized.startsWith('/sdcard/')) {
      normalized = '/storage/emulated/0/${normalized.substring(8)}';
    } else if (normalized == '/sdcard') {
      normalized = '/storage/emulated/0';
    }
    if (normalized.length > 2 && normalized[1] == ':') {
      // Windows paths are case-insensitive
      normalized = normalized.toLowerCase();
    }
    return normalized;
  }

  /// Resolves accessible Android shared storage roots (internal + SD cards)
  /// without traversing virtual `/storage/self` or duplicate `/sdcard` aliases.
  static List<String> discoverAndroidStorageRoots({
    required List<String> storageVolumeDirs,
    bool hasEmulatedZero = true,
    bool hasSdcardAlias = false,
  }) {
    final seen = <String>{};
    final roots = <String>[];

    void addRoot(String raw) {
      final norm = normalizePathSlashes(raw);
      if (norm.isEmpty) return;
      final key = computeCanonicalTrackKey(norm);
      if (seen.add(key)) {
        roots.add(norm);
      }
    }

    if (hasEmulatedZero) {
      addRoot('/storage/emulated/0');
    } else if (hasSdcardAlias) {
      addRoot('/sdcard');
    }

    for (final rawDir in storageVolumeDirs) {
      final norm = normalizePathSlashes(rawDir);
      if (norm.isEmpty) continue;
      final leaf = norm.split('/').where((s) => s.isNotEmpty).lastOrNull ?? '';
      final lowerLeaf = leaf.toLowerCase();
      if (lowerLeaf == 'self' || lowerLeaf == 'emulated') continue;
      addRoot(norm);
    }

    return roots;
  }

  /// Deduplicates and orders iOS sandbox/Files-accessible audio directories
  /// (`ApplicationDocumentsDirectory` -> Files "On My iPhone -> MUXIS", Inbox,
  /// imported `MUXIS_Music` vault, and user-picked folders).
  static List<String> discoverIosStorageRoots({
    required List<String> candidateDirs,
  }) {
    final seen = <String>{};
    final roots = <String>[];

    for (final raw in candidateDirs) {
      final norm = normalizePathSlashes(raw);
      if (norm.isEmpty || shouldSkipDirectory(norm)) continue;
      final isSubpathOfExisting = roots.any(
        (existing) => norm == existing || norm.startsWith('$existing/'),
      );
      if (isSubpathOfExisting) continue;

      if (seen.add(norm)) {
        roots.removeWhere((existing) => existing.startsWith('$norm/'));
        roots.add(norm);
      }
    }

    return roots;
  }

  /// Rebinds old iOS Application Container UUID paths
  /// (`/var/.../Application/<OLD_UUID>/Documents/...`) onto [currentDocumentsDir]
  /// so previously imported local tracks survive app reinstalls/updates on iPhone.
  static String resolveSandboxRelativeMusicPath(
    String storedPath, {
    required String currentDocumentsDir,
  }) {
    final cleanDocs = normalizePathSlashes(currentDocumentsDir);
    final cleanStored = normalizePathSlashes(storedPath);
    if (cleanDocs.isEmpty || cleanStored.isEmpty) return storedPath;

    const docsMarker = '/Documents/';
    final markerIdx = cleanStored.indexOf(docsMarker);
    if (markerIdx != -1) {
      final relativeSuffix = cleanStored.substring(
        markerIdx + docsMarker.length,
      );
      if (relativeSuffix.isNotEmpty) {
        return '$cleanDocs/$relativeSuffix';
      }
    }
    return storedPath;
  }

  /// Produces a deterministic, cross-restart stable track ID for a local audio
  /// file path using FNV-1a 64-bit hashing over its canonical key (preventing
  /// duplicate tracks when rescanning whole phone storage across app restarts).
  static String computeStableLocalTrackId(String filePath) {
    final canonical = computeCanonicalTrackKey(filePath);
    // 32-bit FNV-1a (safe on Dart JS & VM 64-bit) combined with length + secondary hash
    var h1 = 0x811c9dc5;
    var h2 = 0x9e3779b9;
    for (var i = 0; i < canonical.length; i++) {
      final code = canonical.codeUnitAt(i);
      h1 ^= code;
      h1 = (h1 * 0x01000193) & 0xFFFFFFFF;
      h2 ^= (code + i);
      h2 = (h2 * 0x85ebca6b) & 0xFFFFFFFF;
    }
    return 'local-${h1.toRadixString(16).padLeft(8, '0')}${h2.toRadixString(16).padLeft(8, '0')}';
  }
}
