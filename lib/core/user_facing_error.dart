class UserFacingError {
  const UserFacingError({required this.message, required this.code});

  final String message;
  final String code;

  String get parentMessage => '$message（错误编号：$code）';
}

abstract final class UserFacingErrorMapper {
  static UserFacingError map(
    Object error, {
    String fallbackMessage = '暂时无法完成，请稍后重试。',
  }) {
    final raw = error.toString().toLowerCase();
    if (raw.contains('socketexception') ||
        raw.contains('handshakeexception') ||
        raw.contains('failed host lookup') ||
        raw.contains('connection refused')) {
      return const UserFacingError(
        message: '网络暂时不可用，请检查网络后重试。',
        code: 'NET-1001',
      );
    }
    if (raw.contains('timeout') || raw.contains('timed out')) {
      return const UserFacingError(message: '请求时间较长，请稍后重试。', code: 'NET-1002');
    }
    if (raw.contains('401') ||
        raw.contains('403') ||
        raw.contains('unauthorized') ||
        raw.contains('forbidden')) {
      return const UserFacingError(
        message: '登录状态已失效，请重新登录。',
        code: 'AUTH-1001',
      );
    }
    if (raw.contains('permission') || raw.contains('denied')) {
      return const UserFacingError(
        message: '缺少所需权限，请在系统设置中允许后重试。',
        code: 'PERM-1001',
      );
    }
    if (raw.contains('speech') || raw.contains('recognition')) {
      return const UserFacingError(
        message: '语音识别暂时不可用，请稍后重试。',
        code: 'VOICE-1001',
      );
    }
    if (raw.contains('database') ||
        raw.contains('sqlite') ||
        raw.contains('drift')) {
      return const UserFacingError(
        message: '本地资料暂时无法读取，请重新打开应用。',
        code: 'DATA-1001',
      );
    }
    return UserFacingError(message: fallbackMessage, code: 'APP-1000');
  }

  static String message(
    Object error, {
    String fallbackMessage = '暂时无法完成，请稍后重试。',
  }) {
    return map(error, fallbackMessage: fallbackMessage).message;
  }

  static String parentMessage(
    Object error, {
    String fallbackMessage = '暂时无法完成，请稍后重试。',
  }) {
    return map(error, fallbackMessage: fallbackMessage).parentMessage;
  }
}
