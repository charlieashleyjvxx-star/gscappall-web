import 'poem.dart';

class LearningRecord {
  const LearningRecord({
    required this.id,
    required this.poemId,
    required this.poemTitle,
    required this.poemAuthor,
    required this.mode,
    required this.durationMinutes,
    required this.score,
    required this.studiedAt,
    this.note,
    this.stageId,
  });

  factory LearningRecord.fromRow(Map<String, Object?> row) {
    return LearningRecord(
      id: (row['id'] as int?) ?? 0,
      poemId: (row['poem_id'] as int?) ?? 0,
      poemTitle: row['title'] as String? ?? '',
      poemAuthor: row['author'] as String? ?? '',
      mode: row['mode'] as String? ?? 'review',
      durationMinutes: (row['duration_minutes'] as int?) ?? 0,
      score: row['score'] as int?,
      studiedAt:
          DateTime.tryParse(row['created_at'] as String? ?? '') ??
          DateTime.now(),
      note: row['note'] as String?,
      stageId: row['stage_id'] as String?,
    );
  }

  final int id;
  final int poemId;
  final String poemTitle;
  final String poemAuthor;
  final String mode;
  final int durationMinutes;
  final int? score;
  final DateTime studiedAt;
  final String? note;
  final String? stageId;
}

class LearningSummary {
  const LearningSummary({
    required this.totalLearnedPoems,
    required this.totalFavorites,
    required this.totalMinutes,
    required this.streakDays,
    required this.dailyPoemCompleted,
  });

  final int totalLearnedPoems;
  final int totalFavorites;
  final int totalMinutes;
  final int streakDays;
  final bool dailyPoemCompleted;
}

class ChallengeModeProgress {
  const ChallengeModeProgress({
    required this.mode,
    required this.totalSessions,
    required this.bestScore,
    required this.completedLines,
  });

  final String mode;
  final int totalSessions;
  final int bestScore;
  final int completedLines;
}

enum GrowthReportPeriod {
  weekly(7, '本周'),
  monthly(30, '本月');

  const GrowthReportPeriod(this.days, this.label);

  final int days;
  final String label;
}

class LearningModeStat {
  const LearningModeStat({
    required this.mode,
    required this.count,
    required this.minutes,
    required this.averageScore,
  });

  factory LearningModeStat.fromRow(Map<String, Object?> row) {
    return LearningModeStat(
      mode: row['mode'] as String? ?? 'unknown',
      count: (row['count'] as int?) ?? 0,
      minutes: (row['minutes'] as int?) ?? 0,
      averageScore: _nullableRoundedInt(row['average_score']),
    );
  }

  final String mode;
  final int count;
  final int minutes;
  final int? averageScore;
}

class LearningStageStat {
  const LearningStageStat({
    required this.stageId,
    required this.count,
    required this.minutes,
    required this.averageScore,
  });

  factory LearningStageStat.fromRow(Map<String, Object?> row) {
    return LearningStageStat(
      stageId: row['stage_id'] as String? ?? '',
      count: (row['count'] as int?) ?? 0,
      minutes: (row['minutes'] as int?) ?? 0,
      averageScore: _nullableRoundedInt(row['average_score']),
    );
  }

  final String stageId;
  final int count;
  final int minutes;
  final int? averageScore;
}

class LearningScoreTrend {
  const LearningScoreTrend({
    required this.dateKey,
    required this.count,
    required this.averageScore,
  });

  factory LearningScoreTrend.fromRow(Map<String, Object?> row) {
    return LearningScoreTrend(
      dateKey: row['date_key'] as String? ?? '',
      count: (row['count'] as int?) ?? 0,
      averageScore: _nullableRoundedInt(row['average_score']) ?? 0,
    );
  }

  final String dateKey;
  final int count;
  final int averageScore;
}

class LearningStageTrendPoint {
  const LearningStageTrendPoint({
    required this.stageId,
    required this.dateKey,
    required this.count,
    required this.minutes,
    required this.averageScore,
  });

