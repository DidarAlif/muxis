import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/track.dart';
import 'playback_state.dart';

final playbackServiceProvider =
    StateNotifierProvider<AudioPlaybackService, PlaybackState>((ref) {
      return AudioPlaybackService();
    });

class AudioPlaybackService extends StateNotifier<PlaybackState> {
  Timer? _ticker;
  double _lastUnmutedVolume = 1.0;

  AudioPlaybackService() : super(const PlaybackState()) {
    _initDefaults();
  }

  void _initDefaults() {
    // Initial clean state: starts empty until tracks are loaded from DatabaseService or LocalLibraryScanner
    state = const PlaybackState(
      queue: [],
      currentIndex: -1,
      currentTrack: null,
      duration: Duration.zero,
      status: PlaybackStatus.idle,
    );
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

  void playTrack(Track track, {List<Track>? newQueue}) {
    final queue =
        newQueue ??
        (state.queue.contains(track) ? state.queue : [...state.queue, track]);
    final index = queue.indexOf(track);

    state = state.copyWith(
      currentTrack: track,
      queue: queue,
      currentIndex: index >= 0 ? index : 0,
      status: PlaybackStatus.playing,
      position: Duration.zero,
      duration: track.duration,
      bufferedPosition: track.duration * 0.4,
    );

    _startPlaybackTicker();
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
    state = state.copyWith(status: PlaybackStatus.playing);
    _startPlaybackTicker();
  }

  void pause() {
    state = state.copyWith(status: PlaybackStatus.paused);
    _ticker?.cancel();
  }

  void stop() {
    state = state.copyWith(
      status: PlaybackStatus.idle,
      position: Duration.zero,
    );
    _ticker?.cancel();
  }

  void seek(Duration position) {
    final clamped = position < Duration.zero
        ? Duration.zero
        : (position > state.duration ? state.duration : position);
    state = state.copyWith(position: clamped);
  }

  void setVolume(double volume) {
    final clamped = volume.clamp(0.0, 1.0);
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

    // If more than 3 seconds in, seek to beginning of current track
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

    // Update currentIndex if affected
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
      newCurrentIndex = newCurrentIndex >= newQueue.length
          ? 0
          : newCurrentIndex;
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

    final updated = track.copyWith(isFavorite: !track.isFavorite);
    final updatedQueue = state.queue
        .map((t) => t.id == track.id ? updated : t)
        .toList();
    state = state.copyWith(currentTrack: updated, queue: updatedQueue);
  }

  void _startPlaybackTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (timer) {
      if (!state.isPlaying) {
        timer.cancel();
        return;
      }

      final newPos = state.position + const Duration(milliseconds: 250);
      if (newPos >= state.duration) {
        playNext();
      } else {
        // Expand buffer gradually
        final targetBuffer = state.duration;
        final currentBuffer = state.bufferedPosition;
        final newBuffer = currentBuffer < targetBuffer
            ? currentBuffer + const Duration(milliseconds: 500)
            : targetBuffer;

        state = state.copyWith(position: newPos, bufferedPosition: newBuffer);
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
