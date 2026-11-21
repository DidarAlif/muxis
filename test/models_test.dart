import 'package:flutter_test/flutter_test.dart';
import 'package:muxis/shared/models/track.dart';
import 'package:muxis/shared/models/playlist.dart';
import 'package:muxis/shared/models/lyrics_line.dart';

void main() {
  group('Track Model Tests', () {
    test('Track correctly serializes and deserializes from Map', () {
      final track = Track(
        id: 'track_01',
        title: 'Prismatic Echoes',
        artist: 'Aura Collective',
        album: 'Violet Spectrum',
        duration: const Duration(minutes: 3, seconds: 45),
        artworkUrl: 'https://cdn.muxis.audio/covers/01.jpg',
        isLocal: true,
      );

      final map = track.toMap();
      expect(map['id'], equals('track_01'));
      expect(map['title'], equals('Prismatic Echoes'));
      expect(map['artist'], equals('Aura Collective'));
      expect(map['durationMs'], equals(225000));
      expect(map['isLocal'], isTrue);

      final restored = Track.fromMap(map);
      expect(restored.id, equals(track.id));
      expect(restored.title, equals(track.title));
      expect(restored.artist, equals(track.artist));
      expect(restored.duration, equals(track.duration));
      expect(restored.isLocal, isTrue);
    });
  });

  group('LyricsLine Model Tests', () {
    test('LyricsLine parses timestamp correctly', () {
      final line = LyricsLine(
        timestamp: const Duration(seconds: 14, milliseconds: 500),
        text: 'Lost in the cyan neon glow',
      );

      expect(line.timestamp.inMilliseconds, equals(14500));
      expect(line.text, equals('Lost in the cyan neon glow'));
    });
  });

  group('Playlist Model Tests', () {
    test('Playlist initializes with correct defaults', () {
      final playlist = Playlist(
        id: 'pl_01',
        title: 'Cyberpunk Lo-Fi',
        tracks: [],
        createdAt: DateTime(2026, 11, 21),
      );

      expect(playlist.title, equals('Cyberpunk Lo-Fi'));
      expect(playlist.tracks, isEmpty);
      expect(playlist.trackCount, equals(0));
    });
  });
}
