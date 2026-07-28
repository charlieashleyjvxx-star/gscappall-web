import 'dart:convert';

import '../../domain/poem.dart';
import '../../domain/practice_models.dart';
import '../../domain/repositories/poem_repository.dart';
import '../../domain/repositories/practice_repository.dart';
import '../../services/game/challenge_progress_service.dart';
import '../local/app_database.dart';

class LocalPracticeRepository implements PracticeRepository {
  LocalPracticeRepository({
    required AppDatabase database,
    required PoemRepository poemRepository,
  }) : _database = database,
       _poemRepository = poemRepository;

  final AppDatabase _database;
  final PoemRepository _poemRepository;

  @override
  Future<List<Poem>> fetchPracticePoems({int limit = 60}) async {
    final poems = await _poemRepository.fetchPoems();
    return poems.length <= limit
        ? poems
        : poems.take(limit).toList(growable: false);
  }

  @override
  Future<PracticeSession> createSession({
    required PracticeMode mode,
    int? poemId,
    DictationDifficulty difficulty = DictationDifficulty.standard,
    DictationAnswerMode answerMode = DictationAnswerMode.fullText,
  }) async {
    final poem =
        poemId == null
            ? await _pickDefaultPoem()
            : await _poemRepository.fetchPoemById(poemId);
    if (poem == null) {
      throw StateError('No poem is available for practice.');
    }

    final lines = poem.lines.isEmpty ? [poem.content] : poem.lines;
    final questions = <PracticeQuestion>[
      for (var index = 0; index < lines.length; index++)
        PracticeQuestion(
          poemId: poem.id,
          poemTitle: poem.title,
          poemAuthor: poem.author,
          lineIndex: index,
          prompt: _buildPrompt(
            poemTitle: poem.title,
            lineIndex: index,
            expectedAnswer: lines[index].trim(),
            difficulty: difficulty,
            answerMode: answerMode,
          ),
          hint: _buildHint(
            lines: lines,
            index: index,
            difficulty: difficulty,
            answerMode: answerMode,
          ),
          expectedAnswer: lines[index].trim(),
          knowledgePoint: '${poem.title} #${index + 1}',
        ),
    ];

    return PracticeSession(
      sessionId:
          '${poem.id}-${mode.rawValue}-${DateTime.now().millisecondsSinceEpoch}',
      mode: mode,
      poem: poem,
      questions: questions,
      startedAt: DateTime.now(),
      difficulty: difficulty,
      answerMode: answerMode,
    );
  }

  @override
  PracticeLineResult evaluateAnswer({
    required PracticeQuestion question,
    required String answer,
  }) {
    final trimmedAnswer = answer.trim();
    final expected = question.expectedAnswer.trim();
    final normalizedAnswer = _normalizeStrict(trimmedAnswer);
    final normalizedExpected = _normalizeStrict(expected);
    final looseAnswer = _normalizeLoose(trimmedAnswer);
    final looseExpected = _normalizeLoose(expected);

    if (trimmedAnswer.isEmpty) {
      return PracticeLineResult(
        question: question,
        answer: trimmedAnswer,
        isCorrect: false,
        score: 0,
        feedback: 'No answer yet. Use the hint, then try this line again.',
        mistakeType: PracticeMistakeType.blankAnswer,
        characterAnalysis: _characterIssues(trimmedAnswer, expected),
      );
    }

    if (normalizedAnswer == normalizedExpected) {
      return PracticeLineResult(
        question: question,
        answer: trimmedAnswer,
        isCorrect: true,
        score: 100,
        feedback: 'Correct. Keep going.',
      );
    }

    if (looseAnswer == looseExpected) {
      return PracticeLineResult(
        question: question,
        answer: trimmedAnswer,
        isCorrect: false,
        score: 85,
        feedback:
            'The words are right, but punctuation or spacing needs polish.',
        mistakeType: PracticeMistakeType.punctuationError,
        characterAnalysis: _characterIssues(trimmedAnswer, expected),
      );
    }

    final overlap = _characterOverlapRatio(looseAnswer, looseExpected);
    if (looseAnswer.length < looseExpected.length) {
      return PracticeLineResult(
        question: question,
        answer: trimmedAnswer,
        isCorrect: false,
        score: (overlap * 75).round().clamp(15, 74),
        feedback: 'Some characters are missing. Rebuild the line by rhythm.',
        mistakeType: PracticeMistakeType.missingCharacters,
        characterAnalysis: _characterIssues(trimmedAnswer, expected),
      );
    }

    if (looseAnswer.length > looseExpected.length) {
      return PracticeLineResult(
        question: question,
        answer: trimmedAnswer,
        isCorrect: false,
        score: (overlap * 70).round().clamp(10, 72),
        feedback: 'Extra characters or mixed lines were found.',
        mistakeType: PracticeMistakeType.extraCharacters,
        characterAnalysis: _characterIssues(trimmedAnswer, expected),
      );
    }

    return PracticeLineResult(
      question: question,
      answer: trimmedAnswer,
      isCorrect: false,
      score: (overlap * 65).round().clamp(10, 68),
      feedback: 'This line does not match the expected answer.',
      mistakeType: PracticeMistakeType.lineMismatch,
      characterAnalysis: _characterIssues(trimmedAnswer, expected),
    );
  }

