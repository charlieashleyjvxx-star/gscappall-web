import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gscappall/domain/poem.dart';
import 'package:gscappall/shared/widgets/poem_pinyin_text.dart';

void main() {
  const poem = Poem(
    id: 1,
    title: '静夜思',
    author: '李白',
    dynasty: '唐',
    grade: 1,
    gradeLabel: '一年级',
    category: '思乡',
    content: '床前明月光\n疑是地上霜',
    pinyin: 'chuang qian ming yue guang\nyi shi di shang shuang',
    annotation: '',
    translation: '',
    appreciation: '',
    authorIntro: '',
    extension: '',
    audioUrl: null,
    imageUrl: null,
    difficulty: 1,
  );

  testWidgets('hides pinyin while keeping poem lines centered', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: PoemPinyinText(poem: poem, showPinyin: false),
          ),
        ),
      ),
    );

    expect(find.text('chuang'), findsNothing);
    expect(find.text('床前明月光'), findsOneWidget);
    expect(find.text('疑是地上霜'), findsOneWidget);

    final firstLineCenter = tester.getCenter(find.text('床前明月光'));
    expect(firstLineCenter.dx, closeTo(200, 2));
  });

  testWidgets('shows pinyin by default', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PoemPinyinText(poem: poem))),
    );

    expect(find.text('chuang'), findsOneWidget);
  });

  testWidgets(
    'keeps long pinyin on one scaled line in compact narrow layouts',
    (tester) async {
      const longPinyinPoem = Poem(
        id: 2,
        title: '长拼音',
        author: '测试',
        dynasty: '今',
        grade: 1,
        gradeLabel: '一年级',
        category: '测试',
        content: '床前明月光',
        pinyin: 'zhuangzhuang qianqian mingming yueyue guangguang',
        annotation: '',
        translation: '',
        appreciation: '',
        authorIntro: '',
        extension: '',
        audioUrl: null,
        imageUrl: null,
        difficulty: 1,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 120,
              child: PoemPinyinText(poem: longPinyinPoem, compact: true),
            ),
          ),
        ),
      );

      final firstCharacterTop = tester.getTopLeft(find.text('床')).dy;
      final secondCharacterTop = tester.getTopLeft(find.text('前')).dy;
      expect(secondCharacterTop, firstCharacterTop);

      final longPinyin = tester.widget<Text>(find.text('zhuangzhuang'));
      expect(longPinyin.maxLines, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('scales long poem lines into one complete line', (tester) async {
    const longLinePoem = Poem(
      id: 3,
      title: '长句',
      author: '测试',
      dynasty: '今',
      grade: 1,
      gradeLabel: '一年级',
      category: '测试',
      content: '日照香炉生紫烟遥看瀑布挂前川',
      pinyin: 'ri zhao xiang lu sheng zi yan yao kan pu bu gua qian chuan',
      annotation: '',
      translation: '',
      appreciation: '',
      authorIntro: '',
      extension: '',
      audioUrl: null,
      imageUrl: null,
      difficulty: 1,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 220, child: PoemPinyinText(poem: longLinePoem)),
        ),
      ),
    );

    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(find.text('日'), findsOneWidget);
    expect(find.text('川'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('川')).dy,
      closeTo(tester.getTopLeft(find.text('日')).dy, 2),
    );
  });

  testWidgets('splits poem display lines by punctuation', (tester) async {
    const punctuatedPoem = Poem(
      id: 4,
      title: '望庐山瀑布',
      author: '李白',
      dynasty: '唐',
      grade: 2,
      gradeLabel: '二年级',
      category: '山水',
      content: '日照香炉生紫烟，遥看瀑布挂前川。飞流直下三千尺，疑是银河落九天。',
      pinyin:
          'ri zhao xiang lu sheng zi yan yao kan pu bu gua qian chuan fei liu zhi xia san qian chi yi shi yin he luo jiu tian',
      annotation: '',
      translation: '',
      appreciation: '',
      authorIntro: '',
      extension: '',
      audioUrl: null,
      imageUrl: null,
      difficulty: 2,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            child: PoemPinyinText(poem: punctuatedPoem, showPinyin: false),
          ),
        ),
      ),
    );

    expect(find.text('日照香炉生紫烟，'), findsOneWidget);
    expect(find.text('遥看瀑布挂前川。'), findsOneWidget);
    expect(find.text('飞流直下三千尺，'), findsOneWidget);
    expect(find.text('疑是银河落九天。'), findsOneWidget);
  });

  testWidgets('splits pinyin tokens with punctuation based poem lines', (
    tester,
  ) async {
    const punctuatedPoem = Poem(
      id: 5,
      title: '短句',
      author: '测试',
      dynasty: '今',
      grade: 1,
      gradeLabel: '一年级',
      category: '测试',
      content: '日照香炉，遥看瀑布。',
      pinyin: 'ri zhao xiang lu yao kan pu bu',
      annotation: '',
      translation: '',
      appreciation: '',
      authorIntro: '',
      extension: '',
      audioUrl: null,
      imageUrl: null,
      difficulty: 1,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 260,
            child: PoemPinyinText(poem: punctuatedPoem),
          ),
        ),
      ),
    );

    expect(find.text('ri'), findsOneWidget);
    expect(find.text('zhao'), findsOneWidget);
    expect(find.text('xiang'), findsOneWidget);
    expect(find.text('lu'), findsOneWidget);
    expect(find.text('yao'), findsOneWidget);
    expect(find.text('kan'), findsOneWidget);
    expect(find.text('pu'), findsOneWidget);
    expect(find.text('bu'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('遥')).dy,
      greaterThan(tester.getTopLeft(find.text('日')).dy),
    );
  });

  testWidgets('keeps very short repeated comma phrases together', (
    tester,
  ) async {
    const goosePoem = Poem(
      id: 51,
      title: '咏鹅',
      author: '骆宾王',
      dynasty: '唐',
      grade: 1,
      gradeLabel: '一年级',
      category: '咏物言志',
      content: '鹅，鹅，鹅，\n曲项向天歌。',
      pinyin: 'e e e\nqu xiang xiang tian ge',
      annotation: '',
      translation: '',
      appreciation: '',
      authorIntro: '',
      extension: '',
      audioUrl: null,
      imageUrl: null,
      difficulty: 1,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 320, child: PoemPinyinText(poem: goosePoem)),
        ),
      ),
    );

    final gooseCharacters = tester.widgetList<Text>(find.text('鹅')).toList();
    expect(gooseCharacters, hasLength(3));
    final firstTop = tester.getTopLeft(find.text('鹅').first).dy;
    for (final finder in [find.text('鹅').at(1), find.text('鹅').at(2)]) {
      expect(tester.getTopLeft(finder).dy, firstTop);
    }
  });

  testWidgets('keeps pinyin when one poem line maps to multiple pinyin lines', (
    tester,
  ) async {
    const ciPoem = Poem(
      id: 6,
      title: 'Ci',
      author: 'Tester',
      dynasty: 'Now',
      grade: 1,
      gradeLabel: 'Grade 1',
      category: 'Test',
      content: '春风又绿江南岸，明月何时照我还。',
      pinyin: 'chun feng you lv jiang nan an\nming yue he shi zhao wo huan',
      annotation: '',
      translation: '',
      appreciation: '',
      authorIntro: '',
      extension: '',
      audioUrl: null,
      imageUrl: null,
      difficulty: 1,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 320, child: PoemPinyinText(poem: ciPoem)),
        ),
      ),
    );

    expect(find.text('chun'), findsOneWidget);
    expect(find.text('an'), findsOneWidget);
    expect(find.text('ming'), findsOneWidget);
    expect(find.text('huan'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('明')).dy,
      greaterThan(tester.getTopLeft(find.text('春')).dy),
    );
  });

  testWidgets('keeps lyric poem characters at a consistent font size', (
    tester,
  ) async {
    const lyricPoem = Poem(
      id: 7,
      title: '清平乐·村居',
      author: '辛弃疾',
      dynasty: '宋',
      grade: 3,
      gradeLabel: '三年级',
      category: '山水田园',
      content: '茅檐低小，溪上青青草。\n醉里吴音相媚好，白发谁家翁媪？\n大儿锄豆溪东，中儿正织鸡笼。\n最喜小儿亡赖，溪头卧剥莲蓬。',
      pinyin:
          'mao yan di xiao xi shang qing qing cao\nzui li wu yin xiang mei hao bai fa shui jia weng ao\nda er chu dou xi dong zhong er zheng zhi ji long\nzui xi xiao er wu lai xi tou wo bo lian peng',
      annotation: '',
      translation: '',
      appreciation: '',
      authorIntro: '',
      extension: '',
      audioUrl: null,
      imageUrl: null,
      difficulty: 3,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: PoemPinyinText(
              poem: lyricPoem,
              variant: PoemPinyinTextVariant.detail,
            ),
          ),
        ),
      ),
    );

    final first = tester.widget<Text>(find.text('茅')).style?.fontSize;
    final longerLine = tester.widget<Text>(find.text('醉')).style?.fontSize;
    final last = tester.widget<Text>(find.text('莲')).style?.fontSize;

    expect(first, isNotNull);
    expect(longerLine, first);
    expect(last, first);
  });

  testWidgets('keeps representative mixed-length poems internally consistent', (
    tester,
  ) async {
    const poems = [
      Poem(
        id: 8,
        title: '咏鹅',
        author: '骆宾王',
        dynasty: '唐',
        grade: 1,
        gradeLabel: '一年级',
        category: '咏物',
        content: '鹅，鹅，鹅，\n曲项向天歌。\n白毛浮绿水，\n红掌拨清波。',
        pinyin:
            'e e e\nqu xiang xiang tian ge\nbai mao fu lv shui\nhong zhang bo qing bo',
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
        id: 9,
        title: '相见欢',
        author: '李煜',
        dynasty: '南唐',
        grade: 6,
        gradeLabel: '六年级',
        category: '抒情',
        content: '无言独上西楼，月如钩。\n寂寞梧桐深院锁清秋。\n剪不断，理还乱，是离愁。\n别是一般滋味在心头。',
        pinyin:
            'wu yan du shang xi lou yue ru gou\nji mo wu tong shen yuan suo qing qiu\njian bu duan li hai luan shi li chou\nbie shi yi ban zi wei zai xin tou',
        annotation: '',
        translation: '',
        appreciation: '',
        authorIntro: '',
        extension: '',
        audioUrl: null,
        imageUrl: null,
        difficulty: 3,
      ),
      Poem(
        id: 10,
        title: '山坡羊·潼关怀古',
        author: '张养浩',
        dynasty: '元',
        grade: 7,
        gradeLabel: '七年级',
        category: '怀古',
        content:
            '峰峦如聚，波涛如怒，山河表里潼关路。\n望西都，意踌躇。\n伤心秦汉经行处，宫阙万间都做了土。\n兴，百姓苦；亡，百姓苦。',
        pinyin:
            'feng luan ru ju bo tao ru nu shan he biao li tong guan lu\nwang xi du yi chou chu\nshang xin qin han jing xing chu gong que wan jian dou zuo le tu\nxing bai xing ku wang bai xing ku',
        annotation: '',
        translation: '',
        appreciation: '',
        authorIntro: '',
        extension: '',
        audioUrl: null,
        imageUrl: null,
        difficulty: 4,
      ),
    ];

    for (final poem in poems) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: PoemPinyinText(
                poem: poem,
                variant: PoemPinyinTextVariant.detail,
              ),
            ),
          ),
        ),
      );

      final fontSizes =
          tester
              .widgetList<Text>(find.byType(Text))
              .where((text) => _isSingleCjkText(text.data))
              .map((text) => text.style?.fontSize)
              .whereType<double>()
              .toSet();

      expect(
        fontSizes.length,
        1,
        reason: '${poem.title} should not mix poem character font sizes.',
      );
    }
  });

  testWidgets('keeps poem library preview characters at one size', (
    tester,
  ) async {
    const shortPoem = Poem(
      id: 11,
      title: 'Short',
      author: 'Tester',
      dynasty: 'Now',
      grade: 1,
      gradeLabel: 'Grade 1',
      category: 'Test',
      content: '山中一夜雨，',
      pinyin: 'shan zhong yi ye yu',
      annotation: '',
      translation: '',
      appreciation: '',
      authorIntro: '',
      extension: '',
      audioUrl: null,
      imageUrl: null,
      difficulty: 1,
    );
    const lyricPoem = Poem(
      id: 12,
      title: 'Lyric',
      author: 'Tester',
      dynasty: 'Now',
      grade: 1,
      gradeLabel: 'Grade 1',
      category: 'Test',
      content: '无言独上西楼，',
      pinyin: 'wu yan du shang xi lou',
      annotation: '',
      translation: '',
      appreciation: '',
      authorIntro: '',
      extension: '',
      audioUrl: null,
      imageUrl: null,
      difficulty: 1,
    );

    Future<double?> firstCharacterSize(Poem poem) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: PoemPinyinText(
                poem: poem,
                maxVisibleLines: 1,
                variant: PoemPinyinTextVariant.list,
              ),
            ),
          ),
        ),
      );
      return tester
          .widget<Text>(find.text(poem.content.characters.first))
          .style
          ?.fontSize;
    }

    final shortSize = await firstCharacterSize(shortPoem);
    final lyricSize = await firstCharacterSize(lyricPoem);

    expect(shortSize, isNotNull);
    expect(lyricSize, shortSize);
    expect(shortSize, 16);
  });

  testWidgets('does not shrink long poem library preview lines', (
    tester,
  ) async {
    const longPoem = Poem(
      id: 13,
      title: 'Long',
      author: 'Tester',
      dynasty: 'Now',
      grade: 1,
      gradeLabel: 'Grade 1',
      category: 'Test',
      content: '日照香炉生紫烟遥看瀑布挂前川，',
      pinyin: 'ri zhao xiang lu sheng zi yan yao kan pu bu gua qian chuan',
      annotation: '',
      translation: '',
      appreciation: '',
      authorIntro: '',
      extension: '',
      audioUrl: null,
      imageUrl: null,
      difficulty: 1,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 120,
            child: PoemPinyinText(
              poem: longPoem,
              maxVisibleLines: 1,
              variant: PoemPinyinTextVariant.list,
            ),
          ),
        ),
      ),
    );

    final firstSize = tester.widget<Text>(find.text('日')).style?.fontSize;
    final middleSize = tester.widget<Text>(find.text('生')).style?.fontSize;

    expect(firstSize, 16);
    expect(middleSize, firstSize);
  });
}

bool _isSingleCjkText(String? text) {
  if (text == null || text.runes.length != 1) {
    return false;
  }
  return _isCjkRune(text.runes.single);
}

bool _isCjkRune(int rune) {
  return (rune >= 0x4E00 && rune <= 0x9FFF) ||
      (rune >= 0x3400 && rune <= 0x4DBF);
}
