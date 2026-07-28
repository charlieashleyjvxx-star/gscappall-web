import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gscappall/app/app_providers.dart';
import 'package:gscappall/data/local/app_database.dart';
import 'package:gscappall/data/repositories/local_practice_repository.dart';
import 'package:gscappall/domain/learning_models.dart';
import 'package:gscappall/domain/poem.dart';
import 'package:gscappall/domain/practice_models.dart';
import 'package:gscappall/domain/repositories/poem_repository.dart';

void main() {
  test('practice completion persists report summaries and details', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    const now = '2026-05-08T10:00:00.000Z';
    const poem = Poem(
      id: 1,
      title: '静夜思',
      author: '李白',
      dynasty: '唐',
      grade: 1,
      gradeLabel: '一年级',
      category: '思乡',
      content: '床前明月光，\n疑是地上霜。',
      pinyin: '',
      annotation: '',
      translation: '',
      appreciation: '',
      authorIntro: '',
      extension: '',
      audioUrl: null,
      imageUrl: null,
      difficulty: 1,
    );

    await database.selectList('SELECT 1;');
    await database.customStatement('''
      INSERT INTO poems (
        id, title, author, dynasty, grade, grade_label, category, content,
        pinyin, annotation, translation, appreciation, author_intro,
        extension_text, difficulty, seed_version, sync_status, created_at,
        updated_at
      )
      VALUES (
        ${poem.id}, '${poem.title}', '${poem.author}', '${poem.dynasty}',
        ${poem.grade}, '${poem.gradeLabel}', '${poem.category}',
        '${poem.content}', '', '', '', '', '', '', ${poem.difficulty},
        'test', 'local', '$now', '$now'
      );
    ''');

    final repository = LocalPracticeRepository(
      database: database,
      poemRepository: const _FakePoemRepository(poem),
    );
    final session = await repository.createSession(
      mode: PracticeMode.dictation,
      poemId: poem.id,
    );

    final report = await repository.completeSession(
      session: session,
      answers: const {0: '床前明月光，', 1: '写错了'},
    );

    expect(report.totalQuestions, 2);
    expect(report.generatedWrongCount, 1);

    final summaries = await repository.fetchPracticeReportSummaries();
    expect(summaries, hasLength(1));
    expect(summaries.single.poemTitle, '静夜思');
    expect(summaries.single.generatedWrongCount, 1);

    final detail = await repository.fetchPracticeReportDetail(
      summaries.single.id,
    );
    expect(detail, isNotNull);
    expect(detail!.items, hasLength(2));
    expect(detail.items.first.isCorrect, isTrue);
    expect(detail.items.last.isCorrect, isFalse);
    expect(detail.items.last.userAnswer, '写错了');
    expect(detail.suggestions, isNotEmpty);

    final wrongQuestions = await repository.fetchWrongQuestions(
      query: const WrongQuestionQuery(stageId: 'dictation_checkpoint'),
    );
    expect(wrongQuestions, hasLength(1));
    expect(wrongQuestions.single.stageId, 'dictation_checkpoint');
  });

  test(
    'practice report overview aggregates and filters in repository',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);

      const now = '2026-05-08T10:00:00.000Z';
      const poem = Poem(
        id: 1,
        title: '静夜思',
        author: '李白',
        dynasty: '唐',
        grade: 1,
        gradeLabel: '一年级',
        category: '思乡',
        content: '床前明月光，\n疑是地上霜。',
        pinyin: '',
        annotation: '',
        translation: '',
        appreciation: '',
        authorIntro: '',
        extension: '',
        audioUrl: null,
        imageUrl: null,
        difficulty: 1,
      );

      await database.selectList('SELECT 1;');
      await database.customStatement('''
      INSERT INTO poems (
        id, title, author, dynasty, grade, grade_label, category, content,
        pinyin, annotation, translation, appreciation, author_intro,
        extension_text, difficulty, seed_version, sync_status, created_at,
        updated_at
      )
      VALUES (
        ${poem.id}, '${poem.title}', '${poem.author}', '${poem.dynasty}',
        ${poem.grade}, '${poem.gradeLabel}', '${poem.category}',
        '${poem.content}', '', '', '', '', '', '', ${poem.difficulty},
        'test', 'local', '$now', '$now'
      );
    ''');

      final repository = LocalPracticeRepository(
        database: database,
        poemRepository: const _FakePoemRepository(poem),
      );
      final dictation = await repository.createSession(
        mode: PracticeMode.dictation,
        poemId: poem.id,
      );
      await repository.completeSession(
        session: dictation,
        answers: const {0: '床前明月光，', 1: '疑是地上霜。'},
      );

      final evaluation = await repository.createSession(
        mode: PracticeMode.evaluation,
        poemId: poem.id,
      );
      await repository.completeSession(
        session: evaluation,
        answers: const {0: '', 1: '写错了'},
      );

      final overview = await repository.fetchPracticeReportOverview();
      expect(overview.summaries, hasLength(2));
      expect(overview.stats.totalReports, 2);
      expect(overview.stats.dictationCount, 1);
      expect(overview.stats.evaluationCount, 1);
      expect(overview.stats.readingCount, 0);
      expect(overview.stats.recitationCount, 0);
      expect(overview.stats.scoreBands[PracticeScoreBand.excellent], 1);
      expect(
        overview.stats.mistakeTypes[PracticeMistakeType.blankAnswer],
        greaterThanOrEqualTo(1),
      );
      final dictationSummary = overview.summaries.firstWhere(
        (summary) => summary.mode == PracticeMode.dictation,
      );
      expect(dictationSummary.stageId, 'dictation_review');

      final dictationStageOnly = await repository.fetchPracticeReportOverview(
        query: const PracticeReportQuery(stageId: 'dictation_review'),
      );
      expect(dictationStageOnly.summaries, hasLength(1));
      expect(dictationStageOnly.summaries.single.mode, PracticeMode.dictation);

      final checkpointOnly = await repository.fetchPracticeReportOverview(
        query: const PracticeReportQuery(stageId: 'dictation_checkpoint'),
      );
      expect(checkpointOnly.summaries, isEmpty);

      final evaluationOnly = await repository.fetchPracticeReportOverview(
        query: const PracticeReportQuery(mode: PracticeMode.evaluation),
      );
      expect(evaluationOnly.summaries, hasLength(1));
      expect(evaluationOnly.stats.evaluationCount, 1);
      expect(evaluationOnly.stats.dictationCount, 0);

      final blankOnly = await repository.fetchPracticeReportOverview(
        query: const PracticeReportQuery(
          mistakeType: PracticeMistakeType.blankAnswer,
        ),
      );
      expect(blankOnly.summaries, hasLength(1));
      expect(blankOnly.summaries.single.mode, PracticeMode.evaluation);

      final excellentOnly = await repository.fetchPracticeReportOverview(
        query: const PracticeReportQuery(
          scoreBand: PracticeScoreBand.excellent,
        ),
      );
      expect(excellentOnly.summaries, hasLength(1));
      expect(excellentOnly.summaries.single.mode, PracticeMode.dictation);
    },
  );

  test(
    'speech assessment reports persist metrics and filter by practice mode',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);

      const now = '2026-05-08T10:00:00.000Z';
      const poem = Poem(
        id: 1,
        title: '静夜思',
        author: '李白',
        dynasty: '唐',
        grade: 1,
        gradeLabel: '一年级',
        category: '思乡',
        content: '床前明月光，\n疑是地上霜。',
        pinyin: '',
        annotation: '',
        translation: '',
        appreciation: '',
        authorIntro: '',
        extension: '',
        audioUrl: null,
        imageUrl: null,
        difficulty: 1,
      );

      await database.selectList('SELECT 1;');
      await database.customStatement('''
      INSERT INTO poems (
        id, title, author, dynasty, grade, grade_label, category, content,
        pinyin, annotation, translation, appreciation, author_intro,
        extension_text, difficulty, seed_version, sync_status, created_at,
        updated_at
      )
      VALUES (
        ${poem.id}, '${poem.title}', '${poem.author}', '${poem.dynasty}',
        ${poem.grade}, '${poem.gradeLabel}', '${poem.category}',
        '${poem.content}', '', '', '', '', '', '', ${poem.difficulty},
        'test', 'local', '$now', '$now'
      );
    ''');

      final repository = LocalPracticeRepository(
        database: database,
        poemRepository: const _FakePoemRepository(poem),
      );
      final readingReport = await repository.saveAssessmentReport(
        poem: poem,
        mode: PracticeMode.reading,
        results: const [
          PracticeLineResult(
            question: PracticeQuestion(
              poemId: 1,
              poemTitle: '静夜思',
              poemAuthor: '李白',
              lineIndex: 0,
              prompt: 'Reading line 1',
              hint: '静夜思',
              expectedAnswer: '床前明月光，',
            ),
            answer: '床前明月光',
            isCorrect: true,
            score: 92,
            feedback: 'Mock reading feedback',
            assessment: PracticeAssessmentMetrics(
              engine: 'mock-assessment',
              confidence: 0.93,
              accuracy: 95,
              fluency: 88,
              integrity: 91,
              assessmentBasis: 'aux_text_only',
              rawPayloadJson: '{"provider":"mock"}',
            ),
          ),
        ],
      );
      await repository.saveAssessmentReport(
        poem: poem,
        mode: PracticeMode.recitation,
        results: const [
          PracticeLineResult(
            question: PracticeQuestion(
              poemId: 1,
              poemTitle: '静夜思',
              poemAuthor: '李白',
              lineIndex: 1,
              prompt: 'Recitation line 2',
              hint: '静夜思',
              expectedAnswer: '疑是地上霜。',
            ),
            answer: '疑是地上霜',
            isCorrect: true,
            score: 86,
            feedback: 'Mock recitation feedback',
            assessment: PracticeAssessmentMetrics(
              engine: 'mock-assessment',
              confidence: 0.84,
              accuracy: 87,
              fluency: 83,
              integrity: 89,
              assessmentBasis: 'audio_with_aux_text',
            ),
          ),
        ],
      );

      final overview = await repository.fetchPracticeReportOverview();
      expect(overview.stats.totalReports, 2);
      expect(overview.stats.readingCount, 1);
      expect(overview.stats.recitationCount, 1);

      final readingOnly = await repository.fetchPracticeReportOverview(
        query: const PracticeReportQuery(mode: PracticeMode.reading),
      );
      expect(readingOnly.summaries, hasLength(1));
      expect(readingOnly.stats.readingCount, 1);
      expect(readingOnly.stats.recitationCount, 0);

      final detail = await repository.fetchPracticeReportDetail(
        readingReport.sessionId.isEmpty ? 0 : readingOnly.summaries.single.id,
      );
      expect(detail, isNotNull);
      expect(detail!.items.single.assessment.engine, 'mock-assessment');
      expect(detail.items.single.assessment.confidence, 0.93);
      expect(detail.items.single.assessment.accuracy, 95);
      expect(detail.items.single.assessment.fluency, 88);
      expect(detail.items.single.assessment.integrity, 91);
    },
  );

  test('practice report overview provider applies query filters', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    const now = '2026-05-08T10:00:00.000Z';
    const poem = Poem(
      id: 1,
      title: '静夜思',
      author: '李白',
      dynasty: '唐',
      grade: 1,
      gradeLabel: '一年级',
      category: '思乡',
      content: '床前明月光，\n疑是地上霜。',
      pinyin: '',
      annotation: '',
      translation: '',
      appreciation: '',
      authorIntro: '',
      extension: '',
      audioUrl: null,
      imageUrl: null,
      difficulty: 1,
    );

    await database.selectList('SELECT 1;');
    await database.customStatement('''
      INSERT INTO poems (
        id, title, author, dynasty, grade, grade_label, category, content,
        pinyin, annotation, translation, appreciation, author_intro,
        extension_text, difficulty, seed_version, sync_status, created_at,
        updated_at
      )
      VALUES (
        ${poem.id}, '${poem.title}', '${poem.author}', '${poem.dynasty}',
        ${poem.grade}, '${poem.gradeLabel}', '${poem.category}',
        '${poem.content}', '', '', '', '', '', '', ${poem.difficulty},
        'test', 'local', '$now', '$now'
      );
    ''');

    final repository = LocalPracticeRepository(
      database: database,
      poemRepository: const _FakePoemRepository(poem),
    );
    final dictation = await repository.createSession(
      mode: PracticeMode.dictation,
      poemId: poem.id,
    );
    await repository.completeSession(
      session: dictation,
      answers: const {0: '床前明月光，', 1: '疑是地上霜。'},
    );
    final evaluation = await repository.createSession(
      mode: PracticeMode.evaluation,
      poemId: poem.id,
    );
    await repository.completeSession(
      session: evaluation,
      answers: const {0: '', 1: '写错了'},
    );
    await repository.saveAssessmentReport(
      poem: poem,
      mode: PracticeMode.reading,
      results: const [
        PracticeLineResult(
          question: PracticeQuestion(
            poemId: 1,
            poemTitle: '静夜思',
            poemAuthor: '李白',
            lineIndex: 0,
            prompt: 'Reading line 1',
            hint: '静夜思',
            expectedAnswer: '床前明月光，',
          ),
          answer: '床前明月光',
          isCorrect: true,
          score: 91,
          feedback: 'Mock reading feedback',
          assessment: PracticeAssessmentMetrics(
            engine: 'mock-assessment',
            confidence: 0.9,
            accuracy: 92,
            fluency: 90,
            integrity: 91,
          ),
        ),
      ],
    );
    await database.customStatement('''
      INSERT INTO wrong_questions (
        profile_id, poem_id, question_type, prompt, correct_answer,
        user_answer, rule_tag, severity, stage_id, sync_status, created_at,
        updated_at
      )
      VALUES (
        1, ${poem.id}, 'dictation', 'stage prompt', 'stage answer',
        'wrong', 'line_mismatch', 'medium', 'dictation_checkpoint', 'local',
        '$now', '$now'
      );
    ''');

    final container = ProviderContainer(
      overrides: [practiceRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final overview = await container.read(
      practiceReportOverviewProvider(
        const PracticeReportQuery(
          mode: PracticeMode.evaluation,
          mistakeType: PracticeMistakeType.blankAnswer,
        ),
      ).future,
    );

    expect(overview.summaries, hasLength(1));
    expect(overview.summaries.single.mode, PracticeMode.evaluation);
    expect(overview.stats.totalReports, 1);
    expect(overview.stats.readingCount, 0);
    expect(overview.stats.recitationCount, 0);
    expect(
      overview.stats.mistakeTypes[PracticeMistakeType.blankAnswer],
      greaterThanOrEqualTo(1),
    );

    final readingOverview = await container.read(
      practiceReportOverviewProvider(
        const PracticeReportQuery(mode: PracticeMode.reading),
      ).future,
    );
    expect(readingOverview.summaries, hasLength(1));
    expect(readingOverview.stats.readingCount, 1);
    expect(readingOverview.stats.evaluationCount, 0);

    final stageWrongQuestions = await container.read(
      wrongQuestionEntriesProvider(
        const WrongQuestionQuery(stageId: 'dictation_checkpoint'),
      ).future,
    );
    expect(stageWrongQuestions, hasLength(1));
    expect(stageWrongQuestions.single.stageId, 'dictation_checkpoint');
  });
}

class _FakePoemRepository implements PoemRepository {
  const _FakePoemRepository(this.poem);

  final Poem poem;

  @override
  Future<List<Poem>> fetchPoems({PoemQuery query = const PoemQuery()}) async {
    return [poem];
  }

  @override
  Future<Poem?> fetchPoemById(int id) async {
    return id == poem.id ? poem : null;
  }

  @override
  Future<List<Poem>> fetchFavorites() async => const [];

  @override
  Future<PoemStats> fetchStats() async {
    return const PoemStats(
      total: 1,
      gradeCounts: {},
      categoryCounts: {},
      dynastyCounts: {},
    );
  }

  @override
  Future<DailyPoemBundle> getDailyPoem(DateTime date) {
    throw UnimplementedError();
  }

  @override
  Future<void> importSeedIfNeeded({required String seedVersion}) async {}

  @override
  Future<bool> isFavorite(int poemId) async => false;

  @override
  Future<void> setFavorite(int poemId, bool isFavorite) async {}
}