  @override
  Future<PracticeReport> completeSession({
    required PracticeSession session,
    required Map<int, String> answers,
  }) async {
    final results = <PracticeLineResult>[
      for (var index = 0; index < session.questions.length; index++)
        evaluateAnswer(
          question: session.questions[index],
          answer: answers[index] ?? '',
        ),
    ];
    final totalScore = _averageScore(results);
    final report = PracticeReport(
      sessionId: session.sessionId,
      mode: session.mode,
      poem: session.poem,
      results: results,
      totalScore: totalScore,
      correctCount: results.where((result) => result.isCorrect).length,
      generatedWrongCount: results.where((result) => !result.isCorrect).length,
      suggestions: _buildSuggestions(
        mode: session.mode,
        totalScore: totalScore,
        results: results,
      ),
      completedAt: DateTime.now(),
    );
    await _persistReport(report);
    return report;
  }

  @override
  Future<PracticeReport> saveAssessmentReport({
    required Poem poem,
    required PracticeMode mode,
    required List<PracticeLineResult> results,
    DateTime? completedAt,
  }) async {
    final resolvedCompletedAt = completedAt ?? DateTime.now();
    final totalScore = _averageScore(results);
    final report = PracticeReport(
      sessionId:
          '${poem.id}-${mode.rawValue}-${resolvedCompletedAt.microsecondsSinceEpoch}',
      mode: mode,
      poem: poem,
      results: results,
      totalScore: totalScore,
      correctCount: results.where((result) => result.isCorrect).length,
      generatedWrongCount: results.where((result) => !result.isCorrect).length,
      suggestions: _buildSuggestions(
        mode: mode,
        totalScore: totalScore,
        results: results,
      ),
      completedAt: resolvedCompletedAt,
    );
    await _persistReport(report);
    return report;
  }

  @override
  Future<List<PracticeReportSummary>> fetchPracticeReportSummaries({
    int limit = 100,
  }) async {
    final overview = await fetchPracticeReportOverview(
      query: PracticeReportQuery(limit: limit),
    );
    return overview.summaries;
  }

  @override
  Future<PracticeReportOverview> fetchPracticeReportOverview({
    PracticeReportQuery query = const PracticeReportQuery(),
  }) async {
    final profileId = await _database.activeProfileId();
    final conditions = _practiceReportConditions(profileId, query);
    final whereClause = conditions.join(' AND ');
    final rows = await _database.selectList('''
      SELECT r.*, p.title, p.author
      FROM practice_reports r
      INNER JOIN poems p ON p.id = r.poem_id
      WHERE $whereClause
      ORDER BY r.completed_at DESC, r.id DESC
      LIMIT ${query.limit};
    ''');
    return PracticeReportOverview(
      summaries: rows
          .map(PracticeReportSummary.fromRow)
          .toList(growable: false),
      stats: await _fetchPracticeReportStats(whereClause),
    );
  }

