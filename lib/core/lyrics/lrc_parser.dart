import '../../shared/models/lyrics_line.dart';

class LrcParser {
  static final RegExp _lineRegex = RegExp(
    r'^\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)$',
  );
  static final RegExp _wordRegex = RegExp(
    r'<(\d{2}):(\d{2})\.(\d{2,3})>([^<]*)',
  );

  /// Parse standard or enhanced LRC content into a list of [LyricsLine]
  static List<LyricsLine> parse(
    String lrcContent, {
    String? translationContent,
  }) {
    final lines = <LyricsLine>[];
    final rawLines = lrcContent.split('\n');

    final translationMap = <int, String>{};
    if (translationContent != null) {
      for (final tLine in translationContent.split('\n')) {
        final match = _lineRegex.firstMatch(tLine.trim());
        if (match != null) {
          final timeMs = _parseTime(
            match.group(1)!,
            match.group(2)!,
            match.group(3)!,
          );
          translationMap[timeMs.inSeconds] = match.group(4)!.trim();
        }
      }
    }

    for (final raw in rawLines) {
      final trimmed = raw.trim();
      final match = _lineRegex.firstMatch(trimmed);
      if (match != null) {
        final startTime = _parseTime(
          match.group(1)!,
          match.group(2)!,
          match.group(3)!,
        );
        final bodyText = match.group(4)!.trim();

        // Check for enhanced word-by-word timestamps
        List<WordTimestamp>? words;
        if (_wordRegex.hasMatch(bodyText)) {
          words = [];
          for (final wMatch in _wordRegex.allMatches(bodyText)) {
            final wStart = _parseTime(
              wMatch.group(1)!,
              wMatch.group(2)!,
              wMatch.group(3)!,
            );
            final word = wMatch.group(4)!.trim();
            words.add(
              WordTimestamp(
                startTime: wStart,
                endTime: wStart + const Duration(milliseconds: 300),
                word: word,
              ),
            );
          }
        }

        // Clean any tags from body text
        final cleanText = bodyText.replaceAll(RegExp(r'<[^>]*>'), '').trim();

        final translation = translationMap[startTime.inSeconds];

        lines.add(
          LyricsLine(
            startTime: startTime,
            text: cleanText.isEmpty ? '♪' : cleanText,
            translation: translation,
            words: words,
          ),
        );
      }
    }

    // Sort chronologically
    lines.sort((a, b) => a.startTime.compareTo(b.startTime));

    // Calculate end times from subsequent lines
    for (int i = 0; i < lines.length; i++) {
      final current = lines[i];
      final nextStart = (i + 1 < lines.length)
          ? lines[i + 1].startTime
          : current.startTime + const Duration(seconds: 4);
      lines[i] = LyricsLine(
        startTime: current.startTime,
        endTime: nextStart,
        text: current.text,
        translation: current.translation,
        words: current.words,
      );
    }

    return lines;
  }

  static Duration _parseTime(String min, String sec, String frac) {
    final m = int.parse(min);
    final s = int.parse(sec);
    int ms;
    if (frac.length == 2) {
      ms = int.parse(frac) * 10;
    } else {
      ms = int.parse(frac.padRight(3, '0').substring(0, 3));
    }
    return Duration(minutes: m, seconds: s, milliseconds: ms);
  }
}
