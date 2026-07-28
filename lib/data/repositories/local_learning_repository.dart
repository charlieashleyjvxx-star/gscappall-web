import '../../core/app_formatters.dart';
import '../../domain/learning_models.dart';
import '../../domain/poem.dart';
import '../../domain/repositories/learning_repository.dart';
import '../local/app_database.dart';

class LocalLearningRepository implements LearningRepository {
  LocalLearningRepository({required AppDatabase database})
    : _database = database;

  static const int _dailyPoemPoints = 10;
  static const int _studyCardReviewMinutes = 3;

  final AppDatabase _database;

  @override
  Future<void> logLearningRecord({
    required int poemId,
    required String mode,
    int durationMinutes = 0,
    int? score,
    String? note,
    String? stageId,
  }) async {
    final profileId = await _database.activeProfileId();
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final deviceId = currentActorDeviceId();
    final learningMutationId = nextClientMutationId('learning');

    await _database.customStatement('''
      INSERT INTO learning_records (
        profile_id,
        poem_id,
        mode,
        duration_minutes,
        score,
        note,
        stage_id,
        client_mutation_id,
        last_actor_device_id,
        sync_status,
        created_at,
        updated_at
      )
      VALUES (
        $profileId,
        $poemId,
        ${sqlString(mode)},
        $durationMinutes,
        ${score ?? 'NULL'},
        ${sqlNullable(note)},
        ${sqlNullable(stageId)},
        ${sqlString(learningMutationId)},
        ${sqlString(deviceId)},
        'pending_push',
        ${sqlString(nowIso)},
        ${sqlString(nowIso)}
      );
    ''');

    if (mode == 'recite' || mode == 'recite_practice') {
      final reciteMutationId = nextClientMutationId('recite');
      await _database.customStatement('''
        INSERT INTO recite_records (
          profile_id,
          poem_id,
          score,
          client_mutation_id,
          last_actor_device_id,
          sync_status,
          created_at,
          updated_at
        )
        VALUES (
          $profileId,
          $poemId,
          ${score ?? 'NULL'},
          ${sqlString(reciteMutationId)},
          ${sqlString(deviceId)},
          'pending_push',
          ${sqlString(nowIso)},
          ${sqlString(nowIso)}
        );
      ''');
    }
  }

  @override
  Future<LearningSummary> fetchSummary() async {
    final profileId = await _database.activeProfileId();
    final learnedRow = await _database.selectSingle('''
      SELECT COUNT(DISTINCT poem_id) AS total, COALESCE(SUM(duration_minutes), 0) AS minutes
      FROM learning_records
      WHERE profile_id = $profileId;
    ''');
    final favoriteRow = await _database.selectSingle('''
      SELECT COUNT(*) AS count
      FROM favorites
      WHERE profile_id = $profileId AND deleted_at IS NULL;
    ''');
    final dailyRow = await _database.selectSingle('''
      SELECT is_completed
      FROM daily_poem_records
      WHERE profile_id = $profileId
        AND date_key = ${sqlString(AppFormatters.dateKey(DateTime.now()))}
      LIMIT 1;
    ''');
    final streak = await _computeStreakDays();

    return LearningSummary(
      totalLearnedPoems: (learnedRow?['total'] as int?) ?? 0,
      totalFavorites: (favoriteRow?['count'] as int?) ?? 0,
      totalMinutes: (learnedRow?['minutes'] as int?) ?? 0,
      streakDays: streak,
      dailyPoemCompleted: ((dailyRow?['is_completed'] as int?) ?? 0) == 1,
    );
  }

