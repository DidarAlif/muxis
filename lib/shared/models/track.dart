enum MusicSource { local, youtube, spotify, soundcloud, radio, publicDomain }

class Track {
  final String id;
  final String title;
  final String artist;
  final String? artistId;
  final String album;
  final String? albumId;
  final Duration duration;
  final String? artworkUrl;
  final String? localFilePath;
  final String? streamUrl;
  final MusicSource source;
  final bool isFavorite;
  final String? audioFormat; // e.g., 'FLAC 24-bit', '320kbps MP3', 'Opus'
  final int? trackNumber;
  final int? year;

  const Track({
    required this.id,
    required this.title,
    required this.artist,
    this.artistId,
    required this.album,
    this.albumId,
    required this.duration,
    this.artworkUrl,
    this.localFilePath,
    this.streamUrl,
    MusicSource? source,
    this.isFavorite = false,
    this.audioFormat = 'FLAC',
    this.trackNumber,
    this.year,
    bool? isLocal,
  }) : source =
           source ??
           (isLocal == false ? MusicSource.youtube : MusicSource.local);

  bool get isLocal => source == MusicSource.local;

  Track copyWith({
    String? id,
    String? title,
    String? artist,
    String? artistId,
    String? album,
    String? albumId,
    Duration? duration,
    String? artworkUrl,
    String? localFilePath,
    String? streamUrl,
    MusicSource? source,
    bool? isFavorite,
    String? audioFormat,
    int? trackNumber,
    int? year,
  }) {
    return Track(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      artistId: artistId ?? this.artistId,
      album: album ?? this.album,
      albumId: albumId ?? this.albumId,
      duration: duration ?? this.duration,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      localFilePath: localFilePath ?? this.localFilePath,
      streamUrl: streamUrl ?? this.streamUrl,
      source: source ?? this.source,
      isFavorite: isFavorite ?? this.isFavorite,
      audioFormat: audioFormat ?? this.audioFormat,
      trackNumber: trackNumber ?? this.trackNumber,
      year: year ?? this.year,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'artistId': artistId,
      'album': album,
      'albumId': albumId,
      'durationMs': duration.inMilliseconds,
      'artworkUrl': artworkUrl,
      'localFilePath': localFilePath,
      'streamUrl': streamUrl,
      'source': source.name,
      'isLocal': isLocal,
      'isFavorite': isFavorite ? 1 : 0,
      'audioFormat': audioFormat,
      'trackNumber': trackNumber,
      'year': year,
    };
  }

  factory Track.fromMap(Map<String, dynamic> map) {
    return Track(
      id: map['id'] as String,
      title: map['title'] as String,
      artist: map['artist'] as String,
      artistId: map['artistId'] as String?,
      album: map['album'] as String,
      albumId: map['albumId'] as String?,
      duration: Duration(milliseconds: map['durationMs'] as int? ?? 0),
      artworkUrl: map['artworkUrl'] as String?,
      localFilePath: map['localFilePath'] as String?,
      streamUrl: map['streamUrl'] as String?,
      source: MusicSource.values.firstWhere(
        (e) => e.name == map['source'],
        orElse: () => MusicSource.local,
      ),
      isFavorite: (map['isFavorite'] as int? ?? 0) == 1,
      isLocal: map['isLocal'] is bool
          ? map['isLocal'] as bool
          : (map['source'] == 'local'),
      audioFormat: map['audioFormat'] as String? ?? 'FLAC',
      trackNumber: map['trackNumber'] as int?,
      year: map['year'] as int?,
    );
  }
}
