import 'dart:math' as math;

import '../../core/service_status.dart';

class SpeechMismatch {
  const SpeechMismatch({
    required this.expected,
    required this.recognized,
    required this.expectedIndex,
    required this.recognizedIndex,
  });

  final String expected;
  final String recognized;
  final int expectedIndex;
  final int recognizedIndex;

  String get displayLabel => '$expected → $recognized';
}

class SpeechScore {
  const SpeechScore({
    required this.totalScore,
    required this.accuracy,
    required this.completeness,
    required this.fluency,
    required this.feedback,
    required this.expectedLength,
    required this.recognizedLength,
    required this.matchedCount,
    this.duration = Duration.zero,
    this.missedChars = const <String>[],
    this.extraChars = const <String>[],
    this.mismatches = const <SpeechMismatch>[],
  });

  final int totalScore;
  final int accuracy;
  final int completeness;
  final int fluency;
  final String feedback;
  final int expectedLength;
  final int recognizedLength;
  final int matchedCount;
  final Duration duration;
  final List<String> missedChars;
  final List<String> extraChars;
  final List<SpeechMismatch> mismatches;

  bool get hasDetailFeedback =>
      missedChars.isNotEmpty || extraChars.isNotEmpty || mismatches.isNotEmpty;
}

abstract class SpeechScoringService {
  ServiceCapability get capability;

  Future<SpeechScore> score({
    required String expectedText,
    required String recognizedText,
    Duration duration = Duration.zero,
  });
}

class LocalHeuristicSpeechScoringService implements SpeechScoringService {
  const LocalHeuristicSpeechScoringService();

  @override
  ServiceCapability get capability => const ServiceCapability(
    state: ServiceState.placeholder,
    message: '当前采用本地启发式评分，已补齐错字、漏字和节奏反馈，后续仍可接更强评分能力。',
  );

  @override
  Future<SpeechScore> score({
    required String expectedText,
    required String recognizedText,
    Duration duration = Duration.zero,
  }) async {
    final expected = _normalize(expectedText);
    final recognized = _normalize(recognizedText);

    if (expected.isEmpty) {
      return const SpeechScore(
        totalScore: 0,
        accuracy: 0,
        completeness: 0,
        fluency: 0,
        feedback: '缺少目标诗句，暂时无法评分。',
        expectedLength: 0,
        recognizedLength: 0,
        matchedCount: 0,
      );
    }

    final diff = _align(expected, recognized);
    final accuracy =
        (((expected.length - diff.editDistance) / expected.length).clamp(
                  0.0,
                  1.0,
                ) *
                100)
            .round();
    final completeness =
        ((diff.coveredExpectedCount / expected.length).clamp(0.0, 1.0) * 100)
            .round();
    final fluency = _scoreFluency(
      expectedLength: expected.length,
      duration: duration,
      mismatchCount: diff.mismatches.length,
      missedCount: diff.missedChars.length,
      extraCount: diff.extraChars.length,
    );
    final total =
        ((accuracy * 0.5) + (completeness * 0.25) + (fluency * 0.25)).round();

    return SpeechScore(
      totalScore: total,
      accuracy: accuracy,
      completeness: completeness,
      fluency: fluency,
      feedback: _buildFeedback(
        total: total,
        accuracy: accuracy,
        completeness: completeness,
        fluency: fluency,
        diff: diff,
      ),
      expectedLength: expected.length,
      recognizedLength: recognized.length,
      matchedCount: diff.matchedCount,
      duration: duration,
      missedChars: diff.missedChars,
      extraChars: diff.extraChars,
      mismatches: diff.mismatches,
    );
  }

  int _scoreFluency({
    required int expectedLength,
    required Duration duration,
    required int mismatchCount,
    required int missedCount,
    required int extraCount,
  }) {
    if (expectedLength <= 1) {
      return 100;
    }

    final heuristicBase =
        92 - (mismatchCount * 4) - (missedCount * 5) - (extraCount * 3);
    if (duration == Duration.zero) {
      return heuristicBase.clamp(45, 100);
    }

    final seconds = duration.inMilliseconds / 1000;
    final expectedSeconds = math.max(1.8, expectedLength / 3.2);
    final paceRatio = seconds / expectedSeconds;
    final pacePenalty = ((paceRatio - 1).abs() * 35).round().clamp(0, 35);
    final value = heuristicBase - pacePenalty;
    return value.clamp(0, 100);
  }

