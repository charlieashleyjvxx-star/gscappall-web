import 'poem.dart';

enum PracticeMode {
  dictation('dictation', '听写'),
  evaluation('evaluation', '测评'),
  reading('reading', '朗读'),
  recitation('recitation', '背诵');

  const PracticeMode(this.rawValue, this.label);

  final String rawValue;
  final String label;

  static PracticeMode fromRaw(String rawValue) {
    return PracticeMode.values.firstWhere(
      (mode) => mode.rawValue == rawValue,
      orElse: () => PracticeMode.dictation,
    );
  }
}

enum PracticeMistakeType {
  blankAnswer('blank_answer', '未作答'),
  punctuationError('punctuation_error', '标点错误'),
  missingCharacters('missing_characters', '缺字漏字'),
  extraCharacters('extra_characters', '多字赘述'),
  lineMismatch('line_mismatch', '诗句不匹配');

  const PracticeMistakeType(this.rawValue, this.label);

  final String rawValue;
  final String label;

  static PracticeMistakeType fromRaw(String rawValue) {
    return PracticeMistakeType.values.firstWhere(
      (type) => type.rawValue == rawValue,
      orElse: () => PracticeMistakeType.lineMismatch,
    );
  }
}

enum DictationDifficulty {
  easy('easy', '轻松', 2),
  standard('standard', '标准', 1),
  hard('hard', '挑战', 0);

  const DictationDifficulty(this.rawValue, this.label, this.hintLevel);

  final String rawValue;
  final String label;
  final int hintLevel;
}

enum DictationAnswerMode {
  fillBlank('fill_blank', '填空'),
  fullText('full_text', '全文');

  const DictationAnswerMode(this.rawValue, this.label);

  final String rawValue;
  final String label;
}

class PracticeQuestion {
  const PracticeQuestion({
    required this.poemId,
    required this.poemTitle,
    required this.poemAuthor,
    required this.lineIndex,
    required this.prompt,
    required this.hint,
    required this.expectedAnswer,
    this.knowledgePoint,
  });

  final int poemId;
  final String poemTitle;
  final String poemAuthor;
  final int lineIndex;
  final String prompt;
  final String hint;
  final String expectedAnswer;
  final String? knowledgePoint;
}

class PracticeSession {
  const PracticeSession({
    required this.sessionId,
    required this.mode,
    required this.poem,
    required this.questions,
    required this.startedAt,
    this.difficulty = DictationDifficulty.standard,
    this.answerMode = DictationAnswerMode.fullText,
  });

  final String sessionId;
  final PracticeMode mode;
  final Poem poem;
  final List<PracticeQuestion> questions;
  final DateTime startedAt;
  final DictationDifficulty difficulty;
  final DictationAnswerMode answerMode;
}

class PracticeLineResult {
  const PracticeLineResult({
    required this.question,
    required this.answer,
    required this.isCorrect,
    required this.score,
    required this.feedback,
    this.mistakeType,
    this.assessment,
    this.characterAnalysis = const [],
  });

  final PracticeQuestion question;
  final String answer;
  final bool isCorrect;
  final int score;
  final String feedback;
  final PracticeMistakeType? mistakeType;
  final PracticeAssessmentMetrics? assessment;
  final List<PracticeCharacterIssue> characterAnalysis;
}

class PracticeCharacterIssue {
  const PracticeCharacterIssue({
    required this.position,
    required this.expected,
    required this.actual,
    required this.type,
  });

  final int position;
  final String expected;
  final String actual;
  final PracticeMistakeType type;

  String get label {
    final expectedLabel = expected.isEmpty ? '缺字' : expected;
    final actualLabel = actual.isEmpty ? '漏写' : actual;
    return '第 $position 字：应为“$expectedLabel”，写成“$actualLabel”';
  }
}

class PracticeAssessmentMetrics {
  const PracticeAssessmentMetrics({
    required this.engine,
    required this.confidence,
    required this.accuracy,
    required this.fluency,
    required this.integrity,
    this.assessmentBasis,
    this.audioFilePath,
    this.rawPayloadJson,
  });

