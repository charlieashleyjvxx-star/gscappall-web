import 'package:flutter_test/flutter_test.dart';
import 'package:gscappall/domain/learning_models.dart';

void main() {
  test('parent summary includes game-based learning performance', () {
    final report = LearningGrowthReport(
      period: GrowthReportPeriod.weekly,
      startAt: DateTime.utc(2026, 5, 5),
      endAt: DateTime.utc(2026, 5, 11),
      totalSessions: 3,
      totalMinutes: 18,
      uniquePoems: 2,
      averageScore: 86,
      dailyPoemCompletions: 1,
      studyCardReviews: 3,
      practiceReportCount: 1,
      wrongQuestionCount: 1,
      reviewedWrongQuestionCount: 1,
      activeDays: 2,
      longestLearningStreak: 2,
      previousWrongQuestionCount: 2,
      previousReviewedWrongQuestionCount: 1,
      previousAverageScore: 80,
      modeStats: const [
        LearningModeStat(
          mode: 'poetry_jielong',
          count: 2,
          minutes: 12,
          averageScore: 88,
        ),
        LearningModeStat(
          mode: 'feihualing',
          count: 1,
          minutes: 6,
          averageScore: 82,
        ),
      ],
      previousModeStats: const [
        LearningModeStat(
          mode: 'poetry_jielong',
          count: 1,
          minutes: 6,
          averageScore: 80,
        ),
      ],
      stageStats: const [
        LearningStageStat(
          stageId: 'jielong_entry',
          count: 2,
          minutes: 12,
          averageScore: 88,
        ),
      ],
      previousStageStats: const [
        LearningStageStat(
          stageId: 'jielong_entry',
          count: 1,
          minutes: 6,
          averageScore: 80,
        ),
      ],
      scoreTrend: const [],
    );

    expect(report.gameSessionCount, 3);
    expect(report.gameModeStats.map((stat) => stat.mode), [
      'poetry_jielong',
      'feihualing',
    ]);
    expect(report.gameAverageScore, 86);
    expect(report.previousGameSessionCount, 1);
    expect(report.gameSessionDelta, 2);
    expect(report.previousGameAverageScore, 80);
    expect(report.gameAverageScoreDelta, 6);
    expect(report.parentSummary, contains('游戏化练习 3 次'));
    expect(report.parentSummary, contains('均分 86 分'));
  });
}
