/// Pure-Dart theme preset & accent taste catalog for MUXIS.
/// Keeps color tokens as ARGB ints so standalone Dart unit tests can verify
/// every theme without Flutter SDK dependencies.
class MuxisThemeDefinition {
  final String id;
  final String name;
  final String subtitle;
  final bool isDark;
  final int background;
  final int secondaryBackground;
  final int surface;
  final int glassSurface;
  final int glassRim;
  final int border;
  final int textPrimary;
  final int textSecondary;
  final int textMuted;
  final int accent;
  final int secondary;
  final int tertiary;
  final int highlight;
  final int orb1;
  final int orb2;
  final int orb3;

  const MuxisThemeDefinition({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.isDark,
    required this.background,
    required this.secondaryBackground,
    required this.surface,
    required this.glassSurface,
    required this.glassRim,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.secondary,
    required this.tertiary,
    required this.highlight,
    required this.orb1,
    required this.orb2,
    required this.orb3,
  });
}

class MuxisAccentTaste {
  final String id;
  final String name;
  final int darkColor;
  final int lightColor;
  final int secondaryDark;
  final int secondaryLight;

  const MuxisAccentTaste({
    required this.id,
    required this.name,
    required this.darkColor,
    required this.lightColor,
    required this.secondaryDark,
    required this.secondaryLight,
  });
}

class ThemeCatalog {
  ThemeCatalog._();

  static const String defaultDarkId = 'obsidian_aurora';
  static const String defaultLightId = 'luminous_aurora';
  static const String defaultAccentTasteId = 'preset_default';

