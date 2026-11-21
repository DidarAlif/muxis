import '../../shared/models/track.dart';

enum PlaybackStatus { idle, loading, playing, paused, completed, error }

enum RepeatMode { off, all, one }

class PlaybackState {
  final PlaybackStatus status;
  final Track? currentTrack;
  final Duration position;
  final Duration bufferedPosition;
  final Duration duration;
  final double volume;
  final bool isMuted;
  final bool isShuffle;
  final RepeatMode repeatMode;
  final List<Track> queue;
  final int currentIndex;
  final String? errorMessage;

  const PlaybackState({
    this.status = PlaybackStatus.idle,
    this.currentTrack,
    this.position = Duration.zero,
    this.bufferedPosition = Duration.zero,
    this.duration = Duration.zero,
    this.volume = 1.0,
    this.isMuted = false,
    this.isShuffle = false,
    this.repeatMode = RepeatMode.off,
    this.queue = const [],
    this.currentIndex = -1,
    this.errorMessage,
  });

  bool get isPlaying => status == PlaybackStatus.playing;
  bool get isLoading => status == PlaybackStatus.loading;
  bool get hasTrack => currentTrack != null;

  double get progressFraction {
    if (duration.inMilliseconds == 0) return 0.0;
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  double get bufferedFraction {
    if (duration.inMilliseconds == 0) return 0.0;
    return (bufferedPosition.inMilliseconds / duration.inMilliseconds).clamp(
      0.0,
      1.0,
    );
  }

  PlaybackState copyWith({
    PlaybackStatus? status,
    Track? currentTrack,
    Duration? position,
    Duration? bufferedPosition,
    Duration? duration,
    double? volume,
    bool? isMuted,
    bool? isShuffle,
    RepeatMode? repeatMode,
    List<Track>? queue,
    int? currentIndex,
    String? errorMessage,
  }) {
    return PlaybackState(
      status: status ?? this.status,
      currentTrack: currentTrack ?? this.currentTrack,
      position: position ?? this.position,
      bufferedPosition: bufferedPosition ?? this.bufferedPosition,
      duration: duration ?? this.duration,
      volume: volume ?? this.volume,
      isMuted: isMuted ?? this.isMuted,
      isShuffle: isShuffle ?? this.isShuffle,
      repeatMode: repeatMode ?? this.repeatMode,
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
