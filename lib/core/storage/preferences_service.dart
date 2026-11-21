import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final preferencesServiceProvider = Provider<PreferencesService>((ref) {
  return PreferencesService();
});

class PreferencesService {
  static const String _keyVolume = 'muxis_volume';
  static const String _keyShuffle = 'muxis_shuffle';
  static const String _keyRepeatMode = 'muxis_repeat_mode';
  static const String _keyAudioQuality = 'muxis_audio_quality';
  static const String _keyLastScannedDir = 'muxis_last_scanned_dir';

  Future<void> saveVolume(double volume) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyVolume, volume);
  }

  Future<double> getVolume() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyVolume) ?? 1.0;
  }

  Future<void> saveShuffle(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShuffle, enabled);
  }

  Future<bool> getShuffle() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyShuffle) ?? false;
  }

  Future<void> saveRepeatMode(int modeIndex) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyRepeatMode, modeIndex);
  }

  Future<int> getRepeatMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyRepeatMode) ?? 0;
  }

  Future<void> saveAudioQuality(String quality) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAudioQuality, quality);
  }

  Future<String> getAudioQuality() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAudioQuality) ?? 'FLAC 24-bit Lossless';
  }

  Future<void> saveLastScannedDir(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastScannedDir, path);
  }

  Future<String?> getLastScannedDir() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLastScannedDir);
  }
}