  factory LearningStageTrendPoint.fromRow(Map<String, Object?> row) {
    return LearningStageTrendPoint(
      stageId: row['stage_id'] as String? ?? '',
      dateKey: row['date_key'] as String? ?? '',
      count: (row['count'] as int?) ?? 0,
      minutes: (row['minutes'] as int?) ?? 0,
      averageScore: _nullableRoundedInt(row['average_score']),
    );
  }

  final String stageId;
  final String dateKey;
  final int count;
  final int minutes;
  final int? averageScore;
}

class LearningGrowthReport {
  const LearningGrowthReport({
    required this.period,
    required this.startAt,
    required this.endAt,
    required this.totalSessions,
    required this.totalMinutes,
    required this.uniquePoems,
    required this.averageScore,
    required this.dailyPoemCompletions,
    required this.studyCardReviews,
    required this.practiceReportCount,
    required this.wrongQuestionCount,
    required this.reviewedWrongQuestionCount,
    required this.activeDays,
    required this.longestLearningStreak,
    required this.previousWrongQuestionCount,
    required this.previousReviewedWrongQuestionCount,
    required this.previousAverageScore,
    required this.modeStats,
    required this.previousModeStats,
    required this.stageStats,
    required this.previousStageStats,
    required this.scoreTrend,
    this.stageTrend = const [],
  });

  final GrowthReportPeriod period;
  final DateTime startAt;
  final DateTime endAt;
  final int totalSessions;
  final int totalMinutes;
  final int uniquePoems;
  final int? averageScore;
  final int dailyPoemCompletions;
  final int studyCardReviews;
  final int practiceReportCount;
  final int wrongQuestionCount;
  final int reviewedWrongQuestionCount;
  final int activeDays;
  final int longestLearningStreak;
  final int previousWrongQuestionCount;
  final int previousReviewedWrongQuestionCount;
  final int? previousAverageScore;
  final List<LearningModeStat> modeStats;
  final List<LearningModeStat> previousModeStats;
  final List<LearningStageStat> stageStats;
  final List<LearningStageStat> previousStageStats;
  final List<LearningScoreTrend> scoreTrend;
  final List<LearningStageTrendPoint> stageTrend;

  bool get hasActivity => totalSessions > 0 || practiceReportCount > 0;

  double get wrongReviewRatio {
    if (wrongQuestionCount == 0) {
      return 1;
    }
    return (reviewedWrongQuestionCount / wrongQuestionCount).clamp(0, 1);
  }

  int get pendingWrongQuestionCount =>
      (wrongQuestionCount - reviewedWrongQuestionCount).clamp(
        0,
        wrongQuestionCount,
      );

  int get wrongQuestionDelta => wrongQuestionCount - previousWrongQuestionCount;

  int? get scoreDelta {
    if (averageScore == null || previousAverageScore == null) {
      return null;
    }
    return averageScore! - previousAverageScore!;
  }

  LearningModeStat? get topMode {
    if (modeStats.isEmpty) {
      return null;
    }
    final sorted = modeStats.toList(growable: false)
      ..sort((left, right) => right.count.compareTo(left.count));
    return sorted.first;
  }

  int get gameSessionCount {
    return gameModeStats.fold<int>(0, (sum, stat) => sum + stat.count);
  }

  int get previousGameSessionCount {
    return previousGameModeStats.fold<int>(0, (sum, stat) => sum + stat.count);
  }

  int get gameSessionDelta => gameSessionCount - previousGameSessionCount;

  List<LearningModeStat> get gameModeStats {
    return modeStats.where(_isGameMode).toList(growable: false);
  }

  List<LearningModeStat> get previousGameModeStats {
    return previousModeStats.where(_isGameMode).toList(growable: false);
  }

  LearningModeStat? previousGameModeStat(String mode) {
    for (final stat in previousGameModeStats) {
      if (stat.mode == mode) {
        return stat;
      }
    }
    return null;
  }

  static bool _isGameMode(LearningModeStat stat) {
    return stat.mode == 'poetry_jielong' ||
        stat.mode == 'feihualing' ||
        stat.mode == 'dictation';
  }