  const PracticeAssessmentMetrics.empty()
    : engine = '',
      confidence = 0,
      accuracy = 0,
      fluency = 0,
      integrity = 0,
      assessmentBasis = null,
      audioFilePath = null,
      rawPayloadJson = null;

  factory PracticeAssessmentMetrics.fromRow(Map<String, Object?> row) {
    final engine = row['assessment_engine'] as String?;
    if (engine == null || engine.trim().isEmpty) {
      return const PracticeAssessmentMetrics.empty();
    }
    return PracticeAssessmentMetrics(
      engine: engine,
      confidence: _doubleValue(row['assessment_confidence']),
      accuracy: _intValue(row['assessment_accuracy']),
      fluency: _intValue(row['assessment_fluency']),
      integrity: _intValue(row['assessment_integrity']),
      assessmentBasis: row['assessment_basis'] as String?,
      audioFilePath: row['assessment_audio_path'] as String?,
      rawPayloadJson: row['assessment_payload_json'] as String?,
    );
  }

  final String engine;
  final double confidence;
  final int accuracy;
  final int fluency;
  final int integrity;
  final String? assessmentBasis;
  final String? audioFilePath;
  final String? rawPayloadJson;

  bool get hasData => engine.trim().isNotEmpty;

  static int _intValue(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    return 0;
  }

  static double _doubleValue(Object? value) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    return 0;
  }
}

class PracticeReport {
  const PracticeReport({
    required this.sessionId,
    required this.mode,
    required this.poem,
    required this.results,
    required this.totalScore,
    required this.correctCount,
    required this.generatedWrongCount,
    required this.suggestions,
    required this.completedAt,
  });

  final String sessionId;
  final PracticeMode mode;
  final Poem poem;
  final List<PracticeLineResult> results;
  final int totalScore;
  final int correctCount;
  final int generatedWrongCount;
  final List<String> suggestions;
  final DateTime completedAt;

  int get totalQuestions => results.length;

  double get accuracy =>
      totalQuestions == 0 ? 0 : correctCount / totalQuestions;

  String get scoreLevel {
    if (totalScore >= 90) {
      return '掌握稳定';
    }
    if (totalScore >= 75) {
      return '继续巩固';
    }
    if (totalScore >= 60) {
      return '需要复盘';
    }
    return '建议重练';
  }

  String get summaryLabel => '${mode.label} · $scoreLevel';

  PracticeMistakeType? get dominantMistakeType {
    final counters = <PracticeMistakeType, int>{};
    for (final result in results) {
      final mistakeType = result.mistakeType;
      if (mistakeType == null) {
        continue;
      }
      counters[mistakeType] = (counters[mistakeType] ?? 0) + 1;
    }
    if (counters.isEmpty) {
      return null;
    }
    final sortedEntries = counters.entries.toList(growable: false)
      ..sort((left, right) => right.value.compareTo(left.value));
    return sortedEntries.first.key;
  }

  String get reviewAnswerText =>
      results.map((result) => result.answer).join('\n');
}

class PracticeReportSummary {
  const PracticeReportSummary({
    required this.id,
    required this.sessionId,
    required this.mode,
    required this.poemId,
    required this.poemTitle,
    required this.poemAuthor,
    required this.totalScore,
    required this.correctCount,
    required this.totalQuestions,
    required this.generatedWrongCount,
    required this.completedAt,
    this.stageId,
  });

  factory PracticeReportSummary.fromRow(Map<String, Object?> row) {
    return PracticeReportSummary(
      id: (row['id'] as int?) ?? 0,
      sessionId: row['session_id'] as String? ?? '',
      mode: PracticeMode.fromRaw(row['mode'] as String? ?? 'dictation'),
      poemId: (row['poem_id'] as int?) ?? 0,
      poemTitle: row['title'] as String? ?? '',
      poemAuthor: row['author'] as String? ?? '',
      totalScore: (row['total_score'] as int?) ?? 0,
      correctCount: (row['correct_count'] as int?) ?? 0,
      totalQuestions: (row['total_questions'] as int?) ?? 0,
      generatedWrongCount: (row['generated_wrong_count'] as int?) ?? 0,
      completedAt:
          DateTime.tryParse(row['completed_at'] as String? ?? '') ??
          DateTime.now(),
      stageId: row['stage_id'] as String?,
    );
  }

