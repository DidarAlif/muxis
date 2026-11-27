import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme/muxis_colors.dart';
import '../../app/theme/muxis_gradients.dart';
import '../../app/theme/muxis_typography.dart';
import '../../core/audio/audio_playback_service.dart';
import '../../core/storage/preferences_service.dart';
import '../../providers/radio_provider.dart';
import '../../shared/models/radio_station.dart';
import '../../shared/widgets/muxis_button.dart';
import '../../shared/widgets/muxis_card.dart';
import '../../shared/widgets/muxis_glass_card.dart';
import '../../shared/widgets/muxis_liquid_surface.dart';
import '../../shared/widgets/muxis_scroll_view.dart';

class RadioScreen extends ConsumerStatefulWidget {
  const RadioScreen({super.key});

  @override
  ConsumerState<RadioScreen> createState() => _RadioScreenState();
}

class _RadioScreenState extends ConsumerState<RadioScreen> {
  final RadioProvider _radio = RadioProvider();
  final TextEditingController _searchCtrl = TextEditingController();

  List<RadioCountry> _countries = [];
  List<RadioStation> _stations = [];
  List<RadioCityPlace> _cities = [];

  String _selectedCountryCode = 'US';
  String _selectedCountryName = 'United States';
  String? _detectedCity;
  String? _selectedCityFilter;
  String _selectedGenreTag = '';
  double _dialMhz = 98.1;

  bool _loading = true;
  bool _loadingCities = false;
  Timer? _searchDebounce;

  static const List<({String label, String tag})> _genreChips = [
    (label: 'All Stations', tag: ''),
    (label: 'Pop', tag: 'pop'),
    (label: 'Rock', tag: 'rock'),
    (label: 'Electronic', tag: 'electronic'),
    (label: 'Jazz', tag: 'jazz'),
    (label: 'Chill / Lo-Fi', tag: 'chill'),
    (label: 'Classical', tag: 'classical'),
    (label: 'News / Talk', tag: 'news'),
  ];

  @override
  void initState() {
    super.initState();
    _initRadio();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _initRadio({bool forceDetectLocation = false}) async {
    if (mounted) setState(() => _loading = true);
    try {
      final prefs = ref.read(preferencesServiceProvider);
      final savedCode = forceDetectLocation
          ? null
          : await prefs.getRadioCountryCode();

      final detected = await _radio.detectUserCountry();
      final countries = await _radio.fetchCountries();

      String activeCode = savedCode?.isNotEmpty == true
          ? savedCode!
          : detected.countryCode;
      String activeName = detected.countryName;
      if (activeCode == 'ALL') {
        activeName = 'Global Worldwide';
      } else {
        final found = countries
            .where((c) => c.isoCode == activeCode)
            .firstOrNull;
        if (found != null) activeName = found.name;
      }

      final stations = activeCode == 'ALL'
          ? await _radio.fetchTopGlobalStations(limit: 75)
          : await _radio.fetchStationsByCountry(activeCode, limit: 80);

      if (mounted) {
        setState(() {
          _countries = countries;
          _selectedCountryCode = activeCode;
          _selectedCountryName = activeName;
          _detectedCity = detected.city;
          _stations = stations;
          if (stations.isNotEmpty) {
            _dialMhz = stations.first.frequencyMhz;
          }
          _loading = false;
        });
      }

      unawaited(_loadCitiesForCountry(activeName));
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadCitiesForCountry(String countryName) async {
    if (mounted) setState(() => _loadingCities = true);
    final places = await _radio.fetchRadioGardenCities(
      countryName: countryName == 'Global Worldwide' ? 'Global' : countryName,
    );
    if (mounted) {
      setState(() {
        _cities = places;
        _loadingCities = false;
      });
    }
  }

  Future<void> _selectCountry(String code, String name) async {
    await ref.read(preferencesServiceProvider).saveRadioCountryCode(code);
    setState(() {
      _selectedCountryCode = code;
      _selectedCountryName = name;
      _selectedCityFilter = null;
      _selectedGenreTag = '';
      _searchCtrl.clear();
      _loading = true;
    });

    final stations = code == 'ALL'
        ? await _radio.fetchTopGlobalStations(limit: 75)
        : await _radio.fetchStationsByCountry(code, limit: 80);

    if (!mounted) return;
    setState(() {
      _stations = stations;
      if (stations.isNotEmpty) {
        _dialMhz = stations.first.frequencyMhz;
      }
      _loading = false;
    });
    unawaited(_loadCitiesForCountry(name));
  }

  Future<void> _runFilteredFetch({String? cityOverride}) async {
    setState(() => _loading = true);
    final q = _searchCtrl.text.trim();
    final city = cityOverride ?? _selectedCityFilter;
    final hasFilter =
        q.isNotEmpty ||
        _selectedGenreTag.isNotEmpty ||
        (city != null && city.isNotEmpty);

    List<RadioStation> result;
    if (!hasFilter) {
      result = _selectedCountryCode == 'ALL'
          ? await _radio.fetchTopGlobalStations(limit: 75)
          : await _radio.fetchStationsByCountry(
              _selectedCountryCode,
              limit: 80,
            );
    } else {
      result = await _radio.searchStations(
        query: q,
        countryCode: _selectedCountryCode,
        city: city,
        tag: _selectedGenreTag,
        limit: 75,
      );
    }

    if (!mounted) return;
    setState(() {
      _stations = result;
      if (result.isNotEmpty) {
        _dialMhz = result.first.frequencyMhz;
      }
      _loading = false;
    });
  }

  void _onSearchChanged(String val) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _runFilteredFetch();
    });
  }

