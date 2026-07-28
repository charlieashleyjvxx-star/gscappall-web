import 'package:flutter_test/flutter_test.dart';
import 'package:gscappall/domain/poem.dart';
import 'package:gscappall/services/game/poetry_jielong_service.dart';

void main() {
  const service = PoetryJielongService();

  test('builds a normalized line bank from poem content', () {
    final bank = service.buildLineBank(_poems);

    expect(bank, hasLength(5));
    expect(bank.first.text, '床前明月光，');
    expect(bank.first.firstChar, '床');
    expect(bank.first.lastChar, '光');
    expect(bank.first.firstPinyin, 'chuang');
    expect(bank.first.lastPinyin, 'guang');
    expect(service.normalizeLine('床前明月光，。！？'), '床前明月光');
    expect(service.normalizePinyin('guāng'), 'guang');
  });

  test('validates target first character and prevents repeated lines', () {
    final bank = service.buildLineBank(_poems);
    final used = <String>{bank.first.key};

    final wrongStart = service.validateTurn(
      bank: bank,
      input: '疑是地上霜',
      targetChar: '光',
      targetPinyin: 'guang',
      usedKeys: used,
    );
    expect(wrongStart.accepted, isFalse);
    expect(wrongStart.message, contains('光'));

    final accepted = service.validateTurn(
      bank: bank,
      input: '光阴不可留',
      targetChar: '光',
      targetPinyin: 'guang',
      usedKeys: used,
    );
    expect(accepted.accepted, isTrue);
    expect(accepted.sameSoundFallback, isFalse);
    expect(accepted.line?.lastChar, '留');

    final repeated = service.validateTurn(
      bank: bank,
      input: '床前明月光',
      targetChar: '床',
      targetPinyin: 'chuang',
      usedKeys: used,
    );
    expect(repeated.accepted, isFalse);
    expect(repeated.message, contains('已经用过'));
  });

  test('returns suggestions for the target character', () {
    final bank = service.buildLineBank(_poems);
    final suggestions = service.suggestionsForTarget(
      bank,
      targetChar: '光',
      targetPinyin: 'guang',
    );

    expect(suggestions.map((line) => line.text), contains('光阴不可留。'));
  });

  test('accepts same-sound fallback when first character differs', () {
    final bank = service.buildLineBank(_poems);

    final accepted = service.validateTurn(
      bank: bank,
      input: '广厦千万间',
      targetChar: '光',
      targetPinyin: 'guang',
      usedKeys: const {},
    );

    expect(accepted.accepted, isTrue);
    expect(accepted.sameSoundFallback, isTrue);
    expect(accepted.message, contains('同音接上'));

    final report = service.buildReport(lineCount: 4, sameSoundCount: 1);
    expect(report.score, 92);
    expect(report.points, 13);
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
    content: '床前明月光，\n疑是地上霜。',
    pinyin: 'chuang qian ming yue guang\nyi shi di shang shuang',
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
    title: '惜时',
    author: '佚名',
    dynasty: '唐',
    grade: 2,
    gradeLabel: '二年级',
    category: '励志',
    content: '光阴不可留。\n留取丹心照汗青。\n广厦千万间。',
    pinyin:
        'guang yin bu ke liu\nliu qu dan xin zhao han qing\nguang sha qian wan jian',
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
