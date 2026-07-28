import '../learning_models.dart';

abstract class LearningRepository {
  Future<void> logLearningRecord({
    required int poemId,
    required String mode,
    int durationMinutes,
    int? score,
    String? note,
    String? stageId,
  });

  Future<LearningSummary> fetchSummary();
  Future<LearningGrowthReport> fetchGrowthReport({
    GrowthReportPeriod period = GrowthReportPeriod.weekly,
  });
  Future<List<LearningRecord>> fetchRecentRecords({int limit = 12});
  Future<Map<String, ChallengeModeProgress>> fetchChallengeModeProgress();
  Future<List<LearningRecord>> fetchChallengeModeHistory({
    required String mode,
    int limit = 10,
    String? stageId,
  });
  Future<Set<String>> fetchClaimedChallengeRewardKeys();
  Future<bool> markChallengeRewardClaimed({
    required String stageId,
    required int stars,
  });
  Future<void> completeDailyPoem(DateTime date);
  Future<DailyPoemProgress> fetchDailyPoemProgress({DateTime? date});
  Future<List<DailyPoemHistoryEntry>> fetchDailyPoemHistory({int limit = 14});
  Future<void> reviewDailyPoem(DateTime date);
  Future<List<StudyCardDeckEntry>> fetchStudyCardDeck({
    StudyCardQuery query = const StudyCardQuery(),
  });
  Future<StudyCardFilterOptions> fetchStudyCardFilterOptions();
  Future<void> markStudyCardReview({
    required int poemId,
    required bool remembered,
  });
  Future<void> saveStudyCardNote({required int poemId, required String? note});
  Future<bool> awardActivityPoints({
    required String activityType,
    required int points,
  });
}
