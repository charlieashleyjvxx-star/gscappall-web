import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gscappall/data/local/app_database.dart';
import 'package:gscappall/data/local/local_seed_loader.dart';
import 'package:gscappall/data/remote/cloud_sync_api.dart';
import 'package:gscappall/data/repositories/local_learning_repository.dart';
import 'package:gscappall/data/repositories/local_poem_repository.dart';
import 'package:gscappall/domain/learning_models.dart';
import 'package:gscappall/domain/poem.dart';

void main() {
  group('StudyCardReviewSchedule', () {
    test('returns expected spaced repetition intervals and labels', () {
      expect(StudyCardReviewSchedule.intervalForReviewCount(1), 1);
      expect(StudyCardReviewSchedule.intervalForReviewCount(3), 4);
      expect(StudyCardReviewSchedule.intervalForReviewCount(20), 30);

      final now = DateTime(2026, 5, 9, 10);
      expect(StudyCardReviewSchedule.nextReviewLabel(null, now: now), '尚未安排复习');
      expect(
        StudyCardReviewSchedule.nextReviewLabel(
          DateTime(2026, 5, 9, 23),
          now: now,
        ),
        '今天可复习',
      );
      expect(
        StudyCardReviewSchedule.nextReviewLabel(
          DateTime(2026, 5, 10),
          now: now,
        ),
        '明天复习',
      );
      expect(
        StudyCardReviewSchedule.nextReviewLabel(
          DateTime(2026, 5, 12),
          now: now,
        ),
        '5/12 再复习',
      );
    });
  });

  group('LocalLearningRepository study cards and daily poem', () {
    late AppDatabase database;
    late LocalLearningRepository learningRepository;
    late LocalPoemRepository poemRepository;

    setUp(() async {
      database = AppDatabase.forTesting(NativeDatabase.memory());
      learningRepository = LocalLearningRepository(database: database);
      poemRepository = LocalPoemRepository(
        database: database,
        seedLoader: const LocalSeedLoader(),
        remoteApi: const CloudSyncApi(),
      );
      await database.ensureDefaults();
      await database.replaceSeed(poems: _poems, seedVersion: 'test');
    });

    tearDown(() async {
      await database.close();
    });

    test('combines filters and preserves notes on cancel', () async {
      await poemRepository.setFavorite(2, true);
      await learningRepository.markStudyCardReview(poemId: 1, remembered: true);
      await learningRepository.markStudyCardReview(poemId: 1, remembered: true);
      await learningRepository.markStudyCardReview(poemId: 1, remembered: true);
      await learningRepository.markStudyCardReview(
        poemId: 2,
        remembered: false,
      );
      await database.customStatement('''
        UPDATE study_card_progress
        SET next_review_at = ${sqlString(DateTime.now().toUtc().subtract(const Duration(days: 1)).toIso8601String())}
        WHERE poem_id = 2;
      ''');

      expect(
        _ids(
          await learningRepository.fetchStudyCardDeck(
            query: const StudyCardQuery(
              filterType: StudyCardFilterType.favorites,
            ),
          ),
        ),
        [2],
      );
      expect(
        _ids(
          await learningRepository.fetchStudyCardDeck(
            query: const StudyCardQuery(
              filterType: StudyCardFilterType.dueReview,
            ),
          ),
        ),
        [2],
      );
      expect(
        _ids(
          await learningRepository.fetchStudyCardDeck(
            query: const StudyCardQuery(
              filterType: StudyCardFilterType.newCards,
            ),
          ),
        ),
        [3],
      );
      expect(
        _ids(
          await learningRepository.fetchStudyCardDeck(
            query: const StudyCardQuery(
              filterType: StudyCardFilterType.mastered,
            ),
          ),
        ),
        [1],
      );

      await learningRepository.saveStudyCardNote(
        poemId: 1,
        note: '  first line\nsecond line  ',
      );
      expect(
        _entryFor(
          await learningRepository.fetchStudyCardDeck(),
          1,
        ).progress.note,
        'first line\nsecond line',
      );
      expect(
        _entryFor(
          await learningRepository.fetchStudyCardDeck(),
          1,
        ).progress.notePreview,
        'first line second line',
      );
      expect(StudyCardNoteDraft.normalizeSubmitted(null), isNull);
    });

    test(
      'refreshes daily poem statistics and growth report summaries',
      () async {
        final today = DateTime.now();
        await learningRepository.completeDailyPoem(today);
        await learningRepository.reviewDailyPoem(today);
        await learningRepository.logLearningRecord(
          poemId: 1,
          mode: 'dictation',
          durationMinutes: 8,
          score: 80,
        );
        await learningRepository.logLearningRecord(
          poemId: 2,
          mode: 'study_card',
          durationMinutes: 3,
          score: 100,
        );

        final nowIso = DateTime.now().toUtc().toIso8601String();
        await database.customStatement('''
        INSERT INTO practice_reports (
          profile_id, session_id, mode, poem_id, total_score, correct_count,
          total_questions, generated_wrong_count, suggestions_json,
          sync_status, created_at, updated_at, completed_at
        )
        VALUES (
          1, 'growth-session', 'dictation', 1, 80, 1, 2, 1, '[]',
          'pending_push', ${sqlString(nowIso)}, ${sqlString(nowIso)},
          ${sqlString(nowIso)}
        );
      ''');
        await database.customStatement('''
        INSERT INTO wrong_questions (
          profile_id, poem_id, question_type, prompt, correct_answer,
          user_answer, rule_tag, severity, sync_status, created_at, updated_at
        )
        VALUES (
          1, 1, 'dictation', 'prompt', 'answer', '', 'blank_answer',
          'high', 'pending_push', ${sqlString(nowIso)}, ${sqlString(nowIso)}
        );
      ''');

        final progress = await learningRepository.fetchDailyPoemProgress(
          date: today,
        );
        expect(progress.todayCompleted, isTrue);
        expect(progress.todayPoints, 10);
        expect(progress.todayReviewCount, 1);

        final report = await learningRepository.fetchGrowthReport();
        expect(report.period, GrowthReportPeriod.weekly);
        expect(report.totalSessions, 4);
        expect(report.totalMinutes, 19);
        expect(report.uniquePoems, greaterThanOrEqualTo(2));
        expect(report.averageScore, 90);
        expect(report.practiceReportCount, 1);
        expect(report.wrongQuestionCount, 1);
        expect(report.reviewedWrongQuestionCount, 0);
        expect(report.pendingWrongQuestionCount, 1);
        expect(report.activeDays, 1);
        expect(report.longestLearningStreak, 1);
        expect(report.previousWrongQuestionCount, 0);
        expect(report.scoreDelta, isNull);
        expect(report.topMode?.mode, 'dictation');
        expect(report.scoreTrend, isNotEmpty);
        expect(report.focusSuggestion, contains('错题'));
        expect(report.weakPointExplanation, contains('错题复盘不足'));
        expect(report.parentSummary, contains('本周完成 4 次练习'));
        expect(report.parentSummary, contains('最长连续 1 天'));
      },
    );

    test('aggregates challenge mode progress from learning records', () async {
      await learningRepository.logLearningRecord(
        poemId: 1,
        mode: 'poetry_jielong',
        durationMinutes: 8,
        score: 95,
        stageId: 'jielong_entry',
      );
      await learningRepository.logLearningRecord(
        poemId: 2,
        mode: 'feihualing',
        durationMinutes: 6,
        score: 86,
      );
      await learningRepository.logLearningRecord(
        poemId: 3,
        mode: 'dictation',
        durationMinutes: 5,
        score: 78,
      );

      final progress = await learningRepository.fetchChallengeModeProgress();

      expect(progress['poetry_jielong']?.bestScore, 95);
      expect(progress['poetry_jielong']?.completedLines, 4);
      expect(progress['feihualing']?.completedLines, 3);
      expect(progress['dictation']?.completedLines, 1);

      final history = await learningRepository.fetchChallengeModeHistory(
        mode: 'poetry_jielong',
      );
      expect(history, hasLength(1));
      expect(history.single.mode, 'poetry_jielong');
      expect(history.single.score, 95);

      final growth = await learningRepository.fetchGrowthReport();
      expect(growth.stageTrend, isNotEmpty);
      expect(growth.stageTrend.single.stageId, 'jielong_entry');
      expect(growth.stageTrend.single.count, 1);
      expect(growth.stageTrend.single.averageScore, 95);
    });
  });
}