  @override
  Future<LearningGrowthReport> fetchGrowthReport({
    GrowthReportPeriod period = GrowthReportPeriod.weekly,
  }) async {
    final profileId = await _database.activeProfileId();
    final endAt = DateTime.now().toUtc();
    final startAt = endAt.subtract(Duration(days: period.days - 1));
    final previousStartAt = startAt.subtract(Duration(days: period.days));
    final startIso = startAt.toIso8601String();
    final previousStartIso = previousStartAt.toIso8601String();

    final summaryRow = await _database.selectSingle('''
      SELECT
        COUNT(*) AS total_sessions,
        COUNT(DISTINCT poem_id) AS unique_poems,
        COALESCE(SUM(duration_minutes), 0) AS total_minutes,
        AVG(score) AS average_score
      FROM learning_records
      WHERE profile_id = $profileId
        AND created_at >= ${sqlString(startIso)};
    ''');
    final dailyRow = await _database.selectSingle('''
      SELECT COUNT(*) AS count
      FROM daily_poem_records
      WHERE profile_id = $profileId
        AND is_completed = 1
        AND completed_at >= ${sqlString(startIso)};
    ''');
    final studyRow = await _database.selectSingle('''
      SELECT COUNT(*) AS count
      FROM learning_records
      WHERE profile_id = $profileId
        AND mode = 'study_card'
        AND created_at >= ${sqlString(startIso)};
    ''');
    final reportRow = await _database.selectSingle('''
      SELECT COUNT(*) AS count
      FROM practice_reports
      WHERE profile_id = $profileId
        AND completed_at >= ${sqlString(startIso)};
    ''');
    final wrongRow = await _database.selectSingle('''
      SELECT
        COUNT(*) AS count,
        SUM(CASE WHEN reviewed_at IS NOT NULL THEN 1 ELSE 0 END) AS reviewed_count
      FROM wrong_questions
      WHERE profile_id = $profileId
        AND created_at >= ${sqlString(startIso)};
    ''');
    final previousRow = await _database.selectSingle('''
      SELECT
        COUNT(*) AS total_sessions,
        AVG(score) AS average_score
      FROM learning_records
      WHERE profile_id = $profileId
        AND created_at >= ${sqlString(previousStartIso)}
        AND created_at < ${sqlString(startIso)};
    ''');
    final previousWrongRow = await _database.selectSingle('''
      SELECT
        COUNT(*) AS count,
        SUM(CASE WHEN reviewed_at IS NOT NULL THEN 1 ELSE 0 END) AS reviewed_count
      FROM wrong_questions
      WHERE profile_id = $profileId
        AND created_at >= ${sqlString(previousStartIso)}
        AND created_at < ${sqlString(startIso)};
    ''');
    final activeDayRows = await _database.selectList('''
      SELECT DISTINCT substr(created_at, 1, 10) AS date_key
      FROM learning_records
      WHERE profile_id = $profileId
        AND created_at >= ${sqlString(startIso)}
      ORDER BY date_key ASC;
    ''');
    final modeRows = await _database.selectList('''
      SELECT
        mode,
        COUNT(*) AS count,
        COALESCE(SUM(duration_minutes), 0) AS minutes,
        AVG(score) AS average_score
      FROM learning_records
      WHERE profile_id = $profileId
        AND created_at >= ${sqlString(startIso)}
      GROUP BY mode
      ORDER BY count DESC, minutes DESC;
    ''');
    final previousModeRows = await _database.selectList('''
      SELECT
        mode,
        COUNT(*) AS count,
        COALESCE(SUM(duration_minutes), 0) AS minutes,
        AVG(score) AS average_score
      FROM learning_records
      WHERE profile_id = $profileId
        AND created_at >= ${sqlString(previousStartIso)}
        AND created_at < ${sqlString(startIso)}
      GROUP BY mode
      ORDER BY count DESC, minutes DESC;
    ''');
    final stageRows = await _database.selectList('''
      SELECT
        stage_id,
        COUNT(*) AS count,
        COALESCE(SUM(duration_minutes), 0) AS minutes,
        AVG(score) AS average_score
      FROM learning_records
      WHERE profile_id = $profileId
        AND stage_id IS NOT NULL
        AND stage_id <> ''
        AND created_at >= ${sqlString(startIso)}
      GROUP BY stage_id
      ORDER BY count DESC, minutes DESC;
    ''');
    final previousStageRows = await _database.selectList('''
      SELECT
        stage_id,
        COUNT(*) AS count,
        COALESCE(SUM(duration_minutes), 0) AS minutes,
        AVG(score) AS average_score
      FROM learning_records
      WHERE profile_id = $profileId
        AND stage_id IS NOT NULL
        AND stage_id <> ''
        AND created_at >= ${sqlString(previousStartIso)}
        AND created_at < ${sqlString(startIso)}
      GROUP BY stage_id
      ORDER BY count DESC, minutes DESC;
    ''');
    final trendRows = await _database.selectList('''
      SELECT
        substr(created_at, 1, 10) AS date_key,
        COUNT(*) AS count,
        AVG(score) AS average_score
      FROM learning_records
      WHERE profile_id = $profileId
        AND score IS NOT NULL
        AND created_at >= ${sqlString(startIso)}
      GROUP BY substr(created_at, 1, 10)
      ORDER BY date_key ASC;
    ''');
    final stageTrendRows = await _database.selectList('''
      SELECT
        stage_id,
        substr(created_at, 1, 10) AS date_key,
        COUNT(*) AS count,
        COALESCE(SUM(duration_minutes), 0) AS minutes,
        AVG(score) AS average_score
      FROM learning_records
      WHERE profile_id = $profileId
        AND stage_id IS NOT NULL
        AND stage_id <> ''
        AND created_at >= ${sqlString(startIso)}
      GROUP BY stage_id, substr(created_at, 1, 10)
      ORDER BY date_key ASC, count DESC;
    ''');

    return LearningGrowthReport(
      period: period,
      startAt: startAt,
      endAt: endAt,
      totalSessions: (summaryRow?['total_sessions'] as int?) ?? 0,
      totalMinutes: (summaryRow?['total_minutes'] as int?) ?? 0,
      uniquePoems: (summaryRow?['unique_poems'] as int?) ?? 0,
      averageScore: _roundedInt(summaryRow?['average_score']),
      dailyPoemCompletions: (dailyRow?['count'] as int?) ?? 0,
      studyCardReviews: (studyRow?['count'] as int?) ?? 0,
      practiceReportCount: (reportRow?['count'] as int?) ?? 0,
      wrongQuestionCount: (wrongRow?['count'] as int?) ?? 0,
      reviewedWrongQuestionCount: (wrongRow?['reviewed_count'] as int?) ?? 0,
      activeDays: activeDayRows.length,
      longestLearningStreak: _longestDateKeyStreak(
        activeDayRows
            .map((row) => row['date_key'] as String? ?? '')
            .where((dateKey) => dateKey.isNotEmpty)
            .toList(growable: false),
      ),
      previousWrongQuestionCount: (previousWrongRow?['count'] as int?) ?? 0,
      previousReviewedWrongQuestionCount:
          (previousWrongRow?['reviewed_count'] as int?) ?? 0,
      previousAverageScore:
          (previousRow?['total_sessions'] as int? ?? 0) == 0
              ? null
              : _roundedInt(previousRow?['average_score']),
      modeStats: modeRows.map(LearningModeStat.fromRow).toList(growable: false),
      previousModeStats: previousModeRows
          .map(LearningModeStat.fromRow)
          .toList(growable: false),
      stageStats: stageRows
          .map(LearningStageStat.fromRow)
          .toList(growable: false),
      previousStageStats: previousStageRows
          .map(LearningStageStat.fromRow)
          .toList(growable: false),
      scoreTrend: trendRows
          .map(LearningScoreTrend.fromRow)
          .toList(growable: false),
      stageTrend: stageTrendRows
          .map(LearningStageTrendPoint.fromRow)
          .toList(growable: false),
    );
  }

