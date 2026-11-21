import 'package:flutter_riverpod/flutter_riverpod.dart';

class EqualizerBand {
  final int frequencyHz;
  final double gainDb; // -12.0 to +12.0

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
  final double bassBoost; // 0.0 to 1.0
  final double virtualizer; // 0.0 to 1.0

  const EqualizerState({
    this.isEnabled = true,
    this.activePreset = 'Prismatic Aura',
    required this.bands,
    this.bassBoost = 0.25,
    this.virtualizer = 0.35,
  });

  static const List<int> defaultFrequencies = [60, 230, 910, 3600, 14000];

  static EqualizerState initial() {
    return EqualizerState(
      bands: defaultFrequencies
          .map((f) => EqualizerBand(frequencyHz: f, gainDb: 0.0))
          .toList(),
    );
  }

  EqualizerState copyWith({
    bool? isEnabled,
    String? activePreset,
    List<EqualizerBand>? bands,
    double? bassBoost,
    double? virtualizer,
  }) {
    return EqualizerState(
      isEnabled: isEnabled ?? this.isEnabled,
      activePreset: activePreset ?? this.activePreset,
      bands: bands ?? this.bands,
      bassBoost: bassBoost ?? this.bassBoost,
      virtualizer: virtualizer ?? this.virtualizer,
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

  void setBassBoost(double value) {
    state = state.copyWith(bassBoost: value.clamp(0.0, 1.0));
  }

  void setVirtualizer(double value) {
    state = state.copyWith(virtualizer: value.clamp(0.0, 1.0));
  }

  void applyPreset(String presetName) {
    List<double> gains;
    switch (presetName) {
      case 'Prismatic Aura':
        gains = [4.5, 2.0, -1.0, 3.0, 5.0];
        break;
      case 'Bass Boost':
        gains = [7.0, 4.0, 1.0, 0.0, -1.0];
        break;
      case 'Vocal Clarity':
        gains = [-2.0, 1.0, 5.0, 3.5, 1.0];
        break;
      case 'Electronic':
        gains = [5.0, 3.0, -0.5, 2.5, 4.0];
        break;
      case 'Flat':
      default:
        gains = [0.0, 0.0, 0.0, 0.0, 0.0];
        break;
    }

    final newBands = List<EqualizerBand>.generate(
      EqualizerState.defaultFrequencies.length,
      (i) => EqualizerBand(
        frequencyHz: EqualizerState.defaultFrequencies[i],
        gainDb: gains[i],
      ),
    );

    state = state.copyWith(activePreset: presetName, bands: newBands);
  }
}