  @override
  Future<PracticeReportDetail?> fetchPracticeReportDetail(int id) async {
    final profileId = await _database.activeProfileId();
    final row = await _database.selectSingle('''
      SELECT r.*, p.title, p.author
      FROM practice_reports r
      INNER JOIN poems p ON p.id = r.poem_id
      WHERE r.profile_id = $profileId AND r.id = $id
      LIMIT 1;
    ''');
    if (row == null) {
      return null;
    }
    final itemRows = await _database.selectList('''
      SELECT *
      FROM practice_report_items
      WHERE report_id = $id
      ORDER BY line_index ASC, id ASC;
    ''');
    return PracticeReportDetail(
      summary: PracticeReportSummary.fromRow(row),
      items: itemRows.map(PracticeReportItem.fromRow).toList(growable: false),
      suggestions: _decodeSuggestionList(
        row['suggestions_json'] as String? ?? '[]',
      ),
    );
  }

  @override
  Future<List<WrongQuestionEntry>> fetchWrongQuestions({
    WrongQuestionQuery query = const WrongQuestionQuery(),
  }) async {
    final profileId = await _database.activeProfileId();
    final conditions = <String>['w.profile_id = $profileId'];
    if (query.practiceMode != null) {
      conditions.add(
        'w.question_type = ${sqlString(query.practiceMode!.rawValue)}',
      );
    }
    if (query.mistakeType != null) {
      conditions.add('w.rule_tag = ${sqlString(query.mistakeType!.rawValue)}');
    }
    if (query.severity != null && query.severity!.trim().isNotEmpty) {
      conditions.add('w.severity = ${sqlString(query.severity!.trim())}');
    }
    if (query.stageId != null && query.stageId!.trim().isNotEmpty) {
      conditions.add('w.stage_id = ${sqlString(query.stageId!.trim())}');
    }
    if (query.onlyUnreviewed) {
      conditions.add('w.reviewed_at IS NULL');
    }
    final rows = await _database.selectList('''
      SELECT w.*, p.title, p.author
      FROM wrong_questions w
      INNER JOIN poems p ON p.id = w.poem_id
      WHERE ${conditions.join(' AND ')}
      ORDER BY w.created_at DESC, w.id DESC
      LIMIT ${query.limit};
    ''');
    final entries = rows
        .map(WrongQuestionEntry.fromRow)
        .toList(growable: false);
    final knowledgePoint = query.knowledgePoint?.trim();
    if (knowledgePoint == null || knowledgePoint.isEmpty) {
      return entries;
    }
    return entries
        .where((entry) => entry.knowledgePoint == knowledgePoint)
        .toList(growable: false);
  }

  @override
  Future<WrongQuestionEntry?> fetchWrongQuestionDetail(int id) async {
    final profileId = await _database.activeProfileId();
    final row = await _database.selectSingle('''
      SELECT w.*, p.title, p.author
      FROM wrong_questions w
      INNER JOIN poems p ON p.id = w.poem_id
      WHERE w.profile_id = $profileId AND w.id = $id
      LIMIT 1;
    ''');
    return row == null ? null : WrongQuestionEntry.fromRow(row);
  }

  @override
  Future<void> markWrongQuestionReviewed(int id) async {
    final profileId = await _database.activeProfileId();
    final now = DateTime.now().toUtc().toIso8601String();
    final mutationId = nextClientMutationId('wrong-review');
    final deviceId = currentActorDeviceId();
    await _database.customStatement('''
      UPDATE wrong_questions
      SET reviewed_at = ${sqlString(now)},
          updated_at = ${sqlString(now)},
          client_mutation_id = ${sqlString(mutationId)},
          last_actor_device_id = ${sqlString(deviceId)},
          sync_status = 'pending_push'
      WHERE profile_id = $profileId AND id = $id;
    ''');
  }