  @override
  Future<List<LearningRecord>> fetchRecentRecords({int limit = 12}) async {
    final profileId = await _database.activeProfileId();
    final rows = await _database.selectList('''
      SELECT l.*, p.title, p.author
      FROM learning_records l
      INNER JOIN poems p ON p.id = l.poem_id
      WHERE l.profile_id = $profileId
      ORDER BY l.created_at DESC
      LIMIT $limit;
    ''');
    return rows.map(LearningRecord.fromRow).toList(growable: false);
  }

  @override
  Future<Map<String, ChallengeModeProgress>>
  fetchChallengeModeProgress() async {
    final profileId = await _database.activeProfileId();
    final rows = await _database.selectList('''
      SELECT
        mode,
        COUNT(*) AS total_sessions,
        MAX(COALESCE(score, 0)) AS best_score,
        MAX(COALESCE(duration_minutes, 0)) AS max_minutes
      FROM learning_records
      WHERE profile_id = $profileId
        AND mode IN ('poetry_jielong', 'feihualing', 'dictation')
      GROUP BY mode;
    ''');

    return {
      for (final row in rows)
        row['mode'] as String: ChallengeModeProgress(
          mode: row['mode'] as String,
          totalSessions: (row['total_sessions'] as int?) ?? 0,
          bestScore: (row['best_score'] as int?) ?? 0,
          completedLines:
              row['mode'] == 'dictation'
                  ? (row['total_sessions'] as int?) ?? 0
                  : (((row['max_minutes'] as int?) ?? 0) ~/ 2).clamp(0, 999),
        ),
    };
  }