List<int> _ids(List<StudyCardDeckEntry> entries) {
  return entries.map((entry) => entry.poem.id).toList(growable: false);
}

StudyCardDeckEntry _entryFor(List<StudyCardDeckEntry> entries, int poemId) {
  return entries.singleWhere((entry) => entry.poem.id == poemId);
}

const _poems = [
  Poem(
    id: 1,
    title: 'Quiet Night',
    author: 'Li Bai',
    dynasty: 'Tang',
    grade: 1,
    gradeLabel: 'G1',
    category: 'nature',
    content: 'Moonlight before bed.',
    pinyin: 'chuang qian ming yue guang',
    annotation: '',
    translation: 'Moonlight shines before the bed.',
    appreciation: '',
    authorIntro: '',
    extension: '',
    audioUrl: null,
    imageUrl: null,
    difficulty: 1,
  ),
  Poem(
    id: 2,
    title: 'Spring Dawn',
    author: 'Meng Haoran',
    dynasty: 'Tang',
    grade: 1,
    gradeLabel: 'G1',
    category: 'season',
    content: 'Spring sleep no dawn.',
    pinyin: 'chun mian bu jue xiao',
    annotation: '',
    translation: 'Spring sleep misses dawn.',
    appreciation: '',
    authorIntro: '',
    extension: '',
    audioUrl: null,
    imageUrl: null,
    difficulty: 1,
  ),
  Poem(
    id: 3,
    title: 'River Snow',
    author: 'Liu Zongyuan',
    dynasty: 'Song',
    grade: 2,
    gradeLabel: 'G2',
    category: 'nature',
    content: 'A thousand mountains no birds.',
    pinyin: 'qian shan niao fei jue',
    annotation: '',
    translation: 'No birds over a thousand mountains.',
    appreciation: '',
    authorIntro: '',
    extension: '',
    audioUrl: null,
    imageUrl: null,
    difficulty: 2,
  ),
];
