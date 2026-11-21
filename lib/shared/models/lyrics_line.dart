class LyricsLine {
  final Duration startTime;
  final Duration? endTime;
  final String text;
  final String? translation;
  final String? romanization;
  final List<WordTimestamp>? words;

  const LyricsLine({
    required this.startTime,
    this.endTime,
    required this.text,
    this.translation,
    this.romanization,
    this.words,
  });
}

class WordTimestamp {
  final Duration startTime;
  final Duration endTime;
  final String word;

  const WordTimestamp({
    required this.startTime,
    required this.endTime,
    required this.word,
  });
}
