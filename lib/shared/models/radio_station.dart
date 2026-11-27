import 'track.dart';

class RadioCountry {
  final String name;
  final String isoCode;
  final int stationCount;

  const RadioCountry({
    required this.name,
    required this.isoCode,
    this.stationCount = 0,
  });
}

class RadioStation {
  final String id;
  final String name;
  final String streamUrl;
  final String country;
  final String countryCode;
  final String city;
  final double frequencyMhz;
  final String frequencyLabel;
  final String codec;
  final int bitrateKbps;
  final String tags;
  final String? faviconUrl;
  final int votes;

  const RadioStation({
    required this.id,
    required this.name,
    required this.streamUrl,
    required this.country,
    required this.countryCode,
    required this.city,
    required this.frequencyMhz,
    required this.frequencyLabel,
    required this.codec,
    required this.bitrateKbps,
    required this.tags,
    this.faviconUrl,
    this.votes = 0,
  });

  Track toTrack() {
    final locationParts = <String>[
      if (city.isNotEmpty) city,
      if (country.isNotEmpty) country,
    ];
    final location = locationParts.isNotEmpty
        ? locationParts.join(', ')
        : 'Global';
    final formatLabel = bitrateKbps > 0
        ? '$frequencyLabel • $codec ${bitrateKbps}k'
        : '$frequencyLabel • $codec';

    return Track(
      id: 'radio-$id',
      title: name,
      artist: '$frequencyLabel • $location',
      album: tags.isNotEmpty ? tags : 'Live Broadcast',
      duration: Duration.zero,
      artworkUrl: faviconUrl,
      streamUrl: streamUrl,
      source: MusicSource.radio,
      audioFormat: formatLabel,
    );
  }

  /// Extracts a real FM frequency from station title/tags if present,
  /// otherwise assigns a repeatable clean slot inside the FM band (87.7 - 107.9 MHz).
  static ({double mhz, String label}) resolveFrequency({
    required String name,
    String tags = '',
    String seedId = '',
  }) {
    final combined = '$name $tags';
    final fmMatch = RegExp(
      r'\b(8[7-9]|9\d|10[0-8])(?:[.,](\d))?\s*(?:mhz|fm)?\b',
      caseSensitive: false,
    ).firstMatch(combined);
    if (fmMatch != null) {
      final whole = int.tryParse(fmMatch.group(1) ?? '');
      final dec = int.tryParse(fmMatch.group(2) ?? '0') ?? 0;
      if (whole != null) {
        final val = (whole + dec / 10.0).clamp(87.5, 108.0);
        return (mhz: val, label: '${val.toStringAsFixed(1)} FM');
      }
    }

    // Odd 200kHz dial channel allocation across 87.9 - 107.9 MHz (101 channels)
    int hash = 0;
    for (final cu in seedId.codeUnits) {
      hash = (hash * 31 + cu) & 0x7fffffff;
    }
    final slot = hash % 101;
    final val = double.parse((87.9 + slot * 0.2).toStringAsFixed(1));
    return (mhz: val, label: '${val.toStringAsFixed(1)} FM');
  }
}
