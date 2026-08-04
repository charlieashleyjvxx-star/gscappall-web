import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gscappall/app/app_providers.dart';
import 'package:gscappall/domain/poem.dart';
import 'package:gscappall/domain/repositories/poem_repository.dart';
import 'package:gscappall/features/game/feihualing_page.dart';
import 'package:gscappall/features/game/game_session_widgets.dart';
import 'package:gscappall/features/game/poetry_jielong_page.dart';

void main() {
  testWidgets(
    'poetry chain keeps one primary task without extra instructions',
    (tester) async {
      await _pumpPage(tester, const PoetryJielongPage());

      expect(find.text('本局规则'), findsNothing);
      expect(find.text('接一句'), findsOneWidget);
      expect(find.text('给我提示'), findsOneWidget);
      expect(find.text('更多操作'), findsOneWidget);
      expect(find.text('重开'), findsNothing);
      expect(find.text('用提示'), findsNothing);
    },
  );

  testWidgets('feihualing keeps one primary task without extra instructions', (
    tester,
  ) async {
    await _pumpPage(tester, const FeihualingPage());
    await tester.tap(find.byType(ActionChip).first);
    await tester.pumpAndSettle();

    expect(find.text('本局规则'), findsNothing);
    expect(find.text('答一句'), findsOneWidget);
    expect(find.text('给我提示'), findsOneWidget);
    expect(find.text('更多操作'), findsOneWidget);
    expect(find.text('重开本题'), findsNothing);
    expect(find.text('换主题'), findsNothing);
  });

  testWidgets('shared game result exposes one primary next step', (
    tester,
  ) async {
    var restarted = false;
    var left = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GameResultCard(
            summary: '挑战完成，星星已记录。',
            metrics: const {'句数': '3', '得分': '96', '星星': '已获得'},
            primaryLabel: '再来一局',
            onPrimary: () => restarted = true,
            secondaryLabel: '返回闯关地图',
            onSecondary: () => left = true,
          ),
        ),
      ),
    );

    expect(find.text('本局结果'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '再来一局'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '返回闯关地图'), findsOneWidget);
    await tester.tap(find.text('再来一局'));
    await tester.tap(find.text('返回闯关地图'));
    expect(restarted, isTrue);
    expect(left, isTrue);
  });
}

Future<void> _pumpPage(WidgetTester tester, Widget page) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [poemRepositoryProvider.overrideWithValue(_PoemRepository())],
      child: MaterialApp(home: page),
    ),
  );
  await tester.pumpAndSettle();
}

class _PoemRepository implements PoemRepository {
  @override
  Future<List<Poem>> fetchPoems({PoemQuery query = const PoemQuery()}) async {
    return _poems;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _poems = [
  Poem(
    id: 1,
    title: '静夜思',
    author: '李白',
    dynasty: '唐',
    grade: 1,
    gradeLabel: '一年级',
    category: '思乡',
    content: '床前明月光，\n举头望明月。\n低头思故乡。',
    pinyin:
        'chuang qian ming yue guang\nju tou wang ming yue\ndi tou si gu xiang',
    annotation: '',
    translation: '',
    appreciation: '',
    authorIntro: '',
    extension: '',
    audioUrl: null,
    imageUrl: null,
    difficulty: 1,
  ),
  Poem(
    id: 2,
    title: '月夜',
    author: '杜甫',
    dynasty: '唐',
    grade: 2,
    gradeLabel: '二年级',
    category: '月',
    content: '今夜鄜州月，\n月是故乡明。\n明月松间照。',
    pinyin:
        'jin ye fu zhou yue\nyue shi gu xiang ming\nming yue song jian zhao',
    annotation: '',
    translation: '',
    appreciation: '',
    authorIntro: '',
    extension: '',
    audioUrl: null,
    imageUrl: null,
    difficulty: 1,
  ),
];