  final int id;
  final String sessionId;
  final PracticeMode mode;
  final int poemId;
  final String poemTitle;
  final String poemAuthor;
  final int totalScore;
  final int correctCount;
  final int totalQuestions;
  final int generatedWrongCount;
  final DateTime completedAt;
  final String? stageId;
}

class PracticeReportDetail {
  const PracticeReportDetail({
    required this.summary,
    required this.items,
    required this.suggestions,
  });

  final PracticeReportSummary summary;
  final List<PracticeReportItem> items;
  final List<String> suggestions;
}

enum PracticeScoreBand {
  excellent('excellent', '90 分以上', 90, 100),
  solid('solid', '75-89 分', 75, 89),
  review('review', '60-74 分', 60, 74),
  retry('retry', '60 分以下', 0, 59);

  const PracticeScoreBand(
    this.rawValue,
    this.label,
    this.minScore,
    this.maxScore,
  );

  final String rawValue;
  final String label;
  final int minScore;
  final int maxScore;

  bool contains(int score) => score >= minScore && score <= maxScore;
}

class PracticeReportQuery {
  const PracticeReportQuery({
    this.mode,
    this.scoreBand,
    this.mistakeType,
    this.stageId,
    this.limit = 200,
  });

  final PracticeMode? mode;
  final PracticeScoreBand? scoreBand;
  final PracticeMistakeType? mistakeType;
  final String? stageId;
  final int limit;

  PracticeReportQuery copyWith({
    PracticeMode? mode,
    PracticeScoreBand? scoreBand,
    PracticeMistakeType? mistakeType,
    String? stageId,
    int? limit,
    bool clearMode = false,
    bool clearScoreBand = false,
    bool clearMistakeType = false,
    bool clearStageId = false,
  }) {
    return PracticeReportQuery(
      mode: clearMode ? null : (mode ?? this.mode),
      scoreBand: clearScoreBand ? null : (scoreBand ?? this.scoreBand),
      mistakeType: clearMistakeType ? null : (mistakeType ?? this.mistakeType),
      stageId: clearStageId ? null : (stageId ?? this.stageId),
      limit: limit ?? this.limit,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is PracticeReportQuery &&
        other.mode == mode &&
        other.scoreBand == scoreBand &&
        other.mistakeType == mistakeType &&
        other.stageId == stageId &&
        other.limit == limit;
  }

  @override
  int get hashCode => Object.hash(mode, scoreBand, mistakeType, stageId, limit);
}

class PracticeReportOverview {
  const PracticeReportOverview({required this.summaries, required this.stats});

  final List<PracticeReportSummary> summaries;
  final PracticeReportStats stats;
}

class PracticeReportStats {
  const PracticeReportStats({
    required this.totalReports,
    required this.dictationCount,
    required this.evaluationCount,
    required this.readingCount,
    required this.recitationCount,
    required this.averageScore,
    required this.scoreBands,
    required this.mistakeTypes,
  });

  final int totalReports;
  final int dictationCount;
  final int evaluationCount;
  final int readingCount;
  final int recitationCount;
  final int averageScore;
  final Map<PracticeScoreBand, int> scoreBands;
  final Map<PracticeMistakeType, int> mistakeTypes;
}

class PracticeReportItem {
  const PracticeReportItem({
    required this.lineIndex,
    required this.prompt,
    required this.hint,
    required this.expectedAnswer,
    required this.userAnswer,
    required this.isCorrect,
    required this.score,
    required this.feedback,
    this.mistakeType,
    this.assessment = const PracticeAssessmentMetrics.empty(),
  });

