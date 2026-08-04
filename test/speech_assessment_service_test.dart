import 'package:flutter_test/flutter_test.dart';
import 'package:gscappall/services/speech/speech_assessment_service.dart';

void main() {
  group('LocalSpeechAssessmentProvider', () {
    test('returns normalized reading assessment result', () async {
      const provider = LocalSpeechAssessmentProvider();

      final result = await provider.assess(
        const SpeechAssessmentRequest(
          mode: SpeechAssessmentMode.reading,
          expectedText: '床前明月光',
          attemptText: '床前明月光',
          audioFilePath: '/tmp/reading.wav',
          duration: Duration(seconds: 3),
        ),
      );

      expect(result.engine, 'local-practice-assessment');
      expect(result.mode, SpeechAssessmentMode.reading);
      expect(result.assessmentBasis, 'audio_with_aux_text');
      expect(result.totalScore, greaterThanOrEqualTo(90));
      expect(result.accuracy, 100);
      expect(result.completeness, 100);
      expect(result.confidence, greaterThan(0.9));
    });

    test(
      'keeps recitation assessment separate from target correction',
      () async {
        const provider = LocalSpeechAssessmentProvider();

        final result = await provider.assess(
          const SpeechAssessmentRequest(
            mode: SpeechAssessmentMode.recitation,
            expectedText: '疑是地上霜',
            attemptText: '一是地上双',
          ),
        );

        expect(result.mode, SpeechAssessmentMode.recitation);
        expect(result.rawAttemptText, '一是地上双');
        expect(result.normalizedText, '一是地上双');
        expect(result.accuracy, lessThan(100));
        expect(result.assessmentBasis, 'aux_text_only');
      },
    );
  });
}
