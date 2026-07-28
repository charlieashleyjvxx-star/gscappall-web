import 'package:flutter_test/flutter_test.dart';
import 'package:gscappall/services/speech/speech_scoring_service.dart';

void main() {
  const service = LocalHeuristicSpeechScoringService();

  group('LocalHeuristicSpeechScoringService', () {
    test(
      'extracts mismatches and missed characters for short poem lines',
      () async {
        final score = await service.score(
          expectedText: '处处闻啼鸟',
          recognizedText: '处处安体鸟',
          duration: const Duration(seconds: 3),
        );

        expect(
          score.mismatches.map((item) => item.displayLabel),
          containsAll(<String>['闻 → 安', '啼 → 体']),
        );
        expect(score.missedChars, isEmpty);
        expect(score.extraChars, isEmpty);
        expect(score.fluency, greaterThan(0));
      },
    );

    test('marks omitted characters as missed instead of extra', () async {
      final score = await service.score(
        expectedText: '疑是地上霜',
        recognizedText: '疑地上霜',
        duration: const Duration(seconds: 2),
      );

      expect(score.missedChars, contains('是'));
      expect(score.extraChars, isEmpty);
      expect(score.completeness, lessThan(100));
    });
  });
}
