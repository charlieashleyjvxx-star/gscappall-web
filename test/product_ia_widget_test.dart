import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gscappall/app/app_providers.dart';
import 'package:gscappall/app/app_theme.dart';
import 'package:gscappall/domain/app_settings.dart';
import 'package:gscappall/domain/learning_models.dart';
import 'package:gscappall/domain/poem.dart';
import 'package:gscappall/domain/repositories/poem_repository.dart';
import 'package:gscappall/features/poem_detail/poem_detail_page.dart';
import 'package:gscappall/features/poem_library/poem_library_page.dart';

void main() {
  testWidgets('poem detail shows natural next-step advice', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          poemRepositoryProvider.overrideWithValue(_FakePoemRepository()),
          settingsProvider.overrideWith((ref) async => const AppSettings()),
        ],
        child: const MaterialApp(home: PoemDetailPage(poemId: 1)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('开始练习'), findsOneWidget);
    expect(find.text('读一读'), findsWidgets);
    expect(find.text('背一背'), findsWidgets);
    expect(find.text('练听写'), findsWidgets);
    expect(find.text('去复习'), findsOneWidget);
    expect(find.textContaining('一年级'), findsNothing);
  });

  testWidgets('poem detail mobile visual regression', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          poemRepositoryProvider.overrideWithValue(_FakePoemRepository()),
          settingsProvider.overrideWith((ref) async => const AppSettings()),
        ],
        child: MaterialApp(
          theme: buildLightTheme(),
          home: const PoemDetailPage(poemId: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(Scaffold).first,
      matchesGoldenFile('goldens/poem_detail_mobile.png'),
    );
  });

  testWidgets('poem library uses theme and dynasty dropdowns without grade', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          poemRepositoryProvider.overrideWithValue(_FakePoemRepository()),
          settingsProvider.overrideWith((ref) async => const AppSettings()),
        ],
        child: const MaterialApp(home: Scaffold(body: PoemLibraryPage())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('诗词库'), findsOneWidget);
    expect(find.text('主题'), findsOneWidget);
    expect(find.text('朝代'), findsOneWidget);
    expect(find.text('按年级'), findsNothing);
    expect(find.text('全部年级'), findsNothing);
    expect(find.textContaining('一年级'), findsNothing);
    expect(find.bySemanticsLabel('搜索诗词'), findsOneWidget);
  });

  testWidgets('poem library desktop visual regression', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1180, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          poemRepositoryProvider.overrideWithValue(_FakePoemRepository()),
          settingsProvider.overrideWith((ref) async => const AppSettings()),
        ],
        child: MaterialApp(
          theme: buildLightTheme(),
          home: const Scaffold(body: PoemLibraryPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(Scaffold).first,
      matchesGoldenFile('goldens/poem_library_desktop.png'),
    );
  });
}

class _FakePoemRepository implements PoemRepository {
  final _poem = const Poem(
    id: 1,
    title: '静夜思',
    author: '李白',
    dynasty: '唐',
    grade: 1,
    gradeLabel: '一年级',
    category: '思乡',
    content: '床前明月光\n疑是地上霜',
    pinyin: 'chuang qian ming yue guang\nyi shi di shang shuang',
    annotation: '明亮的月光照在床前。',
    translation: '像地上铺了一层白霜。',
    appreciation: '语言简单，情感真切。',
    authorIntro: '李白，唐代诗人。',
    extension: '',
    audioUrl: null,
    imageUrl: null,
    difficulty: 1,
  );

  @override
  Future<void> importSeedIfNeeded({required String seedVersion}) async {}

  @override
  Future<List<Poem>> fetchPoems({PoemQuery query = const PoemQuery()}) async {
    return [_poem];
  }

  @override
  Future<Poem?> fetchPoemById(int id) async => id == _poem.id ? _poem : null;

  @override
  Future<List<Poem>> fetchFavorites() async => const [];

  @override
  Future<void> setFavorite(int poemId, bool isFavorite) async {}

  @override
  Future<bool> isFavorite(int poemId) async => false;

  @override
  Future<PoemStats> fetchStats() async {
    return const PoemStats(
      total: 1,
      gradeCounts: {'一年级': 1},
      categoryCounts: {'思乡': 1},
      dynastyCounts: {'唐': 1},
    );
  }

  @override
  Future<DailyPoemBundle> getDailyPoem(DateTime date) async {
    return DailyPoemBundle(
      dateKey:
          '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      poem: _poem,
      isCompleted: false,
    );
  }
}