  Future<void> _persistReport(PracticeReport report) async {
    final profileId = await _database.activeProfileId();
    final now = report.completedAt.toUtc().toIso8601String();
    final durationMinutes =
        report.results.length < 3 ? 3 : report.results.length;
    final deviceId = currentActorDeviceId();
    final stageId =
        report.mode == PracticeMode.dictation
            ? const ChallengeProgressService().stageIdForResult(
              mode: 'dictation',
              score: report.totalScore,
              completedLines: report.totalQuestions,
            )
            : null;

    await _database.transaction(() async {
      await _database.customStatement('''
        INSERT INTO practice_reports (
          profile_id, session_id, mode, poem_id, total_score, correct_count,
          total_questions, generated_wrong_count, suggestions_json,
          stage_id, completed_at, client_mutation_id, last_actor_device_id,
          sync_status, created_at, updated_at
        )
        VALUES (
          $profileId,
          ${sqlString(report.sessionId)},
          ${sqlString(report.mode.rawValue)},
          ${report.poem.id},
          ${report.totalScore},
          ${report.correctCount},
          ${report.totalQuestions},
          ${report.generatedWrongCount},
          ${sqlString(jsonEncode(report.suggestions))},
          ${sqlNullable(stageId)},
          ${sqlString(now)},
          ${sqlString(nextClientMutationId('practice-report'))},
          ${sqlString(deviceId)},
          'pending_push',
          ${sqlString(now)},
          ${sqlString(now)}
        );
      ''');
      final reportIdRow = await _database.selectSingle(
        'SELECT last_insert_rowid() AS id;',
      );
      final reportId = (reportIdRow?['id'] as int?) ?? 0;

      for (final result in report.results) {
        await _database.customStatement('''
          INSERT INTO practice_report_items (
            report_id, line_index, prompt, hint, expected_answer, user_answer,
            is_correct, score, feedback, mistake_type, assessment_engine,
            assessment_confidence, assessment_accuracy, assessment_fluency,
            assessment_integrity, assessment_basis, assessment_audio_path,
            assessment_payload_json
          )
          VALUES (
            $reportId,
            ${result.question.lineIndex},
            ${sqlString(result.question.prompt)},
            ${sqlString(result.question.hint)},
            ${sqlString(result.question.expectedAnswer)},
            ${sqlString(result.answer)},
            ${result.isCorrect ? 1 : 0},
            ${result.score},
            ${sqlString(result.feedback)},
            ${sqlNullable(result.mistakeType?.rawValue)},
            ${sqlNullable(result.assessment?.engine)},
            ${result.assessment == null ? 'NULL' : result.assessment!.confidence},
            ${result.assessment == null ? 'NULL' : result.assessment!.accuracy},
            ${result.assessment == null ? 'NULL' : result.assessment!.fluency},
            ${result.assessment == null ? 'NULL' : result.assessment!.integrity},
            ${sqlNullable(result.assessment?.assessmentBasis)},
            ${sqlNullable(result.assessment?.audioFilePath)},
            ${sqlNullable(result.assessment?.rawPayloadJson)}
          );
        ''');
      }

      await _database.customStatement('''
        INSERT INTO learning_records (
          profile_id, poem_id, mode, duration_minutes, score, note, stage_id,
          client_mutation_id, last_actor_device_id, sync_status, created_at,
          updated_at
        )
        VALUES (
          $profileId,
          ${report.poem.id},
          ${sqlString(report.mode.rawValue)},
          $durationMinutes,
          ${report.totalScore},
          ${sqlString(_buildLearningNote(report))},
          ${sqlNullable(stageId)},
          ${sqlString(nextClientMutationId('practice-learning'))},
          ${sqlString(deviceId)},
          'pending_push',
          ${sqlString(now)},
          ${sqlString(now)}
        );
      ''');

      await _database.customStatement('''
        INSERT INTO recite_records (
          profile_id, poem_id, score, recognized_text, client_mutation_id,
          last_actor_device_id, sync_status, created_at, updated_at
        )
        VALUES (
          $profileId,
          ${report.poem.id},
          ${report.totalScore},
          ${sqlString(report.reviewAnswerText)},
          ${sqlString(nextClientMutationId('practice-recite'))},
          ${sqlString(deviceId)},
          'pending_push',
          ${sqlString(now)},
          ${sqlString(now)}
        );
      ''');

      for (final result in report.results.where(
        (item) => !item.isCorrect && item.mistakeType != null,
      )) {
        await _database.customStatement('''
          INSERT INTO wrong_questions (
            profile_id, poem_id, question_type, prompt, correct_answer,
            user_answer, rule_tag, severity, stage_id, client_mutation_id,
            last_actor_device_id, sync_status, created_at, updated_at
          )
          VALUES (
            $profileId,
            ${report.poem.id},
            ${sqlString(report.mode.rawValue)},
            ${sqlString(result.question.prompt)},
            ${sqlString(result.question.expectedAnswer)},
            ${sqlString(result.answer)},
            ${sqlString(result.mistakeType!.rawValue)},
            ${sqlString(_severityForScore(result.score))},
            ${sqlNullable(stageId)},
            ${sqlString(nextClientMutationId('practice-wrong'))},
            ${sqlString(deviceId)},
            'pending_push',
            ${sqlString(now)},
            ${sqlString(now)}
          );
        ''');
      }
    });
  }

