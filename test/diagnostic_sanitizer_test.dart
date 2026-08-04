import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gscappall/core/diagnostic_sanitizer.dart';

void main() {
  group('DiagnosticSanitizer', () {
    test('redacts secrets, network addresses, paths, and accounts', () {
      final sanitized = DiagnosticSanitizer.text(
        'token=secret Bearer abc.def '
        'https://api.internal.example/v1 '
        '192.168.1.8:8080 '
        'requestId=request-123 '
        r'C:\Users\learner\private.db '
        '/data/user/0/com.gsc.appall/files/private.db '
        'learner@example.com',
      );

      expect(sanitized, isNot(contains('secret')));
      expect(sanitized, isNot(contains('abc.def')));
      expect(sanitized, isNot(contains('api.internal.example')));
      expect(sanitized, isNot(contains('192.168.1.8')));
      expect(sanitized, isNot(contains('request-123')));
      expect(sanitized, isNot(contains('private.db')));
      expect(sanitized, isNot(contains('learner@example.com')));
    });

    test('redacts sensitive and internal identifiers in nested data', () {
      final sanitized =
          DiagnosticSanitizer.value(<String, Object?>{
                'requestId': 'request-123',
                'device_id': 'device-123',
                'accountId': 'account-123',
                'profileId': 42,
                'cloudId': 'cloud-123',
                'payload': <String, Object?>{
                  'authorization': 'Bearer secret',
                  'refresh_token': 'refresh-secret',
                  'statusCode': 503,
                },
              })!
              as Map<String, Object?>;

      expect(sanitized['requestId'], '[已隐藏]');
      expect(sanitized['device_id'], '[已隐藏]');
      expect(sanitized['accountId'], '[已隐藏]');
      expect(sanitized['profileId'], '[已隐藏]');
      expect(sanitized['cloudId'], '[已隐藏]');
      expect(sanitized['payload'], <String, Object?>{
        'authorization': '[已隐藏]',
        'refresh_token': '[已隐藏]',
        'statusCode': 503,
      });
    });

    test('prettyJson never serializes raw sensitive values', () {
      final report = DiagnosticSanitizer.prettyJson(<String, Object?>{
        'requestId': 'request-123',
        'endpoint': 'https://sync.example.internal/v1',
        'stack': r'C:\private\app.dart:10',
      });
      final decoded = jsonDecode(report) as Map<String, Object?>;

      expect(decoded['requestId'], '[已隐藏]');
      expect(report, isNot(contains('request-123')));
      expect(report, isNot(contains('sync.example.internal')));
      expect(report, isNot(contains(r'C:\private')));
    });
  });
}