  String _buildFeedback({
    required int total,
    required int accuracy,
    required int completeness,
    required int fluency,
    required _AlignmentResult diff,
  }) {
    final advice = <String>[];

    if (total >= 92) {
      advice.add('朗读很稳，字句和节奏都不错。');
    } else if (accuracy < 75) {
      advice.add('先把字句读准，再逐步提速会更稳。');
    } else if (completeness < 85) {
      advice.add('内容还有漏读，建议先完整读完这一句。');
    } else if (fluency < 75) {
      advice.add('字句基本对上了，再把停顿放稳一些会更自然。');
    } else {
      advice.add('整体不错，再练一遍会更顺。');
    }

    if (diff.mismatches.isNotEmpty) {
      final mismatchPreview = diff.mismatches
          .take(3)
          .map((item) => item.displayLabel)
          .join('、');
      advice.add('容易混淆：$mismatchPreview。');
    }

    if (diff.missedChars.isNotEmpty) {
      advice.add('漏掉的字：${diff.missedChars.take(6).join('、')}。');
    }

    if (diff.extraChars.isNotEmpty) {
      advice.add('多读出来的字：${diff.extraChars.take(6).join('、')}。');
    }

    return advice.join(' ');
  }

  _AlignmentResult _align(String expected, String recognized) {
    final rows = expected.length + 1;
    final cols = recognized.length + 1;
    final dp = List.generate(
      rows,
      (_) => List<int>.filled(cols, 0),
      growable: false,
    );

    for (var i = 0; i < rows; i += 1) {
      dp[i][0] = i;
    }
    for (var j = 0; j < cols; j += 1) {
      dp[0][j] = j;
    }

    for (var i = 1; i < rows; i += 1) {
      for (var j = 1; j < cols; j += 1) {
        if (expected[i - 1] == recognized[j - 1]) {
          dp[i][j] = dp[i - 1][j - 1];
          continue;
        }

        final substitution = dp[i - 1][j - 1] + 1;
        final deletion = dp[i - 1][j] + 1;
        final insertion = dp[i][j - 1] + 1;
        dp[i][j] = math.min(substitution, math.min(deletion, insertion));
      }
    }

    final mismatches = <SpeechMismatch>[];
    final missedChars = <String>[];
    final extraChars = <String>[];
    var matchedCount = 0;
    var i = expected.length;
    var j = recognized.length;

    while (i > 0 || j > 0) {
      if (i > 0 &&
          j > 0 &&
          expected[i - 1] == recognized[j - 1] &&
          dp[i][j] == dp[i - 1][j - 1]) {
        matchedCount += 1;
        i -= 1;
        j -= 1;
        continue;
      }

      if (i > 0 && j > 0 && dp[i][j] == dp[i - 1][j - 1] + 1) {
        mismatches.add(
          SpeechMismatch(
            expected: expected[i - 1],
            recognized: recognized[j - 1],
            expectedIndex: i - 1,
            recognizedIndex: j - 1,
          ),
        );
        i -= 1;
        j -= 1;
        continue;
      }

      if (i > 0 && dp[i][j] == dp[i - 1][j] + 1) {
        missedChars.add(expected[i - 1]);
        i -= 1;
        continue;
      }

      if (j > 0 && dp[i][j] == dp[i][j - 1] + 1) {
        extraChars.add(recognized[j - 1]);
        j -= 1;
        continue;
      }

      if (i > 0) {
        missedChars.add(expected[i - 1]);
        i -= 1;
      } else if (j > 0) {
        extraChars.add(recognized[j - 1]);
        j -= 1;
      }
    }

    return _AlignmentResult(
      editDistance: dp[expected.length][recognized.length],
      matchedCount: matchedCount,
      mismatches: mismatches.reversed.toList(growable: false),
      missedChars: missedChars.reversed.toList(growable: false),
      extraChars: extraChars.reversed.toList(growable: false),
    );
  }

  String _normalize(String input) {
    return input.replaceAll(
      RegExp(r"""[\s，。！？；、“”‘’：,.!?;:"'()（）《》〈〉【】\[\]-]"""),
      '',
    );
  }
}

class _AlignmentResult {
  const _AlignmentResult({
    required this.editDistance,
    required this.matchedCount,
    required this.mismatches,
    required this.missedChars,
    required this.extraChars,
  });

  final int editDistance;
  final int matchedCount;
  final List<SpeechMismatch> mismatches;
  final List<String> missedChars;
  final List<String> extraChars;

  int get coveredExpectedCount => matchedCount + mismatches.length;
}
