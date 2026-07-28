import '../../domain/poem.dart';

class PoetryJielongLine {
  const PoetryJielongLine({
    required this.poem,
    required this.text,
    required this.firstChar,
    required this.lastChar,
    required this.firstPinyin,
    required this.lastPinyin,
  });

  final Poem poem;
  final String text;
  final String firstChar;
  final String lastChar;
  final String firstPinyin;
  final String lastPinyin;

  String get key => '${poem.id}:$text';
}

class PoetryJielongTurnResult {
  const PoetryJielongTurnResult({
    required this.accepted,
    required this.sameSoundFallback,
    required this.message,
    this.line,
  });

  final bool accepted;
  final bool sameSoundFallback;
  final String message;
  final PoetryJielongLine? line;
}

class PoetryJielongReport {
  const PoetryJielongReport({
    required this.lineCount,
    required this.sameSoundCount,
    required this.score,
    required this.points,
    required this.summary,
  });

  final int lineCount;
  final int sameSoundCount;
  final int score;
  final int points;
  final String summary;
}

class PoetryJielongService {
  const PoetryJielongService();

  List<PoetryJielongLine> buildLineBank(List<Poem> poems) {
    return poems
        .expand((poem) {
          final pinyinLines = poem.pinyinLines;
          return poem.lines.toList(growable: false).asMap().entries.map((
            entry,
          ) {
            final normalized = normalizeLine(entry.value);
            final chars = normalized.runes
                .map((rune) => String.fromCharCode(rune))
                .toList(growable: false);
            if (chars.isEmpty) {
              return null;
            }
            final syllables = splitPinyinLine(
              entry.key < pinyinLines.length ? pinyinLines[entry.key] : '',
            );
            return PoetryJielongLine(
              poem: poem,
              text: entry.value.trim(),
              firstChar: chars.first,
              lastChar: chars.last,
              firstPinyin: syllables.isEmpty ? '' : syllables.first,
              lastPinyin: syllables.isEmpty ? '' : syllables.last,
            );
          });
        })
        .whereType<PoetryJielongLine>()
        .toList(growable: false);
  }

  String normalizeLine(String input) {
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      final char = String.fromCharCode(rune);
      if (_isChineseChar(rune)) {
        buffer.write(char);
      }
    }
    return buffer.toString();
  }

  List<String> splitPinyinLine(String input) {
    return input
        .split(RegExp(r'\s+'))
        .map(normalizePinyin)
        .where((syllable) => syllable.isNotEmpty)
        .toList(growable: false);
  }

  String normalizePinyin(String input) {
    final lower = input.toLowerCase().trim();
    final buffer = StringBuffer();
    for (final rune in lower.runes) {
      final char = String.fromCharCode(rune);
      final normalized = _toneMap[char] ?? char;
      if (RegExp(r'[a-züv]').hasMatch(normalized)) {
        buffer.write(normalized == 'ü' ? 'v' : normalized);
      }
    }
    return buffer.toString();
  }

  PoetryJielongLine? findLineByText(
    List<PoetryJielongLine> bank,
    String input,
  ) {
    final normalizedInput = normalizeLine(input);
    if (normalizedInput.isEmpty) {
      return null;
    }
    for (final line in bank) {
      if (normalizeLine(line.text) == normalizedInput) {
        return line;
      }
    }
    return null;
  }

  List<PoetryJielongLine> suggestionsForTarget(
    List<PoetryJielongLine> bank, {
    required String targetChar,
    required String targetPinyin,
    Set<String> usedKeys = const {},
    int limit = 6,
  }) {
    final exact = bank.where(
      (line) => line.firstChar == targetChar && !usedKeys.contains(line.key),
    );
    final sameSound = bank.where(
      (line) =>
          line.firstChar != targetChar &&
          targetPinyin.isNotEmpty &&
          line.firstPinyin == targetPinyin &&
          !usedKeys.contains(line.key),
    );
    return [...exact, ...sameSound].take(limit).toList(growable: false);
  }

  PoetryJielongTurnResult validateTurn({
    required List<PoetryJielongLine> bank,
    required String input,
    required String targetChar,
    required String targetPinyin,
    required Set<String> usedKeys,
  }) {
    final line = findLineByText(bank, input);
    if (line == null) {
      return const PoetryJielongTurnResult(
        accepted: false,
        sameSoundFallback: false,
        message: '没有在本地诗词库中找到这一句，请检查原文或换一句。',
      );
    }
    if (usedKeys.contains(line.key)) {
      return const PoetryJielongTurnResult(
        accepted: false,
        sameSoundFallback: false,
        message: '这一句已经用过了，换一句继续接龙吧。',
      );
    }
    if (line.firstChar == targetChar) {
      return PoetryJielongTurnResult(
        accepted: true,
        sameSoundFallback: false,
        message: '接上了！下一句要以“${line.lastChar}”开头。',
        line: line,
      );
    }
    if (targetPinyin.isNotEmpty && line.firstPinyin == targetPinyin) {
      return PoetryJielongTurnResult(
        accepted: true,
        sameSoundFallback: true,
        message:
            '同音接上了！“${line.firstChar}”和“$targetChar”同音，下一句要以“${line.lastChar}”开头。',
        line: line,
      );
    }
    final pinyinHint = targetPinyin.isEmpty ? '' : '，或同音 $targetPinyin';
    return PoetryJielongTurnResult(
      accepted: false,
      sameSoundFallback: false,
      message: '这一句要以“$targetChar”开头$pinyinHint，当前是“${line.firstChar}”。',
    );
  }

  PoetryJielongReport buildReport({
    required int lineCount,
    required int sameSoundCount,
  }) {
    final score = (55 + lineCount * 10 - sameSoundCount * 3).clamp(0, 100);
    final points = lineCount >= 3 ? (5 + lineCount * 2).clamp(0, 20) : 0;
    final summary =
        sameSoundCount == 0
            ? '完成 $lineCount 句接龙，全程严格首尾字相接。'
            : '完成 $lineCount 句接龙，其中 $sameSoundCount 次使用同音兜底。';
    return PoetryJielongReport(
      lineCount: lineCount,
      sameSoundCount: sameSoundCount,
      score: score,
      points: points,
      summary: summary,
    );
  }

  bool _isChineseChar(int rune) {
    return rune >= 0x4E00 && rune <= 0x9FFF;
  }

  static const Map<String, String> _toneMap = {
    'ā': 'a',
    'á': 'a',
    'ǎ': 'a',
    'à': 'a',
    'ē': 'e',
    'é': 'e',
    'ě': 'e',
    'è': 'e',
    'ī': 'i',
    'í': 'i',
    'ǐ': 'i',
    'ì': 'i',
    'ō': 'o',
    'ó': 'o',
    'ǒ': 'o',
    'ò': 'o',
    'ū': 'u',
    'ú': 'u',
    'ǔ': 'u',
    'ù': 'u',
    'ǖ': 'v',
    'ǘ': 'v',
    'ǚ': 'v',
    'ǜ': 'v',
    'ü': 'v',
  };
}
