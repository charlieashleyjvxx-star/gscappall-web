import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gscappall/app/app_providers.dart';
import 'package:gscappall/domain/poem.dart';
import 'package:gscappall/domain/practice_models.dart';
import 'package:gscappall/domain/repositories/practice_repository.dart';
import 'package:gscappall/features/wrong_book/wrong_book_placeholder_page.dart';
import 'package:gscappall/features/shared/stage_scope_route_args.dart';

void main() {
  testWidgets('wrong book applies initial stage filter through provider', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = _FakePracticeRepository(
      entries: [
        WrongQuestionEntry(
          id: 1,
          poemId: 1,
          poemTitle: 'stage-a',
          poemAuthor: 'author-a',
          questionType: PracticeMode.dictation,
          prompt: 'prompt-a',
          correctAnswer: 'answer-a',
          userAnswer: 'wrong-a',
          mistakeType: PracticeMistakeType.missingCharacters,
          severity: 'medium',
          createdAt: DateTime(2026, 5, 21),
          stageId: 'dictation_checkpoint',
        ),
        WrongQuestionEntry(
          id: 2,
          poemId: 2,
          poemTitle: 'stage-b',
          poemAuthor: 'author-b',
          questionType: PracticeMode.dictation,
          prompt: 'prompt-b',
          correctAnswer: 'answer-b',
          userAnswer: 'wrong-b',
          mistakeType: PracticeMistakeType.missingCharacters,
          severity: 'medium',
          createdAt: DateTime(2026, 5, 21),
          stageId: 'dictation_review',
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [practiceRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(
          home: WrongBookPlaceholderPage(
            initialStageId: 'dictation_checkpoint',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.filter_alt_rounded), findsOneWidget);
    expect(repository.queries.last.stageId, 'dictation_checkpoint');

    await tester.tap(find.text('清除筛选'));
    await tester.pumpAndSettle();

    expect(repository.queries.last.stageId, isNull);
  });

  testWidgets('wrong book reads stage filter from route settings', (
    tester,
  ) async {
    final repository = _FakePracticeRepository(
      entries: [
        WrongQuestionEntry(
          id: 1,
          poemId: 1,
          poemTitle: 'stage-a',
          poemAuthor: 'author-a',
          questionType: PracticeMode.dictation,
          prompt: 'prompt-a',
          correctAnswer: 'answer-a',
          userAnswer: 'wrong-a',
          mistakeType: PracticeMistakeType.missingCharacters,
          severity: 'medium',
          createdAt: DateTime(2026, 5, 21),
          stageId: 'dictation_checkpoint',
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [practiceRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          initialRoute: '/wrong-book',
          onGenerateRoute:
              (settings) => MaterialPageRoute(
                settings: StageScopeRouteArgs(
                  stageId: 'dictation_checkpoint',
                  source: 'chapter-detail',
                ).toRouteSettings(name: settings.name),
                builder: (_) => const WrongBookPlaceholderPage(),
              ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.queries.last.stageId, 'dictation_checkpoint');
    expect(find.textContaining('已找到 听写关卡'), findsOneWidget);
    expect(find.text('回到该关卡章节'), findsOneWidget);
  });

  testWidgets('wrong book explains growth report unreviewed stage filter', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _FakePracticeRepository(
      entries: [
        WrongQuestionEntry(
          id: 1,
          poemId: 1,
          poemTitle: 'pending-stage',
          poemAuthor: 'author-a',
          questionType: PracticeMode.dictation,
          prompt: 'prompt-a',
          correctAnswer: 'answer-a',
          userAnswer: 'wrong-a',
          mistakeType: PracticeMistakeType.missingCharacters,
          severity: 'medium',
          createdAt: DateTime(2026, 5, 21),
          stageId: 'dictation_checkpoint',
        ),
        WrongQuestionEntry(
          id: 2,
          poemId: 2,
          poemTitle: 'reviewed-stage',
          poemAuthor: 'author-b',
          questionType: PracticeMode.dictation,
          prompt: 'prompt-b',
          correctAnswer: 'answer-b',
          userAnswer: 'wrong-b',
          mistakeType: PracticeMistakeType.missingCharacters,
          severity: 'medium',
          createdAt: DateTime(2026, 5, 21),
          stageId: 'dictation_checkpoint',
          reviewedAt: DateTime(2026, 5, 22),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [practiceRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          initialRoute: '/wrong-book',
          onGenerateRoute:
              (settings) => MaterialPageRoute(
                settings: const StageScopeRouteArgs(
                  stageId: 'dictation_checkpoint',
                  source: 'growth-report',
                ).toRouteSettings(name: settings.name),
                builder: (_) => const WrongBookPlaceholderPage(),
              ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.queries.last.stageId, 'dictation_checkpoint');
    expect(repository.queries.last.onlyUnreviewed, isTrue);
    expect(find.textContaining('先看 听写关卡 待复习错题'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('pending-stage'), 220);
    expect(find.text('pending-stage'), findsOneWidget);
    expect(find.text('reviewed-stage'), findsNothing);

    await tester.scrollUntilVisible(find.text('查看全部错题'), -220);
    await tester.tap(find.text('查看全部错题'));
    await tester.pumpAndSettle();

    expect(repository.queries.last.stageId, isNull);
    expect(repository.queries.last.onlyUnreviewed, isTrue);
    expect(find.textContaining('先看 听写关卡 待复习错题'), findsNothing);
  });

  testWidgets('wrong book defaults to pending and can switch to all mistakes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _FakePracticeRepository(
      entries: [
        WrongQuestionEntry(
          id: 1,
          poemId: 1,
          poemTitle: 'pending',
          poemAuthor: 'author-a',
          questionType: PracticeMode.dictation,
          prompt: 'prompt-a',
          correctAnswer: 'answer-a',
          userAnswer: 'wrong-a',
          mistakeType: PracticeMistakeType.missingCharacters,
          severity: 'high',
          createdAt: DateTime(2026, 5, 21),
        ),
        WrongQuestionEntry(
          id: 2,
          poemId: 2,
          poemTitle: 'reviewed',
          poemAuthor: 'author-b',
          questionType: PracticeMode.evaluation,
          prompt: 'prompt-b',
          correctAnswer: 'answer-b',
          userAnswer: 'wrong-b',
          mistakeType: PracticeMistakeType.lineMismatch,
          severity: 'medium',
          createdAt: DateTime(2026, 5, 21),
          reviewedAt: DateTime(2026, 5, 22),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [practiceRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: WrongBookPlaceholderPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.queries.last.onlyUnreviewed, isTrue);
    expect(find.text('待复习'), findsWidgets);
    expect(find.text('全部错题'), findsOneWidget);
    expect(find.text('pending'), findsOneWidget);
    expect(find.text('reviewed'), findsNothing);

    await tester.tap(find.text('全部错题'));
    await tester.pumpAndSettle();

    expect(repository.queries.last.onlyUnreviewed, isFalse);
    expect(find.text('pending'), findsOneWidget);
    expect(find.text('reviewed'), findsOneWidget);
  });
}

class _FakePracticeRepository implements PracticeRepository {
  _FakePracticeRepository({required this.entries});

  final List<WrongQuestionEntry> entries;
  final List<WrongQuestionQuery> queries = [];

  @override
  Future<List<WrongQuestionEntry>> fetchWrongQuestions({
    WrongQuestionQuery query = const WrongQuestionQuery(),
  }) async {
    queries.add(query);
    return entries
        .where((entry) {
          return (query.practiceMode == null ||
                  entry.questionType == query.practiceMode) &&
              (query.mistakeType == null ||
                  entry.mistakeType == query.mistakeType) &&
              (query.severity == null || entry.severity == query.severity) &&
              (query.stageId == null || entry.stageId == query.stageId) &&
              (!query.onlyUnreviewed || !entry.isReviewed);
        })
        .toList(growable: false);
  }

  @override
  Future<WrongQuestionEntry?> fetchWrongQuestionDetail(int id) async {
    for (final entry in entries) {
      if (entry.id == id) {
        return entry;
      }
    }
    return null;
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
  Future<PracticeReportDetail?> fetchPracticeReportDetail(int id) {
    throw UnimplementedError();
  }
}