  List<String> _practiceReportConditions(
    int profileId,
    PracticeReportQuery query,
  ) {
    final conditions = <String>['r.profile_id = $profileId'];
    if (query.mode != null) {
      conditions.add('r.mode = ${sqlString(query.mode!.rawValue)}');
    }
    if (query.scoreBand != null) {
      conditions.add(
        'r.total_score BETWEEN ${query.scoreBand!.minScore} AND ${query.scoreBand!.maxScore}',
      );
    }
    if (query.mistakeType != null) {
      conditions.add('''
        EXISTS (
          SELECT 1
          FROM practice_report_items filtered_items
          WHERE filtered_items.report_id = r.id
            AND filtered_items.mistake_type = ${sqlString(query.mistakeType!.rawValue)}
        )
      ''');
    }
    if (query.stageId != null && query.stageId!.trim().isNotEmpty) {
      conditions.add('r.stage_id = ${sqlString(query.stageId!.trim())}');
    }
    return conditions;
  }

  Future<PracticeReportStats> _fetchPracticeReportStats(
    String whereClause,
  ) async {
    final row = await _database.selectSingle('''
      SELECT
        COUNT(*) AS total_reports,
        COALESCE(ROUND(AVG(r.total_score)), 0) AS average_score,
        SUM(CASE WHEN r.mode = 'dictation' THEN 1 ELSE 0 END) AS dictation_count,
        SUM(CASE WHEN r.mode = 'evaluation' THEN 1 ELSE 0 END) AS evaluation_count,
        SUM(CASE WHEN r.mode = 'reading' THEN 1 ELSE 0 END) AS reading_count,
        SUM(CASE WHEN r.mode = 'recitation' THEN 1 ELSE 0 END) AS recitation_count,
        SUM(CASE WHEN r.total_score BETWEEN 90 AND 100 THEN 1 ELSE 0 END) AS excellent_count,
        SUM(CASE WHEN r.total_score BETWEEN 75 AND 89 THEN 1 ELSE 0 END) AS solid_count,
        SUM(CASE WHEN r.total_score BETWEEN 60 AND 74 THEN 1 ELSE 0 END) AS review_count,
        SUM(CASE WHEN r.total_score BETWEEN 0 AND 59 THEN 1 ELSE 0 END) AS retry_count
      FROM practice_reports r
      WHERE $whereClause;
    ''');
    final mistakeRows = await _database.selectList('''
      SELECT i.mistake_type, COUNT(*) AS count
      FROM practice_report_items i
      INNER JOIN practice_reports r ON r.id = i.report_id
      WHERE $whereClause AND i.mistake_type IS NOT NULL
      GROUP BY i.mistake_type;
    ''');
    final mistakeTypes = <PracticeMistakeType, int>{
      for (final type in PracticeMistakeType.values) type: 0,
    };
    for (final mistakeRow in mistakeRows) {
      final rawType = mistakeRow['mistake_type'] as String?;
      if (rawType == null || rawType.isEmpty) {
        continue;
      }
      mistakeTypes[PracticeMistakeType.fromRaw(rawType)] = _intValue(
        mistakeRow['count'],
      );
    }
    return PracticeReportStats(
      totalReports: _intValue(row?['total_reports']),
      dictationCount: _intValue(row?['dictation_count']),
      evaluationCount: _intValue(row?['evaluation_count']),
      readingCount: _intValue(row?['reading_count']),
      recitationCount: _intValue(row?['recitation_count']),
      averageScore: _intValue(row?['average_score']),
      scoreBands: {
        PracticeScoreBand.excellent: _intValue(row?['excellent_count']),
        PracticeScoreBand.solid: _intValue(row?['solid_count']),
        PracticeScoreBand.review: _intValue(row?['review_count']),
        PracticeScoreBand.retry: _intValue(row?['retry_count']),
      },
      mistakeTypes: mistakeTypes,
    );
  }

