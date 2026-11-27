import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/utils/theme_catalog.dart';
import 'muxis_colors.dart';

class MuxisThemeState {
  final ThemeMode mode;
  final String darkPresetId;
  final String lightPresetId;
  final String accentTasteId;

  const MuxisThemeState({
    this.mode = ThemeMode.dark,
    this.darkPresetId = ThemeCatalog.defaultDarkId,
    this.lightPresetId = ThemeCatalog.defaultLightId,
    this.accentTasteId = ThemeCatalog.defaultAccentTasteId,
  });

  String activePresetIdForBrightness(Brightness brightness) =>
      brightness == Brightness.dark ? darkPresetId : lightPresetId;

  MuxisThemeState copyWith({
    ThemeMode? mode,
    String? darkPresetId,
    String? lightPresetId,
    String? accentTasteId,
  }) {
    return MuxisThemeState(
      mode: mode ?? this.mode,
      darkPresetId: darkPresetId ?? this.darkPresetId,
      lightPresetId: lightPresetId ?? this.lightPresetId,
      accentTasteId: accentTasteId ?? this.accentTasteId,
    );
  }
}

final muxisThemeProvider =
    StateNotifierProvider<MuxisThemeController, MuxisThemeState>((ref) {
      return MuxisThemeController();
    });

/// Backwards-compatible provider mirroring [ThemeMode] while syncing full palette selection.
final themeControllerProvider =
    StateNotifierProvider<ThemeController, ThemeMode>((ref) {
      final controller = ThemeController(ref);
      ref.listen<MuxisThemeState>(muxisThemeProvider, (_, next) {
        controller.syncMode(next.mode);
      });
      return controller;
    });

class MuxisThemeController extends StateNotifier<MuxisThemeState> {
  static const String _prefModeKey = 'muxis_theme_mode';
  static const String _prefDarkPresetKey = 'muxis_dark_preset';
  static const String _prefLightPresetKey = 'muxis_light_preset';
  static const String _prefAccentTasteKey = 'muxis_accent_taste';

  MuxisThemeController() : super(const MuxisThemeState()) {
    _applyColors(state);
    _loadTheme();
  }

  void _applyColors(MuxisThemeState s) {
    MuxisColors.applyActivePresets(
      darkPresetId: s.darkPresetId,
      lightPresetId: s.lightPresetId,
      accentTasteId: s.accentTasteId,
    );
  }

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeIndex = prefs.getInt(_prefModeKey);
      final mode =
          (modeIndex != null &&
              modeIndex >= 0 &&
              modeIndex < ThemeMode.values.length)
          ? ThemeMode.values[modeIndex]
          : ThemeMode.dark;

      final darkId = ThemeCatalog.findPreset(
        prefs.getString(_prefDarkPresetKey),
        isDark: true,
      ).id;
      final lightId = ThemeCatalog.findPreset(
        prefs.getString(_prefLightPresetKey),
        isDark: false,
      ).id;
      final tasteId = ThemeCatalog.findAccentTaste(
        prefs.getString(_prefAccentTasteKey),
      ).id;

      final loaded = MuxisThemeState(
        mode: mode,
        darkPresetId: darkId,
        lightPresetId: lightId,
        accentTasteId: tasteId,
      );
      _applyColors(loaded);
      if (mounted) state = loaded;
    } catch (_) {}
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final next = state.copyWith(mode: mode);
    _applyColors(next);
    state = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefModeKey, mode.index);
    } catch (_) {}
  }

  void toggleTheme() {
    if (state.mode == ThemeMode.dark) {
      setThemeMode(ThemeMode.light);
    } else {
      setThemeMode(ThemeMode.dark);
    }
  }

  Future<void> selectPreset(MuxisThemeDefinition preset) async {
    final next = state.copyWith(
      mode: preset.isDark ? ThemeMode.dark : ThemeMode.light,
      darkPresetId: preset.isDark ? preset.id : state.darkPresetId,
      lightPresetId: preset.isDark ? state.lightPresetId : preset.id,
    );
    _applyColors(next);
    state = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefModeKey, next.mode.index);
      if (preset.isDark) {
        await prefs.setString(_prefDarkPresetKey, preset.id);
      } else {
        await prefs.setString(_prefLightPresetKey, preset.id);
      }
    } catch (_) {}
  }

  Future<void> setAccentTaste(String tasteId) async {
    final validId = ThemeCatalog.findAccentTaste(tasteId).id;
    final next = state.copyWith(accentTasteId: validId);
    _applyColors(next);
    state = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefAccentTasteKey, validId);
    } catch (_) {}
  }
}

class ThemeController extends StateNotifier<ThemeMode> {
  final Ref _ref;

  ThemeController(this._ref) : super(_ref.read(muxisThemeProvider).mode);

  void syncMode(ThemeMode mode) {
    if (state != mode) state = mode;
  }

  Future<void> setTheme(ThemeMode mode) =>
      _ref.read(muxisThemeProvider.notifier).setThemeMode(mode);

  void toggleTheme() => _ref.read(muxisThemeProvider.notifier).toggleTheme();
}
