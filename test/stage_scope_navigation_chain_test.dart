import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gscappall/app/app_providers.dart';
import 'package:gscappall/domain/learning_models.dart';
import 'package:gscappall/domain/poem.dart';
import 'package:gscappall/domain/practice_models.dart';
import 'package:gscappall/domain/repositories/learning_repository.dart';
import 'package:gscappall/domain/repositories/practice_repository.dart';
import 'package:gscappall/features/evaluation/evaluation_placeholder_page.dart';
import 'package:gscappall/features/game/challenge_map_page.dart';
import 'package:gscappall/features/profile/learning_history_page.dart';
import 'package:gscappall/features/profile/profile_page.dart';
import 'package:gscappall/features/shared/stage_scope_route_args.dart';
import 'package:gscappall/features/wrong_book/wrong_book_placeholder_page.dart';
import 'package:gscappall/services/game/challenge_progress_service.dart';

void main() {
  testWidgets(
    'stage scoped route chain keeps stageId from map to report to growth and back',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final learningRepository = _StageChainLearningRepository();
      final practiceRepository = _StageChainPracticeRepository();
      final challengeService = const ChallengeProgressService();
      final stages = challengeService
          .defaultRules()
          .where((rule) => rule.mode == 'poetry_jielong')
          .take(2)
          .map(
            (rule) => challengeService.evaluate(
              rule: rule,
              bestScore: rule.id == 'jielong_entry' ? 82 : 0,
              completedLines: rule.id == 'jielong_entry' ? 3 : 0,
              totalSessions: rule.id == 'jielong_entry' ? 1 : 0,
            ),
          )
          .toList(growable: false);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            learningRepositoryProvider.overrideWithValue(learningRepository),
            practiceRepositoryProvider.overrideWithValue(practiceRepository),
          ],
          child: MaterialApp(
            home: ChallengeChapterDetailPage(
              title: 'stage-route-chain',
              stages: stages,
              initialStageId: 'jielong_entry',
              onStartPractice: (_) async {},
            ),
            onGenerateRoute: (settings) {
              final stageId =
                  StageScopeRouteArgs.fromSettings(settings)?.stageId;
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (_) {
                  switch (settings.name) {
                    case '/practice-reports':
                      return PracticeReportHistoryPage(initialStageId: stageId);
                    case '/wrong-book':
                      return WrongBookPlaceholderPage(initialStageId: stageId);
                    case '/learning-history':
                      return LearningHistoryPage(initialStageId: stageId);
                    case '/growth-report':
                      return GrowthReportDetailPage(
                        initialPeriod: GrowthReportPeriod.weekly,
                        initialStageId: stageId,
                      );
                    case '/challenge-map':
                      return Scaffold(
                        body: Center(child: Text('/challenge-map:$stageId')),
                      );
                  }
                  return Scaffold(body: Text('unknown:${settings.name}'));
                },
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('展开本关记录'));
      await tester.pumpAndSettle();

      final reportButton = find.widgetWithIcon(
        FilledButton,
        Icons.assessment_outlined,
      );
      await tester.scrollUntilVisible(reportButton, 220);
      await tester.tap(reportButton);
      await tester.pumpAndSettle();

      expect(practiceRepository.reportQueries.last.stageId, 'jielong_entry');

      final growthButton = find.widgetWithIcon(
        FilledButton,
        Icons.insights_rounded,
      );
      await tester.scrollUntilVisible(growthButton, 220);
      await tester.tap(growthButton.first);
      await tester.pumpAndSettle();

      expect(find.byType(GrowthReportDetailPage), findsOneWidget);

      final mapButton = find.widgetWithIcon(FilledButton, Icons.map_rounded);
      await tester.scrollUntilVisible(mapButton.last, 220);
      await tester.tap(mapButton.last);
      await tester.pumpAndSettle();

      expect(find.text('/challenge-map:jielong_entry'), findsOneWidget);
    },
  );

  test('stage scope args preserve source from map arguments', () {
    final args = StageScopeRouteArgs.fromSettings(
      const RouteSettings(
        arguments: {
          'stageId': 'dictation_checkpoint',
          'source': 'growth-report',
        },
      ),
    );

    expect(args?.stageId, 'dictation_checkpoint');
    expect(args?.source, 'growth-report');
  });
}

class _StageChainPracticeRepository implements PracticeRepository {
  final List<PracticeReportQuery> reportQueries = [];

  @override
  Future<PracticeReportOverview> fetchPracticeReportOverview({
    PracticeReportQuery query = const PracticeReportQuery(),
  }) async {
    reportQueries.add(query);
    return PracticeReportOverview(
      summaries: [
        PracticeReportSummary(
          id: 1,
          sessionId: 'session-1',
          mode: PracticeMode.recitation,
          poemId: 1,
          poemTitle: '静夜思',
          poemAuthor: '李白',
          totalScore: 88,
          correctCount: 3,
          totalQuestions: 3,
          generatedWrongCount: 0,
          completedAt: DateTime.utc(2026, 5, 11),
          stageId: 'jielong_entry',
        ),
      ],
      stats: PracticeReportStats(
        totalReports: 1,
        dictationCount: 0,
        evaluationCount: 0,
        readingCount: 0,
        recitationCount: 1,
        averageScore: 88,
        scoreBands: {for (final band in PracticeScoreBand.values) band: 0},
        mistakeTypes: {for (final type in PracticeMistakeType.values) type: 0},
      ),
    );
  }