  static const List<MuxisThemeDefinition> presets = [
    // --- DARK & OLED THEMES ---
    MuxisThemeDefinition(
      id: 'obsidian_aurora',
      name: 'Prismatic Obsidian',
      subtitle: 'Neon Green, Cyber Teal & Violet Depth',
      isDark: true,
      background: 0xFF060910,
      secondaryBackground: 0xFF0B111C,
      surface: 0xFF121A29,
      glassSurface: 0xB8111928,
      glassRim: 0x26FFFFFF,
      border: 0xFF233046,
      textPrimary: 0xFFFFFFFF,
      textSecondary: 0xFFD2DFEE,
      textMuted: 0xFF9FB2C9,
      accent: 0xFF00FF88,
      secondary: 0xFF00E5FF,
      tertiary: 0xFF9D6BFF,
      highlight: 0xFFFF4D8D,
      orb1: 0xFF071318,
      orb2: 0xFF060910,
      orb3: 0xFF0E0B1A,
    ),
    MuxisThemeDefinition(
      id: 'pure_amoled',
      name: 'Pure AMOLED',
      subtitle: 'Pitch Black #000000 for OLED Screens',
      isDark: true,
      background: 0xFF000000,
      secondaryBackground: 0xFF06080D,
      surface: 0xFF0C1018,
      glassSurface: 0xCC070A10,
      glassRim: 0x22FFFFFF,
      border: 0xFF1D2432,
      textPrimary: 0xFFFFFFFF,
      textSecondary: 0xFFDCE6F2,
      textMuted: 0xFF9AA8BC,
      accent: 0xFF00FFA3,
      secondary: 0xFF38BDF8,
      tertiary: 0xFFA78BFA,
      highlight: 0xFFF43F5E,
      orb1: 0xFF030B08,
      orb2: 0xFF000000,
      orb3: 0xFF070512,
    ),
    MuxisThemeDefinition(
      id: 'midnight_sapphire',
      name: 'Midnight Sapphire',
      subtitle: 'Deep Ocean Navy & Electric Azure Glow',
      isDark: true,
      background: 0xFF050B16,
      secondaryBackground: 0xFF091426,
      surface: 0xFF102039,
      glassSurface: 0xBA0B172C,
      glassRim: 0x2B93C5FD,
      border: 0xFF1E3A5F,
      textPrimary: 0xFFF8FAFC,
      textSecondary: 0xFFDBEAFE,
      textMuted: 0xFF93C5FD,
      accent: 0xFF38BDF8,
      secondary: 0xFF22D3EE,
      tertiary: 0xFF818CF8,
      highlight: 0xFF60A5FA,
      orb1: 0xFF071A2F,
      orb2: 0xFF050B16,
      orb3: 0xFF0F1030,
    ),
    MuxisThemeDefinition(
      id: 'botanical_jade',
      name: 'Botanical Leaf',
      subtitle: 'Deep Forest Canopy, Jade & Fresh Mint',
      isDark: true,
      background: 0xFF040F0B,
      secondaryBackground: 0xFF081A14,
      surface: 0xFF0F261E,
      glassSurface: 0xBC0A1E17,
      glassRim: 0x2B6EE7B7,
      border: 0xFF1B3D31,
      textPrimary: 0xFFF0FDF4,
      textSecondary: 0xFFD1FAE5,
      textMuted: 0xFF86EFAC,
      accent: 0xFF10B981,
      secondary: 0xFF2DD4BF,
      tertiary: 0xFF6EE7B7,
      highlight: 0xFFA3E635,
      orb1: 0xFF072219,
      orb2: 0xFF040F0B,
      orb3: 0xFF0B1C14,
    ),
    MuxisThemeDefinition(
      id: 'crimson_velvet',
      name: 'Crimson Velvet',
      subtitle: 'Velvet Plum Charcoal, Ruby & Rose Neon',
      isDark: true,
      background: 0xFF0F060A,
      secondaryBackground: 0xFF180A11,
      surface: 0xFF24101A,
      glassSurface: 0xBC1B0B14,
      glassRim: 0x2BFDA4AF,
      border: 0xFF421C2F,
      textPrimary: 0xFFFFF1F2,
      textSecondary: 0xFFFCE7F3,
      textMuted: 0xFFF9A8D4,
      accent: 0xFFFF4D8D,
      secondary: 0xFFFB7185,
      tertiary: 0xFFC084FC,
      highlight: 0xFFF43F5E,
      orb1: 0xFF230A16,
      orb2: 0xFF0F060A,
      orb3: 0xFF1D0B24,
    ),
    MuxisThemeDefinition(
      id: 'amber_vinyl',
      name: 'Amber Vinyl',
      subtitle: 'Warm Analog Studio Gold & Copper',
      isDark: true,
      background: 0xFF0D0A06,
      secondaryBackground: 0xFF16110B,
      surface: 0xFF211A11,
      glassSurface: 0xBC1A140C,
      glassRim: 0x2BFCD34D,
      border: 0xFF3A2D1C,
      textPrimary: 0xFFFFFBEB,
      textSecondary: 0xFFFEF3C7,
      textMuted: 0xFFFCD34D,
      accent: 0xFFFBBF24,
      secondary: 0xFFFB923C,
      tertiary: 0xFF34D399,
      highlight: 0xFFF59E0B,
      orb1: 0xFF211709,
      orb2: 0xFF0D0A06,
      orb3: 0xFF1C1009,
    ),
    MuxisThemeDefinition(
      id: 'ultraviolet_synth',
      name: 'Ultraviolet Synth',
      subtitle: 'Cosmic Night Plum, Orchid & Cyber Cyan',
      isDark: true,
      background: 0xFF080514,
      secondaryBackground: 0xFF100A24,
      surface: 0xFF181136,
      glassSurface: 0xBC130C2B,
      glassRim: 0x2BD8B4FE,
      border: 0xFF2D2159,
      textPrimary: 0xFFFAF5FF,
      textSecondary: 0xFFE9D5FF,
      textMuted: 0xFFC084FC,
      accent: 0xFFC084FC,
      secondary: 0xFF22D3EE,
      tertiary: 0xFFF472B6,
      highlight: 0xFFE879F9,
      orb1: 0xFF190C33,
      orb2: 0xFF080514,
      orb3: 0xFF230A26,
    ),

    // --- LIGHT GLASS THEMES ---
    MuxisThemeDefinition(
      id: 'luminous_aurora',
      name: 'Luminous Aurora',
      subtitle: 'Botanical Porcelain Glass & Crisp Emerald',
      isDark: false,
      background: 0xFFEEF7F6,
      secondaryBackground: 0xFFE6F3F2,
      surface: 0xFFFFFFFF,
      glassSurface: 0xC2FFFFFF,
      glassRim: 0xE8FFFFFF,
      border: 0xFFD0E3E8,
      textPrimary: 0xFF0B1320,
      textSecondary: 0xFF1E2D40,
      textMuted: 0xFF475B73,
      accent: 0xFF00A859,
      secondary: 0xFF0284C7,
      tertiary: 0xFF7C3AED,
      highlight: 0xFFDB2777,
      orb1: 0xFFDDF9F1,
      orb2: 0xFFEAF4FF,
      orb3: 0xFFF3ECFF,
    ),
    MuxisThemeDefinition(
      id: 'sakura_pearl',
      name: 'Sakura Pearl',
      subtitle: 'Rose Quartz Mist, Blossom Berry & Orchid',
      isDark: false,
      background: 0xFFFDF2F6,
      secondaryBackground: 0xFFFCE7F0,
      surface: 0xFFFFFFFF,
      glassSurface: 0xCAFFFFFF,
      glassRim: 0xF0FFFFFF,
      border: 0xFFF3D1DF,
      textPrimary: 0xFF1F0A14,
      textSecondary: 0xFF45192E,
      textMuted: 0xFF7A445F,
      accent: 0xFFE11D48,
      secondary: 0xFF9333EA,
      tertiary: 0xFFEC4899,
      highlight: 0xFFF43F5E,
      orb1: 0xFFFFE4EC,
      orb2: 0xFFFDF2F8,
      orb3: 0xFFF3E8FF,
    ),
    MuxisThemeDefinition(
      id: 'nordic_paper',
      name: 'Nordic Studio',
      subtitle: 'Warm Daylight Paper & Cobalt Studio Ink',
      isDark: false,
      background: 0xFFF3F6FA,
      secondaryBackground: 0xFFE7EDF6,
      surface: 0xFFFFFFFF,
      glassSurface: 0xCAFFFFFF,
      glassRim: 0xF0FFFFFF,
      border: 0xFFD1DCEB,
      textPrimary: 0xFF0F172A,
      textSecondary: 0xFF1E293B,
      textMuted: 0xFF475569,
      accent: 0xFF2563EB,
      secondary: 0xFF0D9488,
      tertiary: 0xFF4F46E5,
      highlight: 0xFF0284C7,
      orb1: 0xFFE0ECFF,
      orb2: 0xFFF3F6FA,
      orb3: 0xFFE0F2FE,
    ),
  ];

