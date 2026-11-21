import 'package:flutter_test/flutter_test.dart';
import 'package:muxis/core/audio/dsp/equalizer_node.dart';

void main() {
  group('EqualizerNode DSP Tests', () {
    test('Default 5-band gains are within standard bounds', () {
      final eq = EqualizerNode();
      expect(eq.bands.length, equals(5));

      for (final band in eq.bands) {
        expect(band.gain, greaterThanOrEqualTo(-12.0));
        expect(band.gain, lessThanOrEqualTo(12.0));
      }
    });

    test('Clamping prevents gain values outside -12dB to +12dB', () {
      final eq = EqualizerNode();
      eq.setGain(0, 25.0); // Out of bounds high
      expect(eq.bands[0].gain, equals(12.0));

      eq.setGain(0, -30.0); // Out of bounds low
      expect(eq.bands[0].gain, equals(-12.0));
    });

    test('Preset application applies calibrated band values', () {
      final eq = EqualizerNode();
      eq.applyPreset('Bass Boost');

      expect(eq.bands[0].gain, greaterThan(0.0)); // Bass frequency amplified
      expect(eq.currentPreset, equals('Bass Boost'));
    });
  });
}
