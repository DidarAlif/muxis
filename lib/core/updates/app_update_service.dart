import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../storage/preferences_service.dart';
import 'app_update_models.dart';

export 'app_update_models.dart';

enum UpdatePhase {
  idle,
  checking,
  upToDate,
  available,
  downloading,
  verifying,
  readyToInstall,
  installing,
  error,
}

class AppUpdateState {
  final UpdatePhase phase;
  final String currentVersion;
  final String currentBuild;
  final AppUpdateInfo? availableUpdate;
  final double progress;
  final int receivedBytes;
  final int totalBytes;
  final String? downloadedFilePath;
  final String? statusMessage;
  final String? errorMessage;
  final bool autoCheckEnabled;
  final DateTime? lastCheckedAt;

  const AppUpdateState({
    this.phase = UpdatePhase.idle,
    this.currentVersion = AppUpdateNotifier.fallbackAppVersion,
    this.currentBuild = '18',
    this.availableUpdate,
    this.progress = 0.0,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.downloadedFilePath,
    this.statusMessage,
    this.errorMessage,
    this.autoCheckEnabled = true,
    this.lastCheckedAt,
  });

  bool get isBusy =>
      phase == UpdatePhase.checking ||
      phase == UpdatePhase.downloading ||
      phase == UpdatePhase.verifying ||
      phase == UpdatePhase.installing;

  AppUpdateState copyWith({
    UpdatePhase? phase,
    String? currentVersion,
    String? currentBuild,
    AppUpdateInfo? availableUpdate,
    bool clearAvailableUpdate = false,
    double? progress,
    int? receivedBytes,
    int? totalBytes,
    String? downloadedFilePath,
    bool clearDownloadedFile = false,
    String? statusMessage,
    bool clearStatusMessage = false,
    String? errorMessage,
    bool clearErrorMessage = false,
    bool? autoCheckEnabled,
    DateTime? lastCheckedAt,
  }) {
    return AppUpdateState(
      phase: phase ?? this.phase,
      currentVersion: currentVersion ?? this.currentVersion,
      currentBuild: currentBuild ?? this.currentBuild,
      availableUpdate: clearAvailableUpdate
          ? null
          : (availableUpdate ?? this.availableUpdate),
      progress: progress ?? this.progress,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadedFilePath: clearDownloadedFile
          ? null
          : (downloadedFilePath ?? this.downloadedFilePath),
      statusMessage: clearStatusMessage
          ? null
          : (statusMessage ?? this.statusMessage),
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      autoCheckEnabled: autoCheckEnabled ?? this.autoCheckEnabled,
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
    );
  }
}

final appUpdateProvider =
    StateNotifierProvider<AppUpdateNotifier, AppUpdateState>((ref) {
      final prefs = ref.read(preferencesServiceProvider);
      return AppUpdateNotifier(prefs);
    });

class AppUpdateNotifier extends StateNotifier<AppUpdateState> {
  static const String githubOwner = 'DidarAlif';
  static const String githubRepo = 'muxis';
  static const String fallbackAppVersion = '1.2.6';

