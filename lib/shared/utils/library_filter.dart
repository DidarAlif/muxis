import '../models/track.dart';

enum LibrarySortOption {
  recentlyAdded('Recently Added'),
  titleAsc('Title (A–Z)'),
  titleDesc('Title (Z–A)'),
  artistAsc('Artist (A–Z)'),
  durationDesc('Duration (Longest)'),
  durationAsc('Duration (Shortest)'),
  source('Source Platform');

  final String label;
  const LibrarySortOption(this.label);
}

enum LibraryKeywordPreset {
  all('All'),
  favorites('Favorites'),
  local('Local Files'),
  youtube('YouTube'),
  spotify('Spotify'),
  soundcloud('SoundCloud'),
  lossless('Lossless / FLAC'),
  remixLive('Remix & Live'),
  chillAcoustic('Chill / Acoustic'),
  shortTracks('Quick (< 3m)'),
  extended('Extended (5m+)');

  final String label;
  const LibraryKeywordPreset(this.label);
}

List<Track> applyLibrarySortAndFilter({
  required List<Track> tracks,
  String searchQuery = '',
  LibraryKeywordPreset preset = LibraryKeywordPreset.all,
  LibrarySortOption sortOption = LibrarySortOption.recentlyAdded,
}) {
  final q = searchQuery.trim().toLowerCase();

  List<Track> filtered;
  if (q.isEmpty && preset == LibraryKeywordPreset.all) {
    if (sortOption == LibrarySortOption.recentlyAdded) {
      return tracks.reversed.toList(growable: false);
    }
    filtered = List<Track>.from(tracks);
  } else {
    filtered = tracks.where((t) {
      if (q.isNotEmpty) {
        final matchesText =
            t.title.toLowerCase().contains(q) ||
            t.artist.toLowerCase().contains(q) ||
            t.album.toLowerCase().contains(q) ||
            (t.audioFormat?.toLowerCase().contains(q) ?? false);
        if (!matchesText) return false;
      }

      switch (preset) {
        case LibraryKeywordPreset.all:
          return true;
        case LibraryKeywordPreset.favorites:
          return t.isFavorite;
        case LibraryKeywordPreset.local:
          return t.source == MusicSource.local;
        case LibraryKeywordPreset.youtube:
          return t.source == MusicSource.youtube;
        case LibraryKeywordPreset.spotify:
          return t.source == MusicSource.spotify;
        case LibraryKeywordPreset.soundcloud:
          return t.source == MusicSource.soundcloud;
        case LibraryKeywordPreset.lossless:
          final fmt = (t.audioFormat ?? '').toLowerCase();
          final path = (t.localFilePath ?? '').toLowerCase();
          return fmt.contains('flac') ||
              fmt.contains('lossless') ||
              fmt.contains('wav') ||
              fmt.contains('alac') ||
              path.endsWith('.flac') ||
              path.endsWith('.wav') ||
              path.endsWith('.aiff');
        case LibraryKeywordPreset.remixLive:
          final hay = '${t.title} ${t.album}'.toLowerCase();
          return hay.contains('remix') ||
              hay.contains('live') ||
              hay.contains('mix') ||
              hay.contains('edit') ||
              hay.contains('version');
        case LibraryKeywordPreset.chillAcoustic:
          final hay = '${t.title} ${t.artist} ${t.album}'.toLowerCase();
          return hay.contains('chill') ||
              hay.contains('lo-fi') ||
              hay.contains('lofi') ||
              hay.contains('acoustic') ||
              hay.contains('ambient') ||
              hay.contains('instrumental');
        case LibraryKeywordPreset.shortTracks:
          return t.duration.inSeconds > 0 && t.duration.inSeconds < 180;
        case LibraryKeywordPreset.extended:
          return t.duration.inSeconds >= 300;
      }
    }).toList();
  }

  switch (sortOption) {
    case LibrarySortOption.recentlyAdded:
      // Database preserves insertion order; newest appended items show first cleanly
      return filtered.reversed.toList(growable: false);
    case LibrarySortOption.titleAsc:
    case LibrarySortOption.titleDesc:
      final keyed = filtered
          .map((t) => (track: t, key: t.title.toLowerCase()))
          .toList(growable: false);
      keyed.sort(
        (a, b) => sortOption == LibrarySortOption.titleAsc
            ? a.key.compareTo(b.key)
            : b.key.compareTo(a.key),
      );
      return keyed.map((e) => e.track).toList(growable: false);
    case LibrarySortOption.artistAsc:
      final keyed = filtered
          .map(
            (t) => (
              track: t,
              artistKey: t.artist.toLowerCase(),
              titleKey: t.title.toLowerCase(),
            ),
          )
          .toList(growable: false);
      keyed.sort((a, b) {
        final cmp = a.artistKey.compareTo(b.artistKey);
        return cmp != 0 ? cmp : a.titleKey.compareTo(b.titleKey);
      });
      return keyed.map((e) => e.track).toList(growable: false);
    case LibrarySortOption.durationDesc:
      filtered.sort(
        (a, b) =>
            b.duration.inMilliseconds.compareTo(a.duration.inMilliseconds),
      );
      return filtered;
    case LibrarySortOption.durationAsc:
      filtered.sort(
        (a, b) =>
            a.duration.inMilliseconds.compareTo(b.duration.inMilliseconds),
      );
      return filtered;
    case LibrarySortOption.source:
      final keyed = filtered
          .map(
            (t) => (
              track: t,
              sourceIdx: t.source.index,
              titleKey: t.title.toLowerCase(),
            ),
          )
          .toList(growable: false);
      keyed.sort((a, b) {
        final cmp = a.sourceIdx.compareTo(b.sourceIdx);
        return cmp != 0 ? cmp : a.titleKey.compareTo(b.titleKey);
      });
      return keyed.map((e) => e.track).toList(growable: false);
  }
}
