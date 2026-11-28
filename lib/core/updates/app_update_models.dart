/// Pure-Dart models, semantic version comparison, release asset selection, and
/// SHA-256 checksum parsing helpers for MUXIS in-app self-updates.

class AppReleaseAsset {
  final String name;
  final String downloadUrl;
  final int sizeBytes;

  const AppReleaseAsset({
    required this.name,
    required this.downloadUrl,
    required this.sizeBytes,
  });

  factory AppReleaseAsset.fromJson(Map<String, dynamic> json) {
    return AppReleaseAsset(
      name: (json['name'] as String?) ?? '',
      downloadUrl: (json['browser_download_url'] as String?) ?? '',
      sizeBytes: (json['size'] as num?)?.toInt() ?? 0,
    );
  }
}

class AppUpdateInfo {
  final String tagName;
  final String latestVersion;
  final String currentVersion;
  final String releaseName;
  final String releaseNotes;
  final String htmlUrl;
  final DateTime? publishedAt;
  final AppReleaseAsset asset;
  final String? expectedSha256;

  const AppUpdateInfo({
    required this.tagName,
    required this.latestVersion,
    required this.currentVersion,
    required this.releaseName,
    required this.releaseNotes,
    required this.htmlUrl,
    required this.asset,
    this.publishedAt,
    this.expectedSha256,
  });
}

class ParsedSemver {
  final int major;
  final int minor;
  final int patch;
  final String? preRelease;

  const ParsedSemver({
    required this.major,
    required this.minor,
    required this.patch,
    this.preRelease,
  });

  String get normalized => preRelease == null
      ? '$major.$minor.$patch'
      : '$major.$minor.$patch-$preRelease';
}

class MuxisVersionComparator {
  MuxisVersionComparator._();

  static ParsedSemver parseSemver(String raw) {
    var clean = raw.trim();
    if (clean.startsWith('v') || clean.startsWith('V')) {
      clean = clean.substring(1).trim();
    }

    // Strip build metadata (+18) before comparing semantic version
    final plusIdx = clean.indexOf('+');
    if (plusIdx != -1) {
      clean = clean.substring(0, plusIdx);
    }

    String? preRelease;
    final dashIdx = clean.indexOf('-');
    if (dashIdx != -1) {
      preRelease = clean.substring(dashIdx + 1).trim();
      if (preRelease.isEmpty) preRelease = null;
      clean = clean.substring(0, dashIdx);
    }

    final parts = clean.split('.');
    int parsePart(int idx) {
      if (idx >= parts.length) return 0;
      final digits = RegExp(r'\d+').firstMatch(parts[idx])?.group(0);
      return int.tryParse(digits ?? '') ?? 0;
    }

    return ParsedSemver(
      major: parsePart(0),
      minor: parsePart(1),
      patch: parsePart(2),
      preRelease: preRelease,
    );
  }

  /// Returns positive if [a] > [b], zero if equal, negative if [a] < [b].
  static int compare(String a, String b) {
    final va = parseSemver(a);
    final vb = parseSemver(b);

    if (va.major != vb.major) return va.major.compareTo(vb.major);
    if (va.minor != vb.minor) return va.minor.compareTo(vb.minor);
    if (va.patch != vb.patch) return va.patch.compareTo(vb.patch);

    if (va.preRelease == vb.preRelease) return 0;
    if (va.preRelease == null) return 1; // stable > prerelease
    if (vb.preRelease == null) return -1;
    return va.preRelease!.compareTo(vb.preRelease!);
  }

  static bool isNewerVersion({
    required String remoteVersion,
    required String currentVersion,
  }) {
    return compare(remoteVersion, currentVersion) > 0;
  }
}

class MuxisUpdateSelector {
  MuxisUpdateSelector._();

