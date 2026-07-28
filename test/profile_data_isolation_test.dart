import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gscappall/app/app_providers.dart';
import 'package:gscappall/data/local/app_database.dart';
import 'package:gscappall/data/local/local_seed_loader.dart';
import 'package:gscappall/data/remote/cloud_sync_api.dart';
import 'package:gscappall/data/repositories/local_learning_repository.dart';
import 'package:gscappall/data/repositories/local_poem_repository.dart';
import 'package:gscappall/data/repositories/local_practice_repository.dart';
import 'package:gscappall/data/repositories/local_settings_repository.dart';
import 'package:gscappall/domain/app_settings.dart';
import 'package:gscappall/domain/learning_models.dart';
import 'package:gscappall/domain/poem.dart';
import 'package:gscappall/domain/practice_models.dart';

void main() {
  test('profile data stays isolated across core local repositories', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    const poems = [
      Poem(
        id: 1,
        title: 'Spring Dawn',
        author: 'Meng',
        dynasty: 'Tang',
        grade: 1,
        gradeLabel: 'G1',
        category: 'nature',
        content: 'Spring sleep no dawn.\nBirds sing everywhere.',
        pinyin: 'chun mian bu jue xiao\nchu chu wen ti niao',
        annotation: '',
        translation: '',
        appreciation: '',
        authorIntro: '',
        extension: '',
        audioUrl: null,
        imageUrl: null,
        difficulty: 1,
      ),
      Poem(
        id: 2,
        title: 'Quiet Night',
        author: 'Li',
        dynasty: 'Tang',
        grade: 1,
        gradeLabel: 'G1',
        category: 'home',
        content: 'Moonlight before bed.\nFrost upon the ground.',
        pinyin: 'chuang qian ming yue guang\nyi shi di shang shuang',
        annotation: '',
        translation: '',
        appreciation: '',
        authorIntro: '',
        extension: '',
        audioUrl: null,
        imageUrl: null,
        difficulty: 1,
      ),
    ];

    final settingsRepository = LocalSettingsRepository(database: database);
    final poemRepository = LocalPoemRepository(
      database: database,
      seedLoader: const LocalSeedLoader(),
      remoteApi: const CloudSyncApi(),
    );
    final learningRepository = LocalLearningRepository(database: database);
    final practiceRepository = LocalPracticeRepository(
      database: database,
      poemRepository: poemRepository,
    );
    final date = DateTime(2026, 5, 8);

    await settingsRepository.ensureDefaults();
    await database.replaceSeed(poems: poems, seedVersion: 'profile-test');
    final secondProfile = await settingsRepository.createProfile(
      nickname: 'Second',
    );

    await settingsRepository.switchProfile(1);
    await poemRepository.setFavorite(1, true);
    await learningRepository.completeDailyPoem(date);
    await learningRepository.markStudyCardReview(poemId: 1, remembered: true);
    await learningRepository.saveStudyCardNote(
      poemId: 1,
      note: 'First profile note',
    );
    await settingsRepository.saveSettings(
      const AppSettings(
        activeProfileId: 1,
        fontScale: 1.15,
        speechRate: 0.9,
        showPinyin: false,
      ),
    );
    final firstSession = await practiceRepository.createSession(
      mode: PracticeMode.dictation,
      poemId: 1,
    );
    final firstReport = await practiceRepository.completeSession(
      session: firstSession,
      answers: const {0: ''},
    );
    final firstReportRows = await database.selectList('''
      SELECT id, profile_id, mode, generated_wrong_count
      FROM practice_reports
      WHERE session_id = ${sqlString(firstReport.sessionId)}
      LIMIT 1;
    ''');
    final firstReportId = firstReportRows.single['id'] as int;
    expect(firstReportRows.single['profile_id'], 1);
    expect(firstReportRows.single['mode'], PracticeMode.dictation.rawValue);
    expect(firstReportRows.single['generated_wrong_count'], greaterThan(0));

    expect((await poemRepository.fetchFavorites()).map((poem) => poem.id), [1]);
    expect(
      (await learningRepository.fetchDailyPoemProgress(
        date: date,
      )).todayCompleted,
      isTrue,
    );
    expect(
      (await learningRepository.fetchDailyPoemProgress(date: date)).todayPoints,
      10,
    );
    expect(
      (await learningRepository.fetchDailyPoemProgress(date: date)).totalPoints,
      10,
    );
    expect(
      _entryFor(
        await learningRepository.fetchStudyCardDeck(),
        1,
      ).progress.reviewCount,
      1,
    );
    expect(
      _entryFor(await learningRepository.fetchStudyCardDeck(), 1).progress.note,
      'First profile note',
    );
    expect(await practiceRepository.fetchWrongQuestions(), hasLength(2));
    expect(
      (await practiceRepository.fetchPracticeReportOverview())
          .stats
          .totalReports,
      1,
    );

    await settingsRepository.switchProfile(secondProfile.id);
    final secondProfileSettings = await settingsRepository.loadSettings();
    expect(secondProfileSettings.activeProfileId, secondProfile.id);
    expect(
      secondProfileSettings.showPinyin,
      isFalse,
      reason: 'The pinyin preference should survive profile switches.',
    );
    expect(await poemRepository.fetchFavorites(), isEmpty);
    expect(
      (await learningRepository.fetchDailyPoemProgress(
        date: date,
      )).todayCompleted,
      isFalse,
    );
    expect(
      (await learningRepository.fetchDailyPoemProgress(date: date)).totalPoints,
      0,
    );
    expect(
      _entryFor(
        await learningRepository.fetchStudyCardDeck(),
        1,
      ).progress.reviewCount,
      0,
    );
    expect(
      _entryFor(await learningRepository.fetchStudyCardDeck(), 1).progress.note,
      isNull,
    );
    expect(await practiceRepository.fetchWrongQuestions(), isEmpty);
    expect(
      (await practiceRepository.fetchPracticeReportOverview())
          .stats
          .totalReports,
      0,
    );

    await poemRepository.setFavorite(2, true);
    await learningRepository.completeDailyPoem(date);
    await learningRepository.markStudyCardReview(poemId: 2, remembered: true);
    await learningRepository.saveStudyCardNote(
      poemId: 2,
      note: 'Second profile note',
    );
    final secondSession = await practiceRepository.createSession(
      mode: PracticeMode.evaluation,
      poemId: 2,
    );
    final secondReport = await practiceRepository.completeSession(
      session: secondSession,
      answers: const {0: ''},
    );
    final secondReportRows = await database.selectList('''
      SELECT id, profile_id, mode, generated_wrong_count
      FROM practice_reports
      WHERE session_id = ${sqlString(secondReport.sessionId)}
      LIMIT 1;
    ''');
    expect(secondReportRows.single['profile_id'], secondProfile.id);
    expect(secondReportRows.single['mode'], PracticeMode.evaluation.rawValue);
    expect(secondReportRows.single['generated_wrong_count'], greaterThan(0));
    expect(
      await practiceRepository.fetchPracticeReportDetail(firstReportId),
      isNull,
    );

    await settingsRepository.saveSettings(
      AppSettings(
        activeProfileId: secondProfile.id,
        fontScale: 1.0,
        speechRate: 1.0,
        showPinyin: true,
      ),
    );
    expect((await settingsRepository.loadSettings()).showPinyin, isTrue);

    expect((await poemRepository.fetchFavorites()).map((poem) => poem.id), [2]);
    expect(
      _entryFor(
        await learningRepository.fetchStudyCardDeck(),
        2,
      ).progress.reviewCount,
      1,
    );
    expect(
      _entryFor(await learningRepository.fetchStudyCardDeck(), 2).progress.note,
      'Second profile note',
    );
    expect(
      (await practiceRepository.fetchPracticeReportOverview())
          .stats
          .evaluationCount,
      1,
    );
    expect(
      (await learningRepository.fetchRecentRecords()).map(
        (record) => record.mode,
      ),
      containsAll([
        'daily_poem',
        'study_card',
        PracticeMode.evaluation.rawValue,
      ]),
    );

    await settingsRepository.switchProfile(1);
    expect((await poemRepository.fetchFavorites()).map((poem) => poem.id), [1]);
    expect(
      _entryFor(
        await learningRepository.fetchStudyCardDeck(),
        1,
      ).progress.reviewCount,
      1,
    );
    expect(
      _entryFor(
        await learningRepository.fetchStudyCardDeck(),
        2,
      ).progress.reviewCount,
      0,
    );
    expect(
      _entryFor(await learningRepository.fetchStudyCardDeck(), 1).progress.note,
      'First profile note',
    );
    expect(
      _entryFor(await learningRepository.fetchStudyCardDeck(), 2).progress.note,
      isNull,
    );
    expect(
      (await practiceRepository.fetchPracticeReportOverview())
          .stats
          .dictationCount,
      1,
    );
    expect(
      (await practiceRepository.fetchPracticeReportOverview())
          .stats
          .evaluationCount,
      0,
    );
    expect((await settingsRepository.loadSettings()).showPinyin, isTrue);

    final countRows = await database.selectList('''
      SELECT profile_id, COUNT(*) AS count
      FROM favorites
      WHERE deleted_at IS NULL
      GROUP BY profile_id
      ORDER BY profile_id;
    ''');
    expect(countRows.map((row) => row['profile_id']), [1, secondProfile.id]);
    expect(countRows.map((row) => row['count']), [1, 1]);

    final settings = await settingsRepository.loadSettings();
    expect(settings.activeProfileId, 1);
    expect(settings.showPinyin, isTrue);
    expect(settings.fontScale, 1.0);

    final studyRows = await database.selectList('''
      SELECT profile_id, poem_id, note
      FROM study_card_progress
      ORDER BY profile_id, poem_id;
    ''');
    expect(studyRows.map((row) => '${row['profile_id']}:${row['poem_id']}'), [
      '1:1',
      '${secondProfile.id}:2',
    ]);
    expect(studyRows.map((row) => row['note']), [
      'First profile note',
      'Second profile note',
    ]);

    final studyCardLearningRows = await database.selectList('''
      SELECT profile_id, poem_id, mode, note
      FROM learning_records
      WHERE mode = 'study_card'
      ORDER BY profile_id, poem_id;
    ''');
    expect(
      studyCardLearningRows.map(
        (row) => '${row['profile_id']}:${row['poem_id']}',
      ),
      ['1:1', '${secondProfile.id}:2'],
    );
    expect(
      studyCardLearningRows.every((row) => row['mode'] == 'study_card'),
      isTrue,
    );
    expect(
      studyCardLearningRows.map((row) => row['note']),
      everyElement(isNotNull),
    );

    final reportRows = await database.selectList('''
      SELECT profile_id, mode, COUNT(*) AS count
      FROM practice_reports
      GROUP BY profile_id, mode
      ORDER BY profile_id, mode;
    ''');
    expect(reportRows.map((row) => '${row['profile_id']}:${row['mode']}'), [
      '1:dictation',
      '${secondProfile.id}:evaluation',
    ]);
    expect(reportRows.map((row) => row['count']), [1, 1]);

    final dailyRows = await database.selectList('''
      SELECT profile_id, date_key, is_completed, points_earned
      FROM daily_poem_records
      WHERE is_completed = 1
      ORDER BY profile_id, date_key;
    ''');
    expect(dailyRows.map((row) => '${row['profile_id']}:${row['date_key']}'), [
      '1:2026-05-08',
      '${secondProfile.id}:2026-05-08',
    ]);
    expect(dailyRows.map((row) => row['points_earned']), [10, 10]);

    final checkInRows = await database.selectList('''
      SELECT profile_id, date_key, check_in_type, points_earned
      FROM check_in_records
      ORDER BY profile_id, date_key;
    ''');
    expect(
      checkInRows.map(
        (row) =>
            '${row['profile_id']}:${row['date_key']}:${row['check_in_type']}',
      ),
      ['1:2026-05-08:daily_poem', '${secondProfile.id}:2026-05-08:daily_poem'],
    );
    expect(checkInRows.map((row) => row['points_earned']), [10, 10]);

    final pointRows = await database.selectList('''
      SELECT id, total_points, current_points, total_check_ins
      FROM user_points
      ORDER BY id;
    ''');
    expect(pointRows.map((row) => row['id']), [1, secondProfile.id]);
    expect(pointRows.map((row) => row['total_points']), [10, 10]);
    expect(pointRows.map((row) => row['total_check_ins']), [1, 1]);

    final wrongRows = await database.selectList('''
      SELECT profile_id, question_type, COUNT(*) AS count
      FROM wrong_questions
      GROUP BY profile_id, question_type
      ORDER BY profile_id, question_type;
    ''');
    expect(
      wrongRows.map((row) => '${row['profile_id']}:${row['question_type']}'),
      ['1:dictation', '${secondProfile.id}:evaluation'],
    );
    expect(wrongRows.map((row) => row['count']), [2, 2]);
  });

  test(
    'profile scoped providers refresh after profile switch invalidation',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);

      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
      );
      addTearDown(container.dispose);

      await container.read(settingsRepositoryProvider).ensureDefaults();
      await database.replaceSeed(poems: _poems, seedVersion: 'provider-test');

      final settingsRepository = container.read(settingsRepositoryProvider);
      final poemRepository = container.read(poemRepositoryProvider);
      final learningRepository = container.read(learningRepositoryProvider);
      final practiceRepository = container.read(practiceRepositoryProvider);
      final secondProfile = await settingsRepository.createProfile(
        nickname: 'Provider Second',
      );
      final today = DateTime.now();

      await settingsRepository.switchProfile(1);
      await poemRepository.setFavorite(1, true);
      await learningRepository.completeDailyPoem(today);
      await learningRepository.markStudyCardReview(poemId: 1, remembered: true);
      await learningRepository.saveStudyCardNote(
        poemId: 1,
        note: 'Provider first note',
      );
      final firstSession = await practiceRepository.createSession(
        mode: PracticeMode.dictation,
        poemId: 1,
      );
      final firstReport = await practiceRepository.completeSession(
        session: firstSession,
        answers: const {0: ''},
      );
      final firstReportId =
          (await database.selectSingle(
                'SELECT id FROM practice_reports WHERE session_id = ${sqlString(firstReport.sessionId)} LIMIT 1;',
              ))!['id']
              as int;

      expect(
        (await container.read(favoritesProvider.future)).map((poem) => poem.id),
        [1],
      );
      expect(
        (await container.read(dailyPoemProgressProvider.future)).todayCompleted,
        isTrue,
      );
      expect(
        _entryFor(
          await container.read(
            studyCardDeckProvider(const StudyCardQuery()).future,
          ),
          1,
        ).progress.note,
        'Provider first note',
      );
      expect(
        (await container.read(
          learningHistoryProvider(20).future,
        )).map((record) => record.mode),
        containsAll([
          'daily_poem',
          'study_card',
          PracticeMode.dictation.rawValue,
        ]),
      );
      expect(
        (await container.read(
          practiceReportOverviewProvider(const PracticeReportQuery()).future,
        )).stats.dictationCount,
        1,
      );
      expect(
        await container.read(
          practiceReportDetailProvider(firstReportId).future,
        ),
        isNotNull,
      );
      expect(
        await container.read(
          wrongQuestionEntriesProvider(const WrongQuestionQuery()).future,
        ),
        hasLength(2),
      );

      await settingsRepository.switchProfile(secondProfile.id);
      await poemRepository.setFavorite(2, true);
      await learningRepository.markStudyCardReview(poemId: 2, remembered: true);
      await learningRepository.saveStudyCardNote(
        poemId: 2,
        note: 'Provider second note',
      );
      final secondSession = await practiceRepository.createSession(
        mode: PracticeMode.evaluation,
        poemId: 2,
      );
      await practiceRepository.completeSession(
        session: secondSession,
        answers: const {0: ''},
      );

      invalidateProfileScopedProviderContainer(container);

      expect(
        (await container.read(profileProvider.future)).id,
        secondProfile.id,
      );
      expect(
        (await container.read(settingsProvider.future)).activeProfileId,
        secondProfile.id,
      );
      expect(
        (await container.read(favoritesProvider.future)).map((poem) => poem.id),
        [2],
      );
      expect(
        (await container.read(dailyPoemProgressProvider.future)).todayCompleted,
        isFalse,
      );
      final secondDailyHistory = await container.read(
        dailyPoemHistoryProvider.future,
      );
      expect(secondDailyHistory, hasLength(1));
      expect(secondDailyHistory.single.isCompleted, isFalse);
      expect(
        _entryFor(
          await container.read(
            studyCardDeckProvider(const StudyCardQuery()).future,
          ),
          1,
        ).progress.note,
        isNull,
      );
      expect(
        _entryFor(
          await container.read(
            studyCardDeckProvider(const StudyCardQuery()).future,
          ),
          2,
        ).progress.note,
        'Provider second note',
      );
      expect(
        (await container.read(learningSummaryProvider.future)).totalFavorites,
        1,
      );
      expect(
        (await container.read(
          recentLearningRecordsProvider.future,
        )).map((record) => record.mode),
        containsAll(['study_card', PracticeMode.evaluation.rawValue]),
      );
      expect(
        await container.read(learningHistoryProvider(20).future),
        hasLength(2),
      );
      final overview = await container.read(
        practiceReportOverviewProvider(const PracticeReportQuery()).future,
      );
      expect(overview.stats.totalReports, 1);
      expect(overview.stats.evaluationCount, 1);
      expect(
        await container.read(
          practiceReportDetailProvider(firstReportId).future,
        ),
        isNull,
      );
      expect(
        await container.read(
          wrongQuestionEntriesProvider(const WrongQuestionQuery()).future,
        ),
        hasLength(2),
      );
    },
  );
}