  @override
  Future<List<LearningRecord>> fetchChallengeModeHistory({
    required String mode,
    int limit = 10,
    String? stageId,
  }) async {
    final profileId = await _database.activeProfileId();
    final stageClause =
        stageId == null || stageId.isEmpty
            ? ''
            : 'AND l.stage_id = ${sqlString(stageId)}';
    final rows = await _database.selectList('''
      SELECT l.*, p.title, p.author
      FROM learning_records l
      INNER JOIN poems p ON p.id = l.poem_id
      WHERE l.profile_id = $profileId
        AND l.mode = ${sqlString(mode)}
        $stageClause
      ORDER BY l.created_at DESC
      LIMIT $limit;
    ''');
    return rows.map(LearningRecord.fromRow).toList(growable: false);
  }

  @override
  Future<Set<String>> fetchClaimedChallengeRewardKeys() async {
    final profileId = await _database.activeProfileId();
    final rows = await _database.selectList('''
      SELECT stage_id, stars
      FROM challenge_stage_rewards
      WHERE profile_id = $profileId;
    ''');
    return rows.map((row) => '${row['stage_id']}:${row['stars']}').toSet();
  }

  @override
  Future<bool> markChallengeRewardClaimed({
    required String stageId,
    required int stars,
  }) async {
    if (stageId.isEmpty || stars <= 0) {
      return false;
    }
    final profileId = await _database.activeProfileId();
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final mutationId = nextClientMutationId('challenge_reward');
    final deviceId = currentActorDeviceId();
    final existing = await _database.selectSingle('''
      SELECT id
      FROM challenge_stage_rewards
      WHERE profile_id = $profileId
        AND stage_id = ${sqlString(stageId)}
        AND stars = $stars
      LIMIT 1;
    ''');
    if (existing != null) {
      return false;
    }
    await _database.customStatement('''
      INSERT INTO challenge_stage_rewards (
        profile_id,
        stage_id,
        stars,
        claimed_at,
        client_mutation_id,
        last_actor_device_id,
        sync_status,
        created_at,
        updated_at
      )
      VALUES (
        $profileId,
        ${sqlString(stageId)},
        $stars,
        ${sqlString(nowIso)},
        ${sqlString(mutationId)},
        ${sqlString(deviceId)},
        'pending_push',
        ${sqlString(nowIso)},
        ${sqlString(nowIso)}
      );
    ''');
    return true;
  }

  @override
  Future<void> completeDailyPoem(DateTime date) async {
    await _database.ensureDefaults();
    final profileId = await _database.activeProfileId();
    final dateKey = AppFormatters.dateKey(date);
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final mutationId = nextClientMutationId('daily');
    final deviceId = currentActorDeviceId();

    await _database.ensureDailyPoem(date);
    final currentRow = await _database.selectSingle('''
      SELECT poem_id, is_completed
      FROM daily_poem_records
      WHERE profile_id = $profileId AND date_key = ${sqlString(dateKey)}
      LIMIT 1;
    ''');
    if (((currentRow?['is_completed'] as int?) ?? 0) == 1) {
      return;
    }

    await _database.customStatement('''
      UPDATE daily_poem_records
      SET is_completed = 1,
          completed_at = ${sqlString(nowIso)},
          points_earned = $_dailyPoemPoints,
          client_mutation_id = ${sqlString(mutationId)},
          last_actor_device_id = ${sqlString(deviceId)},
          sync_status = 'pending_push',
          updated_at = ${sqlString(nowIso)}
      WHERE profile_id = $profileId
        AND date_key = ${sqlString(dateKey)};
    ''');

    await _recordCheckIn(
      dateKey: dateKey,
      checkInType: 'daily_poem',
      points: _dailyPoemPoints,
      mutationId: nextClientMutationId('checkin'),
      deviceId: deviceId,
      nowIso: nowIso,
    );

    final poemId = (currentRow?['poem_id'] as int?) ?? 0;
    if (poemId > 0) {
      await logLearningRecord(
        poemId: poemId,
        mode: 'daily_poem',
        durationMinutes: 5,
        note: '完成今日一诗',
      );
    }
  }

