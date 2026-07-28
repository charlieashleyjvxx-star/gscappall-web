import 'dart:convert';

import 'package:flutter/foundation.dart';

enum AppLogLevel { debug, info, warning, error }

abstract final class AppLogger {
  static void event(
    String event, {
    required String feature,
    AppLogLevel level = AppLogLevel.info,
    Map<String, Object?> fields = const {},
  }) {
    if (kReleaseMode) {
      return;
    }
    final payload = <String, Object?>{
      'level': level.name,
      'feature': feature,
      'event': event,
      ...fields,
    };
    debugPrint('[GSC] ${jsonEncode(payload)}');
  }
}
