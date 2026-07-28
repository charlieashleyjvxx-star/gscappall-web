import 'package:flutter_test/flutter_test.dart';
import 'package:gscappall/domain/poem.dart';

void main() {
  test('poem lines split by newline and trim blanks', () {
    const poem = Poem(
      id: 1,
      title: 'Test',
      author: 'Author',
      dynasty: 'Dynasty',
      grade: 1,
      gradeLabel: '一年级',
      category: '启蒙',
      content: '床前明月光\n  疑是地上霜  \n\n举头望明月',
      pinyin: '',
      annotation: '',
      translation: '',
      appreciation: '',
      authorIntro: '',
      extension: '',
      audioUrl: null,
      imageUrl: null,
      difficulty: 1,
    );

    expect(poem.lines, ['床前明月光', '疑是地上霜', '举头望明月']);
  });

  test('poem pinyin lines split by newline and trim blanks', () {
    const poem = Poem(
      id: 1,
      title: '静夜思',
      author: '李白',
      dynasty: '唐',
      grade: 1,
      gradeLabel: '一年级',
      category: '思乡',
      content: '床前明月光\n疑是地上霜',
      pinyin: ' chuáng qián míng yuè guāng \n\n yí shì dì shàng shuāng ',
      annotation: '',
      translation: '',
      appreciation: '',
      authorIntro: '',
      extension: '',
      audioUrl: null,
      imageUrl: null,
      difficulty: 1,
    );

    expect(poem.pinyinLines, [
      'chuáng qián míng yuè guāng',
      'yí shì dì shàng shuāng',
    ]);
  });
}
