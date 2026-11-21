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
  static const String _keyYtCookie = 'muxis_yt_cookie';
  static const String _keyYtSapisid = 'muxis_yt_sapisid';
  static const String _keySpotifyClientId = 'muxis_spotify_client_id';
  static const String _keySpotifyClientSecret = 'muxis_spotify_client_secret';

  Future<void> saveYtCookie(String cookie) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyYtCookie, cookie);
  }

  Future<String?> getYtCookie() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyYtCookie);
  }

  Future<void> saveYtSapisid(String sapisid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyYtSapisid, sapisid);
  }

  Future<String?> getYtSapisid() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyYtSapisid);
  }

  Future<void> saveSpotifyClientId(String clientId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySpotifyClientId, clientId);
  }

  Future<String?> getSpotifyClientId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySpotifyClientId);
  }

  Future<void> saveSpotifyClientSecret(String secret) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySpotifyClientSecret, secret);
  }

  Future<String?> getSpotifyClientSecret() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySpotifyClientSecret);
  }

  Future<void> clearStreamingCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyYtCookie);
    await prefs.remove(_keyYtSapisid);
    await prefs.remove(_keySpotifyClientId);
    await prefs.remove(_keySpotifyClientSecret);
  }

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