  Future<Poem?> _pickDefaultPoem() async {
    final profileId = await _database.activeProfileId();
    final row = await _database.selectSingle('''
      SELECT p.id
      FROM poems p
      LEFT JOIN learning_records l ON l.poem_id = p.id AND l.profile_id = $profileId
      WHERE p.deleted_at IS NULL
      GROUP BY p.id
      ORDER BY COUNT(l.id) ASC, p.grade ASC, p.id ASC
      LIMIT 1;
    ''');
    final poemId = (row?['id'] as int?) ?? 0;
    if (poemId <= 0) {
      final poems = await _poemRepository.fetchPoems();
      return poems.isEmpty ? null : poems.first;
    }
    return _poemRepository.fetchPoemById(poemId);
  }

  List<String> _buildSuggestions({
    required PracticeMode mode,
    required int totalScore,
    required List<PracticeLineResult> results,
  }) {
    final suggestions = <String>[];
    final mistakeCounters = <PracticeMistakeType, int>{};
    for (final result in results) {
      final mistakeType = result.mistakeType;
      if (mistakeType != null) {
        mistakeCounters[mistakeType] = (mistakeCounters[mistakeType] ?? 0) + 1;
      }
    }
    if (totalScore >= 90) {
      suggestions.add('Stable mastery. Try recitation or reading next.');
    } else if (totalScore >= 75) {
      suggestions.add('Good foundation. Retry the missed lines first.');
    } else if (totalScore >= 60) {
      suggestions.add('Review the study card, then run dictation again.');
    } else {
      suggestions.add('Many lines need review. Read the source poem first.');
    }
    final dominantEntry = mistakeCounters.entries.toList(growable: false)
      ..sort((left, right) => right.value.compareTo(left.value));
    if (dominantEntry.isNotEmpty) {
      suggestions.add(switch (dominantEntry.first.key) {
        PracticeMistakeType.blankAnswer =>
          'Use line-by-line hints before retrying.',
        PracticeMistakeType.punctuationError =>
          'Remember punctuation and pauses.',
        PracticeMistakeType.missingCharacters =>
          'Break the line into rhythm chunks.',
        PracticeMistakeType.extraCharacters =>
          'Focus on the current line only.',
        PracticeMistakeType.lineMismatch => 'Review title, author, and theme.',
      });
    }
    if (mode == PracticeMode.evaluation && totalScore < 85) {
      suggestions.add('Use the wrong book filters to review weak points.');
    }
    return suggestions;
  }