  static const List<MuxisAccentTaste> accentTastes = [
    MuxisAccentTaste(
      id: defaultAccentTasteId,
      name: 'Preset',
      darkColor: 0xFF00FF88,
      lightColor: 0xFF00A859,
      secondaryDark: 0xFF00E5FF,
      secondaryLight: 0xFF0284C7,
    ),
    MuxisAccentTaste(
      id: 'neon_mint',
      name: 'Neon Mint',
      darkColor: 0xFF00FF88,
      lightColor: 0xFF00A859,
      secondaryDark: 0xFF00E5FF,
      secondaryLight: 0xFF0891B2,
    ),
    MuxisAccentTaste(
      id: 'leaf_emerald',
      name: 'Leaf Jade',
      darkColor: 0xFF10B981,
      lightColor: 0xFF059669,
      secondaryDark: 0xFF34D399,
      secondaryLight: 0xFF0D9488,
    ),
    MuxisAccentTaste(
      id: 'cyber_cyan',
      name: 'Cyber Cyan',
      darkColor: 0xFF00E5FF,
      lightColor: 0xFF0284C7,
      secondaryDark: 0xFF38BDF8,
      secondaryLight: 0xFF2563EB,
    ),
    MuxisAccentTaste(
      id: 'royal_violet',
      name: 'Violet',
      darkColor: 0xFFA855F7,
      lightColor: 0xFF7C3AED,
      secondaryDark: 0xFFEC4899,
      secondaryLight: 0xFF9333EA,
    ),
    MuxisAccentTaste(
      id: 'sakura_rose',
      name: 'Sakura Rose',
      darkColor: 0xFFFF4D8D,
      lightColor: 0xFFE11D48,
      secondaryDark: 0xFFFB7185,
      secondaryLight: 0xFFDB2777,
    ),
    MuxisAccentTaste(
      id: 'studio_gold',
      name: 'Warm Gold',
      darkColor: 0xFFFBBF24,
      lightColor: 0xFFD97706,
      secondaryDark: 0xFFFB923C,
      secondaryLight: 0xFFEA580C,
    ),
    MuxisAccentTaste(
      id: 'electric_cobalt',
      name: 'Cobalt Blue',
      darkColor: 0xFF60A5FA,
      lightColor: 0xFF2563EB,
      secondaryDark: 0xFF818CF8,
      secondaryLight: 0xFF4F46E5,
    ),
  ];

  static List<MuxisThemeDefinition> get darkPresets =>
      presets.where((p) => p.isDark).toList(growable: false);

  static List<MuxisThemeDefinition> get lightPresets =>
      presets.where((p) => !p.isDark).toList(growable: false);

  static MuxisThemeDefinition? findById(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final p in presets) {
      if (p.id == id) return p;
    }
    return null;
  }

  static MuxisThemeDefinition findPreset(String? id, {required bool isDark}) {
    final exact = findById(id);
    if (exact != null && exact.isDark == isDark) return exact;
    return presets.firstWhere(
      (p) => p.id == (isDark ? defaultDarkId : defaultLightId),
    );
  }

  static MuxisAccentTaste findAccentTaste(String? id) {
    for (final t in accentTastes) {
      if (t.id == id) return t;
    }
    return accentTastes.first;
  }

  static int resolveAccentHex(MuxisThemeDefinition preset, String? tasteId) {
    if (tasteId == null || tasteId.isEmpty || tasteId == defaultAccentTasteId) {
      return preset.accent;
    }
    final taste = findAccentTaste(tasteId);
    return preset.isDark ? taste.darkColor : taste.lightColor;
  }

  static int resolveSecondaryHex(MuxisThemeDefinition preset, String? tasteId) {
    if (tasteId == null || tasteId.isEmpty || tasteId == defaultAccentTasteId) {
      return preset.secondary;
    }
    final taste = findAccentTaste(tasteId);
    return preset.isDark ? taste.secondaryDark : taste.secondaryLight;
  }
}