  List<LearningModeStat> get gameModeTrendStats {
    final modes = <String>{
      ...gameModeStats.map((stat) => stat.mode),
      ...previousGameModeStats.map((stat) => stat.mode),
    };
    return modes
        .map((mode) {
          return gameModeStats.firstWhere(
            (stat) => stat.mode == mode,
            orElse:
                () => LearningModeStat(
                  mode: mode,
                  count: 0,
                  minutes: 0,
                  averageScore: null,
                ),
          );
        })
        .toList(growable: false);
  }

  int? get gameAverageScore {
    return _weightedAverage(gameModeStats);
  }

  int? get previousGameAverageScore {
    return _weightedAverage(previousGameModeStats);
  }

  int? get gameAverageScoreDelta {
    final current = gameAverageScore;
    final previous = previousGameAverageScore;
    if (current == null || previous == null) {
      return null;
    }
    return current - previous;
  }

  List<LearningStageStat> get gameStageStats {
    return stageStats
        .where((stat) => stat.stageId.trim().isNotEmpty)
        .toList(growable: false);
  }

  LearningStageStat? previousGameStageStat(String stageId) {
    for (final stat in previousStageStats) {
      if (stat.stageId == stageId) {
        return stat;
      }
    }
    return null;
  }

  List<LearningStageTrendPoint> gameStageTrend(String stageId) {
    return stageTrend
        .where((point) => point.stageId == stageId && point.dateKey.isNotEmpty)
        .toList(growable: false);
  }

  String get gameTrendExplanation {
    if (gameSessionCount == 0 && previousGameSessionCount == 0) {
      return '本期还没有游戏化练习记录，建议先从诗词接龙或飞花令开始一次短练。';
    }
    final countText =
        gameSessionDelta == 0
            ? '练习次数与上一周期持平'
            : gameSessionDelta > 0
            ? '练习次数比上一周期多 $gameSessionDelta 次'
            : '练习次数比上一周期少 ${gameSessionDelta.abs()} 次';
    final scoreText =
        gameAverageScoreDelta == null
            ? '均分暂时缺少可比数据'
            : gameAverageScoreDelta == 0
            ? '均分保持稳定'
            : gameAverageScoreDelta! > 0
            ? '均分提高 ${gameAverageScoreDelta!} 分'
            : '均分下降 ${gameAverageScoreDelta!.abs()} 分';
    return '$countText，$scoreText。家长可以重点观察孩子是否愿意反复挑战未三星关卡。';
  }

  static int? _weightedAverage(List<LearningModeStat> stats) {
    final scoredStats = stats
        .where((stat) => stat.averageScore != null)
        .toList(growable: false);
    if (scoredStats.isEmpty) {
      return null;
    }
    final weightedScore = scoredStats.fold<int>(
      0,
      (sum, stat) => sum + (stat.averageScore! * stat.count),
    );
    final count = scoredStats.fold<int>(0, (sum, stat) => sum + stat.count);
    if (count == 0) {
      return null;
    }
    return (weightedScore / count).round();
  }

  String get focusSuggestion {
    if (!hasActivity) {
      return '先完成一次每日诗或学习卡复习，报告就会开始记录成长轨迹。';
    }
    if (pendingWrongQuestionCount > 0) {
      return '本期还有错题没有复盘，建议优先清理错题本。';
    }
    if (studyCardReviews < 3) {
      return '学习卡复习次数偏少，可以安排几张待复习卡巩固记忆。';
    }
    if ((averageScore ?? 0) < 75 && practiceReportCount > 0) {
      return '测评分数还有提升空间，建议从报告里的弱项类型开始练。';
    }
    return '节奏不错，继续保持每日短练和错题复盘。';
  }

  String get weakPointExplanation {
    if (!hasActivity) {
      return '暂时没有足够数据判断弱项。建议先完成每日诗、学习卡或一次听写测评。';
    }
    if (pendingWrongQuestionCount > 0) {
      final trend =
          wrongQuestionDelta <= 0
              ? '错题数量比上一周期没有增加，方向是好的。'
              : '错题数量比上一周期多 $wrongQuestionDelta 道，需要先稳住准确率。';
      return '主要弱项是错题复盘不足，还有 $pendingWrongQuestionCount 道错题没有标记复习。$trend';
    }
    if (studyCardReviews < 3) {
      return '主要弱项是记忆巩固不足，本期学习卡复习只有 $studyCardReviews 次。';
    }
    if ((averageScore ?? 100) < 75 && practiceReportCount > 0) {
      return '主要弱项是测评稳定性，本期均分 ${averageScore ?? 0}，建议从低分报告开始复盘。';
    }
    return '本期没有明显短板，可以继续保持当前练习节奏。';
  }

