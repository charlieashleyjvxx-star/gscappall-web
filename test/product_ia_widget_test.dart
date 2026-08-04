import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gscappall/app/app_providers.dart';
import 'package:gscappall/app/app_theme.dart';
import 'package:gscappall/core/service_status.dart';
import 'package:gscappall/domain/app_settings.dart';
import 'package:gscappall/domain/learning_models.dart';
import 'package:gscappall/domain/poem.dart';
import 'package:gscappall/domain/repositories/poem_repository.dart';
import 'package:gscappall/features/poem_detail/poem_detail_page.dart';
import 'package:gscappall/features/poem_library/poem_library_page.dart';
import 'package:gscappall/services/audio/audio_player_service.dart';
import 'package:gscappall/services/speech/text_to_speech_service.dart';

void main() {
  testWidgets('poem detail keeps reading entry and knowledge narration', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final textToSpeech = _RecordingTextToSpeechService();
    final audioPlayer = _RecordingAudioPlayerService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          poemRepositoryProvider.overrideWithValue(_FakePoemRepository()),
          settingsProvider.overrideWith((ref) async => const AppSettings()),
          textToSpeechServiceProvider.overrideWithValue(textToSpeech),
          audioPlayerServiceProvider.overrideWithValue(audioPlayer),
        ],
        child: const MaterialApp(home: PoemDetailPage(poemId: 1)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('开始练习'), findsOneWidget);
    expect(find.text('开始朗读'), findsOneWidget);
    expect(find.text('其他练习'), findsNothing);
    expect(find.text('背一背'), findsNothing);
    expect(find.text('练听写'), findsNothing);
    expect(find.text('去复习'), findsNothing);
    expect(find.text('了解这首诗'), findsNothing);
    expect(find.text('想知道意思时再看这里。'), findsNothing);
    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
    expect(find.textContaining('一年级'), findsNothing);

    final expectedNarration = <String, String>{
      '注释': '明亮的月光照在床前。',
      '译文': '像地上铺了一层白霜。',
      '赏析': '语言简单，情感真切。',
      '作者': '李白，唐代诗人。',
      '拓展': '月亮常被古人用来表达思乡之情。',
    };
    for (final entry in expectedNarration.entries) {
      if (entry.key != '注释') {
        if (entry.key == '拓展') {
          await tester.drag(
            find.byType(SingleChildScrollView).last,
            const Offset(-160, 0),
          );
          await tester.pump();
        }
        await tester.tap(find.text(entry.key));
        await tester.pump();
      }
      await tester.tap(find.byTooltip('播放${entry.key}'));
      await tester.pumpAndSettle();
      expect(textToSpeech.texts.last, entry.value);
      expect(textToSpeech.speechRates.last, 0.9);
      expect(audioPlayer.sources.last, 'narration.mp3');
    }
    debugDefaultTargetPlatformOverride = null;
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

class _RecordingAudioPlayerService implements AudioPlayerService {
  final List<String> sources = <String>[];

  @override
  ServiceCapability get capability => const ServiceCapability(
    state: ServiceState.available,
    message: '测试音频可用。',
  );

  @override
  Future<void> play(String? source) async {
    if (source != null) {
      sources.add(source);
    }
  }

  @override
  Future<void> prepare() async {}

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  Future<void> stop() async {}
}

class _RecordingTextToSpeechService implements TextToSpeechService {
  final List<String> texts = <String>[];
  final List<double> speechRates = <double>[];

  @override
  ServiceCapability get capability => const ServiceCapability(
    state: ServiceState.available,
    message: '测试语音可用。',
  );

  @override
  Future<void> initialize() async {}

  @override
  Future<TextToSpeechSynthesisResult> synthesizeToFile({
    required String text,
    String locale = 'zh-CN',
    String? cacheKey,
    bool forceRegenerate = false,
    double speechRate = 1.0,
    double pitch = 1.0,
  }) async {
    texts.add(text);
    speechRates.add(speechRate);
    return const TextToSpeechSynthesisResult(
      filePath: 'narration.mp3',
      locale: 'zh-CN',
      engine: 'test',
      voice: 'test',
      wasCached: false,
    );
  }
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
    extension: '月亮常被古人用来表达思乡之情。',
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