  RadioStation? _nearestStationToDial() {
    if (_stations.isEmpty) return null;
    RadioStation best = _stations.first;
    double bestDiff = (best.frequencyMhz - _dialMhz).abs();
    for (final s in _stations) {
      final d = (s.frequencyMhz - _dialMhz).abs();
      if (d < bestDiff) {
        bestDiff = d;
        best = s;
      }
    }
    return best;
  }

  Future<void> _tuneToStation(RadioStation station) async {
    setState(() => _dialMhz = station.frequencyMhz);
    unawaited(_radio.registerClick(station.id));
    final queue = _stations.map((s) => s.toTrack()).toList();
    await ref
        .read(playbackServiceProvider.notifier)
        .playTrack(station.toTrack(), newQueue: queue);
  }

  void _scanNextStation(int direction) {
    if (_stations.isEmpty) return;
    final sorted = List<RadioStation>.from(_stations)
      ..sort((a, b) => a.frequencyMhz.compareTo(b.frequencyMhz));
    RadioStation target;
    if (direction >= 0) {
      target =
          sorted.where((s) => s.frequencyMhz > _dialMhz + 0.05).firstOrNull ??
          sorted.first;
    } else {
      target =
          sorted.where((s) => s.frequencyMhz < _dialMhz - 0.05).lastOrNull ??
          sorted.last;
    }
    _tuneToStation(target);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    final playingTrackId = ref.watch(
      playbackServiceProvider.select((s) => s.currentTrack?.id),
    );
    final isPlaying = ref.watch(
      playbackServiceProvider.select((s) => s.isPlaying),
    );
    final tunedStation = _nearestStationToDial();

    return MuxisScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- HEADER & COUNTRY SELECTOR ---
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.radio_rounded,
                        size: 26,
                        color: MuxisColors.electricCyan,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Global Radio & FM Tuner',
                        style: MuxisTypography.pageTitle(isDark: isDark),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _detectedCity != null
                        ? 'Auto-detected region: $_selectedCountryName ($_detectedCity) • Live world frequencies'
                        : 'Region: $_selectedCountryName • Tune live FM & digital streams worldwide',
                    style: TextStyle(
                      fontSize: 13,
                      color: MuxisColors.textSecondary(isDark),
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  MuxisButton(
                    label: 'Detect My Country',
                    icon: const Icon(Icons.my_location_rounded, size: 15),
                    variant: MuxisButtonVariant.liquidGlass,
                    height: 34,
                    onPressed: () => _initRadio(forceDetectLocation: true),
                  ),
                  MuxisButton(
                    label: 'Global Top',
                    icon: const Icon(Icons.public_rounded, size: 15),
                    variant: _selectedCountryCode == 'ALL'
                        ? MuxisButtonVariant.primary
                        : MuxisButtonVariant.secondary,
                    height: 34,
                    onPressed: () => _selectCountry('ALL', 'Global Worldwide'),
                  ),
                  _buildCountryDropdown(isDark),
                ],
              ),
            ],
          ),
          const SizedBox(height: 22),

          // --- INTERACTIVE FM FREQUENCY DIAL ---
          MuxisGlassCard(
            padding: EdgeInsets.all(isMobile ? 16 : 22),
            borderRadius: 20,
            enableBackdropBlur: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            gradient: MuxisGradients.prismaticPrimary,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            '${_dialMhz.toStringAsFixed(1)} MHz',
                            style: const TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tunedStation?.name ?? 'Scanning Band...',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: MuxisColors.textPrimary(isDark),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                tunedStation != null
                                    ? '${tunedStation.frequencyLabel} • ${tunedStation.country} • ${tunedStation.codec} ${tunedStation.bitrateKbps > 0 ? '${tunedStation.bitrateKbps}kbps' : ''}'
                                    : 'Slide dial across 87.5 – 108.0 MHz',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: MuxisColors.textSecondary(isDark),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        IconButton(
                          tooltip: 'Previous Station Frequency',
                          onPressed: () => _scanNextStation(-1),
                          icon: Icon(
                            Icons.fast_rewind_rounded,
                            color: MuxisColors.textPrimary(isDark),
                          ),
                        ),
                        MuxisButton(
                          label:
                              tunedStation != null &&
                                  playingTrackId ==
                                      'radio-${tunedStation.id}' &&
                                  isPlaying
                              ? 'Pause On-Air'
                              : 'Tune In Now',
                          icon: Icon(
                            tunedStation != null &&
                                    playingTrackId ==
                                        'radio-${tunedStation.id}' &&
                                    isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: 18,
                            color: isDark ? Colors.black : Colors.white,
                          ),
                          variant: MuxisButtonVariant.primary,
                          height: 36,
                          onPressed: tunedStation == null
                              ? null
                              : () {
                                  if (playingTrackId ==
                                          'radio-${tunedStation.id}' &&
                                      isPlaying) {
                                    ref
                                        .read(playbackServiceProvider.notifier)
                                        .togglePlay();
                                  } else {
                                    _tuneToStation(tunedStation);
                                  }
                                },
                        ),
                        IconButton(
                          tooltip: 'Next Station Frequency',
                          onPressed: () => _scanNextStation(1),
                          icon: Icon(
                            Icons.fast_forward_rounded,
                            color: MuxisColors.textPrimary(isDark),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 28,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _FmDialScalePainter(
                      activeMhz: _dialMhz,
                      stationFrequencies: _stations
                          .map((s) => s.frequencyMhz)
                          .toList(),
                      isDark: isDark,
                    ),
                  ),
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: MuxisColors.electricCyan,
                    inactiveTrackColor: MuxisColors.border(isDark)
                        .withOpacity(0.6),
                    thumbColor: MuxisColors.electricCyan,
                    overlayColor: MuxisColors.electricCyan.withOpacity(0.2),
                  ),
                  child: Slider(
                    min: 87.5,
                    max: 108.0,
                    divisions: 205,
                    value: _dialMhz.clamp(87.5, 108.0),
                    onChanged: (v) {
                      setState(
                        () => _dialMhz = double.parse(v.toStringAsFixed(1)),
                      );
                    },
                    onChangeEnd: (_) {
                      final nearest = _nearestStationToDial();
                      if (nearest != null) {
                        _tuneToStation(nearest);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // --- STATION SEARCH & GENRE CHIPS ---
          TextField(
            controller: _searchCtrl,
            onChanged: _onSearchChanged,
            onSubmitted: (_) => _runFilteredFetch(),
            style: TextStyle(
              color: MuxisColors.textPrimary(isDark),
              fontSize: 13,
            ),
            decoration: InputDecoration(
              hintText: 'Search station name, frequency (e.g. 89.6 or 101.1), city, or genre...',
              hintStyle: TextStyle(
                color: MuxisColors.textMuted(isDark),
                fontSize: 13,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: MuxisColors.electricCyan,
                size: 20,
              ),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        _runFilteredFetch();
                      },
                    )
                  : null,
              filled: true,
              fillColor: isDark
                  ? MuxisColors.elevatedSurface.withOpacity(0.75)
                  : Colors.white.withOpacity(0.84),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: MuxisColors.border(isDark)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: MuxisColors.border(isDark)),
              ),
            ),
          ),
          const SizedBox(height: 12),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _genreChips.map((chip) {
              final selected = _selectedGenreTag == chip.tag;
              return MuxisLiquidSurface(
                onTap: () {
                  setState(() => _selectedGenreTag = chip.tag);
                  _runFilteredFetch();
                },
                enableGlass: false,
                blurSigma: 0,
                borderRadius: 18,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                colorOverride: selected
                    ? MuxisColors.electricCyan.withOpacity(0.2)
                    : (isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.white.withOpacity(0.76)),
                borderOverride: Border.all(
                  color: selected
                      ? MuxisColors.electricCyan
                      : MuxisColors.border(isDark),
                ),
                child: Text(
                  chip.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? MuxisColors.electricCyan
                        : MuxisColors.textSecondary(isDark),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 22),

          // --- RADIO GARDEN CITIES IN REGION ---
          if (_cities.isNotEmpty || _loadingCities) ...[
            Wrap(
              spacing: 12,
              runSpacing: 6,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Live Radio Cities (Radio Garden Directory)',
                  style: MuxisTypography.sectionHeading(isDark: isDark),
                ),
                TextButton.icon(
                  onPressed: () {
                    launchUrl(
                      Uri.parse('https://radio.garden/listen/'),
                      mode: LaunchMode.externalApplication,
                    );
                  },
                  icon: const Icon(Icons.open_in_new_rounded, size: 14),
                  label: const Text('Open Radio Garden Globe'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_loadingCities)
              const LinearProgressIndicator(minHeight: 2)
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (_selectedCityFilter != null)
                    MuxisLiquidSurface(
                      onTap: () {
                        setState(() => _selectedCityFilter = null);
                        _runFilteredFetch(cityOverride: '');
                      },
                      enableGlass: false,
                      blurSigma: 0,
                      borderRadius: 16,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 6,
                      ),
                      colorOverride: MuxisColors.coralPulse.withOpacity(0.18),
                      borderOverride: Border.all(color: MuxisColors.coralPulse),
                      child: Text(
                        'Clear City: $_selectedCityFilter ×',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: MuxisColors.coralPulse,
                        ),
                      ),
                    ),
                  ..._cities.map((c) {
                    final active = _selectedCityFilter == c.title;
                    return MuxisLiquidSurface(
                      onTap: () {
                        setState(() => _selectedCityFilter = c.title);
                        _runFilteredFetch(cityOverride: c.title);
                      },
                      enableGlass: false,
                      blurSigma: 0,
                      borderRadius: 16,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 6,
                      ),
                      colorOverride: active
                          ? MuxisColors.neonGreen.withOpacity(0.18)
                          : (isDark
                                ? Colors.white.withOpacity(0.05)
                                : Colors.white.withOpacity(0.75)),
                      borderOverride: Border.all(
                        color: active
                            ? MuxisColors.neonGreen
                            : MuxisColors.border(isDark),
                      ),
                      child: Text(
                        '${c.title} (${c.stationCount})',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: active
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: active
                              ? MuxisColors.neonGreen
                              : MuxisColors.textPrimary(isDark),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            const SizedBox(height: 24),
          ],

          // --- LIVE STATIONS ---
          Wrap(
            spacing: 12,
            runSpacing: 4,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${_selectedCountryName == 'Global Worldwide' ? 'Global' : _selectedCountryName} Live Stations (${_stations.length})',
                style: MuxisTypography.sectionHeading(isDark: isDark),
              ),
              Text(
                'Direct Live Stream Audio',
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 11,
                  color: MuxisColors.accent(isDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_stations.isEmpty)
            MuxisEmptyState(
              icon: Icons.radio_rounded,
              title: 'No Matching Radio Stations Found',
              message: 'Try clearing your city/genre filter or switch to another country above.',
            )
          else ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final spacing = constraints.maxWidth < 520 ? 12.0 : 16.0;
                final cols = ((constraints.maxWidth + spacing) / 184)
                    .floor()
                    .clamp(2, 6);
                final cardWidth =
                    ((constraints.maxWidth - spacing * (cols - 1)) / cols)
                        .clamp(132.0, 210.0);
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: _stations.take(8).map((st) {
                    return MuxisCard(
                      width: cardWidth,
                      title: st.name,
                      subtitle:
                          '${st.frequencyLabel} • ${st.city.isNotEmpty ? st.city : st.country}',
                      artworkUrl: st.faviconUrl,
                      onTap: () => _tuneToStation(st),
                      onPlayTap: () => _tuneToStation(st),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 26),
            Text(
              'All Tunable Frequencies',
              style: MuxisTypography.sectionHeading(isDark: isDark),
            ),
            const SizedBox(height: 12),
            ..._stations.map((st) {
              final active = playingTrackId == 'radio-${st.id}' && isPlaying;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: MuxisLiquidSurface(
                  onTap: () => _tuneToStation(st),
                  enableGlass: false,
                  blurSigma: 0,
                  borderRadius: 14,
                  accentColor: MuxisColors.electricCyan,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  colorOverride: active
                      ? MuxisColors.electricCyan.withOpacity(0.14)
                      : (isDark
                            ? Colors.white.withOpacity(0.03)
                            : Colors.white.withOpacity(0.7)),
                  borderOverride: Border.all(
                    color: active
                        ? MuxisColors.electricCyan
                        : MuxisColors.border(isDark).withOpacity(0.6),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 78,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: MuxisColors.electricCyan.withOpacity(
                            active ? 0.25 : 0.12,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          st.frequencyLabel,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: MuxisColors.electricCyan,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              st.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                                color: MuxisColors.textPrimary(isDark),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              [
                                if (st.city.isNotEmpty) st.city,
                                if (st.country.isNotEmpty) st.country,
                                if (st.tags.isNotEmpty) st.tags,
                              ].join(' • '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: MuxisColors.textSecondary(isDark),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: isDark
                              ? Colors.white.withOpacity(0.07)
                              : Colors.black.withOpacity(0.05),
                        ),
                        child: Text(
                          st.bitrateKbps > 0
                              ? '${st.codec} ${st.bitrateKbps}k'
                              : st.codec,
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 10,
                            color: MuxisColors.textMuted(isDark),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        active
                            ? Icons.graphic_eq_rounded
                            : Icons.play_circle_filled_rounded,
                        color: active
                            ? MuxisColors.neonGreen
                            : MuxisColors.electricCyan,
                        size: 24,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildCountryDropdown(bool isDark) {
    final hasCurrent = _countries.any((c) => c.isoCode == _selectedCountryCode);
    final items = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: 'ALL', child: Text('Global Worldwide')),
      if (!hasCurrent && _selectedCountryCode != 'ALL')
        DropdownMenuItem(
          value: _selectedCountryCode,
          child: Text(_selectedCountryName),
        ),
      ..._countries
          .take(120)
          .map(
            (c) => DropdownMenuItem(
              value: c.isoCode,
              child: Text('${c.name} (${c.stationCount})'),
            ),
          ),
    ];

    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark
            ? MuxisColors.elevatedSurface.withOpacity(0.85)
            : Colors.white.withOpacity(0.88),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MuxisColors.border(isDark)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCountryCode,
          dropdownColor: MuxisColors.surface(isDark),
          style: TextStyle(
            fontSize: 12.5,
            color: MuxisColors.textPrimary(isDark),
          ),
          items: items,
          onChanged: (code) {
            if (code == null) return;
            if (code == 'ALL') {
              _selectCountry('ALL', 'Global Worldwide');
              return;
            }
            final matched = _countries
                .where((c) => c.isoCode == code)
                .firstOrNull;
            _selectCountry(code, matched?.name ?? code);
          },
        ),
      ),
    );
  }
}

class _FmDialScalePainter extends CustomPainter {
  final double activeMhz;
  final List<double> stationFrequencies;
  final bool isDark;

  const _FmDialScalePainter({
    required this.activeMhz,
    required this.stationFrequencies,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final tickPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withOpacity(0.22)
      ..strokeWidth = 1.2;
    final stationPaint = Paint()
      ..color = MuxisColors.neonGreen.withOpacity(0.75)
      ..strokeWidth = 2.0;
    final needlePaint = Paint()
      ..color = MuxisColors.electricCyan
      ..strokeWidth = 2.6;

    const minMhz = 87.5;
    const maxMhz = 108.0;
    const span = maxMhz - minMhz;

    for (double f = 88.0; f <= 108.0; f += 0.5) {
      final t = ((f - minMhz) / span).clamp(0.0, 1.0);
      final x = t * size.width;
      final isMajor = (f * 10).round() % 20 == 0;
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x, size.height - (isMajor ? 14 : 7)),
        tickPaint,
      );
    }

    for (final sf in stationFrequencies) {
      final t = ((sf - minMhz) / span).clamp(0.0, 1.0);
      final x = t * size.width;
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x, size.height - 18),
        stationPaint,
      );
    }

    final needleT = ((activeMhz - minMhz) / span).clamp(0.0, 1.0);
    final nx = math.min(size.width, math.max(0.0, needleT * size.width));
    canvas.drawLine(Offset(nx, 0), Offset(nx, size.height), needlePaint);
  }

  @override
  bool shouldRepaint(covariant _FmDialScalePainter oldDelegate) {
    return oldDelegate.activeMhz != activeMhz ||
        oldDelegate.stationFrequencies.length != stationFrequencies.length ||
        oldDelegate.isDark != isDark;
  }
}