  @override
  Future<DailyPoemProgress> fetchDailyPoemProgress({DateTime? date}) async {
    await _database.ensureDefaults();
    final profileId = await _database.activeProfileId();
    final targetDate = date ?? DateTime.now();
    final dateKey = AppFormatters.dateKey(targetDate);
    await _database.ensureDailyPoem(targetDate);

    final pointsRow = await _database.selectSingle('''
      SELECT *
      FROM user_points
      WHERE id = $profileId
      LIMIT 1;
    ''');
    final dailyRow = await _database.selectSingle('''
      SELECT is_completed, points_earned, review_count
      FROM daily_poem_records
      WHERE profile_id = $profileId AND date_key = ${sqlString(dateKey)}
      LIMIT 1;
    ''');

    return DailyPoemProgress(
      totalPoints: (pointsRow?['total_points'] as int?) ?? 0,
      currentPoints: (pointsRow?['current_points'] as int?) ?? 0,
      totalCheckIns: (pointsRow?['total_check_ins'] as int?) ?? 0,
      consecutiveDays: (pointsRow?['consecutive_days'] as int?) ?? 0,
      lastCheckInDate: DateTime.tryParse(
        pointsRow?['last_check_in_date'] as String? ?? '',
      ),
      todayCompleted: ((dailyRow?['is_completed'] as int?) ?? 0) == 1,
      todayPoints: (dailyRow?['points_earned'] as int?) ?? 0,
      todayReviewCount: (dailyRow?['review_count'] as int?) ?? 0,
    );
  }

  @override
  Future<List<DailyPoemHistoryEntry>> fetchDailyPoemHistory({
    int limit = 14,
  }) async {
    final profileId = await _database.activeProfileId();
    final rows = await _database.selectList('''
      SELECT d.*, p.title, p.author, p.dynasty
      FROM daily_poem_records d
      INNER JOIN poems p ON p.id = d.poem_id
      WHERE d.profile_id = $profileId
      ORDER BY d.date_key DESC
      LIMIT $limit;
    ''');
    return rows.map(DailyPoemHistoryEntry.fromRow).toList(growable: false);
  }

  @override
  Future<void> reviewDailyPoem(DateTime date) async {
    await _database.ensureDefaults();
    final profileId = await _database.activeProfileId();
    final dateKey = AppFormatters.dateKey(date);
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final mutationId = nextClientMutationId('daily-review');
    final deviceId = currentActorDeviceId();

    await _database.ensureDailyPoem(date);
    final row = await _database.selectSingle('''
      SELECT poem_id
      FROM daily_poem_records
      WHERE profile_id = $profileId AND date_key = ${sqlString(dateKey)}
      LIMIT 1;
    ''');
    final poemId = (row?['poem_id'] as int?) ?? 0;
    if (poemId == 0) {
      return;
    }

    await _database.customStatement('''
      UPDATE daily_poem_records
      SET review_count = COALESCE(review_count, 0) + 1,
          last_reviewed_at = ${sqlString(nowIso)},
          client_mutation_id = ${sqlString(mutationId)},
          last_actor_device_id = ${sqlString(deviceId)},
          sync_status = 'pending_push',
          updated_at = ${sqlString(nowIso)}
      WHERE profile_id = $profileId AND date_key = ${sqlString(dateKey)};
    ''');

    await logLearningRecord(
      poemId: poemId,
      mode: 'daily_poem_review',
      durationMinutes: 3,
      note: '复习每日一诗',
    );
  }

