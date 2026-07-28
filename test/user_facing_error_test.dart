import 'package:flutter_test/flutter_test.dart';
import 'package:gscappall/core/user_facing_error.dart';

void main() {
  test('maps technical network errors to safe copy and stable code', () {
    final result = UserFacingErrorMapper.map(
      Exception('SocketException: Failed host lookup api.internal.local'),
    );

    expect(result.code, 'NET-1001');
    expect(result.message, isNot(contains('api.internal.local')));
    expect(result.parentMessage, contains('NET-1001'));
  });

  test('does not expose unknown exception details', () {
    final result = UserFacingErrorMapper.map(
      Exception('database path C:/private/user.db token=secret'),
      fallbackMessage: '内容加载失败，请稍后重试。',
    );

    expect(result.message, isNot(contains('C:/private')));
    expect(result.message, isNot(contains('secret')));
    expect(result.code, 'DATA-1001');
  });
}
