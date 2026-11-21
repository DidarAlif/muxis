import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../providers/innertube_music_provider.dart';
import '../../providers/spotify_music_provider.dart';
import '../../shared/models/track.dart';
import '../database/database_service.dart';
import 'playback_state.dart';

final playbackServiceProvider =
    StateNotifierProvider<AudioPlaybackService, PlaybackState>((ref) {
  final db = ref.watch(databaseServiceProvider);
  return AudioPlaybackService(databaseService: db);
});

class AudioPlaybackService extends StateNotifier<PlaybackState> {
  final AudioPlayer _player;
  final InnerTubeMusicProvider _innerTubeProvider;
  final SpotifyMusicProvider _spotifyProvider;
  final DatabaseService? _databaseService;

  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<Duration>? _bufferedPositionSub;

  double _lastUnmutedVolume = 1.0;
  bool _isDisposed = false;

  AudioPlaybackService({
    AudioPlayer? player,
    InnerTubeMusicProvider? innerTubeProvider,
    SpotifyMusicProvider? spotifyProvider,
    DatabaseService? databaseService,
  })  : _player = player ?? AudioPlayer(),
        _innerTubeProvider = innerTubeProvider ?? InnerTubeMusicProvider(),
        _spotifyProvider = spotifyProvider ?? SpotifyMusicProvider(),
        _databaseService = databaseService,
        super(const PlaybackState()) {
    _initAudioListeners();
    if (_databaseService != null) {
      final saved = _databaseService!.getAllTracks();
      if (saved.isNotEmpty) {
        loadInitialTracks(saved);
      }
    }
  }

  void _initAudioListeners() {
    _playerStateSub = _player.playerStateStream.listen((playerState) {
      if (_isDisposed) return;

      final isPlaying = playerState.playing;
      final procState = playerState.processingState;

      PlaybackStatus status;
      switch (procState) {
        case ProcessingState.idle:
          status = PlaybackStatus.idle;
          break;
        case ProcessingState.loading:
        case ProcessingState.buffering:
          status = PlaybackStatus.loading;
          break;
        case ProcessingState.ready:
          status = isPlaying ? PlaybackStatus.playing : PlaybackStatus.paused;
          break;
        case ProcessingState.completed:
          status = PlaybackStatus.completed;
          _handleTrackCompleted();
          return;
      }

      state = state.copyWith(status: status);
    }, onError: (Object err) {
      if (!_isDisposed) {
        state = state.copyWith(
          status: PlaybackStatus.error,
          errorMessage: 'Audio Engine Error: $err',
        );
      }
    });

    _positionSub = _player.positionStream.listen((pos) {
      if (!_isDisposed) {
        state = state.copyWith(position: pos);
      }
    });

    _durationSub = _player.durationStream.listen((dur) {
      if (!_isDisposed && dur != null) {
        state = state.copyWith(duration: dur);
      }
    });

    _bufferedPositionSub = _player.bufferedPositionStream.listen((buf) {
      if (!_isDisposed) {
        state = state.copyWith(bufferedPosition: buf);
      }
    });
  }

  void _handleTrackCompleted() {
    if (state.repeatMode == RepeatMode.one) {
      seek(Duration.zero);
      play();
    } else {
      playNext();
    }
  }

  void loadInitialTracks(List<Track> tracks) {
    if (tracks.isEmpty) return;
    state = state.copyWith(
      queue: tracks,
      currentIndex: 0,
      currentTrack: tracks[0],
      duration: tracks[0].duration,
      status: PlaybackStatus.idle,
    );
  }

  Future<void> playTrack(Track track, {List<Track>? newQueue}) async {
    final queue = newQueue ??
        (state.queue.contains(track) ? state.queue : [...state.queue, track]);
    final index = queue.indexOf(track);

    state = state.copyWith(
      currentTrack: track,
      queue: queue,
      currentIndex: index >= 0 ? index : 0,
      status: PlaybackStatus.loading,
      position: Duration.zero,
      duration: track.duration,
      bufferedPosition: Duration.zero,
      errorMessage: null,
    );

    try {
      // 1. Resolve Audio Source
      String? playUri;

      if (track.localFilePath != null && track.localFilePath!.isNotEmpty) {
        // Local music playback
        await _player.setFilePath(track.localFilePath!);
        await _player.play();
        _databaseService?.recordHistory(track.id);
        return;
      }

      if (track.streamUrl != null && track.streamUrl!.isNotEmpty) {
        playUri = track.streamUrl;
      } else if (track.source == MusicSource.youtube) {
        playUri = await _innerTubeProvider.resolveAudioStreamUrl(track);
      } else if (track.source == MusicSource.spotify) {
        playUri = await _spotifyProvider.resolveAudioStreamUrl(track);
      } else {
        playUri = await _innerTubeProvider.resolveAudioStreamUrl(track);
      }

      if (playUri == null || playUri.isEmpty) {
        // If stream resolution fails, attempt fallback query
        final fallbackTracks = await _innerTubeProvider.search('${track.artist} ${track.title}');
        if (fallbackTracks.isNotEmpty) {
          playUri = await _innerTubeProvider.resolveAudioStreamUrl(fallbackTracks.first);
        }
      }

      if (playUri != null && playUri.isNotEmpty) {
        // Set up player with iOS headers for highest compatibility and zero ads
        await _player.setUrl(
          playUri,
          headers: {
            'User-Agent':
                'com.google.ios.youtube/21.03.1 (iPhone16,2; U; CPU iOS 18_2 like Mac OS X;)',
            'Accept': '*/*',
          },
        );
        await _player.play();
        _databaseService?.recordHistory(track.id);
      } else {
        state = state.copyWith(
          status: PlaybackStatus.error,
          errorMessage: 'Unable to resolve ad-free stream for: ${track.title}',
        );
      }
    } catch (e) {
      if (!_isDisposed) {
        state = state.copyWith(
          status: PlaybackStatus.error,
          errorMessage: 'Playback error: $e',
        );
      }
    }
  }

