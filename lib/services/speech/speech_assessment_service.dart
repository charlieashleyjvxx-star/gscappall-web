import '../../core/service_status.dart';
import 'speech_scoring_service.dart';

enum SpeechAssessmentMode { reading, recitation }

extension SpeechAssessmentModeLabel on SpeechAssessmentMode {
  String get label {
    return switch (this) {
      SpeechAssessmentMode.reading => '朗读',
      SpeechAssessmentMode.recitation => '背诵',
    };
  }
}

class SpeechAssessmentRequest {
  const SpeechAssessmentRequest({
    required this.mode,
    required this.expectedText,
    this.attemptText = '',
    this.audioFilePath,
    this.duration = Duration.zero,
    this.metadata = const <String, Object?>{},
  });

  final SpeechAssessmentMode mode;
  final String expectedText;
  final String attemptText;
  final String? audioFilePath;
  final Duration duration;
  final Map<String, Object?> metadata;
}

class SpeechAssessmentResult extends SpeechScore {
  const SpeechAssessmentResult({
    required super.totalScore,
    required super.accuracy,
    required super.completeness,
    required super.fluency,
    required super.feedback,
    required super.expectedLength,
    required super.recognizedLength,
    required super.matchedCount,
    required this.mode,
    required this.engine,
    required this.assessmentBasis,
    required this.normalizedText,
    required this.confidence,
    super.duration = Duration.zero,
    super.missedChars = const <String>[],
    super.extraChars = const <String>[],
    super.mismatches = const <SpeechMismatch>[],
    this.rawAttemptText = '',
    this.audioFilePath,
    this.rawProviderPayload = const <String, Object?>{},
  });

  final SpeechAssessmentMode mode;
  final String engine;
  final String assessmentBasis;
  final String rawAttemptText;
  final String normalizedText;
  final String? audioFilePath;
  final double confidence;
  final Map<String, Object?> rawProviderPayload;
}

abstract class SpeechAssessmentProvider {
  ServiceCapability get capability;

  Future<SpeechAssessmentResult> assess(SpeechAssessmentRequest request);
}

class MockSpeechAssessmentProvider implements SpeechAssessmentProvider {
  const MockSpeechAssessmentProvider({
    this.heuristicScoringService = const LocalHeuristicSpeechScoringService(),
  });

  final SpeechScoringService heuristicScoringService;

  @override
  ServiceCapability get capability => const ServiceCapability(
    state: ServiceState.placeholder,
    message: '已切到云端语音评测架构，当前使用 Mock Provider 跑通朗读/背诵链路；sherpa_onnx 仅作为离线辅助识别。',
  );

  @override
  Future<SpeechAssessmentResult> assess(SpeechAssessmentRequest request) async {
    final score = await heuristicScoringService.score(
      expectedText: request.expectedText,
      recognizedText: request.attemptText,
      duration: request.duration,
    );
    final normalized = _normalize(request.attemptText);
    final hasAudio = request.audioFilePath?.trim().isNotEmpty ?? false;

    return SpeechAssessmentResult(
      totalScore: score.totalScore,
      accuracy: score.accuracy,
      completeness: score.completeness,
      fluency: score.fluency,
      feedback: _buildFeedbackPrefix(request, hasAudio) + score.feedback,
      expectedLength: score.expectedLength,
      recognizedLength: score.recognizedLength,
      matchedCount: score.matchedCount,
      duration: score.duration,
      missedChars: score.missedChars,
      extraChars: score.extraChars,
      mismatches: score.mismatches,
      mode: request.mode,
      engine: 'mock-assessment',
      assessmentBasis: hasAudio ? 'audio_with_aux_text' : 'aux_text_only',
      rawAttemptText: request.attemptText,
      normalizedText: normalized,
      audioFilePath: request.audioFilePath,
      confidence: _estimateConfidence(score),
      rawProviderPayload: <String, Object?>{
        'provider': 'mock',
        'mode': request.mode.name,
        'hasAudio': hasAudio,
        'metadata': request.metadata,
      },
    );
  }

  String _buildFeedbackPrefix(SpeechAssessmentRequest request, bool hasAudio) {
    final source = hasAudio ? '已收到录音文件，' : '当前未拿到录音文件，';
    return '$source${request.mode.label}评分先由 Mock 评测引擎生成，后续可替换为云端发音评测。';
  }

  double _estimateConfidence(SpeechScore score) {
    final value =
        (score.accuracy * 0.45 +
            score.completeness * 0.35 +
            score.fluency * 0.2) /
        100;
    return value.clamp(0.0, 1.0);
  }

  String _normalize(String input) {
    return input.replaceAll(
      RegExp(r"""[\s，。！？；、“”‘’：,.!?;:"'()（）《》〈〉【】\[\]-]"""),
      '',
    );
  }
}
