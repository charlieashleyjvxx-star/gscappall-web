import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gscappall/domain/poem.dart';
import 'package:gscappall/shared/widgets/poem_pinyin_text.dart';

void main() {
  testWidgets('normalizes standalone e with tone mark in poem detail pinyin', (
    tester,
  ) async {
    const poem = Poem(
      id: 1,
      title: '\u548f\u9e45',
      author: '\u9a86\u5bbe\u738b',
      dynasty: '\u5510',
      grade: 1,
      gradeLabel: '\u4e00\u5e74\u7ea7',
      category: '\u542f\u8499',
      content: '\u9e45\uff0c\u9e45\uff0c\u9e45',
      pinyin: 'é é é',
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
      const MaterialApp(home: Scaffold(body: PoemPinyinText(poem: poem))),
    );

    expect(find.text('é'), findsNothing);
    expect(find.text('e'), findsNWidgets(3));
  });
}
