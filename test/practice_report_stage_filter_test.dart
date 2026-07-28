import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gscappall/app/app_providers.dart';
import 'package:gscappall/domain/poem.dart';
import 'package:gscappall/domain/practice_models.dart';
import 'package:gscappall/domain/repositories/practice_repository.dart';
import 'package:gscappall/features/evaluation/evaluation_placeholder_page.dart';
import 'package:gscappall/features/shared/stage_scope_route_args.dart';

void main() {
  testWidgets('practice report applies initial stage filter through provider', (
    tester,
  ) async {
    final repository = _FakePracticeRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [practiceRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(
          home: PracticeReportHistoryPage(
            initialStageId: 'dictation_checkpoint',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.reportQueries.last.stageId, 'dictation_checkpoint');
    expect(find.textContaining('当前只看'), findsOneWidget);

    await tester.tap(find.text('清除筛选').first);
    await tester.pumpAndSettle();

    expect(repository.reportQueries.last.stageId, isNull);
    expect(find.textContaining('当前只看'), findsNothing);
  });

  testWidgets('practice report reads stage filter from route settings', (
    tester,
  ) async {
    final repository = _FakePracticeRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [practiceRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          initialRoute: '/practice-reports',
          onGenerateRoute:
              (settings) => MaterialPageRoute(
                settings: StageScopeRouteArgs(
                  stageId: 'dictation_checkpoint',
                  source: 'chapter-detail',
                ).toRouteSettings(name: settings.name),
                builder: (_) => const PracticeReportHistoryPage(),
              ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.reportQueries.last.stageId, 'dictation_checkpoint');
    expect(find.textContaining('当前只看'), findsOneWidget);
    expect(find.textContaining('继续看这一关'), findsOneWidget);
    expect(find.text('回到该关卡章节'), findsOneWidget);
  });

  testWidgets('practice report explains growth report stage filter', (
    tester,
  ) async {
    final repository = _FakePracticeRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [practiceRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          initialRoute: '/practice-reports',
          onGenerateRoute:
              (settings) => MaterialPageRoute(
                settings: const StageScopeRouteArgs(
                  stageId: 'dictation_checkpoint',
                  source: 'growth-report',
                ).toRouteSettings(name: settings.name),
                builder: (_) => const PracticeReportHistoryPage(),
              ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.reportQueries.last.stageId, 'dictation_checkpoint');
    expect(find.textContaining('已帮你找到这一关'), findsOneWidget);
    expect(find.textContaining('先看 听写关卡 练习结果'), findsOneWidget);

    await tester.tap(find.text('查看全部报告'));
    await tester.pumpAndSettle();

    expect(repository.reportQueries.last.stageId, isNull);
    expect(find.textContaining('先看 听写关卡 练习结果'), findsNothing);
  });
}

class _FakePracticeRepository implements PracticeRepository {
  _FakePracticeRepository();

  final List<PracticeReportQuery> reportQueries = [];

  @override
  Future<PracticeReportOverview> fetchPracticeReportOverview({
    PracticeReportQuery query = const PracticeReportQuery(),
  }) async {
    reportQueries.add(query);
    return PracticeReportOverview(
      summaries: const [],
      stats: PracticeReportStats(
        totalReports: 0,
        dictationCount: 0,
        evaluationCount: 0,
        readingCount: 0,
        recitationCount: 0,
        averageScore: 0,
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
  }) {
    throw UnimplementedError();
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
