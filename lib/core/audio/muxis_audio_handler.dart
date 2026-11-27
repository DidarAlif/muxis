import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../../shared/models/track.dart';
import '../../shared/utils/media_notification_utils.dart';

/// Bridges MUXIS playback state and transport controls with Android MediaStyle
/// notification bar / lock-screen controls and iOS MPNowPlayingInfoCenter.
class MuxisAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  static MuxisAudioHandler? _instance;

  static MuxisAudioHandler? get instance => _instance;

  VoidCallback? onPlayCallback;
  VoidCallback? onPauseCallback;
  VoidCallback? onStopCallback;
  VoidCallback? onNextCallback;
  VoidCallback? onPreviousCallback;
  ValueChanged<Duration>? onSeekCallback;

  bool _sessionConfigured = false;
  AudioSession? _audioSession;
  StreamSubscription<void>? _noisySub;
  StreamSubscription<AudioInterruptionEvent>? _interruptionSub;

  /// Initializes the system AudioService & AudioSession cleanly on mobile platforms.
  static Future<MuxisAudioHandler?> initGlobal() async {
    if (_instance != null) return _instance;
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
      return null;
    }

    try {
      final handler = await AudioService.init<MuxisAudioHandler>(
        builder: () => MuxisAudioHandler(),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'app.muxis.muxis.channel.audio',
          androidNotificationChannelName: 'MUXIS Playback',
          androidNotificationChannelDescription:
              'Playback controls and now-playing bar for MUXIS',
          androidNotificationIcon: 'drawable/ic_muxis_notification',
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: true,
          androidShowNotificationBadge: true,
        ),
      );
      _instance = handler;
      await handler.ensureAudioSessionConfigured();
      return handler;
    } catch (_) {
      return null;
    }
  }

  /// Configures hardware audio focus and headphone unplug ("becoming noisy") handling.
  Future<void> ensureAudioSessionConfigured() async {
    if (_sessionConfigured) return;
    _sessionConfigured = true;
    try {
      final session = await AudioSession.instance;
      _audioSession = session;
      await session.configure(const AudioSessionConfiguration.music());
      _noisySub = session.becomingNoisyEventStream.listen((_) {
        onPauseCallback?.call();
      });
      _interruptionSub = session.interruptionEventStream.listen((event) {
        if (event.begin &&
            (event.type == AudioInterruptionType.pause ||
                event.type == AudioInterruptionType.unknown)) {
          onPauseCallback?.call();
        }
      });
    } catch (_) {}
  }

  /// Activates OS audio focus right before starting audio playback.
  Future<void> activateAudioFocus() async {
    try {
      await ensureAudioSessionConfigured();
      await _audioSession?.setActive(true);
    } catch (_) {}
  }

  /// Publishes current track metadata (title, artist, album, duration, artwork)
  /// to the Android notification shade and lock screen.
  void updateNowPlaying(Track track) {
    final meta = MediaNotificationHelper.resolveDisplayMetadata(track);
    final item = MediaItem(
      id: track.id,
      title: meta.title,
      artist: meta.artist,
      album: meta.album,
      duration: MediaNotificationHelper.resolveNotificationDuration(track),
      artUri: MediaNotificationHelper.resolveArtworkUri(track.artworkUrl),
      extras: {
        'source': track.source.name,
        if (track.audioFormat != null) 'audioFormat': track.audioFormat,
      },
    );
    mediaItem.add(item);
  }

  /// Updates track duration cleanly once the player resolves exact stream length.
  void updateDuration(Duration duration) {
    if (duration <= Duration.zero) return;
    final current = mediaItem.value;
    if (current == null || current.duration == duration) return;
    mediaItem.add(current.copyWith(duration: duration));
  }

  /// Publishes current queue list to system media browsers.
  void syncQueue(List<Track> tracks) {
    final items = tracks
        .take(50)
        .map((t) {
          final meta = MediaNotificationHelper.resolveDisplayMetadata(t);
          return MediaItem(
            id: t.id,
            title: meta.title,
            artist: meta.artist,
            album: meta.album,
            duration: MediaNotificationHelper.resolveNotificationDuration(t),
            artUri: MediaNotificationHelper.resolveArtworkUri(t.artworkUrl),
          );
        })
        .toList(growable: false);
    queue.add(items);
  }

  /// Updates OS media notification transport buttons, play state, and scrub position.
  void syncPlaybackState({
    required bool playing,
    required ProcessingState processingState,
    required Duration position,
    required Duration bufferedPosition,
    double speed = 1.0,
    bool forceActive = false,
  }) {
    final mappedProc = switch (processingState) {
      ProcessingState.idle =>
        forceActive ? AudioProcessingState.loading : AudioProcessingState.idle,
      ProcessingState.loading => AudioProcessingState.loading,
      ProcessingState.buffering => AudioProcessingState.buffering,
      ProcessingState.ready => AudioProcessingState.ready,
      ProcessingState.completed => AudioProcessingState.completed,
    };

    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          playing ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
          MediaAction.play,
          MediaAction.pause,
          MediaAction.playPause,
          MediaAction.skipToNext,
          MediaAction.skipToPrevious,
          MediaAction.stop,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: mappedProc,
        playing: playing,
        updatePosition: position,
        bufferedPosition: bufferedPosition,
        speed: playing ? speed : 0.0,
      ),
    );
  }

  @override
  Future<void> play() async => onPlayCallback?.call();

  @override
  Future<void> pause() async => onPauseCallback?.call();

  @override
  Future<void> stop() async {
    onStopCallback?.call();
    try {
      await _audioSession?.setActive(false);
    } catch (_) {}
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) async => onSeekCallback?.call(position);

  @override
  Future<void> skipToNext() async => onNextCallback?.call();

  @override
  Future<void> skipToPrevious() async => onPreviousCallback?.call();

  void clearCallbacks() {
    onPlayCallback = null;
    onPauseCallback = null;
    onStopCallback = null;
    onNextCallback = null;
    onPreviousCallback = null;
    onSeekCallback = null;
  }

  void disposeSubscriptions() {
    _noisySub?.cancel();
    _interruptionSub?.cancel();
  }
}
