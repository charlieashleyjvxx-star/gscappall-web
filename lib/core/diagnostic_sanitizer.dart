import 'dart:convert';

abstract final class DiagnosticSanitizer {
  static String text(Object? value) {
    var sanitized = value?.toString() ?? '';
    for (final pattern in _secretPatterns) {
      sanitized = sanitized.replaceAllMapped(
        pattern,
        (match) => '${match.group(1)}=[已隐藏]',
      );
    }
    sanitized = sanitized
        .replaceAll(_bearerPattern, 'Bearer [已隐藏]')
        .replaceAllMapped(
          _identifierPattern,
          (match) => '${match.group(1)}=[已隐藏]',
        )
        .replaceAll(_urlPattern, '[网络地址已隐藏]')
        .replaceAll(_windowsPathPattern, '[本地路径已隐藏]')
        .replaceAll(_androidPathPattern, '[本地路径已隐藏]')
        .replaceAll(_emailPattern, '[账号已隐藏]')
        .replaceAll(_ipv4Pattern, '[网络地址已隐藏]');
    return sanitized;
  }

  static Object? value(Object? input) {
    if (input is Map) {
      return <String, Object?>{
        for (final entry in input.entries)
          entry.key.toString():
              _isSensitiveKey(entry.key.toString())
                  ? '[已隐藏]'
                  : value(entry.value),
      };
    }
    if (input is Iterable) {
      return input.map(value).toList(growable: false);
    }
    if (input is String) {
      return text(input);
    }
    return input;
  }

  static String prettyJson(Object? input) {
    return const JsonEncoder.withIndent('  ').convert(value(input));
  }

  static bool _isSensitiveKey(String key) {
    final normalized = key.toLowerCase().replaceAll(RegExp(r'[_-]'), '');
    return normalized.contains('token') ||
        normalized.contains('password') ||
        normalized.contains('secret') ||
        normalized.contains('authorization') ||
        normalized.contains('credential') ||
        normalized.contains('requestid') ||
        normalized.contains('deviceid') ||
        normalized.contains('accountid') ||
        normalized.contains('profileid') ||
        normalized.contains('userid') ||
        normalized.contains('cloudid') ||
        normalized.contains('clientmutationid') ||
        normalized.contains('email') ||
        normalized.contains('phone') ||
        normalized.contains('filepath') ||
        normalized.endsWith('path');
  }

  static final List<RegExp> _secretPatterns = [
    RegExp(
      r'(authorization|token|password|secret|credential|api[_-]?key)\s*[:=]\s*[^\s,;]+',
      caseSensitive: false,
    ),
  ];
  static final RegExp _bearerPattern = RegExp(
    r'Bearer\s+[A-Za-z0-9._~+/=-]+',
    caseSensitive: false,
  );
  static final RegExp _identifierPattern = RegExp(
    r'(requestId|deviceId|accountId|profileId|userId|cloudId|clientMutationId)\s*[:=]\s*[^\s,;]+',
    caseSensitive: false,
  );
  static final RegExp _urlPattern = RegExp(
    r'''https?://[^\s"'<>]+''',
    caseSensitive: false,
  );
  static final RegExp _windowsPathPattern = RegExp(r'\b[A-Za-z]:\\[^\s,;]+');
  static final RegExp _androidPathPattern = RegExp(
    r'/(?:data|storage|sdcard|Users|home)/[^\s,;]+',
  );
  static final RegExp _emailPattern = RegExp(
    r'\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b',
    caseSensitive: false,
  );
  static final RegExp _ipv4Pattern = RegExp(
    r'\b(?:\d{1,3}\.){3}\d{1,3}(?::\d{1,5})?\b',
  );
}
