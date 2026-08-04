import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gscappall/app/app_providers.dart';
import 'package:gscappall/domain/app_settings.dart';
import 'package:gscappall/domain/learning_models.dart';
import 'package:gscappall/domain/poem.dart';
import 'package:gscappall/domain/practice_models.dart';
import 'package:gscappall/domain/repositories/learning_repository.dart';
import 'package:gscappall/domain/repositories/poem_repository.dart';
import 'package:gscappall/domain/repositories/practice_repository.dart';
import 'package:gscappall/domain/user_profile.dart';
import 'package:gscappall/features/dictation/dictation_page.dart';
import 'package:gscappall/features/profile/profile_page.dart';
import 'package:gscappall/features/study_cards/study_cards_page.dart';
import 'package:gscappall/features/wrong_book/wrong_question_retry_page.dart';

void main() {
  testWidgets('dictation checks the current line before moving forward', (
    tester,
  ) async {
    await _setPhoneSize(tester);
    final repository = _FakePracticeRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [practiceRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: DictationPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('检查这一句'), findsOneWidget);
    expect(find.text('练下一句'), findsNothing);
    await tester.enterText(find.byType(TextField).first, '床前明月光');
    await tester.tap(find.text('检查这一句'));
    await tester.pumpAndSettle();

    expect(find.text('练下一句'), findsOneWidget);
    expect(find.text('第 1/2 句'), findsOneWidget);
    expect(find.text('校验并下一句'), findsNothing);

    await tester.tap(find.text('练下一句'));
    await tester.pumpAndSettle();
    expect(find.text('第 2/2 句'), findsOneWidget);
    expect(find.text('检查这一句'), findsOneWidget);
  });

  testWidgets('study card asks for one decision at each step', (tester) async {
    await _setPhoneSize(tester);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          poemRepositoryProvider.overrideWithValue(_FakePoemRepository()),
          learningRepositoryProvider.overrideWithValue(
            _FakeLearningRepository(),
          ),
          pinyinVisibleProvider.overrideWithValue(false),
        ],
        child: const MaterialApp(home: StudyCardsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('翻开看看'), findsOneWidget);
    expect(find.text('我记住了，下一张'), findsNothing);
    expect(find.text('下一张'), findsNothing);

    await tester.tap(find.text('翻开看看'));
    await tester.pumpAndSettle();
    expect(find.text('我记住了，下一张'), findsOneWidget);
    expect(find.text('再看一遍'), findsOneWidget);
  });

  testWidgets('a corrected wrong question ends with a clear return action', (
    tester,
  ) async {
    await _setPhoneSize(tester);
    final practiceRepository = _FakePracticeRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          practiceRepositoryProvider.overrideWithValue(practiceRepository),
          learningRepositoryProvider.overrideWithValue(
            _FakeLearningRepository(),
          ),
        ],
        child: MaterialApp(home: WrongQuestionRetryPage(entry: _wrongQuestion)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '床前明月光');
    await tester.tap(find.text('检查这一题'));
    await tester.pumpAndSettle();

    expect(find.text('本次通过'), findsOneWidget);
    expect(find.text('完成并返回错题本'), findsOneWidget);
    expect(find.text('再次校验'), findsNothing);
    expect(practiceRepository.reviewedIds, contains(_wrongQuestion.id));
  });

  testWidgets('profile exposes focused settings without parent management', (
    tester,
  ) async {
    await _setPhoneSize(tester);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileProvider.overrideWith((ref) async => _profile),
          settingsProvider.overrideWith((ref) async => const AppSettings()),
          serviceCatalogProvider.overrideWithValue(const []),
        ],
        child: const MaterialApp(home: Scaffold(body: ProfilePage())),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('我的内容'), findsOneWidget);
    expect(find.text('我的收藏'), findsOneWidget);
    expect(find.text('学习卡片'), findsOneWidget);
    expect(find.text('家长管理'), findsNothing);
    expect(find.text('展开家长管理'), findsNothing);
    expect(find.text('我的设置'), findsOneWidget);
    expect(find.text('应用设置'), findsOneWidget);
    expect(find.text('切换资料'), findsNothing);

    await tester.tap(find.text('应用设置'));
    await tester.pumpAndSettle();
    expect(find.text('切换孩子'), findsOneWidget);
    expect(find.text('修改名字'), findsOneWidget);
    expect(find.text('学习提醒'), findsOneWidget);
    expect(find.text('每日提醒'), findsOneWidget);
  });
}

