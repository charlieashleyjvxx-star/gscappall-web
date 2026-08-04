import 'package:flutter_test/flutter_test.dart';
import 'package:gscappall/core/app_crash_reporter.dart';

void main() {
  test('sanitizes crash metadata and stack paths', () {
    final entry = AppCrashReporter.sanitizedEntry(
      Exception(
        'token=secret https://api.internal.example '
        'learner@example.com',
      ),
      StackTrace.fromString(r'#0 C:\Users\learner\project\lib\main.dart:10:2'),
      context: 'requestId=request-123',
    );
    final serialized = entry.toString();

    expect(serialized, isNot(contains('secret')));
    expect(serialized, isNot(contains('api.internal.example')));
    expect(serialized, isNot(contains('learner@example.com')));
    expect(serialized, isNot(contains(r'C:\Users\learner')));
    expect(serialized, isNot(contains('request-123')));
  });

  test('production entry omits raw exception message', () {
    final entry = AppCrashReporter.sanitizedEntry(
      Exception('private learner answer'),
      StackTrace.fromString('#0 PracticePage.save'),
      hideMessage: true,
    );

    expect(entry['message'], '[错误详情已隐藏]');
    expect(entry.toString(), isNot(contains('private learner answer')));
    expect(entry['stackTrace'], contains('PracticePage.save'));
  });
}
