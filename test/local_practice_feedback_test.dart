import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gscappall/data/local/app_database.dart';
import 'package:gscappall/data/repositories/local_practice_repository.dart';
import 'package:gscappall/domain/practice_models.dart';
import 'package:gscappall/domain/repositories/poem_repository.dart';

void main() {
  test('dictation feedback stays localized for every answer branch', () {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = LocalPracticeRepository(
      database: database,
      poemRepository: _UnusedPoemRepository(),
    );
    const question = PracticeQuestion(
      poemId: 1,
      poemTitle: '咏鹅',
      poemAuthor: '骆宾王',
      lineIndex: 0,
      prompt: '默写第一句',
      hint: '第一个字：鹅',
      expectedAnswer: '鹅，鹅，鹅，',
    );

    final answers = <String>['', '鹅，鹅，鹅，', '鹅鹅鹅', '鹅鹅', '鹅鹅鹅鹅', '曲项向天'];

    for (final answer in answers) {
      final result = repository.evaluateAnswer(
        question: question,
        answer: answer,
      );
      expect(result.feedback, isNotEmpty);
      expect(result.feedback, isNot(matches(RegExp(r'[A-Za-z]'))));
    }
  });
}

class _UnusedPoemRepository implements PoemRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