  @override
  Future<List<StudyCardDeckEntry>> fetchStudyCardDeck({
    StudyCardQuery query = const StudyCardQuery(),
  }) async {
    await _database.ensureDefaults();
    final profileId = await _database.activeProfileId();
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final conditions = <String>['p.deleted_at IS NULL'];

    switch (query.filterType) {
      case StudyCardFilterType.all:
        break;
      case StudyCardFilterType.dynasty:
        final value = query.filterValue?.trim();
        if (value != null && value.isNotEmpty) {
          conditions.add('p.dynasty = ${sqlString(value)}');
        }
        break;
      case StudyCardFilterType.author:
        final value = query.filterValue?.trim();
        if (value != null && value.isNotEmpty) {
          conditions.add('p.author = ${sqlString(value)}');
        }
        break;
      case StudyCardFilterType.category:
        final value = query.filterValue?.trim();
        if (value != null && value.isNotEmpty) {
          conditions.add('p.category = ${sqlString(value)}');
        }
        break;
      case StudyCardFilterType.favorites:
        conditions.add('f.id IS NOT NULL AND f.deleted_at IS NULL');
        break;
      case StudyCardFilterType.dueReview:
        conditions.add(
          's.next_review_at IS NOT NULL AND s.next_review_at <= ${sqlString(nowIso)}',
        );
        break;
      case StudyCardFilterType.newCards:
        conditions.add("(s.memory_status IS NULL OR s.memory_status = 'new')");
        break;
      case StudyCardFilterType.mastered:
        conditions.add("s.memory_status = 'mastered'");
        break;
    }

    final rows = await _database.selectList('''
      SELECT
        p.*,
        p.id AS poem_id,
        COALESCE(s.memory_status, 'new') AS memory_status,
        COALESCE(s.review_count, 0) AS review_count,
        s.next_review_at,
        s.note AS study_note,
        s.updated_at AS study_updated_at,
        CASE WHEN f.id IS NOT NULL AND f.deleted_at IS NULL THEN 1 ELSE 0 END AS is_favorite
      FROM poems p
      LEFT JOIN study_card_progress s ON s.poem_id = p.id AND s.profile_id = $profileId
      LEFT JOIN favorites f ON f.poem_id = p.id AND f.profile_id = $profileId
      WHERE ${conditions.join(' AND ')}
      ORDER BY
        CASE
          WHEN s.next_review_at IS NOT NULL AND s.next_review_at <= ${sqlString(nowIso)} THEN 0
          WHEN s.next_review_at IS NOT NULL THEN 1
          ELSE 2
        END ASC,
        COALESCE(s.next_review_at, '9999-12-31T00:00:00Z') ASC,
        p.grade ASC,
        p.id ASC;
    ''');

    return rows
        .map(
          (row) => StudyCardDeckEntry(
            poem: Poem.fromRow(row),
            progress: StudyCardProgress.fromRow(row),
            isFavorite: ((row['is_favorite'] as int?) ?? 0) == 1,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<StudyCardFilterOptions> fetchStudyCardFilterOptions() async {
    final dynastyRows = await _database.selectList('''
      SELECT dynasty
      FROM poems
      WHERE deleted_at IS NULL AND dynasty IS NOT NULL AND dynasty != ''
      GROUP BY dynasty
      ORDER BY MIN(id) ASC;
    ''');
    final authorRows = await _database.selectList('''
      SELECT author
      FROM poems
      WHERE deleted_at IS NULL AND author IS NOT NULL AND author != ''
      GROUP BY author
      ORDER BY COUNT(*) DESC, MIN(id) ASC;
    ''');
    final categoryRows = await _database.selectList('''
      SELECT category
      FROM poems
      WHERE deleted_at IS NULL AND category IS NOT NULL AND category != ''
      GROUP BY category
      ORDER BY COUNT(*) DESC, MIN(id) ASC;
    ''');

    return StudyCardFilterOptions(
      dynasties: dynastyRows
          .map((row) => row['dynasty'] as String?)
          .whereType<String>()
          .toList(growable: false),
      authors: authorRows
          .map((row) => row['author'] as String?)
          .whereType<String>()
          .toList(growable: false),
      categories: categoryRows
          .map((row) => row['category'] as String?)
          .whereType<String>()
          .toList(growable: false),
    );
  }

  @override
  Future<void> markStudyCardReview({
    required int poemId,
    required bool remembered,
  }) async {
    await _database.ensureDefaults();
    final profileId = await _database.activeProfileId();
    final existing = await _database.selectSingle('''
      SELECT review_count, note
      FROM study_card_progress
      WHERE profile_id = $profileId AND poem_id = $poemId
      LIMIT 1;
    ''');

    final currentReviewCount = (existing?['review_count'] as int?) ?? 0;
    final currentNote = existing?['note'] as String?;
    final nextReviewCount = remembered ? currentReviewCount + 1 : 0;
    final intervalDays =
        remembered
            ? StudyCardReviewSchedule.intervalForReviewCount(nextReviewCount)
            : 1;
    final nextStatus =
        remembered
            ? (nextReviewCount >= 3 ? 'mastered' : 'learning')
            : 'review';

    await _upsertStudyCardProgress(
      poemId: poemId,
      memoryStatus: nextStatus,
      reviewCount: nextReviewCount,
      nextReviewAt: DateTime.now().add(Duration(days: intervalDays)),
      note: currentNote,
      mutationPrefix: remembered ? 'study-card-remember' : 'study-card-review',
    );

    await logLearningRecord(
      poemId: poemId,
      mode: 'study_card',
      durationMinutes: _studyCardReviewMinutes,
      note: remembered ? '学习卡片：已记住，$intervalDays 天后再复习' : '学习卡片：安排明天再看一遍',
    );
  }

  @override
  Future<void> saveStudyCardNote({
    required int poemId,
    required String? note,
  }) async {
    await _database.ensureDefaults();
    final profileId = await _database.activeProfileId();
    final existing = await _database.selectSingle('''
      SELECT memory_status, review_count, next_review_at
      FROM study_card_progress
      WHERE profile_id = $profileId AND poem_id = $poemId
      LIMIT 1;
    ''');

    await _upsertStudyCardProgress(
      poemId: poemId,
      memoryStatus: existing?['memory_status'] as String? ?? 'new',
      reviewCount: (existing?['review_count'] as int?) ?? 0,
      nextReviewAt: DateTime.tryParse(
        existing?['next_review_at'] as String? ?? '',
      ),
      note: note,
      mutationPrefix: 'study-card-note',
    );
  }

  Future<int> _computeStreakDays() async {
    final profileId = await _database.activeProfileId();
    final checkInRow = await _database.selectSingle('''
      SELECT consecutive_days
      FROM user_points
      WHERE id = $profileId
      LIMIT 1;
    ''');
    final checkInStreak = (checkInRow?['consecutive_days'] as int?) ?? 0;

    final rows = await _database.selectList('''
      SELECT DISTINCT substr(created_at, 1, 10) AS day
      FROM learning_records
      WHERE profile_id = $profileId
      ORDER BY day DESC;
    ''');
    final learnedDays =
        rows.map((row) => row['day'] as String?).whereType<String>().toSet();
    if (learnedDays.isEmpty) {
      return 0;
    }

    final today = DateTime.now();
    var cursor = DateTime(today.year, today.month, today.day);
    var streak = 0;

    if (!learnedDays.contains(AppFormatters.dateKey(cursor))) {
      cursor = cursor.subtract(const Duration(days: 1));
    }

    while (learnedDays.contains(AppFormatters.dateKey(cursor))) {
      streak += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    return streak > checkInStreak ? streak : checkInStreak;
  }

  Future<bool> _recordCheckIn({
    required String dateKey,
    required String checkInType,
    required int points,
    required String mutationId,
    required String deviceId,
    required String nowIso,
  }) async {
    final profileId = await _database.activeProfileId();
    final existing = await _database.selectSingle('''
      SELECT id
      FROM check_in_records
      WHERE profile_id = $profileId
        AND date_key = ${sqlString(dateKey)}
        AND check_in_type = ${sqlString(checkInType)}
      LIMIT 1;
    ''');
    if (existing != null) {
      return false;
    }

    await _database.customStatement('''
      INSERT INTO check_in_records (
        profile_id,
        date_key,
        check_in_type,
        points_earned,
        client_mutation_id,
        last_actor_device_id,
        sync_status,
        created_at,
        updated_at
      )
      VALUES (
        $profileId,
        ${sqlString(dateKey)},
        ${sqlString(checkInType)},
        $points,
        ${sqlString(mutationId)},
        ${sqlString(deviceId)},
        'pending_push',
        ${sqlString(nowIso)},
        ${sqlString(nowIso)}
      );
    ''');

    final consecutiveDays = await _calculateConsecutiveCheckInDays();
    await _database.customStatement('''
      UPDATE user_points
      SET total_points = total_points + $points,
          current_points = current_points + $points,
          total_check_ins = total_check_ins + 1,
          consecutive_days = $consecutiveDays,
          last_check_in_date = ${sqlString(dateKey)},
          client_mutation_id = ${sqlString(mutationId)},
          last_actor_device_id = ${sqlString(deviceId)},
          sync_status = 'pending_push',
          updated_at = ${sqlString(nowIso)}
      WHERE id = $profileId;
    ''');
    return true;
  }

  Future<int> _calculateConsecutiveCheckInDays() async {
    final profileId = await _database.activeProfileId();
    final rows = await _database.selectList('''
      SELECT DISTINCT date_key
      FROM check_in_records
      WHERE profile_id = $profileId
      ORDER BY date_key DESC;
    ''');
    final checkInDays =
        rows
            .map((row) => row['date_key'] as String?)
            .whereType<String>()
            .toSet();
    if (checkInDays.isEmpty) {
      return 0;
    }

    final today = DateTime.now();
    var cursor = DateTime(today.year, today.month, today.day);
    var streak = 0;

    if (!checkInDays.contains(AppFormatters.dateKey(cursor))) {
      cursor = cursor.subtract(const Duration(days: 1));
    }

    while (checkInDays.contains(AppFormatters.dateKey(cursor))) {
      streak += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    return streak;
  }

  Future<void> _upsertStudyCardProgress({
    required int poemId,
    required String memoryStatus,
    required int reviewCount,
    required DateTime? nextReviewAt,
    required String? note,
    required String mutationPrefix,
  }) async {
    final profileId = await _database.activeProfileId();
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final mutationId = nextClientMutationId(mutationPrefix);
    final deviceId = currentActorDeviceId();
    final normalizedNote = note?.trim();

    await _database.customStatement('''
      INSERT INTO study_card_progress (
        profile_id,
        poem_id,
        memory_status,
        review_count,
        next_review_at,
        note,
        client_mutation_id,
        last_actor_device_id,
        sync_status,
        created_at,
        updated_at
      )
      VALUES (
        $profileId,
        $poemId,
        ${sqlString(memoryStatus)},
        $reviewCount,
        ${sqlNullable(nextReviewAt?.toUtc().toIso8601String())},
        ${sqlNullable(normalizedNote)},
        ${sqlString(mutationId)},
        ${sqlString(deviceId)},
        'pending_push',
        ${sqlString(nowIso)},
        ${sqlString(nowIso)}
      )
      ON CONFLICT(profile_id, poem_id) DO UPDATE SET
        memory_status = excluded.memory_status,
        review_count = excluded.review_count,
        next_review_at = excluded.next_review_at,
        note = excluded.note,
        client_mutation_id = excluded.client_mutation_id,
        last_actor_device_id = excluded.last_actor_device_id,
        sync_status = excluded.sync_status,
        updated_at = excluded.updated_at;
    ''');
  }

  @override
  Future<bool> awardActivityPoints({
    required String activityType,
    required int points,
  }) async {
    if (points <= 0) {
      return false;
    }
    final dateKey = AppFormatters.dateKey(DateTime.now());
    final mutationId = nextClientMutationId(activityType);
    final deviceId = currentActorDeviceId();
    final nowIso = DateTime.now().toUtc().toIso8601String();
    return _recordCheckIn(
      dateKey: dateKey,
      checkInType: activityType,
      points: points,
      mutationId: mutationId,
      deviceId: deviceId,
      nowIso: nowIso,
    );
  }

  int? _roundedInt(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    return null;
  }

  int _longestDateKeyStreak(List<String> dateKeys) {
    if (dateKeys.isEmpty) {
      return 0;
    }

    var longest = 1;
    var current = 1;
    DateTime? previous;

    for (final dateKey in dateKeys) {
      final currentDate = DateTime.tryParse(dateKey);
      if (currentDate == null) {
        continue;
      }
      if (previous != null && currentDate.difference(previous).inDays == 1) {
        current += 1;
      } else if (previous != null &&
          currentDate.difference(previous).inDays == 0) {
        // DISTINCT should already remove duplicates, but keep this safe.
      } else {
        current = 1;
      }
      if (current > longest) {
        longest = current;
      }
      previous = currentDate;
    }

    return longest;
  }
}
