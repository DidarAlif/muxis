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
  static const String _keyExtraScanRoots = 'muxis_extra_scan_roots';
  static const String _keyActiveSource = 'muxis_active_streaming_source';
  static const String _keyYtCookie = 'muxis_yt_cookie';
  static const String _keyYtSapisid = 'muxis_yt_sapisid';
  static const String _keyYtAuthUser = 'muxis_yt_auth_user';
  static const String _keyYtUserName = 'muxis_yt_user_name';
  static const String _keyYtUserAvatar = 'muxis_yt_user_avatar';
  static const String _keyYtPlaylistsCache = 'muxis_yt_playlists_cache';
  static const String _keySpotifyClientId = 'muxis_spotify_client_id';
  static const String _keySpotifyClientSecret = 'muxis_spotify_client_secret';
  static const String _keySpotifyAccessToken = 'muxis_spotify_access_token';
  static const String _keySpotifyClientToken = 'muxis_spotify_client_token';
  static const String _keySpotifySpDc = 'muxis_spotify_sp_dc';
  static const String _keySpotifyPathfinderHashes =
      'muxis_spotify_pathfinder_hashes';
  static const String _keySpotifyPlaylistsCache =
      'muxis_spotify_playlists_cache';
  static const String _keySpotifyUserName = 'muxis_spotify_user_name';
  static const String _keySpotifyUserAvatar = 'muxis_spotify_user_avatar';
  static const String _keySpotifyProduct = 'muxis_spotify_product';
  static const String _keyGoogleClientId = 'muxis_google_client_id';
  static const String _keyGoogleClientSecret = 'muxis_google_client_secret';
  static const String _keyAutoUpdateEnabled = 'muxis_auto_update_enabled';
  static const String _keySkippedUpdateVersion = 'muxis_skipped_update_version';
  static const String _keyMiniPlayerOnMinimize =
      'muxis_mini_player_on_minimize';
  static const String _keyYtFeaturedCache = 'muxis_yt_featured_cache';
  static const String _keySpFeaturedCache = 'muxis_sp_featured_cache';
  static const String _keyScOAuthToken = 'muxis_sc_oauth_token';
  static const String _keyScClientId = 'muxis_sc_client_id';
  static const String _keyScUserName = 'muxis_sc_user_name';
  static const String _keyScUserAvatar = 'muxis_sc_user_avatar';
  static const String _keyScPlaylistsCache = 'muxis_sc_playlists_cache';
  static const String _keyScFeaturedCache = 'muxis_sc_featured_cache';
  static const String _keyRadioCountryCode = 'muxis_radio_country_code';

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

  Future<void> saveYtAuthUser(String authUser) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyYtAuthUser, authUser);
  }

  Future<String> getYtAuthUser() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getString(_keyYtAuthUser);
    return (val != null && val.isNotEmpty) ? val : '0';
  }

  Future<void> saveYtPlaylistsCache(String jsonStr) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyYtPlaylistsCache, jsonStr);
  }

  Future<String?> getYtPlaylistsCache() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyYtPlaylistsCache);
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

  Future<void> saveSpotifyClientToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySpotifyClientToken, token);
  }

  Future<String?> getSpotifyClientToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySpotifyClientToken);
  }

  Future<void> saveSpotifyPathfinderHashes(String jsonStr) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySpotifyPathfinderHashes, jsonStr);
  }

  Future<String?> getSpotifyPathfinderHashes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySpotifyPathfinderHashes);
  }

  Future<void> saveSpotifyPlaylistsCache(String jsonStr) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySpotifyPlaylistsCache, jsonStr);
  }

  Future<String?> getSpotifyPlaylistsCache() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySpotifyPlaylistsCache);
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

  Future<void> saveSpotifyUserProfile(
    String name,
    String? avatarUrl,
    String product,
  ) async {
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
    await prefs.remove(_keyYtAuthUser);
    await prefs.remove(_keyYtUserName);
    await prefs.remove(_keyYtUserAvatar);
    await prefs.remove(_keyYtPlaylistsCache);
    await prefs.remove(_keyYtFeaturedCache);
    await prefs.remove(_keySpotifyClientId);
    await prefs.remove(_keySpotifyClientSecret);
    await prefs.remove(_keySpotifyAccessToken);
    await prefs.remove(_keySpotifyClientToken);
    await prefs.remove(_keySpotifySpDc);
    await prefs.remove(_keySpotifyPathfinderHashes);
    await prefs.remove(_keySpotifyPlaylistsCache);
    await prefs.remove(_keySpFeaturedCache);
    await prefs.remove(_keySpotifyUserName);
    await prefs.remove(_keySpotifyUserAvatar);
    await prefs.remove(_keySpotifyProduct);
    await prefs.remove(_keyGoogleClientId);
    await prefs.remove(_keyGoogleClientSecret);
    await prefs.remove(_keyScOAuthToken);
    await prefs.remove(_keyScUserName);
    await prefs.remove(_keyScUserAvatar);
    await prefs.remove(_keyScPlaylistsCache);
    await prefs.remove(_keyScFeaturedCache);
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
    await addExtraScanRoot(path);
  }

  Future<String?> getLastScannedDir() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLastScannedDir);
  }

  Future<void> addExtraScanRoot(String dirPath) async {
    final clean = dirPath.trim();
    if (clean.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_keyExtraScanRoots) ?? const [];
    if (existing.contains(clean)) return;
    await prefs.setStringList(_keyExtraScanRoots, [...existing, clean]);
  }

  Future<List<String>> getExtraScanRoots() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyExtraScanRoots) ?? const [];
  }

  Future<void> saveAutoUpdateEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoUpdateEnabled, enabled);
  }

  Future<bool> getAutoUpdateEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAutoUpdateEnabled) ?? true;
  }

  Future<void> saveSkippedUpdateVersion(String? version) async {
    final prefs = await SharedPreferences.getInstance();
    if (version == null || version.isEmpty) {
      await prefs.remove(_keySkippedUpdateVersion);
    } else {
      await prefs.setString(_keySkippedUpdateVersion, version);
    }
  }

  Future<String?> getSkippedUpdateVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySkippedUpdateVersion);
  }

  Future<void> saveMiniPlayerOnMinimize(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyMiniPlayerOnMinimize, enabled);
  }

  Future<bool> getMiniPlayerOnMinimize() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyMiniPlayerOnMinimize) ?? true;
  }

  Future<void> saveFeaturedCache(String sourceKey, String jsonStr) async {
    final prefs = await SharedPreferences.getInstance();
    final key = sourceKey == 'spotify'
        ? _keySpFeaturedCache
        : (sourceKey == 'soundcloud'
              ? _keyScFeaturedCache
              : _keyYtFeaturedCache);
    if (jsonStr.isEmpty) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, jsonStr);
    }
  }

  Future<String?> getFeaturedCache(String sourceKey) async {
    final prefs = await SharedPreferences.getInstance();
    final key = sourceKey == 'spotify'
        ? _keySpFeaturedCache
        : (sourceKey == 'soundcloud'
              ? _keyScFeaturedCache
              : _keyYtFeaturedCache);
    return prefs.getString(key);
  }

  Future<void> saveScOAuthToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    if (token.isEmpty) {
      await prefs.remove(_keyScOAuthToken);
    } else {
      await prefs.setString(_keyScOAuthToken, token);
    }
  }

  Future<String?> getScOAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyScOAuthToken);
  }

  Future<void> saveScClientId(String clientId) async {
    final prefs = await SharedPreferences.getInstance();
    if (clientId.isEmpty) {
      await prefs.remove(_keyScClientId);
    } else {
      await prefs.setString(_keyScClientId, clientId);
    }
  }

  Future<String?> getScClientId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyScClientId);
  }

  Future<void> saveScUserProfile(String name, String? avatarUrl) async {
    final prefs = await SharedPreferences.getInstance();
    if (name.isEmpty) {
      await prefs.remove(_keyScUserName);
    } else {
      await prefs.setString(_keyScUserName, name);
    }
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      await prefs.setString(_keyScUserAvatar, avatarUrl);
    } else {
      await prefs.remove(_keyScUserAvatar);
    }
  }

  Future<String?> getScUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyScUserName);
  }

  Future<String?> getScUserAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyScUserAvatar);
  }

  Future<void> saveScPlaylistsCache(String jsonStr) async {
    final prefs = await SharedPreferences.getInstance();
    if (jsonStr.isEmpty) {
      await prefs.remove(_keyScPlaylistsCache);
    } else {
      await prefs.setString(_keyScPlaylistsCache, jsonStr);
    }
  }

  Future<String?> getScPlaylistsCache() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyScPlaylistsCache);
  }

  Future<void> saveRadioCountryCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyRadioCountryCode, code);
  }

  Future<String?> getRadioCountryCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyRadioCountryCode);
  }
}
