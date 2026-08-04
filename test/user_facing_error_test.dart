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

  test('uses consistent copy for permissions and voice failures', () {
    final permission = UserFacingErrorMapper.map(
      Exception('Permission denied for microphone'),
    );
    final voice = UserFacingErrorMapper.map(
      Exception('Speech recognition unavailable'),
    );

    expect(permission.code, 'PERM-1001');
    expect(permission.message, '缺少所需权限，请在系统设置中允许后重试。');
    expect(voice.code, 'VOICE-1001');
    expect(voice.message, '语音识别暂时不可用，请稍后重试。');
  });

  test('uses stable fallback without exposing unknown details', () {
    final result = UserFacingErrorMapper.map(
      Exception('InternalFeatureException private-value'),
      fallbackMessage: '操作失败，请稍后重试。',
    );

    expect(result.code, 'APP-1000');
    expect(result.message, '操作失败，请稍后重试。');
    expect(result.message, isNot(contains('private-value')));
  });

  test('maps sync availability, authorization, and server failures', () {
    final unavailable = UserFacingErrorMapper.map(
      UnsupportedError('Cloud sync network transport is disabled.'),
    );
    final forbidden = UserFacingErrorMapper.map(
      Exception('HTTP 403 forbidden'),
    );
    final server = UserFacingErrorMapper.map(Exception('HTTP 503 unavailable'));

    expect(unavailable.code, 'SYNC-1001');
    expect(unavailable.message, '当前版本暂不支持网络备份。');
    expect(forbidden.code, 'AUTH-1002');
    expect(server.code, 'NET-1003');
  });
}