  /// Picks the cleanest platform-native installer/package from a GitHub release.
  static AppReleaseAsset? selectAssetForOperatingSystem(
    List<AppReleaseAsset> assets,
    String operatingSystem,
  ) {
    final os = operatingSystem.toLowerCase();
    final valid = assets.where((a) => a.downloadUrl.isNotEmpty).toList();
    if (valid.isEmpty) return null;

    AppReleaseAsset? firstMatch(bool Function(AppReleaseAsset a) test) {
      for (final a in valid) {
        if (test(a)) return a;
      }
      return null;
    }

    switch (os) {
      case 'windows':
        return firstMatch((a) => a.name == 'Muxis-Windows-x64-Setup.exe') ??
            firstMatch(
              (a) =>
                  a.name.toLowerCase().contains('windows') &&
                  a.name.toLowerCase().endsWith('.exe'),
            ) ??
            firstMatch((a) => a.name == 'Muxis-Windows-x64.zip') ??
            firstMatch(
              (a) =>
                  a.name.toLowerCase().contains('windows') &&
                  a.name.toLowerCase().endsWith('.zip'),
            );
      case 'android':
        return firstMatch((a) => a.name == 'Muxis-Android.apk') ??
            firstMatch((a) => a.name.toLowerCase().endsWith('.apk'));
      case 'ios':
        return firstMatch((a) => a.name == 'Muxis-iOS.ipa') ??
            firstMatch((a) => a.name.toLowerCase().endsWith('.ipa')) ??
            firstMatch((a) => a.name == 'Muxis-iOS-Unsigned.zip') ??
            firstMatch(
              (a) =>
                  a.name.toLowerCase().contains('ios') &&
                  a.name.toLowerCase().endsWith('.zip'),
            );
      case 'macos':
        return firstMatch((a) => a.name == 'Muxis-macOS-Universal.zip') ??
            firstMatch(
              (a) =>
                  a.name.toLowerCase().contains('macos') &&
                  (a.name.toLowerCase().endsWith('.dmg') ||
                      a.name.toLowerCase().endsWith('.zip')),
            );
      case 'linux':
        return firstMatch((a) => a.name == 'Muxis-Linux-x64.tar.gz') ??
            firstMatch(
              (a) =>
                  a.name.toLowerCase().contains('linux') &&
                  (a.name.toLowerCase().endsWith('.appimage') ||
                      a.name.toLowerCase().endsWith('.deb') ||
                      a.name.toLowerCase().endsWith('.tar.gz')),
            );
      default:
        return null;
    }
  }

  static String? parseSha256ForAsset(String checksumsText, String assetName) {
    final targetLower = assetName.toLowerCase();
    for (final rawLine in checksumsText.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      final match = RegExp(r'^([a-fA-F0-9]{64})\s+\*?(.+)$').firstMatch(line);
      if (match == null) continue;
      final hash = match.group(1)!.toLowerCase();
      final name = match.group(2)!.trim().split('/').last.split('\\').last;
      if (name.toLowerCase() == targetLower) {
        return hash;
      }
    }
    return null;
  }

  static String formatBytes(int bytes) {
    if (bytes <= 0) return 'Unknown size';
    const kb = 1024.0;
    const mb = kb * 1024.0;
    if (bytes >= mb) {
      return '${(bytes / mb).toStringAsFixed(1)} MB';
    }
    if (bytes >= kb) {
      return '${(bytes / kb).toStringAsFixed(0)} KB';
    }
    return '$bytes B';
  }

  static String cleanReleaseNotes(String markdown, {String? releaseName}) {
    final normalized = markdown.replaceAll('\r\n', '\n').trim();
    if (normalized.isEmpty) {
      return releaseName != null && releaseName.isNotEmpty
          ? '$releaseName includes stability improvements, UI polish, and streaming upgrades.'
          : 'This release includes performance improvements, UI enhancements, and bug fixes.';
    }

    final lines = <String>[];
    for (final raw in normalized.split('\n')) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) {
        if (lines.isNotEmpty && lines.last.isNotEmpty) {
          lines.add('');
        }
        continue;
      }
      // Collapse GitHub markdown headers neatly for dialog display
      if (trimmed.startsWith('### ')) {
        lines.add(trimmed.substring(4).trim());
      } else if (trimmed.startsWith('## ')) {
        lines.add(trimmed.substring(3).trim());
      } else if (trimmed.startsWith('# ')) {
        lines.add(trimmed.substring(2).trim());
      } else if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
        lines.add('• ${trimmed.substring(2).trim()}');
      } else {
        lines.add(trimmed);
      }
    }
    return lines.join('\n').trim();
  }

  /// Normalizes low-level network/socket exceptions into concise user guidance.
  static String formatUpdateError(Object error) {
    final raw = error.toString().trim();
    final lower = raw.toLowerCase();
    if (lower.contains('failed host lookup') ||
        lower.contains('socketexception') ||
        lower.contains('connection errored') ||
        lower.contains('no address associated')) {
      return 'Network or DNS lookup failed while contacting GitHub. Check your internet connection and retry, or tap Download Manually.';
    }
    if (lower.contains('timeout') || lower.contains('timed out')) {
      return 'Update check timed out. Check your internet connection and retry.';
    }
    if (raw.startsWith('Exception: ')) {
      return raw.substring(11);
    }
    return raw;
  }
}