const _poems = [
  Poem(
    id: 1,
    title: 'Spring Dawn',
    author: 'Meng',
    dynasty: 'Tang',
    grade: 1,
    gradeLabel: 'G1',
    category: 'nature',
    content: 'Spring sleep no dawn.\nBirds sing everywhere.',
    pinyin: 'chun mian bu jue xiao\nchu chu wen ti niao',
    annotation: '',
    translation: '',
    appreciation: '',
    authorIntro: '',
    extension: '',
    audioUrl: null,
    imageUrl: null,
    difficulty: 1,
  ),
  Poem(
    id: 2,
    title: 'Quiet Night',
    author: 'Li',
    dynasty: 'Tang',
    grade: 1,
    gradeLabel: 'G1',
    category: 'home',
    content: 'Moonlight before bed.\nFrost upon the ground.',
    pinyin: 'chuang qian ming yue guang\nyi shi di shang shuang',
    annotation: '',
    translation: '',
    appreciation: '',
    authorIntro: '',
    extension: '',
    audioUrl: null,
    imageUrl: null,
    difficulty: 1,
  ),
];

StudyCardDeckEntry _entryFor(List<StudyCardDeckEntry> entries, int poemId) {
  return entries.singleWhere((entry) => entry.poem.id == poemId);
}
