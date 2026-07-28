import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gscappall/app/app_providers.dart';
import 'package:gscappall/domain/poem.dart';
import 'package:gscappall/domain/practice_models.dart';
import 'package:gscappall/domain/repositories/practice_repository.dart';
import 'package:gscappall/features/evaluation/practice_report_detail_page.dart';
import 'package:gscappall/features/shared/stage_scope_route_args.dart';
import 'package:gscappall/features/wrong_book/wrong_question_detail_page.dart';

void main() {
  testWidgets('practice report detail shows clean Chinese labels', (
    tester,
  ) async {
    final repository = _FakePracticeRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [practiceRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(
          home: CleanPracticeReportDetailPage(reportId: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('报告详情'), findsOneWidget);
    expect(find.text('正确率'), findsOneWidget);
    expect(find.text('新增错题'), findsOneWidget);
    expect(find.text('关卡进步'), findsOneWidget);
    expect(find.text('关联关卡'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('复习建议'), 220);
    expect(find.text('复习建议'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('你的答案'), 220);
    expect(find.text('你的答案'), findsOneWidget);
    expect(find.text('标准答案'), findsOneWidget);
  });

  testWidgets('practice report detail shows source hint from route args', (
    tester,
  ) async {
    final repository = _FakePracticeRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [practiceRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          initialRoute: '/practice-report-detail',
          onGenerateRoute:
              (settings) => MaterialPageRoute(
                settings: const StageScopeRouteArgs(
                  reportId: 1,
                  source: 'sync-log',
                ).toRouteSettings(name: settings.name),
                builder:
                    (_) => const CleanPracticeReportDetailPage(reportId: 1),
              ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('已找到相关进度'), findsOneWidget);
    expect(find.textContaining('听写关卡'), findsWidgets);
    expect(find.text('回到地图'), findsOneWidget);
  });

  testWidgets('practice report detail returns to map with report source', (
    tester,
  ) async {
    final repository = _FakePracticeRepository();
    final pushedSettings = <RouteSettings>[];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [practiceRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          home: const CleanPracticeReportDetailPage(reportId: 1),
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

    await tester.scrollUntilVisible(find.text('回到地图'), 260);
    await tester.pumpAndSettle();
    await tester.tap(find.text('回到地图'));
    await tester.pumpAndSettle();

    final args = StageScopeRouteArgs.fromSettings(pushedSettings.last);
    expect(pushedSettings.last.name, '/challenge-map');
    expect(args?.stageId, 'dictation_checkpoint');
    expect(args?.source, 'practice-report');
  });

  testWidgets('wrong question detail shows clean Chinese labels', (
    tester,
  ) async {
    final repository = _FakePracticeRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [practiceRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(
          home: CleanWrongQuestionDetailPage(wrongQuestionId: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('错题详情'), findsOneWidget);
    expect(find.text('题目'), findsOneWidget);
    expect(find.text('你的答案'), findsOneWidget);
    expect(find.text('标准答案'), findsOneWidget);
    expect(find.text('严重程度'), findsOneWidget);
    expect(find.text('闯关关卡'), findsOneWidget);
    expect(find.text('关卡进步'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('标记已复习'), 220);
    expect(find.text('标记已复习'), findsOneWidget);
  });

  testWidgets('wrong question detail shows source hint from route args', (
    tester,
  ) async {
    final repository = _FakePracticeRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [practiceRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          initialRoute: '/wrong-question-detail',
          onGenerateRoute:
              (settings) => MaterialPageRoute(
                settings: const StageScopeRouteArgs(
                  wrongQuestionId: 1,
                  source: 'notification',
                ).toRouteSettings(name: settings.name),
                builder:
                    (_) =>
                        const CleanWrongQuestionDetailPage(wrongQuestionId: 1),
              ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('继续练习'), findsOneWidget);
    expect(find.textContaining('听写关卡'), findsWidgets);
    await tester.scrollUntilVisible(find.text('本关复盘'), 220);
    expect(find.text('本关复盘'), findsOneWidget);
  });

  testWidgets('wrong question detail returns to map with wrong source', (
    tester,
  ) async {
    final repository = _FakePracticeRepository();
    final pushedSettings = <RouteSettings>[];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [practiceRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          home: const CleanWrongQuestionDetailPage(wrongQuestionId: 1),
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

    await tester.scrollUntilVisible(find.text('回到地图'), 260);
    await tester.pumpAndSettle();
    await tester.tap(find.text('回到地图'));
    await tester.pumpAndSettle();

    final args = StageScopeRouteArgs.fromSettings(pushedSettings.last);
    expect(pushedSettings.last.name, '/challenge-map');
    expect(args?.stageId, 'dictation_checkpoint');
    expect(args?.source, 'wrong-question');
  });
}

class _FakePracticeRepository implements PracticeRepository {
  @override
  Future<PracticeReportDetail?> fetchPracticeReportDetail(int id) async {
    return PracticeReportDetail(
      summary: PracticeReportSummary(
        id: id,
        sessionId: 'session-1',
        mode: PracticeMode.dictation,
        poemId: 1,
        poemTitle: '静夜思',
        poemAuthor: '李白',
        totalScore: 88,
        correctCount: 1,
        totalQuestions: 1,
        generatedWrongCount: 1,
        completedAt: DateTime.utc(2026, 5, 21),
        stageId: 'dictation_checkpoint',
      ),
      items: const [
        PracticeReportItem(
          lineIndex: 0,
          prompt: '床前明月光',
          hint: '',
          expectedAnswer: '床前明月光',
          userAnswer: '床前明月',
          isCorrect: false,
          score: 80,
          feedback: '少写了一个字',
          mistakeType: PracticeMistakeType.missingCharacters,
        ),
      ],
      suggestions: const ['复习易错字，再听写一遍。'],
    );
  }

  @override
  Future<WrongQuestionEntry?> fetchWrongQuestionDetail(int id) async {
    return WrongQuestionEntry(
      id: id,
      poemId: 1,
      poemTitle: '静夜思',
      poemAuthor: '李白',
      questionType: PracticeMode.dictation,
      prompt: '床前明月光',
      correctAnswer: '床前明月光',
      userAnswer: '床前明月',
      mistakeType: PracticeMistakeType.missingCharacters,
      severity: 'medium',
      createdAt: DateTime.utc(2026, 5, 21),
      stageId: 'dictation_checkpoint',
    );
  }

  @override
  Future<void> markWrongQuestionReviewed(int id) async {}

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
  Future<PracticeReportOverview> fetchPracticeReportOverview({
    PracticeReportQuery query = const PracticeReportQuery(),
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<WrongQuestionEntry>> fetchWrongQuestions({
    WrongQuestionQuery query = const WrongQuestionQuery(),
  }) {
    throw UnimplementedError();
  }
}
