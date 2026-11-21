import 'package:flutter_riverpod/flutter_riverpod.dart';

class AudioStudioState {
  // Vocal Reduction (Karaoke Center Extraction)
  final bool isKaraokeEnabled;
  final double vocalAttenuation; // 0.0 to 1.0 (1.0 = full vocal removal)
  final double centerWidth; // 0.0 to 1.0

  // Pitch & Speed (Bungee-inspired DSP)
  final double playbackSpeed; // 0.5x to 2.0x
  final double pitchShiftSemitones; // -12 to +12 semitones
  final bool isSlowedAndReverb;

  // Spatial Reverb
  final bool isReverbEnabled;
  final double reverbDecay; // 0.1 to 10.0 seconds
  final double reverbWetDryMix; // 0.0 to 1.0

  const AudioStudioState({
    this.isKaraokeEnabled = false,
    this.vocalAttenuation = 0.85,
    this.centerWidth = 0.5,
    this.playbackSpeed = 1.0,
    this.pitchShiftSemitones = 0.0,
    this.isSlowedAndReverb = false,
    this.isReverbEnabled = false,
    this.reverbDecay = 2.5,
    this.reverbWetDryMix = 0.35,
  });

  AudioStudioState copyWith({
    bool? isKaraokeEnabled,
    double? vocalAttenuation,
    double? centerWidth,
    double? playbackSpeed,
    double? pitchShiftSemitones,
    bool? isSlowedAndReverb,
    bool? isReverbEnabled,
    double? reverbDecay,
    double? reverbWetDryMix,
  }) {
    return AudioStudioState(
      isKaraokeEnabled: isKaraokeEnabled ?? this.isKaraokeEnabled,
      vocalAttenuation: vocalAttenuation ?? this.vocalAttenuation,
      centerWidth: centerWidth ?? this.centerWidth,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      pitchShiftSemitones: pitchShiftSemitones ?? this.pitchShiftSemitones,
      isSlowedAndReverb: isSlowedAndReverb ?? this.isSlowedAndReverb,
      isReverbEnabled: isReverbEnabled ?? this.isReverbEnabled,
      reverbDecay: reverbDecay ?? this.reverbDecay,
      reverbWetDryMix: reverbWetDryMix ?? this.reverbWetDryMix,
    );
  }
}

final audioStudioProvider =
    StateNotifierProvider<AudioStudioNotifier, AudioStudioState>((ref) {
      return AudioStudioNotifier();
    });

class AudioStudioNotifier extends StateNotifier<AudioStudioState> {
  AudioStudioNotifier() : super(const AudioStudioState());

  void toggleKaraoke() {
    state = state.copyWith(isKaraokeEnabled: !state.isKaraokeEnabled);
  }

  void setVocalAttenuation(double val) {
    state = state.copyWith(vocalAttenuation: val.clamp(0.0, 1.0));
  }

  void setPlaybackSpeed(double speed) {
    state = state.copyWith(playbackSpeed: speed.clamp(0.5, 2.0));
  }

  void setPitchShift(double semitones) {
    state = state.copyWith(pitchShiftSemitones: semitones.clamp(-12.0, 12.0));
  }

  void toggleSlowedAndReverb() {
    final next = !state.isSlowedAndReverb;
    if (next) {
      state = state.copyWith(
        isSlowedAndReverb: true,
        playbackSpeed: 0.85,
        pitchShiftSemitones: -2.0,
        isReverbEnabled: true,
        reverbDecay: 3.8,
        reverbWetDryMix: 0.45,
      );
    } else {
      state = state.copyWith(
        isSlowedAndReverb: false,
        playbackSpeed: 1.0,
        pitchShiftSemitones: 0.0,
        isReverbEnabled: false,
      );
    }
  }

  void toggleReverb() {
    state = state.copyWith(isReverbEnabled: !state.isReverbEnabled);
  }

  void setReverbDecay(double decay) {
    state = state.copyWith(reverbDecay: decay.clamp(0.5, 10.0));
  }

  void setReverbMix(double mix) {
    state = state.copyWith(reverbWetDryMix: mix.clamp(0.0, 1.0));
  }

  void resetAll() {
    state = const AudioStudioState();
  }
}
