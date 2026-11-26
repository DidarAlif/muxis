import 'package:flutter_test/flutter_test.dart';
import 'package:muxis/core/audio/dsp/equalizer_node.dart';
import 'package:muxis/core/lyrics/lyrics_service.dart';

void main() {
  group('EqualizerNotifier 10-Band DSP Tests', () {
    test('Initializes with 10 studio frequency bands and Prismatic Neon preset', () {
      final notifier = EqualizerNotifier();
      final eq = notifier.state;

      expect(eq.isEnabled, isTrue);
      expect(eq.bands.length, equals(10));
      expect(
        eq.bands.map((b) => b.frequencyHz).toList(),
        equals(EqualizerState.defaultFrequencies),
      );
      expect(eq.activePreset, equals('Prismatic Neon'));
    });

    test('Clamps band gains between -12 dB and +12 dB and marks preset Custom', () {
      final notifier = EqualizerNotifier();

      notifier.setBandGain(0, 24.0);
      expect(notifier.state.bands[0].gainDb, equals(12.0));
      expect(notifier.state.activePreset, equals('Custom'));

      notifier.setBandGain(9, -30.0);
      expect(notifier.state.bands[9].gainDb, equals(-12.0));
    });

    test('Applies Sub-Bass Thump preset and resets cleanly to Flat', () {
      final notifier = EqualizerNotifier();

      notifier.applyPreset('Sub-Bass Thump');
      expect(notifier.state.activePreset, equals('Sub-Bass Thump'));
      expect(notifier.state.bands[0].gainDb, greaterThan(0.0));

      notifier.resetToFlat();
      expect(notifier.state.activePreset, equals('Flat'));
      for (final band in notifier.state.bands) {
        expect(band.gainDb, equals(0.0));
      }
    });
  });

  group('LyricsService Metadata Normalization Tests', () {
    test('Strips video/remaster suffixes without losing core track title', () {
      expect(
        LyricsService.cleanTrackTitle(
          'Blinding Lights (Official Music Video) [HD]',
        ),
        equals('Blinding Lights'),
      );
      expect(
        LyricsService.cleanTrackTitle('Starboy - Remastered 2022'),
        equals('Starboy'),
      );
    });

    test('Strips YouTube Topic suffix and extracts primary artist', () {
      expect(
        LyricsService.cleanArtistName('Daft Punk - Topic'),
        equals('Daft Punk'),
      );
      expect(
        LyricsService.cleanArtistName('The Weeknd, Ariana Grande'),
        equals('The Weeknd'),
      );
    });
  });
}
