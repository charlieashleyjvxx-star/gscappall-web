import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gscappall/app/app_providers.dart';
import 'package:gscappall/domain/learning_models.dart';
import 'package:gscappall/domain/repositories/learning_repository.dart';
import 'package:gscappall/features/profile/learning_history_page.dart';
import 'package:gscappall/features/shared/stage_scope_route_args.dart';

void main() {
  testWidgets('learning history applies initial stage filter', (tester) async {
    final repository = _FakeLearningRepository(
      records: [
        LearningRecord(
          id: 1,
          poemId: 1,
          poemTitle: 'stage-a',
          poemAuthor: 'author-a',
          mode: 'poetry_jielong',
          durationMinutes: 5,
          score: 88,
          studiedAt: DateTime(2026, 5, 21, 8),
          stageId: 'jielong_entry',
        ),
        LearningRecord(
          id: 2,
          poemId: 2,
          poemTitle: 'stage-b',
          poemAuthor: 'author-b',
          mode: 'dictation',
          durationMinutes: 6,
          score: 76,
          studiedAt: DateTime(2026, 5, 21, 9),
          stageId: 'dictation_checkpoint',
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [learningRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(
          home: LearningHistoryPage(initialStageId: 'jielong_entry'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('stage-a'), findsOneWidget);
    expect(find.text('stage-b'), findsNothing);
    expect(find.textContaining('当前只看'), findsOneWidget);

    await tester.tap(find.text('清除筛选'));
    await tester.pumpAndSettle();

    expect(find.text('stage-b'), findsOneWidget);
  });

  testWidgets('learning history reads stage filter from route settings', (
    tester,
  ) async {
    final repository = _FakeLearningRepository(
      records: [
        LearningRecord(
          id: 1,
          poemId: 1,
          poemTitle: 'stage-a',
          poemAuthor: 'author-a',
          mode: 'poetry_jielong',
          durationMinutes: 5,
          score: 88,
          studiedAt: DateTime(2026, 5, 21, 8),
          stageId: 'jielong_entry',
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [learningRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          initialRoute: '/learning-history',
          onGenerateRoute:
              (settings) => MaterialPageRoute(
                settings: StageScopeRouteArgs(
                  stageId: 'jielong_entry',
                  source: 'chapter-detail',
                ).toRouteSettings(name: settings.name),
                builder: (_) => const LearningHistoryPage(),
              ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('stage-a'), findsOneWidget);
    expect(find.textContaining('当前只看'), findsOneWidget);
    expect(find.textContaining('继续看这一关'), findsOneWidget);
    expect(find.text('回到该关卡章节'), findsOneWidget);
  });

  testWidgets('learning history explains growth report stage filter', (
    tester,
  ) async {
    final repository = _FakeLearningRepository(
      records: [
        LearningRecord(
          id: 1,
          poemId: 1,
          poemTitle: 'stage-a',
          poemAuthor: 'author-a',
          mode: 'poetry_jielong',
          durationMinutes: 5,
          score: 88,
          studiedAt: DateTime(2026, 5, 21, 8),
          stageId: 'jielong_entry',
        ),
        LearningRecord(
          id: 2,
          poemId: 2,
          poemTitle: 'stage-b',
          poemAuthor: 'author-b',
          mode: 'dictation',
          durationMinutes: 6,
          score: 76,
          studiedAt: DateTime(2026, 5, 21, 9),
          stageId: 'dictation_checkpoint',
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [learningRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          initialRoute: '/learning-history',
          onGenerateRoute:
              (settings) => MaterialPageRoute(
                settings: const StageScopeRouteArgs(
                  stageId: 'jielong_entry',
                  source: 'growth-report',
                ).toRouteSettings(name: settings.name),
                builder: (_) => const LearningHistoryPage(),
              ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('stage-a'), findsOneWidget);
    expect(find.text('stage-b'), findsNothing);
    expect(find.textContaining('已帮你找到这一关'), findsOneWidget);
    expect(find.textContaining('先看 接龙入门 最近练习'), findsOneWidget);

    await tester.tap(find.text('查看全部历史'));
    await tester.pumpAndSettle();

    expect(find.text('stage-b'), findsOneWidget);
    expect(find.textContaining('先看 接龙入门 最近练习'), findsNothing);
  });

  test('learning history filter scope matches stage and trend date', () {
    final scope = LearningHistoryFilterScope(
      stageId: 'jielong_entry',
      dateKey: '2026-05-21',
    );
    final matched = LearningRecord(
      id: 1,
      poemId: 1,
      poemTitle: 'trend-day',
      poemAuthor: 'author-a',
      mode: 'poetry_jielong',
      durationMinutes: 5,
      score: 88,
      studiedAt: DateTime.parse('2026-05-21T08:00:00Z'),
      stageId: 'jielong_entry',
    );
    final otherDate = LearningRecord(
      id: 2,
      poemId: 1,
      poemTitle: 'other-day',
      poemAuthor: 'author-a',
      mode: 'poetry_jielong',
      durationMinutes: 5,
      score: 88,
      studiedAt: DateTime.parse('2026-05-20T08:00:00Z'),
      stageId: 'jielong_entry',
    );

    expect(scope.matches(matched), isTrue);
    expect(scope.matches(otherDate), isFalse);
  });

  testWidgets('learning record detail opens from history tile', (tester) async {
    final repository = _FakeLearningRepository(
      records: [
        LearningRecord(
          id: 7,
          poemId: 1,
          poemTitle: 'detail-record',
          poemAuthor: 'author-a',
          mode: 'poetry_jielong',
          durationMinutes: 5,
          score: 88,
          studiedAt: DateTime(2026, 5, 21, 8),
          stageId: 'jielong_entry',
          note: 'stage note',
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [learningRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          home: const LearningHistoryPage(),
          onGenerateRoute: (settings) {
            final args = StageScopeRouteArgs.fromSettings(settings);
            return MaterialPageRoute<void>(
              settings: settings,
              builder:
                  (_) => LearningRecordDetailPage(
                    recordId: args?.learningRecordId ?? -1,
                  ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('detail-record'));
    await tester.pumpAndSettle();

    expect(find.text('学习记录详情'), findsOneWidget);
    expect(find.text('stage note'), findsOneWidget);
    expect(find.text('闯关关卡'), findsOneWidget);
    expect(find.text('关卡进步'), findsOneWidget);
    expect(find.textContaining('关卡：接龙入门'), findsOneWidget);
    expect(find.textContaining('完成句数：约 2 句接龙'), findsOneWidget);
    expect(find.textContaining('练习分数：88 分'), findsOneWidget);
  });

  testWidgets('learning record detail shows source hint from route args', (
    tester,
  ) async {
    final repository = _FakeLearningRepository(
      records: [
        LearningRecord(
          id: 7,
          poemId: 1,
          poemTitle: 'detail-record',
          poemAuthor: 'author-a',
          mode: 'poetry_jielong',
          durationMinutes: 5,
          score: 88,
          studiedAt: DateTime(2026, 5, 21, 8),
          stageId: 'jielong_entry',
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [learningRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          initialRoute: '/learning-record-detail',
          onGenerateRoute:
              (settings) => MaterialPageRoute<void>(
                settings: const StageScopeRouteArgs(
                  learningRecordId: 7,
                  source: 'sync-log',
                ).toRouteSettings(name: settings.name),
                builder: (_) => const LearningRecordDetailPage(recordId: 7),
              ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('已找到相关进度'), findsOneWidget);
    expect(find.textContaining('接龙入门'), findsWidgets);
    expect(find.text('回到该关卡章节'), findsOneWidget);
  });

  testWidgets('learning record detail returns to map with record source', (
    tester,
  ) async {
    final repository = _FakeLearningRepository(
      records: [
        LearningRecord(
          id: 7,
          poemId: 1,
          poemTitle: 'detail-record',
          poemAuthor: 'author-a',
          mode: 'poetry_jielong',
          durationMinutes: 5,
          score: 88,
          studiedAt: DateTime(2026, 5, 21, 8),
          stageId: 'jielong_entry',
        ),
      ],
    );
    final pushedSettings = <RouteSettings>[];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [learningRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          home: const LearningRecordDetailPage(recordId: 7),
          onGenerateRoute: (settings) {
            pushedSettings.add(settings);
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const Scaffold(body: Text('challenge-map')),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('回到该关卡章节'), 320);
    await tester.ensureVisible(find.text('回到该关卡章节'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('回到该关卡章节'));
    await tester.pumpAndSettle();

    final args = StageScopeRouteArgs.fromSettings(pushedSettings.last);
    expect(pushedSettings.last.name, '/challenge-map');
    expect(args?.stageId, 'jielong_entry');
    expect(args?.source, 'learning-record');
  });
}

class _FakeLearningRepository implements LearningRepository {
  _FakeLearningRepository({required this.records});

  final List<LearningRecord> records;

  @override
  Future<List<LearningRecord>> fetchRecentRecords({int limit = 12}) async {
    return records.take(limit).toList(growable: false);
  }

  @override
  Future<LearningGrowthReport> fetchGrowthReport({
    GrowthReportPeriod period = GrowthReportPeriod.weekly,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<LearningSummary> fetchSummary() {
    throw UnimplementedError();
  }

  @override
  Future<Map<String, ChallengeModeProgress>> fetchChallengeModeProgress() {
    throw UnimplementedError();
  }

  @override
  Future<List<LearningRecord>> fetchChallengeModeHistory({
    required String mode,
    int limit = 10,
    String? stageId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Set<String>> fetchClaimedChallengeRewardKeys() {
    throw UnimplementedError();
  }

  @override
  Future<bool> markChallengeRewardClaimed({
    required String stageId,
    required int stars,
  }) {
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
