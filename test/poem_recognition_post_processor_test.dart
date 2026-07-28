import 'package:flutter_test/flutter_test.dart';
import 'package:gscappall/domain/poem.dart';
import 'package:gscappall/services/speech/poem_recognition_post_processor.dart';

void main() {
  const processor = PoemRecognitionPostProcessor();

  group('PoemRecognitionPostProcessor', () {
    test('snaps close homophone final result for spring dawn line', () {
      const poem = Poem(
        id: 1,
        title: '春晓',
        author: '孟浩然',
        dynasty: '唐',
        grade: 2,
        gradeLabel: '二年级',
        category: '自然',
        content: '春眠不觉晓。\n处处闻啼鸟。\n夜来风雨声。\n花落知多少。',
        pinyin:
            'chun mian bu jue xiao\n'
            'chu chu wen ti niao\n'
            'ye lai feng yu sheng\n'
            'hua luo zhi duo shao',
        annotation: '',
        translation: '',
        appreciation: '',
        authorIntro: '',
        extension: '',
        audioUrl: null,
        imageUrl: null,
        difficulty: 2,
      );

      final correction = processor.correctForTarget(
        poem: poem,
        lineIndex: 1,
        recognizedText: '处处安体鸟',
        isFinal: true,
      );

      expect(correction.wasCorrected, isTrue);
      expect(correction.displayText, '处处闻啼鸟。');
      expect(correction.reason, 'target_line_snap');
    });

    test('snaps close homophone final result for quiet night thought line', () {
      const poem = Poem(
        id: 2,
        title: '静夜思',
        author: '李白',
        dynasty: '唐',
        grade: 1,
        gradeLabel: '一年级',
        category: '思乡',
        content: '床前明月光。\n疑是地上霜。\n举头望明月。\n低头思故乡。',
        pinyin:
            'chuang qian ming yue guang\n'
            'yi shi di shang shuang\n'
            'ju tou wang ming yue\n'
            'di tou si gu xiang',
        annotation: '',
        translation: '',
        appreciation: '',
        authorIntro: '',
        extension: '',
        audioUrl: null,
        imageUrl: null,
        difficulty: 1,
      );

      final correction = processor.correctForTarget(
        poem: poem,
        lineIndex: 1,
        recognizedText: '疑似第三双',
        isFinal: true,
      );

      expect(correction.wasCorrected, isTrue);
      expect(correction.displayText, '疑是地上霜。');
      expect(correction.reason, 'target_line_snap');
    });

    test('does not snap unrelated content', () {
      const poem = Poem(
        id: 3,
        title: '咏鹅',
        author: '骆宾王',
        dynasty: '唐',
        grade: 1,
        gradeLabel: '一年级',
        category: '童趣',
        content: '鹅鹅鹅。\n曲项向天歌。',
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

      final correction = processor.correctForTarget(
        poem: poem,
        lineIndex: 1,
        recognizedText: '今天下午放学了',
        isFinal: true,
      );

      expect(correction.wasCorrected, isFalse);
      expect(correction.displayText, '今天下午放学了');
    });

    test('keeps partial result raw before final confirmation', () {
      const poem = Poem(
        id: 4,
        title: '春晓',
        author: '孟浩然',
        dynasty: '唐',
        grade: 2,
        gradeLabel: '二年级',
        category: '自然',
        content: '春眠不觉晓。\n处处闻啼鸟。',
        pinyin: 'chun mian bu jue xiao\nchu chu wen ti niao',
        annotation: '',
        translation: '',
        appreciation: '',
        authorIntro: '',
        extension: '',
        audioUrl: null,
        imageUrl: null,
        difficulty: 2,
      );

      final correction = processor.correctForTarget(
        poem: poem,
        lineIndex: 1,
        recognizedText: '处处安体鸟',
        isFinal: false,
      );

      expect(correction.wasCorrected, isFalse);
      expect(correction.displayText, '处处安体鸟');
      expect(correction.reason, 'keep_raw_partial');
    });

    test('snaps shifted final result with missing and extra characters', () {
      const poem = Poem(
        id: 5,
        title: '\u6625\u6653',
        author: '\u5b5f\u6d69\u7136',
        dynasty: '\u5510',
        grade: 2,
        gradeLabel: '\u4e8c\u5e74\u7ea7',
        category: '\u81ea\u7136',
        content:
            '\u6625\u7720\u4e0d\u89c9\u6653\u3002\n'
            '\u5904\u5904\u95fb\u557c\u9e1f\u3002',
        pinyin: 'chun mian bu jue xiao\nchu chu wen ti niao',
        annotation: '',
        translation: '',
        appreciation: '',
        authorIntro: '',
        extension: '',
        audioUrl: null,
        imageUrl: null,
        difficulty: 2,
      );

      final correction = processor.correctForTarget(
        poem: poem,
        lineIndex: 1,
        recognizedText: '\u5904\u5904\u5b89\u542c\u9e1f\u554a',
        isFinal: true,
      );

      expect(correction.wasCorrected, isTrue);
      expect(correction.displayText, '\u5904\u5904\u95fb\u557c\u9e1f\u3002');
      expect(correction.reason, 'target_line_snap');
    });

    test('guided reading mode prefers target line for noisy final speech', () {
      const poem = Poem(
        id: 6,
        title: '\u9759\u591c\u601d',
        author: '\u674e\u767d',
        dynasty: '\u5510',
        grade: 1,
        gradeLabel: '\u4e00\u5e74\u7ea7',
        category: '\u601d\u4e61',
        content:
            '\u5e8a\u524d\u660e\u6708\u5149\u3002\n'
            '\u7591\u662f\u5730\u4e0a\u971c\u3002',
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

      final correction = processor.correctForTarget(
        poem: poem,
        lineIndex: 1,
        recognizedText: '\u4e00\u4e2a\u5730\u4e0a\u53cc',
        isFinal: true,
        preferTargetOnFinal: true,
      );

      expect(correction.wasCorrected, isTrue);
      expect(correction.displayText, '\u7591\u662f\u5730\u4e0a\u971c\u3002');
      expect(correction.reason, 'target_line_guided');
    });
  });
}
