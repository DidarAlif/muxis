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
  static const String _keyActiveSource = 'muxis_active_streaming_source';
  static const String _keyYtCookie = 'muxis_yt_cookie';
  static const String _keyYtSapisid = 'muxis_yt_sapisid';
  static const String _keyYtUserName = 'muxis_yt_user_name';
  static const String _keyYtUserAvatar = 'muxis_yt_user_avatar';
  static const String _keySpotifyClientId = 'muxis_spotify_client_id';
  static const String _keySpotifyClientSecret = 'muxis_spotify_client_secret';
  static const String _keySpotifyAccessToken = 'muxis_spotify_access_token';
  static const String _keySpotifySpDc = 'muxis_spotify_sp_dc';
  static const String _keySpotifyUserName = 'muxis_spotify_user_name';
  static const String _keySpotifyUserAvatar = 'muxis_spotify_user_avatar';
  static const String _keySpotifyProduct = 'muxis_spotify_product';
  static const String _keyGoogleClientId = 'muxis_google_client_id';
  static const String _keyGoogleClientSecret = 'muxis_google_client_secret';

  Future<void> saveActiveSource(String source) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyActiveSource, source);
  }

  Future<String> getActiveSource() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyActiveSource) ?? 'youtube';
  }

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

  Future<void> saveYtUserProfile(String name, String? avatarUrl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyYtUserName, name);
    if (avatarUrl != null) {
      await prefs.setString(_keyYtUserAvatar, avatarUrl);
    } else {
      await prefs.remove(_keyYtUserAvatar);
    }
  }

  Future<String?> getYtUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyYtUserName);
  }

  Future<String?> getYtUserAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyYtUserAvatar);
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

  Future<void> saveSpotifyAccessToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySpotifyAccessToken, token);
  }

  Future<String?> getSpotifyAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySpotifyAccessToken);
  }

  Future<void> saveSpotifySpDc(String spDc) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySpotifySpDc, spDc);
  }

  Future<String?> getSpotifySpDc() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySpotifySpDc);
  }

  Future<void> saveGoogleClientId(String clientId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyGoogleClientId, clientId);
  }

  Future<String?> getGoogleClientId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyGoogleClientId);
  }

  Future<void> saveGoogleClientSecret(String secret) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyGoogleClientSecret, secret);
  }

  Future<String?> getGoogleClientSecret() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyGoogleClientSecret);
  }

  Future<void> saveSpotifyUserProfile(String name, String? avatarUrl, String product) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySpotifyUserName, name);
    await prefs.setString(_keySpotifyProduct, product);
    if (avatarUrl != null) {
      await prefs.setString(_keySpotifyUserAvatar, avatarUrl);
    } else {
      await prefs.remove(_keySpotifyUserAvatar);
    }
  }

  Future<String?> getSpotifyUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySpotifyUserName);
  }

  Future<String?> getSpotifyUserAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySpotifyUserAvatar);
  }

  Future<String?> getSpotifyProduct() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySpotifyProduct);
  }

  Future<void> clearStreamingCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyYtCookie);
    await prefs.remove(_keyYtSapisid);
    await prefs.remove(_keyYtUserName);
    await prefs.remove(_keyYtUserAvatar);
    await prefs.remove(_keySpotifyClientId);
    await prefs.remove(_keySpotifyClientSecret);
    await prefs.remove(_keySpotifyAccessToken);
    await prefs.remove(_keySpotifySpDc);
    await prefs.remove(_keySpotifyUserName);
    await prefs.remove(_keySpotifyUserAvatar);
    await prefs.remove(_keySpotifyProduct);
    await prefs.remove(_keyGoogleClientId);
    await prefs.remove(_keyGoogleClientSecret);
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
