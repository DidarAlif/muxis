import 'dart:io';

import 'package:dio/dio.dart';

import '../shared/models/radio_station.dart';

class RadioCityPlace {
  final String id;
  final String title;
  final String country;
  final int stationCount;
  final String url;

  const RadioCityPlace({
    required this.id,
    required this.title,
    required this.country,
    required this.stationCount,
    required this.url,
  });
}

class RadioProvider {
  static const List<String> _mirrors = [
    'https://de1.api.radio-browser.info',
    'https://fr1.api.radio-browser.info',
    'https://at1.api.radio-browser.info',
  ];

  static const Map<String, String> _headers = {
    'User-Agent': 'MUXIS/1.2.12 (Cross-Platform Audio Player)',
    'Accept': 'application/json',
  };

  static List<RadioCountry>? _cachedCountries;
  static DateTime? _countriesFetchedAt;
  static List<RadioCityPlace>? _cachedPlaces;

  final Dio _dio;
  int _mirrorIdx = 0;

  RadioProvider({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 7),
              receiveTimeout: const Duration(seconds: 10),
              headers: _headers,
            ),
          );

  Future<dynamic> _getRadioBrowser(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    for (int attempt = 0; attempt < _mirrors.length; attempt++) {
      final idx = (_mirrorIdx + attempt) % _mirrors.length;
      final base = _mirrors[idx];
      try {
        final res = await _dio.get<dynamic>(
          '$base$path',
          queryParameters: query,
          options: Options(headers: _headers),
        );
        if (res.statusCode == 200 && res.data != null) {
          _mirrorIdx = idx;
          return res.data;
        }
      } catch (_) {}
    }
    return null;
  }

  /// Auto-detects the listener's country using live IP geolocation with locale fallback.
  Future<({String countryCode, String countryName, String? city})>
  detectUserCountry() async {
    try {
      final res = await _dio.get<dynamic>('https://ipwho.is/');
      if (res.data is Map && res.data['success'] == true) {
        final code = (res.data['country_code']?.toString() ?? '')
            .trim()
            .toUpperCase();
        final country = (res.data['country']?.toString() ?? '').trim();
        final city = (res.data['city']?.toString() ?? '').trim();
        if (code.length == 2) {
          return (
            countryCode: code,
            countryName: country.isNotEmpty ? country : code,
            city: city.isNotEmpty ? city : null,
          );
        }
      }
    } catch (_) {}

    try {
      final res = await _dio.get<dynamic>('https://api.country.is/');
      if (res.data is Map) {
        final code = (res.data['country']?.toString() ?? '')
            .trim()
            .toUpperCase();
        if (code.length == 2) {
          final countries = await fetchCountries();
          final match = countries.where((c) => c.isoCode == code).firstOrNull;
          return (
            countryCode: code,
            countryName: match?.name ?? code,
            city: null,
          );
        }
      }
    } catch (_) {}

    final localeParts = Platform.localeName.split(RegExp(r'[_-]'));
    final fallbackCode = localeParts.length > 1 && localeParts.last.length == 2
        ? localeParts.last.toUpperCase()
        : 'US';
    return (
      countryCode: fallbackCode,
      countryName: fallbackCode == 'US' ? 'United States' : fallbackCode,
      city: null,
    );
  }

  Future<List<RadioCountry>> fetchCountries() async {
    if (_cachedCountries != null &&
        _countriesFetchedAt != null &&
        DateTime.now().difference(_countriesFetchedAt!).inMinutes < 30) {
      return _cachedCountries!;
    }

    final data = await _getRadioBrowser(
      '/json/countries',
      query: const {
        'order': 'stationcount',
        'reverse': 'true',
        'hidebroken': 'true',
      },
    );

    if (data is! List) return _cachedCountries ?? const [];

    final seen = <String>{};
    final out = <RadioCountry>[];
    for (final raw in data) {
      if (raw is! Map) continue;
      final code = (raw['iso_3166_1']?.toString() ?? '').trim().toUpperCase();
      final name = (raw['name']?.toString() ?? '').trim();
      final count = (raw['stationcount'] as num?)?.toInt() ?? 0;
      if (code.length != 2 || name.isEmpty || count <= 0) continue;
      if (!seen.add(code)) continue;
      out.add(RadioCountry(name: name, isoCode: code, stationCount: count));
    }

    _cachedCountries = out;
    _countriesFetchedAt = DateTime.now();
    return out;
  }

  Future<List<RadioStation>> fetchStationsByCountry(
    String countryCode, {
    int limit = 80,
  }) async {
    final code = countryCode.trim().toUpperCase();
    if (code.isEmpty) return fetchTopGlobalStations(limit: limit);

    final data = await _getRadioBrowser(
      '/json/stations/bycountrycodeexact/$code',
      query: {
        'limit': '$limit',
        'order': 'votes',
        'reverse': 'true',
        'hidebroken': 'true',
      },
    );
    return _parseStationsList(data);
  }

  Future<List<RadioStation>> fetchTopGlobalStations({int limit = 60}) async {
    final data = await _getRadioBrowser(
      '/json/stations/topvote/$limit',
      query: const {'hidebroken': 'true'},
    );
    return _parseStationsList(data);
  }

  Future<List<RadioStation>> searchStations({
    String? query,
    String? countryCode,
    String? city,
    String? tag,
    int limit = 60,
  }) async {
    final qp = <String, dynamic>{
      'limit': '$limit',
      'order': 'votes',
      'reverse': 'true',
      'hidebroken': 'true',
    };
    if (countryCode != null &&
        countryCode.trim().isNotEmpty &&
        countryCode.trim().toUpperCase() != 'ALL') {
      qp['countrycode'] = countryCode.trim().toUpperCase();
    }
    if (query != null && query.trim().isNotEmpty) {
      qp['name'] = query.trim();
    }
    if (city != null && city.trim().isNotEmpty) {
      qp['state'] = city.trim();
    }
    if (tag != null && tag.trim().isNotEmpty) {
      qp['tag'] = tag.trim().toLowerCase();
    }

    var results = _parseStationsList(
      await _getRadioBrowser('/json/stations/search', query: qp),
    );

    // If city filter in `state` field returned empty, broaden search via `name`
    if (results.isEmpty && city != null && city.trim().isNotEmpty) {
      final fallbackQp = Map<String, dynamic>.from(qp)..remove('state');
      fallbackQp['name'] = city.trim();
      results = _parseStationsList(
        await _getRadioBrowser('/json/stations/search', query: fallbackQp),
      );
    }

    return results;
  }

  Future<List<RadioCityPlace>> fetchRadioGardenCities({
    String? countryName,
  }) async {
    if (_cachedPlaces == null) {
      try {
        final res = await _dio.get<dynamic>(
          'https://radio.garden/api/ara/content/places',
          options: Options(headers: _headers),
        );
        final list = (res.data?['data']?['list'] as List<dynamic>?) ?? const [];
        final parsed = <RadioCityPlace>[];
        for (final raw in list) {
          if (raw is! Map) continue;
          final id = raw['id']?.toString() ?? '';
          final title = (raw['title']?.toString() ?? '').trim();
          final country = (raw['country']?.toString() ?? '').trim();
          final size = (raw['size'] as num?)?.toInt() ?? 0;
          final url = (raw['url']?.toString() ?? '').trim();
          if (id.isEmpty || title.isEmpty || size <= 0) continue;
          parsed.add(
            RadioCityPlace(
              id: id,
              title: title,
              country: country,
              stationCount: size,
              url: url,
            ),
          );
        }
        parsed.sort((a, b) => b.stationCount.compareTo(a.stationCount));
        _cachedPlaces = parsed;
      } catch (_) {
        _cachedPlaces ??= const [];
      }
    }

    final all = _cachedPlaces ?? const [];
    if (countryName == null ||
        countryName.trim().isEmpty ||
        countryName == 'Global') {
      return all.take(24).toList();
    }

    final needle = countryName.trim().toLowerCase();
    final matched = all
        .where(
          (p) =>
              p.country.toLowerCase() == needle ||
              p.country.toLowerCase().contains(needle) ||
              needle.contains(p.country.toLowerCase()),
        )
        .toList();
    return matched.isNotEmpty
        ? matched.take(18).toList()
        : all.take(16).toList();
  }

  Future<void> registerClick(String stationId) async {
    if (stationId.isEmpty) return;
    try {
      await _getRadioBrowser('/json/url/$stationId');
    } catch (_) {}
  }

  List<RadioStation> _parseStationsList(dynamic data) {
    if (data is! List) return const [];
    final out = <RadioStation>[];
    final seenUrl = <String>{};

    for (final raw in data) {
      if (raw is! Map) continue;
      final id = (raw['stationuuid']?.toString() ?? '').trim();
      final name = (raw['name']?.toString() ?? '').trim();
      final streamUrl =
          ((raw['url_resolved']?.toString() ?? '').trim().isNotEmpty
                  ? raw['url_resolved'].toString()
                  : (raw['url']?.toString() ?? ''))
              .trim();
      if (id.isEmpty ||
          name.isEmpty ||
          (!streamUrl.startsWith('http://') &&
              !streamUrl.startsWith('https://'))) {
        continue;
      }
      if (!seenUrl.add(streamUrl)) continue;

      final country = (raw['country']?.toString() ?? '').trim();
      final countryCode = (raw['countrycode']?.toString() ?? '')
          .trim()
          .toUpperCase();
      final city = (raw['state']?.toString() ?? '').trim();
      final codec = (raw['codec']?.toString() ?? 'STREAM').trim().toUpperCase();
      final bitrate = (raw['bitrate'] as num?)?.toInt() ?? 0;
      final tags = (raw['tags']?.toString() ?? '').trim();
      final faviconRaw = (raw['favicon']?.toString() ?? '').trim();
      final favicon = faviconRaw.startsWith('http') ? faviconRaw : null;
      final votes = (raw['votes'] as num?)?.toInt() ?? 0;

      final freq = RadioStation.resolveFrequency(
        name: name,
        tags: tags,
        seedId: id,
      );

      out.add(
        RadioStation(
          id: id,
          name: name,
          streamUrl: streamUrl,
          country: country,
          countryCode: countryCode,
          city: city,
          frequencyMhz: freq.mhz,
          frequencyLabel: freq.label,
          codec: codec.isEmpty ? 'MP3' : codec,
          bitrateKbps: bitrate,
          tags: tags,
          faviconUrl: favicon,
          votes: votes,
        ),
      );
    }

    // Prefer direct MP3/AAC streams before HLS playlists when votes are close
    out.sort((a, b) {
      final aDirect = a.streamUrl.toLowerCase().contains('.m3u8') ? 1 : 0;
      final bDirect = b.streamUrl.toLowerCase().contains('.m3u8') ? 1 : 0;
      if (aDirect != bDirect) return aDirect.compareTo(bDirect);
      return b.votes.compareTo(a.votes);
    });
    return out;
  }
}
