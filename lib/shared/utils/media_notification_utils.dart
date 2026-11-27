import '../models/track.dart';

/// Pure-Dart helpers mapping MUXIS [Track] objects into OS media notification
/// metadata cleanly across Android MediaSession, iOS Lock Screen, and Radio streams.
class MediaNotificationHelper {
  MediaNotificationHelper._();

  /// Returns a valid network or file [Uri] for notification artwork, or `null`
  /// when [rawUrl] is blank or uses an unsupported/invalid scheme.
  static Uri? resolveArtworkUri(String? rawUrl) {
    final trimmed = rawUrl?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    final parsed = Uri.tryParse(trimmed);
    if (parsed == null) return null;
    final scheme = parsed.scheme.toLowerCase();
    if (scheme == 'http' || scheme == 'https' || scheme == 'file') {
      return parsed;
    }
    return null;
  }

  /// Normalizes duration for notification controls (`null` for live Radio streams
  /// or zero-duration tracks so the OS does not show an invalid `0:00` bar).
  static Duration? resolveNotificationDuration(Track track) {
    if (track.source == MusicSource.radio) return null;
    return track.duration > Duration.zero ? track.duration : null;
  }

  /// Builds safe non-empty display strings for Android MediaStyle notifications.
  static ({String title, String artist, String album}) resolveDisplayMetadata(
    Track track,
  ) {
    final title = track.title.trim().isNotEmpty
        ? track.title.trim()
        : 'MUXIS Audio';
    final artist = track.artist.trim().isNotEmpty
        ? track.artist.trim()
        : (track.source == MusicSource.radio
              ? 'Live Radio Stream'
              : 'Unknown Artist');
    final album = track.album.trim().isNotEmpty
        ? track.album.trim()
        : (track.source == MusicSource.radio ? 'MUXIS Global FM' : title);
    return (title: title, artist: artist, album: album);
  }
}
