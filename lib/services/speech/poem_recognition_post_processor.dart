import 'package:lpinyin/lpinyin.dart';

import '../../domain/poem.dart';

class PoemRecognitionCorrection {
  const PoemRecognitionCorrection({
    required this.displayText,
    required this.rawText,
    required this.wasCorrected,
    required this.reason,
    required this.charSimilarity,
    required this.phoneticSimilarity,
  });

  final String displayText;
  final String rawText;
  final bool wasCorrected;
  final String reason;
  final double charSimilarity;
  final double phoneticSimilarity;
}

class PoemRecognitionPostProcessor {
  const PoemRecognitionPostProcessor();

  PoemRecognitionCorrection correctForTarget({
    required Poem poem,
    required int lineIndex,
    required String recognizedText,
    required bool isFinal,
    bool preferTargetOnFinal = false,
  }) {
    final rawText = recognizedText.trim();
    if (rawText.isEmpty) {
      return const PoemRecognitionCorrection(
        displayText: '',
        rawText: '',
        wasCorrected: false,
        reason: 'empty',
        charSimilarity: 0,
        phoneticSimilarity: 0,
      );
    }

    final lines = poem.lines;
    if (lineIndex < 0 || lineIndex >= lines.length) {
      return PoemRecognitionCorrection(
        displayText: rawText,
        rawText: rawText,
        wasCorrected: false,
        reason: 'line_out_of_range',
        charSimilarity: 0,
        phoneticSimilarity: 0,
      );
    }

    final expectedText = lines[lineIndex].trim();
    final expectedNormalized = _normalizeSpokenText(expectedText);
    final recognizedNormalized = _normalizeSpokenText(rawText);
    if (expectedNormalized.isEmpty || recognizedNormalized.isEmpty) {
      return PoemRecognitionCorrection(
        displayText: rawText,
        rawText: rawText,
        wasCorrected: false,
        reason: 'normalized_empty',
        charSimilarity: 0,
        phoneticSimilarity: 0,
      );
    }

    if (expectedNormalized == recognizedNormalized) {
      return PoemRecognitionCorrection(
        displayText: expectedText,
        rawText: rawText,
        wasCorrected: rawText != expectedText,
        reason: rawText == expectedText ? 'exact' : 'restore_punctuation',
        charSimilarity: 1,
        phoneticSimilarity: 1,
      );
    }

    final expectedChars = _splitCharacters(expectedNormalized);
    final recognizedChars = _splitCharacters(recognizedNormalized);
    final charSimilarity = _sequenceSimilarity(expectedChars, recognizedChars);

    final expectedPinyin = _expectedPinyin(poem, lineIndex, expectedNormalized);
    final recognizedPinyin = _recognizedPinyin(recognizedNormalized);
    final phoneticSimilarity = _phoneticSequenceSimilarity(
      expectedPinyin,
      recognizedPinyin,
    );

    if (preferTargetOnFinal && isFinal && recognizedNormalized.length >= 2) {
      return PoemRecognitionCorrection(
        displayText: expectedText,
        rawText: rawText,
        wasCorrected: true,
        reason: 'target_line_guided',
        charSimilarity: charSimilarity,
        phoneticSimilarity: phoneticSimilarity,
      );
    }

    final lengthDelta = (expectedChars.length - recognizedChars.length).abs();
    final shouldSnapToTarget = _shouldSnapToTarget(
      isFinal: isFinal,
      charSimilarity: charSimilarity,
      phoneticSimilarity: phoneticSimilarity,
      lengthDelta: lengthDelta,
      expectedLength: expectedChars.length,
      recognizedLength: recognizedChars.length,
      targetContained:
          recognizedNormalized.contains(expectedNormalized) ||
          expectedNormalized.contains(recognizedNormalized),
    );

    if (shouldSnapToTarget) {
      return PoemRecognitionCorrection(
        displayText: expectedText,
        rawText: rawText,
        wasCorrected: true,
        reason: 'target_line_snap',
        charSimilarity: charSimilarity,
        phoneticSimilarity: phoneticSimilarity,
      );
    }

    return PoemRecognitionCorrection(
      displayText: rawText,
      rawText: rawText,
      wasCorrected: false,
      reason: isFinal ? 'keep_raw_final' : 'keep_raw_partial',
      charSimilarity: charSimilarity,
      phoneticSimilarity: phoneticSimilarity,
    );
  }

  bool _shouldSnapToTarget({
    required bool isFinal,
    required double charSimilarity,
    required double phoneticSimilarity,
    required int lengthDelta,
    required int expectedLength,
    required int recognizedLength,
    required bool targetContained,
  }) {
    if (!isFinal || recognizedLength == 0 || expectedLength == 0) {
      return false;
    }

    if (targetContained && recognizedLength >= (expectedLength * 0.55).ceil()) {
      return true;
    }

    final allowedLengthDelta = _maxInt(2, (expectedLength * 0.45).ceil());
    if (charSimilarity >= 0.72 && lengthDelta <= allowedLengthDelta) {
      return true;
    }
    if (phoneticSimilarity >= 0.68 && lengthDelta <= allowedLengthDelta) {
      return true;
    }
    if (phoneticSimilarity >= 0.56 &&
        charSimilarity >= 0.34 &&
        lengthDelta <= allowedLengthDelta) {
      return true;
    }

    return false;
  }