  void togglePlay() {
    if (state.isPlaying) {
      pause();
    } else {
      play();
    }
  }

  void play() {
    if (!state.hasTrack && state.queue.isNotEmpty) {
      playTrack(state.queue[0]);
      return;
    }
    _player.play();
  }

  void pause() {
    _player.pause();
  }

  void stop() {
    _player.stop();
    state = state.copyWith(
      status: PlaybackStatus.idle,
      position: Duration.zero,
    );
  }

  void seek(Duration position) {
    final clamped = position < Duration.zero
        ? Duration.zero
        : (position > state.duration ? state.duration : position);
    _player.seek(clamped);
    state = state.copyWith(position: clamped);
  }

  void setVolume(double volume) {
    final clamped = volume.clamp(0.0, 1.0);
    _player.setVolume(clamped);
    state = state.copyWith(volume: clamped, isMuted: clamped == 0.0);
    if (clamped > 0.0) {
      _lastUnmutedVolume = clamped;
    }
  }

  void toggleMute() {
    if (state.isMuted) {
      setVolume(_lastUnmutedVolume > 0 ? _lastUnmutedVolume : 0.5);
    } else {
      _lastUnmutedVolume = state.volume;
      setVolume(0.0);
    }
  }

  void toggleShuffle() {
    state = state.copyWith(isShuffle: !state.isShuffle);
  }

  void cycleRepeatMode() {
    switch (state.repeatMode) {
      case RepeatMode.off:
        state = state.copyWith(repeatMode: RepeatMode.all);
        break;
      case RepeatMode.all:
        state = state.copyWith(repeatMode: RepeatMode.one);
        break;
      case RepeatMode.one:
        state = state.copyWith(repeatMode: RepeatMode.off);
        break;
    }
  }

  void playNext() {
    if (state.queue.isEmpty) return;

    if (state.repeatMode == RepeatMode.one) {
      seek(Duration.zero);
      play();
      return;
    }

    int nextIndex = state.currentIndex + 1;
    if (nextIndex >= state.queue.length) {
      if (state.repeatMode == RepeatMode.all) {
        nextIndex = 0;
      } else {
        stop();
        return;
      }
    }

    playTrack(state.queue[nextIndex]);
  }

  void playPrevious() {
    if (state.queue.isEmpty) return;

    if (state.position.inSeconds > 3) {
      seek(Duration.zero);
      return;
    }

    int prevIndex = state.currentIndex - 1;
    if (prevIndex < 0) {
      prevIndex = state.queue.length - 1;
    }
    playTrack(state.queue[prevIndex]);
  }

  void addToQueue(Track track, {bool playNext = false}) {
    final newQueue = List<Track>.from(state.queue);
    if (playNext &&
        state.currentIndex >= 0 &&
        state.currentIndex < newQueue.length) {
      newQueue.insert(state.currentIndex + 1, track);
    } else {
      newQueue.add(track);
    }
    state = state.copyWith(queue: newQueue);
  }

  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= state.queue.length) return;
    if (newIndex < 0 || newIndex > state.queue.length) return;

    final newQueue = List<Track>.from(state.queue);
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = newQueue.removeAt(oldIndex);
    newQueue.insert(newIndex, item);

    int newCurrentIndex = state.currentIndex;
    if (state.currentIndex == oldIndex) {
      newCurrentIndex = newIndex;
    } else if (state.currentIndex > oldIndex &&
        state.currentIndex <= newIndex) {
      newCurrentIndex -= 1;
    } else if (state.currentIndex < oldIndex &&
        state.currentIndex >= newIndex) {
      newCurrentIndex += 1;
    }

    state = state.copyWith(queue: newQueue, currentIndex: newCurrentIndex);
  }

  void removeFromQueue(int index) {
    if (index < 0 || index >= state.queue.length) return;
    final newQueue = List<Track>.from(state.queue);
    newQueue.removeAt(index);

    int newCurrentIndex = state.currentIndex;
    if (index < state.currentIndex) {
      newCurrentIndex -= 1;
    } else if (index == state.currentIndex) {
      if (newQueue.isEmpty) {
        stop();
        state = state.copyWith(queue: [], currentTrack: null, currentIndex: -1);
        return;
      }
      newCurrentIndex =
          newCurrentIndex >= newQueue.length ? 0 : newCurrentIndex;
      playTrack(newQueue[newCurrentIndex], newQueue: newQueue);
      return;
    }

    state = state.copyWith(queue: newQueue, currentIndex: newCurrentIndex);
  }

  void clearQueue() {
    stop();
    state = state.copyWith(queue: [], currentTrack: null, currentIndex: -1);
  }

  void toggleFavoriteCurrentTrack() {
    final track = state.currentTrack;
    if (track == null) return;

    _databaseService?.toggleFavorite(track.id);
    final updated = track.copyWith(isFavorite: !track.isFavorite);
    final updatedQueue = state.queue
        .map((t) => t.id == track.id ? updated : t)
        .toList();
    state = state.copyWith(currentTrack: updated, queue: updatedQueue);
  }

  @override
  void dispose() {
    _isDisposed = true;
    _playerStateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _bufferedPositionSub?.cancel();
    _player.dispose();
    super.dispose();
  }
}
