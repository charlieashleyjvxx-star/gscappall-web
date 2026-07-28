import 'package:flutter_test/flutter_test.dart';
import 'package:gscappall/domain/poem.dart';
import 'package:gscappall/services/game/feihualing_service.dart';

void main() {
  const service = FeihualingService();

  test('builds theme pool from repeated characters in poem lines', () {
    final themes = service.buildThemePool(_poems, limit: 3, minHits: 2);

    expect(themes.first.character, '月');
    expect(themes.first.hitCount, 3);
    expect(themes.first.exampleLines, contains('床前明月光，'));
  });

  test('validates single player answers', () {
    final bank = service.buildLineBank(_poems);

    final accepted = service.validateTurn(
      bank: bank,
      input: '举头望明月',
      themeCharacter: '月',
      usedKeys: const {},
    );
    expect(accepted.accepted, isTrue);

    final wrongTheme = service.validateTurn(
      bank: bank,
      input: '低头思故乡',
      themeCharacter: '月',
      usedKeys: const {},
    );
    expect(wrongTheme.accepted, isFalse);
    expect(wrongTheme.message, contains('没有“月”'));

    final repeated = service.validateTurn(
      bank: bank,
      input: '举头望明月',
      themeCharacter: '月',
      usedKeys: {accepted.line!.key},
    );
    expect(repeated.accepted, isFalse);
  });

  test('checks theme matching and builds report', () {
    expect(service.lineMatchesTheme('举头望明月。', '月'), isTrue);
    expect(service.lineMatchesTheme('低头思故乡。', '月'), isFalse);

    final report = service.buildReport(themeCharacter: '月', lineCount: 4);
    expect(report.score, 98);
    expect(report.points, 14);
    expect(report.summary, contains('月'));
  });
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
    content: '床前明月光，\n举头望明月。',
    pinyin: '',
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
    content: '今夜鄜州月，\n低头思故乡。',
    pinyin: '',
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