  final PreferencesService _prefs;
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(minutes: 10),
      headers: const {
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'MUXIS-App-Updater/1.2.5',
      },
    ),
  );

  CancelToken? _activeCancelToken;
  bool _hasDismissedPopupThisSession = false;
  bool _initialized = false;

  AppUpdateNotifier(this._prefs) : super(const AppUpdateState()) {
    unawaited(init());
  }

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    String version = fallbackAppVersion;
    String build = '18';
    try {
      final info = await PackageInfo.fromPlatform();
      if (info.version.isNotEmpty) version = info.version;
      if (info.buildNumber.isNotEmpty) build = info.buildNumber;
    } catch (_) {}

    final autoEnabled = await _prefs.getAutoUpdateEnabled();
    if (!mounted) return;
    state = state.copyWith(
      currentVersion: version,
      currentBuild: build,
      autoCheckEnabled: autoEnabled,
    );
  }

  Future<void> setAutoCheckEnabled(bool enabled) async {
    await _prefs.saveAutoUpdateEnabled(enabled);
    if (!mounted) return;
    state = state.copyWith(autoCheckEnabled: enabled);
  }

  Future<void> skipVersion(String version) async {
    await _prefs.saveSkippedUpdateVersion(version);
    _hasDismissedPopupThisSession = true;
    if (!mounted) return;
    state = state.copyWith(
      phase: UpdatePhase.idle,
      clearStatusMessage: true,
      clearErrorMessage: true,
    );
  }

  void dismissForSession() {
    _hasDismissedPopupThisSession = true;
    if (state.phase == UpdatePhase.error) {
      state = state.copyWith(
        phase: state.availableUpdate != null
            ? UpdatePhase.available
            : UpdatePhase.idle,
        clearErrorMessage: true,
      );
    }
  }

  Future<AppUpdateInfo?> checkForUpdates({bool userInitiated = false}) async {
    await init();
    if (kIsWeb) return null;

    if (!userInitiated) {
      if (!state.autoCheckEnabled || _hasDismissedPopupThisSession) {
        return null;
      }
    }

    if (state.phase == UpdatePhase.downloading ||
        state.phase == UpdatePhase.verifying ||
        state.phase == UpdatePhase.installing) {
      return state.availableUpdate;
    }

    state = state.copyWith(
      phase: UpdatePhase.checking,
      statusMessage: 'Checking GitHub Releases...',
      clearErrorMessage: true,
    );

    try {
      final data = await _fetchLatestReleaseData();
      if (data == null) {
        throw Exception('Empty response from GitHub Releases API.');
      }

      if (data['draft'] == true || data['prerelease'] == true) {
        state = state.copyWith(
          phase: UpdatePhase.upToDate,
          lastCheckedAt: DateTime.now(),
          statusMessage: 'You are on the latest stable version.',
        );
        return null;
      }

      final tagName = (data['tag_name'] as String?)?.trim() ?? '';
      if (tagName.isEmpty) {
        throw Exception('Latest release tag missing.');
      }

      final parsedLatest = MuxisVersionComparator.parseSemver(tagName);
      final latestVersion = parsedLatest.normalized;
      final isNewer = MuxisVersionComparator.isNewerVersion(
        remoteVersion: latestVersion,
        currentVersion: state.currentVersion,
      );

      if (!isNewer) {
        state = state.copyWith(
          phase: userInitiated ? UpdatePhase.upToDate : UpdatePhase.idle,
          clearAvailableUpdate: true,
          lastCheckedAt: DateTime.now(),
          statusMessage: 'MUXIS v${state.currentVersion} is up to date.',
        );
        return null;
      }

      if (!userInitiated) {
        final skipped = await _prefs.getSkippedUpdateVersion();
        if (skipped != null && skipped == latestVersion) {
          state = state.copyWith(
            phase: UpdatePhase.idle,
            lastCheckedAt: DateTime.now(),
            clearStatusMessage: true,
          );
          return null;
        }
      }

      final rawAssets = (data['assets'] as List<dynamic>?) ?? const [];
      final assets = rawAssets
          .whereType<Map<String, dynamic>>()
          .map(AppReleaseAsset.fromJson)
          .toList();

      final selectedAsset = MuxisUpdateSelector.selectAssetForOperatingSystem(
        assets,
        Platform.operatingSystem,
      );
      if (selectedAsset == null) {
        if (!userInitiated) {
          state = state.copyWith(
            phase: UpdatePhase.idle,
            lastCheckedAt: DateTime.now(),
            clearStatusMessage: true,
          );
          return null;
        }
        throw Exception(
          'Release $tagName found, but no ${Platform.operatingSystem} installer asset is attached yet.',
        );
      }

      String? expectedSha;
      final checksumAsset = assets.cast<AppReleaseAsset?>().firstWhere(
        (a) => a?.name == 'checksums-sha256.txt',
        orElse: () => null,
      );
      if (checksumAsset != null && checksumAsset.downloadUrl.isNotEmpty) {
        try {
          final csResp = await _dio.get<String>(
            checksumAsset.downloadUrl,
            options: Options(responseType: ResponseType.plain),
          );
          if (csResp.data != null) {
            expectedSha = MuxisUpdateSelector.parseSha256ForAsset(
              csResp.data!,
              selectedAsset.name,
            );
          }
        } catch (_) {
          // Optional integrity metadata; non-empty size verification still runs
        }
      }

      final publishedRaw = data['published_at'] as String?;
      final updateInfo = AppUpdateInfo(
        tagName: tagName,
        latestVersion: latestVersion,
        currentVersion: state.currentVersion,
        releaseName: (data['name'] as String?)?.trim() ?? 'MUXIS $tagName',
        releaseNotes: MuxisUpdateSelector.cleanReleaseNotes(
          (data['body'] as String?) ?? '',
          releaseName: (data['name'] as String?)?.trim(),
        ),
        htmlUrl:
            (data['html_url'] as String?) ??
            'https://github.com/$githubOwner/$githubRepo/releases/latest',
        publishedAt: publishedRaw != null
            ? DateTime.tryParse(publishedRaw)
            : null,
        asset: selectedAsset,
        expectedSha256: expectedSha,
      );

      state = state.copyWith(
        phase: UpdatePhase.available,
        availableUpdate: updateInfo,
        progress: 0.0,
        receivedBytes: 0,
        totalBytes: selectedAsset.sizeBytes,
        lastCheckedAt: DateTime.now(),
        statusMessage: 'Update ${updateInfo.tagName} is ready to download.',
        clearDownloadedFile: true,
        clearErrorMessage: true,
      );

      return updateInfo;
    } catch (e) {
      if (!mounted) return null;
      if (!userInitiated) {
        state = state.copyWith(
          phase: UpdatePhase.idle,
          clearStatusMessage: true,
          clearErrorMessage: true,
        );
        return null;
      }
      state = state.copyWith(
        phase: UpdatePhase.error,
        lastCheckedAt: DateTime.now(),
        errorMessage: 'Unable to check for updates: ${_formatError(e)}',
        clearStatusMessage: true,
      );
      return null;
    }
  }

  Future<void> downloadAndInstall() async {
    final update = state.availableUpdate;
    if (update == null || state.phase == UpdatePhase.downloading) return;

    _activeCancelToken?.cancel();
    final cancelToken = CancelToken();
    _activeCancelToken = cancelToken;

    try {
      final tempBase = await getTemporaryDirectory();
      final updatesDir = Directory(p.join(tempBase.path, 'muxis_updates'));
      if (!await updatesDir.exists()) {
        await updatesDir.create(recursive: true);
      } else {
        await for (final entity in updatesDir.list()) {
          try {
            await entity.delete(recursive: true);
          } catch (_) {}
        }
      }

      final safeName = update.asset.name.replaceAll(
        RegExp(r'[^a-zA-Z0-9._-]'),
        '_',
      );
      final targetPath = p.join(updatesDir.path, safeName);

      state = state.copyWith(
        phase: UpdatePhase.downloading,
        progress: 0.0,
        receivedBytes: 0,
        totalBytes: update.asset.sizeBytes,
        statusMessage: 'Downloading ${update.asset.name}...',
        clearErrorMessage: true,
        clearDownloadedFile: true,
      );

      var lastUiTick = DateTime.fromMillisecondsSinceEpoch(0);
      await _dio.download(
        update.asset.downloadUrl,
        targetPath,
        cancelToken: cancelToken,
        deleteOnError: true,
        options: Options(
          followRedirects: true,
          maxRedirects: 8,
          headers: const {
            'Accept': '*/*',
            'User-Agent': 'MUXIS-App-Updater/1.1',
          },
        ),
        onReceiveProgress: (received, total) {
          if (!mounted) return;
          final effectiveTotal = total > 0 ? total : update.asset.sizeBytes;
          final now = DateTime.now();
          if (now.difference(lastUiTick).inMilliseconds < 80 &&
              received < effectiveTotal) {
            return;
          }
          lastUiTick = now;
          final frac = effectiveTotal > 0
              ? (received / effectiveTotal).clamp(0.0, 1.0)
              : 0.0;
          state = state.copyWith(
            progress: frac,
            receivedBytes: received,
            totalBytes: effectiveTotal,
            statusMessage:
                'Downloading ${MuxisUpdateSelector.formatBytes(received)} / ${MuxisUpdateSelector.formatBytes(effectiveTotal)}',
          );
        },
      );

      final downloadedFile = File(targetPath);
      if (!await downloadedFile.exists() ||
          await downloadedFile.length() == 0) {
        throw Exception('Downloaded installer file was empty or missing.');
      }

      // SHA-256 verification when checksum metadata exists
      if (update.expectedSha256 != null && update.expectedSha256!.isNotEmpty) {
        if (!mounted) return;
        state = state.copyWith(
          phase: UpdatePhase.verifying,
          progress: 1.0,
          statusMessage: 'Verifying SHA-256 package signature...',
        );
        final digest = await sha256.bind(downloadedFile.openRead()).first;
        final actualHex = digest.toString().toLowerCase();
        if (actualHex != update.expectedSha256!.toLowerCase()) {
          try {
            await downloadedFile.delete();
          } catch (_) {}
          throw Exception(
            'Integrity check failed (SHA-256 mismatch). Download discarded safely.',
          );
        }
      }

      if (!mounted) return;
      state = state.copyWith(
        phase: UpdatePhase.installing,
        progress: 1.0,
        downloadedFilePath: targetPath,
        statusMessage: 'Launching ${update.tagName} installer...',
      );

      await _launchPlatformInstaller(targetPath, update);
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        if (!mounted) return;
        state = state.copyWith(
          phase: UpdatePhase.available,
          progress: 0.0,
          receivedBytes: 0,
          statusMessage: 'Download canceled.',
          clearErrorMessage: true,
        );
        return;
      }
      if (!mounted) return;
      state = state.copyWith(
        phase: UpdatePhase.error,
        errorMessage: 'Download failed: ${_formatError(e)}',
        clearStatusMessage: true,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        phase: UpdatePhase.error,
        errorMessage: _formatError(e),
        clearStatusMessage: true,
      );
    } finally {
      if (identical(_activeCancelToken, cancelToken)) {
        _activeCancelToken = null;
      }
    }
  }

  Future<void> _launchPlatformInstaller(
    String filePath,
    AppUpdateInfo update,
  ) async {
    if (Platform.isWindows) {
      final lower = filePath.toLowerCase();
      if (lower.endsWith('.exe')) {
        await Process.start(filePath, const [
          '/SP-',
          '/SILENT',
          '/CLOSEAPPLICATIONS',
          '/RESTARTAPPLICATIONS',
        ], mode: ProcessStartMode.detached);
        if (mounted) {
          state = state.copyWith(
            phase: UpdatePhase.installing,
            statusMessage: 'Installer started! Closing MUXIS so the update can finish and relaunch automatically...',
          );
        }
        await Future<void>.delayed(const Duration(milliseconds: 500));
        exit(0);
      } else {
        await Process.start('explorer.exe', ['/select,', filePath]);
        if (mounted) {
          state = state.copyWith(
            phase: UpdatePhase.readyToInstall,
            statusMessage:
                'Downloaded portable archive. Opened Explorer at $filePath',
          );
        }
        return;
      }
    }

    if (Platform.isAndroid) {
      final result = await OpenFilex.open(
        filePath,
        type: 'application/vnd.android.package-archive',
      );
      if (!mounted) return;
      if (result.type == ResultType.done) {
        state = state.copyWith(
          phase: UpdatePhase.readyToInstall,
          statusMessage: 'Android installer opened. Tap Update (or allow "Install unknown apps" once if prompted) to finish.',
        );
      } else if (result.type == ResultType.permissionDenied) {
        state = state.copyWith(
          phase: UpdatePhase.error,
          errorMessage: 'Permission needed: enable "Install unknown apps" for MUXIS in Android Settings, then tap Install again.',
        );
      } else {
        state = state.copyWith(
          phase: UpdatePhase.error,
          errorMessage: result.message.isNotEmpty
              ? result.message
              : 'Could not launch Android package installer automatically.',
        );
      }
      return;
    }

    if (Platform.isMacOS) {
      if (filePath.toLowerCase().endsWith('.zip')) {
        final extractDir = p.join(
          p.dirname(filePath),
          'extracted_${update.latestVersion}',
        );
        await Directory(extractDir).create(recursive: true);
        final unzipRes = await Process.run('unzip', [
          '-o',
          '-q',
          filePath,
          '-d',
          extractDir,
        ]);
        if (unzipRes.exitCode == 0) {
          String revealPath = extractDir;
          await for (final entity in Directory(extractDir).list()) {
            if (entity.path.toLowerCase().endsWith('.app')) {
              revealPath = entity.path;
              break;
            }
          }
          await Process.start('open', ['-R', revealPath]);
          if (mounted) {
            state = state.copyWith(
              phase: UpdatePhase.readyToInstall,
              statusMessage: 'Unpacked in Finder. Drag MUXIS.app into Applications to complete the update.',
            );
          }
          return;
        }
      }
      await Process.start('open', ['-R', filePath]);
      if (mounted) {
        state = state.copyWith(
          phase: UpdatePhase.readyToInstall,
          statusMessage: 'Revealed update package in Finder.',
        );
      }
      return;
    }

    if (Platform.isLinux) {
      await Process.start('xdg-open', [p.dirname(filePath)]);
      if (mounted) {
        state = state.copyWith(
          phase: UpdatePhase.readyToInstall,
          statusMessage:
              'Update downloaded to ${p.dirname(filePath)}. Extract and launch the new bundle.',
        );
      }
      return;
    }

    await openReleasePage();
  }

  Future<void> launchDownloadedInstallerAgain() async {
    final path = state.downloadedFilePath;
    final update = state.availableUpdate;
    if (path == null || update == null || !File(path).existsSync()) {
      await downloadAndInstall();
      return;
    }
    try {
      await _launchPlatformInstaller(path, update);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        phase: UpdatePhase.error,
        errorMessage: _formatError(e),
      );
    }
  }

  void cancelDownload() {
    _activeCancelToken?.cancel('Canceled by user');
  }

  Future<void> openReleasePage() async {
    final url =
        state.availableUpdate?.htmlUrl ??
        'https://github.com/$githubOwner/$githubRepo/releases/latest';
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<Map<String, dynamic>?> _fetchLatestReleaseData() async {
    Object? primaryError;
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        'https://api.github.com/repos/$githubOwner/$githubRepo/releases/latest',
      );
      if (resp.data != null) return resp.data;
    } catch (e) {
      primaryError = e;
    }

    // Fallback 1: Resolve github.com/releases/latest redirect tag cleanly
    try {
      final redirectResp = await _dio.get<String>(
        'https://github.com/$githubOwner/$githubRepo/releases/latest',
        options: Options(
          headers: const {
            'Accept': 'text/html',
            'User-Agent': 'MUXIS-App-Updater/1.2.5',
          },
          responseType: ResponseType.plain,
        ),
      );
      final resolvedUrl = redirectResp.realUri.toString();
      final match = RegExp(r'/releases/tag/([^/?#]+)').firstMatch(resolvedUrl);
      if (match != null) {
        final tagName = Uri.decodeComponent(match.group(1)!);
        final dlBase =
            'https://github.com/$githubOwner/$githubRepo/releases/download/$tagName';
        return {
          'tag_name': tagName,
          'name': 'MUXIS $tagName',
          'html_url':
              'https://github.com/$githubOwner/$githubRepo/releases/tag/$tagName',
          'body': '',
          'assets': [
            {
              'name': 'Muxis-Android.apk',
              'browser_download_url': '$dlBase/Muxis-Android.apk',
              'size': 0,
            },
            {
              'name': 'Muxis-Windows-x64-Setup.exe',
              'browser_download_url': '$dlBase/Muxis-Windows-x64-Setup.exe',
              'size': 0,
            },
            {
              'name': 'Muxis-macOS-Universal.zip',
              'browser_download_url': '$dlBase/Muxis-macOS-Universal.zip',
              'size': 0,
            },
            {
              'name': 'Muxis-Linux-x64.tar.gz',
              'browser_download_url': '$dlBase/Muxis-Linux-x64.tar.gz',
              'size': 0,
            },
            {
              'name': 'checksums-sha256.txt',
              'browser_download_url': '$dlBase/checksums-sha256.txt',
              'size': 0,
            },
          ],
        };
      }
    } catch (_) {}

    // Fallback 2: GitHub Pages static release manifest
    try {
      final pageResp = await _dio.get<Map<String, dynamic>>(
        'https://didaralif.github.io/muxis/latest-release.json',
      );
      if (pageResp.data != null) return pageResp.data;
    } catch (_) {}

    if (primaryError != null) throw primaryError;
    return null;
  }

  String _formatError(Object e) {
    return MuxisUpdateSelector.formatUpdateError(e);
  }
}
