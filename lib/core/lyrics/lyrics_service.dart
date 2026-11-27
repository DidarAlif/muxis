import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../shared/models/lyrics_line.dart';
import '../../shared/models/track.dart';
import 'lrc_parser.dart';

final lyricsServiceProvider = Provider<LyricsService>((ref) {
  return LyricsService();
});

class LyricsService {
  final Map<String, List<LyricsLine>> _cache = {};

  /// Clean titles/artist tags from streaming metadata (e.g. `(Official Video)`,
  /// `- Remastered`, `- Topic`) so real LRCLIB matches succeed reliably.
  static String cleanTrackTitle(String raw) {
    var cleaned = raw.replaceAll(
      RegExp(
        r'\s*[\(\[](?:official\s*(?:music\s*)?(?:video|audio|lyric(?:s)?|visualizer)|lyrics?|hd|4k|hq|remaster(?:ed)?(?:\s*\d{4})?|explicit|clean|live|feat\.?[^\)\]]*|ft\.?[^\)\]]*)[\)\]]',
        caseSensitive: false,
      ),
      '',
    );
    cleaned = cleaned.replaceAll(
      RegExp(
        r'\s*[-–—]\s*(?:remaster(?:ed)?(?:\s*\d{4})?|radio\s*edit|single\s*version|album\s*version)$',
        caseSensitive: false,
      ),
      '',
    );
    return cleaned.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
  }

  static String cleanArtistName(String raw) {
    var cleaned = raw.replaceAll(
      RegExp(r'\s*-\s*Topic$', caseSensitive: false),
      '',
    );
    final splitFeat = cleaned.split(
      RegExp(r'\s*(?:feat\.|ft\.|featuring|&|,)\s*', caseSensitive: false),
    );
    if (splitFeat.isNotEmpty && splitFeat.first.trim().isNotEmpty) {
      cleaned = splitFeat.first;
    }
    return cleaned.trim();
  }

  Future<List<LyricsLine>> fetchLyrics(Track track) async {
    final cacheKey = '${track.id}::${track.title}::${track.artist}';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    final title = cleanTrackTitle(track.title);
    final artist = cleanArtistName(track.artist);
    final durationSec = track.duration.inSeconds;

    if (title.isEmpty) {
      _cache[cacheKey] = const [];
      return const [];
    }

    try {
      // 1. Primary LRCLIB exact lookup
      final queryParams = <String, String>{
        'track_name': title,
        if (artist.isNotEmpty && artist.toLowerCase() != 'unknown artist')
          'artist_name': artist,
        if (durationSec > 0) 'duration': '$durationSec',
      };
      final uri = Uri.https('lrclib.net', '/api/get', queryParams);
      final response = await http.get(uri).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          if (decoded['instrumental'] == true) {
            _cache[cacheKey] = const [];
            return const [];
          }
          final parsed = _extractLyricsFromRecord(decoded, track.duration);
          if (parsed.isNotEmpty) {
            _cache[cacheKey] = parsed;
            return parsed;
          }
        }
      }

      // 2. Secondary LRCLIB search lookup (handles minor punctuation/duration diffs)
      final searchParams = <String, String>{
        if (artist.isNotEmpty && artist.toLowerCase() != 'unknown artist') ...{
          'track_name': title,
          'artist_name': artist,
        } else
          'q': title,
      };
      final searchUri = Uri.https('lrclib.net', '/api/search', searchParams);
      final searchRes = await http
          .get(searchUri)
          .timeout(const Duration(seconds: 5));
      if (searchRes.statusCode == 200) {
        final results = jsonDecode(searchRes.body);
        if (results is List && results.isNotEmpty) {
          final best = _pickBestSearchMatch(results, durationSec);
          if (best != null) {
            if (best['instrumental'] == true) {
              _cache[cacheKey] = const [];
              return const [];
            }
            final parsed = _extractLyricsFromRecord(best, track.duration);
            if (parsed.isNotEmpty) {
              _cache[cacheKey] = parsed;
              return parsed;
            }
          }
        }
      }
    } catch (_) {
      // Network or parse failure: return empty so UI renders spectrum cleanly.
    }

    // Do NOT synthesize placeholder/fake lyrics when none exist.
    _cache[cacheKey] = const [];
    return const [];
  }

  Map<String, dynamic>? _pickBestSearchMatch(
    List<dynamic> results,
    int durationSec,
  ) {
    Map<String, dynamic>? fallbackSynced;
    Map<String, dynamic>? fallbackPlain;

    for (final item in results) {
      if (item is! Map<String, dynamic>) continue;
      if (item['instrumental'] == true) continue;
      final synced = item['syncedLyrics'] as String?;
      final plain = item['plainLyrics'] as String?;
      final itemDuration = (item['duration'] as num?)?.round() ?? 0;
      final durationClose =
          durationSec <= 0 ||
          itemDuration <= 0 ||
          (itemDuration - durationSec).abs() <= 15;

      if (synced != null && synced.trim().isNotEmpty) {
        if (durationClose) return item;
        fallbackSynced ??= item;
      } else if (plain != null && plain.trim().isNotEmpty && durationClose) {
        fallbackPlain ??= item;
      }
    }

    return fallbackSynced ?? fallbackPlain;
  }

  List<LyricsLine> _extractLyricsFromRecord(
    Map<String, dynamic> record,
    Duration trackDuration,
  ) {
    final syncedLyrics = record['syncedLyrics'] as String?;
    if (syncedLyrics != null && syncedLyrics.trim().isNotEmpty) {
      final parsed = LrcParser.parse(syncedLyrics);
      if (parsed.isNotEmpty) {
        return parsed;
      }
    }

    final plainLyrics = record['plainLyrics'] as String?;
    if (plainLyrics != null && plainLyrics.trim().isNotEmpty) {
      final rawLines = plainLyrics
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();
      if (rawLines.length >= 3) {
        final totalMs = trackDuration.inMilliseconds > 15000
            ? trackDuration.inMilliseconds
            : rawLines.length * 4000;
        final stepMs = (totalMs / rawLines.length).round().clamp(1500, 12000);
        return List<LyricsLine>.generate(rawLines.length, (i) {
          final start = Duration(milliseconds: i * stepMs);
          final end = Duration(milliseconds: (i + 1) * stepMs);
          return LyricsLine(startTime: start, endTime: end, text: rawLines[i]);
        });
      }
    }

    return const [];
  }
}