  String get parentSummary {
    if (!hasActivity) {
      return '${period.label}还没有形成学习记录。家长可以先陪孩子完成一次短练，建立第一条成长轨迹。';
    }
    final scoreText = averageScore == null ? '暂无有效得分' : '平均 $averageScore 分';
    final streakText =
        activeDays == 0
            ? '还没有形成稳定学习日'
            : '活跃 $activeDays 天，最长连续 $longestLearningStreak 天';
    final scoreTrendText =
        scoreDelta == null
            ? '得分趋势暂不明显'
            : scoreDelta! >= 0
            ? '均分比上一周期提高 $scoreDelta 分'
            : '均分比上一周期下降 ${scoreDelta!.abs()} 分';
    final wrongTrendText =
        wrongQuestionDelta <= 0
            ? '错题数量较上一周期持平或减少'
            : '错题比上一周期增加 $wrongQuestionDelta 道';
    final gameText =
        gameSessionCount == 0
            ? '游戏化练习还没有形成记录'
            : '游戏化练习 $gameSessionCount 次${gameAverageScore == null ? '' : '，均分 $gameAverageScore 分'}';
    return '${period.label}完成 $totalSessions 次练习，覆盖 $uniquePoems 首诗词，累计 $totalMinutes 分钟，$scoreText。$streakText；$scoreTrendText；$wrongTrendText；$gameText。$focusSuggestion';
  }
}

class DailyPoemBundle {
  const DailyPoemBundle({
    required this.dateKey,
    required this.poem,
    required this.isCompleted,
  });

  final String dateKey;
  final Poem poem;
  final bool isCompleted;
}