  @override
  Future<List<Poem>> fetchPracticePoems({int limit = 60}) {
    throw UnimplementedError();
  }

  @override
  Future<PracticeSession> createSession({
    required PracticeMode mode,
    int? poemId,
    DictationDifficulty difficulty = DictationDifficulty.standard,
    DictationAnswerMode answerMode = DictationAnswerMode.fullText,
  }) {
    throw UnimplementedError();
  }

  @override
  PracticeLineResult evaluateAnswer({
    required PracticeQuestion question,
    required String answer,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<PracticeReport> completeSession({
    required PracticeSession session,
    required Map<int, String> answers,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<PracticeReport> saveAssessmentReport({
    required Poem poem,
    required PracticeMode mode,
    required List<PracticeLineResult> results,
    DateTime? completedAt,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<PracticeReportSummary>> fetchPracticeReportSummaries({
    int limit = 100,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<PracticeReportDetail?> fetchPracticeReportDetail(int id) {
    throw UnimplementedError();
  }

  @override
  Future<List<WrongQuestionEntry>> fetchWrongQuestions({
    WrongQuestionQuery query = const WrongQuestionQuery(),
  }) async {
    return const [];
  }

  @override
  Future<WrongQuestionEntry?> fetchWrongQuestionDetail(int id) {
    throw UnimplementedError();
  }

  @override
  Future<void> markWrongQuestionReviewed(int id) {
    throw UnimplementedError();
  }
}

class _StageChainLearningRepository implements LearningRepository {
  @override
  Future<LearningGrowthReport> fetchGrowthReport({
    GrowthReportPeriod period = GrowthReportPeriod.weekly,
  }) async {
    return LearningGrowthReport(
      period: period,
      startAt: DateTime.utc(2026, 5, 5),
      endAt: DateTime.utc(2026, 5, 11),
      totalSessions: 3,
      totalMinutes: 18,
      uniquePoems: 2,
      averageScore: 86,
      dailyPoemCompletions: 1,
      studyCardReviews: 2,
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
  }

  @override
  Future<Map<String, ChallengeModeProgress>>
  fetchChallengeModeProgress() async {
    return const {
      'poetry_jielong': ChallengeModeProgress(
        mode: 'poetry_jielong',
        totalSessions: 1,
        bestScore: 82,
        completedLines: 3,
      ),
    };
  }

  @override
  Future<List<LearningRecord>> fetchChallengeModeHistory({
    required String mode,
    int limit = 10,
    String? stageId,
  }) async {
    if (stageId != null && stageId != 'jielong_entry') {
      return const [];
    }
    return [
      LearningRecord(
        id: 1,
        poemId: 1,
        poemTitle: '静夜思',
        poemAuthor: '李白',
        mode: mode,
        durationMinutes: 6,
        score: 82,
        studiedAt: DateTime.utc(2026, 5, 11),
        stageId: 'jielong_entry',
      ),
    ];
  }

  @override
  Future<List<LearningRecord>> fetchRecentRecords({int limit = 12}) async {
    return [
      LearningRecord(
        id: 1,
        poemId: 1,
        poemTitle: '静夜思',
        poemAuthor: '李白',
        mode: 'poetry_jielong',
        durationMinutes: 6,
        score: 82,
        studiedAt: DateTime.utc(2026, 5, 11),
        stageId: 'jielong_entry',
      ),
    ];
  }

  @override
  Future<Set<String>> fetchClaimedChallengeRewardKeys() async => const {};

  @override
  Future<bool> markChallengeRewardClaimed({
    required String stageId,
    required int stars,
  }) async {
    return false;
  }

  @override
  Future<LearningSummary> fetchSummary() {
    throw UnimplementedError();
  }

  @override
  Future<void> logLearningRecord({
    required int poemId,
    required String mode,
    int durationMinutes = 0,
    int? score,
    String? note,
    String? stageId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> completeDailyPoem(DateTime date) {
    throw UnimplementedError();
  }

  @override
  Future<DailyPoemProgress> fetchDailyPoemProgress({DateTime? date}) {
    throw UnimplementedError();
  }

  @override
  Future<List<DailyPoemHistoryEntry>> fetchDailyPoemHistory({int limit = 14}) {
    throw UnimplementedError();
  }

  @override
  Future<void> reviewDailyPoem(DateTime date) {
    throw UnimplementedError();
  }

  @override
  Future<List<StudyCardDeckEntry>> fetchStudyCardDeck({
    StudyCardQuery query = const StudyCardQuery(),
  }) {
    throw UnimplementedError();
  }

  @override
  Future<StudyCardFilterOptions> fetchStudyCardFilterOptions() {
    throw UnimplementedError();
  }

  @override
  Future<void> markStudyCardReview({
    required int poemId,
    required bool remembered,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> saveStudyCardNote({required int poemId, required String? note}) {
    throw UnimplementedError();
  }

  @override
  Future<bool> awardActivityPoints({
    required String activityType,
    required int points,
  }) {
    throw UnimplementedError();
  }
}
