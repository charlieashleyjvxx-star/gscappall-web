import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gscappall/app/app_providers.dart';
import 'package:gscappall/core/service_status.dart';
import 'package:gscappall/domain/learning_models.dart';
import 'package:gscappall/domain/poem.dart';
import 'package:gscappall/domain/repositories/poem_repository.dart';
import 'package:gscappall/features/home/home_page.dart';
import 'package:gscappall/features/reading/reading_placeholder_page.dart';
import 'package:gscappall/features/recite/recite_placeholder_page.dart';
import 'package:gscappall/services/audio/audio_player_service.dart';
import 'package:gscappall/services/record/recorder_service.dart';
import 'package:gscappall/services/speech/speech_recognition_service.dart';
import 'package:gscappall/services/speech/text_to_speech_service.dart';

void main() {
  testWidgets('home starts with today task and omits the old hero actions', (
    tester,
  ) async {
    await _setPhoneSize(tester);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          todayPoemProvider.overrideWith(
            (ref) async => DailyPoemBundle(
              dateKey: '2026-07-29',
              poem: _poem,
              isCompleted: false,
            ),
          ),
          pinyinVisibleProvider.overrideWithValue(false),
        ],
        child: const MaterialApp(home: Scaffold(body: HomePage())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('今日任务'), findsOneWidget);
    expect(find.text('今天从哪里开始？'), findsNothing);
    expect(find.text('去诗词库'), findsNothing);
    expect(find.text('去练习'), findsNothing);
  });

  testWidgets('reading completes a line without microphone or scoring', (
    tester,
  ) async {
    await _setPhoneSize(tester);

    await tester.pumpWidget(
      ProviderScope(
        overrides: _practiceOverrides(),
        child: const MaterialApp(home: ReadingPlaceholderPage(poemId: 1)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('一起读'), findsOneWidget);
    expect(find.text('整首朗读'), findsOneWidget);
    expect(find.text('逐句朗读'), findsOneWidget);
    expect(find.text('听老师读'), findsNothing);
    expect(find.text('听一遍声音，看看每个字怎么读。'), findsNothing);
    expect(find.text('家长辅助'), findsNothing);
    expect(find.text('我的录音回放'), findsOneWidget);
    expect(find.text('先录下自己的朗读，再用回放对照目标诗句做复盘。'), findsNothing);
    expect(find.text('回放按钮会在生成本地录音后启用。'), findsNothing);
    expect(find.text('总分'), findsNothing);
    expect(find.text('手动修改朗读内容'), findsNothing);

    await tester.tap(find.text('一起读'));
    await tester.pumpAndSettle();

    expect(find.text('读完啦'), findsOneWidget);

    await tester.tap(find.text('读完啦'));
    await tester.pumpAndSettle();

    expect(find.text('做得好'), findsNothing);
    expect(find.text('读下一句'), findsOneWidget);
    expect(find.text('听听我的声音'), findsOneWidget);
    expect(find.text('重新读一遍'), findsOneWidget);
    expect(find.text('总分'), findsNothing);

    await tester.tap(find.text('重新读一遍'));
    await tester.pumpAndSettle();
    expect(find.text('一起读'), findsOneWidget);
  });

  testWidgets('reading can complete the whole poem in one flow', (
    tester,
  ) async {
    await _setPhoneSize(tester);

    await tester.pumpWidget(
      ProviderScope(
        overrides: _practiceOverrides(),
        child: const MaterialApp(home: ReadingPlaceholderPage(poemId: 1)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('整首朗读'));
    await tester.pump();
    expect(find.text('听一听'), findsOneWidget);
    expect(find.text('听老师读'), findsNothing);
    expect(find.text('听一遍声音，看看每个字怎么读。'), findsNothing);
    expect(find.text('0.8x'), findsOneWidget);
    expect(find.text('1.0x'), findsOneWidget);
    expect(find.text('1.2x'), findsOneWidget);

    await tester.tap(find.text('听一听'));
    await tester.pump();
    expect(find.text('一起读'), findsOneWidget);

    await tester.tap(find.text('一起读'));
    await tester.pump();

    expect(find.text('读完啦'), findsOneWidget);
    await tester.tap(find.text('读完啦'));
    await tester.pump();

    expect(find.text('整首读完啦'), findsNothing);
    expect(find.text('完成这首诗'), findsOneWidget);
    expect(find.text('读下一句'), findsNothing);
    expect(find.text('我想自己读'), findsNothing);
  });

  testWidgets(
    'recitation uses progressive masking without speech recognition',
    (tester) async {
      await _setPhoneSize(tester);

      await tester.pumpWidget(
        ProviderScope(
          overrides: _practiceOverrides(),
          child: const MaterialApp(home: RecitePlaceholderPage(poemId: 1)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('少几个字'), findsWidgets);
      expect(find.text('家长辅助'), findsOneWidget);
      expect(find.text('总分'), findsNothing);
      expect(find.text('手动修改背诵内容'), findsNothing);

      await tester.tap(find.widgetWithText(FilledButton, '少几个字'));
      await tester.pump();
      expect(find.text('再遮一些'), findsWidgets);

      await tester.tap(find.widgetWithText(FilledButton, '再遮一些'));
      await tester.pump();
      expect(find.text('全部遮住'), findsWidgets);

      await tester.tap(find.widgetWithText(FilledButton, '全部遮住'));
      await tester.pump();
      expect(find.text('我背完啦'), findsOneWidget);

      await tester.tap(find.text('我背完啦'));
      await tester.pump();
      expect(find.text('做得好'), findsOneWidget);
      expect(find.text('练下一句'), findsOneWidget);

      await tester.tap(find.text('练下一句'));
      await tester.pump();
      expect(find.text('看着读'), findsOneWidget);
      expect(find.text('少几个字'), findsWidgets);
    },
  );
}

Future<void> _setPhoneSize(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

_practiceOverrides() => [
  poemRepositoryProvider.overrideWithValue(_FakePoemRepository()),
  pinyinVisibleProvider.overrideWithValue(false),
  audioPlayerServiceProvider.overrideWithValue(_FakeAudioPlayerService()),
  recorderServiceProvider.overrideWithValue(_FakeRecorderService()),
  speechRecognitionServiceProvider.overrideWithValue(
    const _FakeSpeechRecognitionService(),
  ),
  textToSpeechServiceProvider.overrideWithValue(
    const _FakeTextToSpeechService(),
  ),
];

const Poem _poem = Poem(
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
  appreciation: '语言自然，感情真切。',
  authorIntro: '李白，唐代诗人。',
  extension: '',
  audioUrl: 'test-audio.mp3',
  imageUrl: null,
  difficulty: 1,
);

class _FakePoemRepository implements PoemRepository {
  @override
  Future<void> importSeedIfNeeded({required String seedVersion}) async {}

  @override
  Future<List<Poem>> fetchPoems({PoemQuery query = const PoemQuery()}) async {
    return const [_poem];
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
      dateKey: '2026-07-29',
      poem: _poem,
      isCompleted: false,
    );
  }
}

class _FakeAudioPlayerService implements AudioPlayerService {
  @override
  ServiceCapability get capability => const ServiceCapability(
    state: ServiceState.unavailable,
    message: '测试环境不播放音频。',
  );

  @override
  Future<void> play(String? source) async {}

  @override
  Future<void> prepare() async {}

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  Future<void> stop() async {}
}

class _FakeRecorderService implements RecorderService {
  bool isRecording = false;

  @override
  ServiceCapability get capability => const ServiceCapability(
    state: ServiceState.unavailable,
    message: '测试环境不录音。',
  );

  @override
  Future<bool> refreshPermission({bool request = false}) async => false;

  @override
  Future<void> requestPermission() async {}

  @override
  Future<void> start() async {
    isRecording = true;
  }

  @override
  Future<String?> stop() async {
    isRecording = false;
    return 'child-reading.m4a';
  }
}

class _FakeSpeechRecognitionService implements SpeechRecognitionService {
  const _FakeSpeechRecognitionService();

  @override
  ServiceCapability get capability => const ServiceCapability(
    state: ServiceState.unavailable,
    message: '测试环境不识别语音。',
  );

  @override
  SpeechRecognitionDebugSnapshot? get lastDebugSnapshot => null;

  @override
  String? get lastNativeState => 'unavailable';

  @override
  Future<void> initialize() async {}

  @override
  Stream<SpeechRecognitionResult> recognize() => const Stream.empty();

  @override
  Future<void> stop() async {}
}

class _FakeTextToSpeechService implements TextToSpeechService {
  const _FakeTextToSpeechService();

  @override
  ServiceCapability get capability => const ServiceCapability(
    state: ServiceState.unavailable,
    message: '测试环境不生成示范音频。',
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
    return const TextToSpeechSynthesisResult(
      filePath: 'demo.mp3',
      locale: 'zh-CN',
      engine: null,
      voice: null,
      wasCached: false,
    );
  }
}