int? _nullableRoundedInt(Object? value) {
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

class DailyPoemProgress {
  const DailyPoemProgress({
    required this.totalPoints,
    required this.currentPoints,
    required this.totalCheckIns,
    required this.consecutiveDays,
    required this.todayCompleted,
    required this.todayPoints,
    required this.todayReviewCount,
    this.lastCheckInDate,
  });

  final int totalPoints;
  final int currentPoints;
  final int totalCheckIns;
  final int consecutiveDays;
  final bool todayCompleted;
  final int todayPoints;
  final int todayReviewCount;
  final DateTime? lastCheckInDate;
}

class DailyPoemHistoryEntry {
  const DailyPoemHistoryEntry({
    required this.dateKey,
    required this.poemId,
    required this.poemTitle,
    required this.poemAuthor,
    required this.poemDynasty,
    required this.isCompleted,
    required this.pointsEarned,
    required this.reviewCount,
    this.completedAt,
    this.lastReviewedAt,
  });

  factory DailyPoemHistoryEntry.fromRow(Map<String, Object?> row) {
    return DailyPoemHistoryEntry(
      dateKey: row['date_key'] as String? ?? '',
      poemId: (row['poem_id'] as int?) ?? 0,
      poemTitle: row['title'] as String? ?? '',
      poemAuthor: row['author'] as String? ?? '',
      poemDynasty: row['dynasty'] as String? ?? '',
      isCompleted: ((row['is_completed'] as int?) ?? 0) == 1,
      pointsEarned: (row['points_earned'] as int?) ?? 0,
      reviewCount: (row['review_count'] as int?) ?? 0,
      completedAt: DateTime.tryParse(row['completed_at'] as String? ?? ''),
      lastReviewedAt: DateTime.tryParse(
        row['last_reviewed_at'] as String? ?? '',
      ),
    );
  }

  final String dateKey;
  final int poemId;
  final String poemTitle;
  final String poemAuthor;
  final String poemDynasty;
  final bool isCompleted;
  final int pointsEarned;
  final int reviewCount;
  final DateTime? completedAt;
  final DateTime? lastReviewedAt;
}

enum StudyCardFilterType {
  all,
  dynasty,
  author,
  category,
  favorites,
  dueReview,
  newCards,
  mastered,
}

class StudyCardQuery {
  const StudyCardQuery({
    this.filterType = StudyCardFilterType.all,
    this.filterValue,
  });

  final StudyCardFilterType filterType;
  final String? filterValue;

  bool get requiresValue =>
      filterType == StudyCardFilterType.dynasty ||
      filterType == StudyCardFilterType.author ||
      filterType == StudyCardFilterType.category;

  StudyCardQuery copyWith({
    StudyCardFilterType? filterType,
    String? filterValue,
    bool clearValue = false,
  }) {
    return StudyCardQuery(
      filterType: filterType ?? this.filterType,
      filterValue: clearValue ? null : (filterValue ?? this.filterValue),
    );
  }
}

class StudyCardFilterOptions {
  const StudyCardFilterOptions({
    required this.dynasties,
    required this.authors,
    required this.categories,
  });

  final List<String> dynasties;
  final List<String> authors;
  final List<String> categories;
}

class StudyCardReviewSchedule {
  const StudyCardReviewSchedule._();

  static const List<int> intervalsInDays = [1, 2, 4, 7, 15, 30];

  static int intervalForReviewCount(int reviewCount) {
    final normalizedCount = reviewCount.clamp(1, intervalsInDays.length);
    return intervalsInDays[normalizedCount - 1];
  }

  static String nextReviewLabel(DateTime? nextReviewAt, {DateTime? now}) {
    if (nextReviewAt == null) {
      return '尚未安排复习';
    }

    final base = now ?? DateTime.now();
    final localNext = nextReviewAt.toLocal();
    final today = DateTime(base.year, base.month, base.day);
    final target = DateTime(localNext.year, localNext.month, localNext.day);
    final diff = target.difference(today).inDays;

    if (diff <= 0) {
      return '今天可复习';
    }
    if (diff == 1) {
      return '明天复习';
    }
    return '${localNext.month}/${localNext.day} 再复习';
  }
}

class StudyCardProgress {
  const StudyCardProgress({
    required this.poemId,
    required this.memoryStatus,
    required this.reviewCount,
    this.nextReviewAt,
    this.note,
    this.updatedAt,
  });

  factory StudyCardProgress.fromRow(Map<String, Object?> row) {
    return StudyCardProgress(
      poemId: (row['poem_id'] as int?) ?? 0,
      memoryStatus: row['memory_status'] as String? ?? 'new',
      reviewCount: (row['review_count'] as int?) ?? 0,
      nextReviewAt: DateTime.tryParse(row['next_review_at'] as String? ?? ''),
      note: row['study_note'] as String? ?? row['note'] as String?,
      updatedAt: DateTime.tryParse(row['study_updated_at'] as String? ?? ''),
    );
  }

  final int poemId;
  final String memoryStatus;
  final int reviewCount;
  final DateTime? nextReviewAt;
  final String? note;
  final DateTime? updatedAt;

  bool get hasNote => (note ?? '').trim().isNotEmpty;

  String get notePreview {
    final normalized = (note ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.length <= 48) {
      return normalized;
    }
    return '${normalized.substring(0, 48)}...';
  }
}

class StudyCardDeckEntry {
  const StudyCardDeckEntry({
    required this.poem,
    required this.progress,
    required this.isFavorite,
  });

  final Poem poem;
  final StudyCardProgress progress;
  final bool isFavorite;

  bool get isDueForReview {
    return isDueForReviewAt(DateTime.now());
  }

  bool isDueForReviewAt(DateTime now) {
    final nextReviewAt = progress.nextReviewAt;
    if (nextReviewAt == null) {
      return false;
    }
    return !nextReviewAt.isAfter(now);
  }
}

class StudyCardNoteDraft {
  const StudyCardNoteDraft._();

  static String? normalizeSubmitted(String? submittedText) {
    if (submittedText == null) {
      return null;
    }
    return submittedText.trim();
  }
}
