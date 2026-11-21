class LyricsLine {
  final Duration startTime;
  final Duration? endTime;
  final String text;
  final String? translation;
  final String? romanization;
  final List<WordTimestamp>? words;

  Duration get timestamp => startTime;

  const LyricsLine({
    Duration? startTime,
    Duration? timestamp,
    this.endTime,
    required this.text,
    this.translation,
    this.romanization,
    this.words,
  }) : startTime = startTime ?? timestamp ?? Duration.zero;
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