Future<void> _setPhoneSize(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

const _poem = Poem(
  id: 1,
  title: '静夜思',
  author: '李白',
  dynasty: '唐',
  grade: 1,
  gradeLabel: '一年级',
  category: '思乡',
  content: '床前明月光\n疑是地上霜',
  pinyin: 'chuang qian ming yue guang\nyi shi di shang shuang',
  annotation: '月光照在床前。',
  translation: '月光像地上的白霜。',
  appreciation: '语言自然。',
  authorIntro: '李白，唐代诗人。',
  extension: '',
  audioUrl: null,
  imageUrl: null,
  difficulty: 1,
);

const _questions = [
  PracticeQuestion(
    poemId: 1,
    poemTitle: '静夜思',
    poemAuthor: '李白',
    lineIndex: 0,
    prompt: '请默写第 1 句',
    hint: '五个字',
    expectedAnswer: '床前明月光',
  ),
  PracticeQuestion(
    poemId: 1,
    poemTitle: '静夜思',
    poemAuthor: '李白',
    lineIndex: 1,
    prompt: '请默写第 2 句',
    hint: '五个字',
    expectedAnswer: '疑是地上霜',
  ),
];

final _wrongQuestion = WrongQuestionEntry(
  id: 9,
  poemId: 1,
  poemTitle: '静夜思',
  poemAuthor: '李白',
  questionType: PracticeMode.dictation,
  prompt: '请默写第 1 句',
  correctAnswer: '床前明月光',
  userAnswer: '床前明月',
  mistakeType: PracticeMistakeType.missingCharacters,
  severity: 'medium',
  createdAt: DateTime.utc(2026, 7, 29),
);

final _profile = UserProfile(
  id: 1,
  nickname: '小诗童',
  tagline: '今天也和古诗做朋友',
  createdAt: DateTime.utc(2026, 7, 29),
);

class _FakePracticeRepository implements PracticeRepository {
  final reviewedIds = <int>[];

  @override
  Future<List<Poem>> fetchPracticePoems({int limit = 60}) async => [_poem];

  @override
  Future<PracticeSession> createSession({
    required PracticeMode mode,
    int? poemId,
    DictationDifficulty difficulty = DictationDifficulty.standard,
    DictationAnswerMode answerMode = DictationAnswerMode.fullText,
  }) async {
    return PracticeSession(
      sessionId: 'p1-test',
      mode: mode,
      poem: _poem,
      questions: _questions,
      startedAt: DateTime.utc(2026, 7, 29),
      difficulty: difficulty,
      answerMode: answerMode,
    );
  }

  @override
  PracticeLineResult evaluateAnswer({
    required PracticeQuestion question,
    required String answer,
  }) {
    final correct = answer.trim() == question.expectedAnswer;
    return PracticeLineResult(
      question: question,
      answer: answer,
      isCorrect: correct,
      score: correct ? 100 : 60,
      feedback: correct ? '写对了。' : '再检查一次。',
      mistakeType: correct ? null : PracticeMistakeType.missingCharacters,
    );
  }

  @override
  Future<void> markWrongQuestionReviewed(int id) async {
    reviewedIds.add(id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeLearningRepository implements LearningRepository {
  @override
  Future<List<StudyCardDeckEntry>> fetchStudyCardDeck({
    StudyCardQuery query = const StudyCardQuery(),
  }) async {
    return const [
      StudyCardDeckEntry(
        poem: _poem,
        progress: StudyCardProgress(
          poemId: 1,
          memoryStatus: 'new',
          reviewCount: 0,
        ),
        isFavorite: false,
      ),
    ];
  }

  @override
  Future<StudyCardFilterOptions> fetchStudyCardFilterOptions() async {
    return const StudyCardFilterOptions(
      dynasties: ['唐'],
      authors: ['李白'],
      categories: ['思乡'],
    );
  }

  @override
  Future<void> logLearningRecord({
    required int poemId,
    required String mode,
    int durationMinutes = 0,
    int? score,
    String? note,
    String? stageId,
  }) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePoemRepository implements PoemRepository {
  @override
  Future<void> importSeedIfNeeded({required String seedVersion}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
