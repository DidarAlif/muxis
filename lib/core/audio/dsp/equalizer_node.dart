import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

class EqualizerBand {
  final int frequencyHz;
  final double gainDb; // -12.0 to +12.0 dB

  const EqualizerBand({required this.frequencyHz, required this.gainDb});

  EqualizerBand copyWith({double? gainDb}) {
    return EqualizerBand(
      frequencyHz: frequencyHz,
      gainDb: gainDb ?? this.gainDb,
    );
  }
}

class EqualizerState {
  final bool isEnabled;
  final String activePreset;
  final List<EqualizerBand> bands;
  final double preampGainDb; // -6.0 to +6.0 dB
  final double bassBoost; // 0.0 to 1.0 (sub-bass saturation)
  final double trebleBoost; // 0.0 to 1.0 (air presence)
  final double virtualizer; // 0.0 to 1.0 (spatial expansion)

  const EqualizerState({
    this.isEnabled = true,
    this.activePreset = 'Prismatic Neon',
    required this.bands,
    this.preampGainDb = 0.0,
    this.bassBoost = 0.35,
    this.trebleBoost = 0.25,
    this.virtualizer = 0.30,
  });

  /// 10-Band Professional Studio Standard Frequencies
  static const List<int> defaultFrequencies = [
    32,
    64,
    125,
    250,
    500,
    1000,
    2000,
    4000,
    8000,
    16000,
  ];

  static EqualizerState initial() {
    final state = EqualizerState(
      bands: defaultFrequencies
          .map((f) => EqualizerBand(frequencyHz: f, gainDb: 0.0))
          .toList(),
    );
    return state.applyPresetValues('Prismatic Neon');
  }

  EqualizerState copyWith({
    bool? isEnabled,
    String? activePreset,
    List<EqualizerBand>? bands,
    double? preampGainDb,
    double? bassBoost,
    double? trebleBoost,
    double? virtualizer,
  }) {
    return EqualizerState(
      isEnabled: isEnabled ?? this.isEnabled,
      activePreset: activePreset ?? this.activePreset,
      bands: bands ?? this.bands,
      preampGainDb: preampGainDb ?? this.preampGainDb,
      bassBoost: bassBoost ?? this.bassBoost,
      trebleBoost: trebleBoost ?? this.trebleBoost,
      virtualizer: virtualizer ?? this.virtualizer,
    );
  }

  /// Calculates dynamic effective gain multiplier for audio engine (linear amplitude)
  double computeAcousticGainMultiplier() {
    if (!isEnabled) return 1.0;

    // Linear conversion of preamp gain: 10^(dB / 20)
    final preampMultiplier = pow(10.0, preampGainDb / 20.0).toDouble();

    // Weighted low-end boost contribution (bands 0 to 3)
    double lowEndSum = 0.0;
    for (int i = 0; i < min(4, bands.length); i++) {
      lowEndSum += bands[i].gainDb;
    }
    final avgLowDb = (lowEndSum / 4.0) + (bassBoost * 6.0);
    final bassEnergy = pow(10.0, (avgLowDb * 0.15) / 20.0).toDouble();

    // Treble air contribution (bands 7 to 9)
    double highEndSum = 0.0;
    for (int i = max(0, bands.length - 3); i < bands.length; i++) {
      highEndSum += bands[i].gainDb;
    }
    final avgHighDb = (highEndSum / 3.0) + (trebleBoost * 4.0);
    final trebleEnergy = pow(10.0, (avgHighDb * 0.1) / 20.0).toDouble();

    // Composite acoustic loudness multiplier (clamped to prevent distortion)
    return (preampMultiplier * (0.6 + 0.25 * bassEnergy + 0.15 * trebleEnergy))
        .clamp(0.2, 2.0);
  }

  EqualizerState applyPresetValues(String presetName) {
    List<double> gains;
    double bass = bassBoost;
    double treble = trebleBoost;

    switch (presetName) {
      case 'Prismatic Neon':
        gains = [4.5, 4.0, 2.0, -0.5, 0.5, 1.5, 3.0, 4.5, 5.5, 6.0];
        bass = 0.45;
        treble = 0.40;
        break;
      case 'Sub-Bass Thump':
        gains = [9.0, 7.5, 5.0, 2.5, 0.0, -1.0, -0.5, 0.5, 1.5, 2.0];
        bass = 0.85;
        treble = 0.15;
        break;
      case 'Vocal Clarity':
        gains = [-3.0, -2.0, -0.5, 1.0, 3.5, 5.0, 4.0, 2.5, 1.0, 0.0];
        bass = 0.10;
        treble = 0.35;
        break;
      case 'Electronic & EDM':
        gains = [6.5, 5.5, 3.0, -1.0, -1.5, 1.0, 2.5, 4.0, 5.5, 6.5];
        bass = 0.65;
        treble = 0.50;
        break;
      case 'Rock & Metal':
        gains = [5.5, 4.0, 2.0, -1.5, -2.0, 1.0, 3.5, 5.0, 4.5, 4.0];
        bass = 0.50;
        treble = 0.40;
        break;
      case 'Jazz & Acoustic':
        gains = [2.5, 2.0, 1.5, 1.0, 2.0, 2.5, 2.0, 1.5, 1.0, 0.5];
        bass = 0.25;
        treble = 0.20;
        break;
      case 'Lo-Fi Warmth':
        gains = [4.0, 4.5, 3.0, 1.0, 0.0, -1.5, -3.0, -4.5, -6.5, -9.0];
        bass = 0.55;
        treble = 0.05;
        break;
      case 'Flat':
      default:
        gains = List.filled(defaultFrequencies.length, 0.0);
        bass = 0.0;
        treble = 0.0;
        break;
    }

    final newBands = List<EqualizerBand>.generate(
      defaultFrequencies.length,
      (i) =>
          EqualizerBand(frequencyHz: defaultFrequencies[i], gainDb: gains[i]),
    );

    return copyWith(
      activePreset: presetName,
      bands: newBands,
      bassBoost: bass,
      trebleBoost: treble,
    );
  }
}

final equalizerProvider =
    StateNotifierProvider<EqualizerNotifier, EqualizerState>((ref) {
      return EqualizerNotifier();
    });

class EqualizerNotifier extends StateNotifier<EqualizerState> {
  EqualizerNotifier() : super(EqualizerState.initial());

  void toggleEnabled() {
    state = state.copyWith(isEnabled: !state.isEnabled);
  }

  void setBandGain(int index, double gainDb) {
    if (index < 0 || index >= state.bands.length) return;
    final updatedBands = List<EqualizerBand>.from(state.bands);
    updatedBands[index] = updatedBands[index].copyWith(
      gainDb: gainDb.clamp(-12.0, 12.0),
    );
    state = state.copyWith(bands: updatedBands, activePreset: 'Custom');
  }

  void setPreampGain(double gainDb) {
    state = state.copyWith(preampGainDb: gainDb.clamp(-6.0, 6.0));
  }

  void setBassBoost(double value) {
    state = state.copyWith(bassBoost: value.clamp(0.0, 1.0));
  }

  void setTrebleBoost(double value) {
    state = state.copyWith(trebleBoost: value.clamp(0.0, 1.0));
  }

  void setVirtualizer(double value) {
    state = state.copyWith(virtualizer: value.clamp(0.0, 1.0));
  }

  void applyPreset(String presetName) {
    state = state.applyPresetValues(presetName);
  }

  void resetToFlat() {
    applyPreset('Flat');
  }
}