  String _normalizeSpokenText(String input) {
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      if (_isChineseRune(rune) || _isAsciiLetterOrDigit(rune)) {
        buffer.writeCharCode(rune);
      }
    }
    return buffer.toString().trim();
  }

  List<String> _expectedPinyin(Poem poem, int lineIndex, String fallbackText) {
    final pinyinLines = poem.pinyin
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    if (lineIndex >= 0 && lineIndex < pinyinLines.length) {
      final tokens = _normalizePinyinTokens(pinyinLines[lineIndex]);
      if (tokens.isNotEmpty) {
        return tokens;
      }
    }
    return _recognizedPinyin(fallbackText);
  }

  List<String> _recognizedPinyin(String text) {
    final converted = PinyinHelper.getPinyinE(
      text,
      separator: ' ',
      format: PinyinFormat.WITHOUT_TONE,
    );
    return _normalizePinyinTokens(converted);
  }

  List<String> _normalizePinyinTokens(String text) {
    final normalized = text
        .toLowerCase()
        .replaceAll('u:', 'v')
        .replaceAll('ü', 'v')
        .replaceAll(RegExp(r'[^a-zv\s]+'), ' ');
    return normalized
        .split(RegExp(r'\s+'))
        .map((token) => token.trim())
        .where((token) => token.isNotEmpty)
        .toList(growable: false);
  }

  double _phoneticSequenceSimilarity(List<String> left, List<String> right) {
    if (left.isEmpty || right.isEmpty) {
      return 0;
    }

    final scores = List<List<double>>.generate(
      left.length + 1,
      (_) => List<double>.filled(right.length + 1, 0),
    );
    for (var i = 1; i <= left.length; i += 1) {
      for (var j = 1; j <= right.length; j += 1) {
        final match =
            scores[i - 1][j - 1] +
            _syllableSimilarity(left[i - 1], right[j - 1]);
        final skipLeft = scores[i - 1][j];
        final skipRight = scores[i][j - 1];
        scores[i][j] = [
          match,
          skipLeft,
          skipRight,
        ].reduce((value, element) => value > element ? value : element);
      }
    }
    final maxLength = _maxInt(left.length, right.length);
    return scores[left.length][right.length] / maxLength;
  }

  double _sequenceSimilarity(List<String> left, List<String> right) {
    if (left.isEmpty || right.isEmpty) {
      return 0;
    }
    final distance = _levenshteinList(left, right);
    final maxLength = _maxInt(left.length, right.length);
    return 1 - (distance / maxLength);
  }

  double _syllableSimilarity(String left, String right) {
    if (left == right) {
      return 1;
    }
    if (left.isEmpty || right.isEmpty) {
      return 0;
    }

    final distance = _levenshtein(left, right);
    final maxLength = _maxInt(left.length, right.length);
    return 1 - (distance / maxLength);
  }

  int _levenshtein(String left, String right) {
    if (left == right) {
      return 0;
    }
    if (left.isEmpty) {
      return right.length;
    }
    if (right.isEmpty) {
      return left.length;
    }

    final costs = List<int>.generate(right.length + 1, (index) => index);
    for (var i = 1; i <= left.length; i += 1) {
      var previous = costs[0];
      costs[0] = i;
      for (var j = 1; j <= right.length; j += 1) {
        final insert = costs[j] + 1;
        final delete = costs[j - 1] + 1;
        final replace =
            previous +
            (left.codeUnitAt(i - 1) == right.codeUnitAt(j - 1) ? 0 : 1);
        previous = costs[j];
        costs[j] = [
          insert,
          delete,
          replace,
        ].reduce((value, element) => value < element ? value : element);
      }
    }
    return costs.last;
  }

  int _levenshteinList(List<String> left, List<String> right) {
    if (left == right) {
      return 0;
    }
    if (left.isEmpty) {
      return right.length;
    }
    if (right.isEmpty) {
      return left.length;
    }

    final costs = List<int>.generate(right.length + 1, (index) => index);
    for (var i = 1; i <= left.length; i += 1) {
      var previous = costs[0];
      costs[0] = i;
      for (var j = 1; j <= right.length; j += 1) {
        final insert = costs[j] + 1;
        final delete = costs[j - 1] + 1;
        final replace = previous + (left[i - 1] == right[j - 1] ? 0 : 1);
        previous = costs[j];
        costs[j] = [
          insert,
          delete,
          replace,
        ].reduce((value, element) => value < element ? value : element);
      }
    }
    return costs.last;
  }

  List<String> _splitCharacters(String text) {
    return text.runes
        .map((rune) => String.fromCharCode(rune))
        .toList(growable: false);
  }

  bool _isChineseRune(int rune) {
    return rune >= 0x4E00 && rune <= 0x9FFF;
  }

  bool _isAsciiLetterOrDigit(int rune) {
    return (rune >= 0x30 && rune <= 0x39) ||
        (rune >= 0x41 && rune <= 0x5A) ||
        (rune >= 0x61 && rune <= 0x7A);
  }

  int _maxInt(int left, int right) => left > right ? left : right;
}
