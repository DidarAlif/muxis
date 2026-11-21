import '../../shared/models/track.dart';

abstract class MediaSessionHandler {
  Future<void> updateMetadata(Track track);
  Future<void> updatePlaybackState({
    required bool isPlaying,
    required Duration position,
    required Duration duration,
    required double playbackSpeed,
  });
  Future<void> clear();
}

class NoopMediaSessionHandler implements MediaSessionHandler {
  @override
  Future<void> updateMetadata(Track track) async {}

  @override
  Future<void> updatePlaybackState({
    required bool isPlaying,
    required Duration position,
    required Duration duration,
    required double playbackSpeed,
  }) async {}

  @override
  Future<void> clear() async {}
}
