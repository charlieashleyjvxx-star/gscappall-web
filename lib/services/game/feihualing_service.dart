import '../../domain/poem.dart';

class FeihualingTheme {
  const FeihualingTheme({
    required this.character,
    required this.hitCount,
    required this.exampleLines,
  });

  final String character;
  final int hitCount;
  final List<String> exampleLines;
}

class FeihualingLine {
  const FeihualingLine({required this.poem, required this.text});

  final Poem poem;
  final String text;

  String get key => '${poem.id}:$text';
}

class FeihualingTurnResult {
  const FeihualingTurnResult({
    required this.accepted,
    required this.message,
    this.line,
  });

  final bool accepted;
  final String message;
  final FeihualingLine? line;
}

class FeihualingReport {
  const FeihualingReport({
    required this.themeCharacter,
    required this.lineCount,
    required this.score,
    required this.points,
    required this.summary,
  });

  final String themeCharacter;
  final int lineCount;
  final int score;
  final int points;
  final String summary;
}

class FeihualingService {
  const FeihualingService();

  List<FeihualingLine> buildLineBank(List<Poem> poems) {
    return poems
        .expand(
          (poem) => poem.lines.map(
            (line) => FeihualingLine(poem: poem, text: line.trim()),
          ),
        )
        .where((line) => _normalizeLine(line.text).isNotEmpty)
        .toList(growable: false);
  }

  List<FeihualingTheme> buildThemePool(
    List<Poem> poems, {
    int limit = 12,
    int minHits = 2,
  }) {
    final hits = <String, List<String>>{};
    for (final line in buildLineBank(poems)) {
      final normalized = _normalizeLine(line.text);
      for (final rune in normalized.runes) {
        final char = String.fromCharCode(rune);
        hits.putIfAbsent(char, () => <String>[]).add(line.text);
      }
    }

    final themes = hits.entries
        .where((entry) => entry.value.length >= minHits)
        .map(
          (entry) => FeihualingTheme(
            character: entry.key,
            hitCount: entry.value.length,
            exampleLines: entry.value.take(3).toList(growable: false),
          ),
        )
        .toList(growable: false)
      ..sort((left, right) => right.hitCount.compareTo(left.hitCount));

    return themes.take(limit).toList(growable: false);
  }

  bool lineMatchesTheme(String line, String themeCharacter) {
    return _normalizeLine(line).contains(themeCharacter);
  }

  FeihualingLine? findLineByText(List<FeihualingLine> bank, String input) {
    final normalizedInput = _normalizeLine(input);
    if (normalizedInput.isEmpty) {
      return null;
    }
    for (final line in bank) {
      if (_normalizeLine(line.text) == normalizedInput) {
        return line;
      }
    }
    return null;
  }

  FeihualingTurnResult validateTurn({
    required List<FeihualingLine> bank,
    required String input,
    required String themeCharacter,
    required Set<String> usedKeys,
  }) {
    final line = findLineByText(bank, input);
    if (line == null) {
      return const FeihualingTurnResult(
        accepted: false,
        message: '没有在本地诗词库中找到这一句，请检查原文或换一句。',
      );
    }
    if (usedKeys.contains(line.key)) {
      return const FeihualingTurnResult(
        accepted: false,
        message: '这一句已经答过了，换一句继续飞花令吧。',
      );
    }
    if (!lineMatchesTheme(line.text, themeCharacter)) {
      return FeihualingTurnResult(
        accepted: false,
        message: '这一句里没有“$themeCharacter”，不能算作本轮答案。',
      );
    }
    return FeihualingTurnResult(
      accepted: true,
      message: '答对了！继续说一句带“$themeCharacter”的诗句。',
      line: line,
    );
  }

  List<FeihualingLine> suggestionsForTheme(
    List<FeihualingLine> bank,
    String themeCharacter, {
    Set<String> usedKeys = const {},
    int limit = 5,
  }) {
    return bank
        .where(
          (line) =>
              lineMatchesTheme(line.text, themeCharacter) &&
              !usedKeys.contains(line.key),
        )
        .take(limit)
        .toList(growable: false);
  }

  FeihualingReport buildReport({
    required String themeCharacter,
    required int lineCount,
  }) {
    final score = (50 + lineCount * 12).clamp(0, 100);
    final points = lineCount >= 3 ? (6 + lineCount * 2).clamp(0, 20) : 0;
    return FeihualingReport(
      themeCharacter: themeCharacter,
      lineCount: lineCount,
      score: score,
      points: points,
      summary: '围绕“$themeCharacter”完成 $lineCount 句飞花令。',
    );
  }

  String _normalizeLine(String input) {
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      if (rune >= 0x4E00 && rune <= 0x9FFF) {
        buffer.write(String.fromCharCode(rune));
      }
    }
    return buffer.toString();
  }
}