  factory PracticeReportItem.fromRow(Map<String, Object?> row) {
    final rawMistakeType = row['mistake_type'] as String?;
    return PracticeReportItem(
      lineIndex: (row['line_index'] as int?) ?? 0,
      prompt: row['prompt'] as String? ?? '',
      hint: row['hint'] as String? ?? '',
      expectedAnswer: row['expected_answer'] as String? ?? '',
      userAnswer: row['user_answer'] as String? ?? '',
      isCorrect: ((row['is_correct'] as int?) ?? 0) == 1,
      score: (row['score'] as int?) ?? 0,
      feedback: row['feedback'] as String? ?? '',
      mistakeType:
          rawMistakeType == null || rawMistakeType.isEmpty
              ? null
              : PracticeMistakeType.fromRaw(rawMistakeType),
      assessment: PracticeAssessmentMetrics.fromRow(row),
    );
  }

  final int lineIndex;
  final String prompt;
  final String hint;
  final String expectedAnswer;
  final String userAnswer;
  final bool isCorrect;
  final int score;
  final String feedback;
  final PracticeMistakeType? mistakeType;
  final PracticeAssessmentMetrics assessment;
}

class WrongQuestionQuery {
  const WrongQuestionQuery({
    this.practiceMode,
    this.mistakeType,
    this.severity,
    this.knowledgePoint,
    this.stageId,
    this.onlyUnreviewed = false,
    this.limit = 200,
  });

  final PracticeMode? practiceMode;
  final PracticeMistakeType? mistakeType;
  final String? severity;
  final String? knowledgePoint;
  final String? stageId;
  final bool onlyUnreviewed;
  final int limit;

  @override
  bool operator ==(Object other) {
    return other is WrongQuestionQuery &&
        other.practiceMode == practiceMode &&
        other.mistakeType == mistakeType &&
        other.severity == severity &&
        other.knowledgePoint == knowledgePoint &&
        other.stageId == stageId &&
        other.onlyUnreviewed == onlyUnreviewed &&
        other.limit == limit;
  }

  @override
  int get hashCode => Object.hash(
    practiceMode,
    mistakeType,
    severity,
    knowledgePoint,
    stageId,
    onlyUnreviewed,
    limit,
  );
}

class WrongQuestionEntry {
  const WrongQuestionEntry({
    required this.id,
    required this.poemId,
    required this.poemTitle,
    required this.poemAuthor,
    required this.questionType,
    required this.prompt,
    required this.correctAnswer,
    required this.userAnswer,
    required this.mistakeType,
    required this.severity,
    required this.createdAt,
    this.stageId,
    this.reviewedAt,
  });

  factory WrongQuestionEntry.fromRow(Map<String, Object?> row) {
    return WrongQuestionEntry(
      id: (row['id'] as int?) ?? 0,
      poemId: (row['poem_id'] as int?) ?? 0,
      poemTitle: row['title'] as String? ?? '',
      poemAuthor: row['author'] as String? ?? '',
      questionType: PracticeMode.fromRaw(
        row['question_type'] as String? ?? 'dictation',
      ),
      prompt: row['prompt'] as String? ?? '',
      correctAnswer: row['correct_answer'] as String? ?? '',
      userAnswer: row['user_answer'] as String? ?? '',
      mistakeType: PracticeMistakeType.fromRaw(
        row['rule_tag'] as String? ?? '',
      ),
      severity: row['severity'] as String? ?? 'medium',
      createdAt:
          DateTime.tryParse(row['created_at'] as String? ?? '') ??
          DateTime.now(),
      stageId: row['stage_id'] as String?,
      reviewedAt: DateTime.tryParse(row['reviewed_at'] as String? ?? ''),
    );
  }

  final int id;
  final int poemId;
  final String poemTitle;
  final String poemAuthor;
  final PracticeMode questionType;
  final String prompt;
  final String correctAnswer;
  final String userAnswer;
  final PracticeMistakeType mistakeType;
  final String severity;
  final DateTime createdAt;
  final String? stageId;
  final DateTime? reviewedAt;

  bool get isReviewed => reviewedAt != null;

  String get knowledgePoint {
    final lineMatch = RegExp(r'第\s*(\d+)\s*句').firstMatch(prompt);
    final lineLabel = lineMatch == null ? '整首' : '第 ${lineMatch.group(1)} 句';
    return '$poemTitle · $lineLabel';
  }
}