  List<String> _decodeSuggestionList(String rawJson) {
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! List) {
        return const [];
      }
      return decoded
          .whereType<String>()
          .where((item) => item.trim().isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  String _buildPrompt({
    required String poemTitle,
    required int lineIndex,
    required String expectedAnswer,
    required DictationDifficulty difficulty,
    required DictationAnswerMode answerMode,
  }) {
    final lineLabel = '《$poemTitle》第 ${lineIndex + 1} 句';
    if (answerMode == DictationAnswerMode.fillBlank) {
      return '$lineLabel：补上空缺的字。\n${_maskLine(expectedAnswer, difficulty)}';
    }
    return '默写$lineLabel。';
  }

  String _buildHint({
    required List<String> lines,
    required int index,
    required DictationDifficulty difficulty,
    required DictationAnswerMode answerMode,
  }) {
    final current = lines[index].trim();
    final currentChars = _chars(current);
    final pieces = <String>[];
    pieces.add(index == 0 ? '先想一想题目、作者和开头画面。' : '上一句：${lines[index - 1]}');
    if (difficulty.hintLevel >= 1 && currentChars.isNotEmpty) {
      pieces.add('第一个字：${currentChars.first}');
    }
    if (difficulty.hintLevel >= 2 && currentChars.length > 1) {
      pieces.add('最后一个字：${currentChars.last}');
    }
    if (answerMode == DictationAnswerMode.fillBlank) {
      pieces.add('可以只补空，也可以写完整一句。');
    }
    return pieces.join(' ');
  }

  String _maskLine(String line, DictationDifficulty difficulty) {
    final chars = _chars(line);
    if (chars.isEmpty) {
      return line;
    }
    final revealEvery = switch (difficulty) {
      DictationDifficulty.easy => 3,
      DictationDifficulty.standard => 4,
      DictationDifficulty.hard => 999,
    };
    return chars.asMap().entries.map((entry) {
      final char = entry.value;
      if (_isPunctuation(char)) {
        return char;
      }
      if (entry.key == 0 || (entry.key + 1) % revealEvery == 0) {
        return char;
      }
      return '_';
    }).join();
  }

  List<PracticeCharacterIssue> _characterIssues(
    String answer,
    String expected,
  ) {
    final actualChars = _chars(_normalizeLoose(answer));
    final expectedChars = _chars(_normalizeLoose(expected));
    final length =
        actualChars.length > expectedChars.length
            ? actualChars.length
            : expectedChars.length;
    final issues = <PracticeCharacterIssue>[];
    for (var index = 0; index < length; index++) {
      final actual = index < actualChars.length ? actualChars[index] : '';
      final expected = index < expectedChars.length ? expectedChars[index] : '';
      if (actual == expected) {
        continue;
      }
      final type =
          actual.isEmpty
              ? PracticeMistakeType.missingCharacters
              : expected.isEmpty
              ? PracticeMistakeType.extraCharacters
              : PracticeMistakeType.lineMismatch;
      issues.add(
        PracticeCharacterIssue(
          position: index + 1,
          expected: expected,
          actual: actual,
          type: type,
        ),
      );
      if (issues.length >= 8) {
        break;
      }
    }
    return issues;
  }

  String _buildLearningNote(PracticeReport report) {
    return '${report.mode.label} done: ${report.correctCount}/${report.totalQuestions} correct, ${report.generatedWrongCount} wrong questions.';
  }

  String _severityForScore(int score) {
    if (score >= 80) {
      return 'low';
    }
    if (score >= 45) {
      return 'medium';
    }
    return 'high';
  }

  int _averageScore(List<PracticeLineResult> results) {
    if (results.isEmpty) {
      return 0;
    }
    return (results.fold<int>(0, (sum, result) => sum + result.score) /
            results.length)
        .round();
  }

  int _intValue(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    return 0;
  }

  String _normalizeStrict(String input) {
    return input
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll('，', ',')
        .replaceAll('。', '.')
        .replaceAll('？', '?')
        .replaceAll('！', '!')
        .replaceAll('；', ';')
        .replaceAll('：', ':')
        .trim();
  }

  String _normalizeLoose(String input) {
    return _normalizeStrict(input).replaceAll(RegExp(r'[,.?!;:]'), '');
  }

  bool _isPunctuation(String input) {
    return RegExp(r'^[，。？！；：、,.?!;:]$').hasMatch(input);
  }

  double _characterOverlapRatio(String left, String right) {
    if (left.isEmpty || right.isEmpty) {
      return 0;
    }
    final leftChars = _chars(left);
    final rightChars = _chars(right);
    final minLength =
        leftChars.length < rightChars.length
            ? leftChars.length
            : rightChars.length;
    var sameCount = 0;
    for (var index = 0; index < minLength; index++) {
      if (leftChars[index] == rightChars[index]) {
        sameCount += 1;
      }
    }
    return sameCount / rightChars.length;
  }

  List<String> _chars(String input) {
    return input.runes
        .map((value) => String.fromCharCode(value))
        .toList(growable: false);
  }
}
