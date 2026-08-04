import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'diagnostic_sanitizer.dart';

abstract final class AppCrashReporter {
  static const _maximumEntries = 50;
  static const releaseId = String.fromEnvironment(
    'GSC_RELEASE_ID',
    defaultValue: 'unversioned',
  );
  static File? _reportFile;
  static Future<void> _writeQueue = Future<void>.value();

  static Future<void> initialize() async {
    try {
      final supportDirectory = await getApplicationSupportDirectory();
      final directory = Directory('${supportDirectory.path}/diagnostics');
      await directory.create(recursive: true);
      _reportFile = File('${directory.path}/crash_reports.jsonl');
    } catch (_) {
      _reportFile = null;
    }
  }

  static Future<void> record(
    Object error,
    StackTrace stackTrace, {
    String context = 'uncaught',
    bool fatal = true,
  }) {
    final entry = sanitizedEntry(
      error,
      stackTrace,
      context: context,
      fatal: fatal,
      hideMessage: kReleaseMode,
    );
    _writeQueue = _writeQueue.then((_) => _append(entry));
    return _writeQueue;
  }

  @visibleForTesting
  static Map<String, Object?> sanitizedEntry(
    Object error,
    StackTrace stackTrace, {
    String context = 'uncaught',
    bool fatal = true,
    bool hideMessage = false,
  }) {
    return <String, Object?>{
      'occurredAt': DateTime.now().toUtc().toIso8601String(),
      'releaseId': releaseId,
      'context': DiagnosticSanitizer.text(context),
      'fatal': fatal,
      'errorType': error.runtimeType.toString(),
      'message': hideMessage ? '[错误详情已隐藏]' : DiagnosticSanitizer.text(error),
      'stackTrace': DiagnosticSanitizer.text(stackTrace),
    };
  }

  static Future<String> exportSanitizedReport() async {
    return DiagnosticSanitizer.prettyJson(await exportSanitizedData());
  }

  static Future<Map<String, Object?>> exportSanitizedData() async {
    await _writeQueue;
    final entries = await _readEntries();
    return Map<String, Object?>.from(
      DiagnosticSanitizer.value(<String, Object?>{
            'generatedAt': DateTime.now().toUtc().toIso8601String(),
            'releaseId': releaseId,
            'crashes': entries,
          })!
          as Map,
    );
  }

  static Future<void> _append(Map<String, Object?> entry) async {
    final file = _reportFile;
    if (file == null) {
      return;
    }
    try {
      final entries = await _readEntries();
      entries.add(entry);
      final retained =
          entries.length > _maximumEntries
              ? entries.sublist(entries.length - _maximumEntries)
              : entries;
      final content = retained.map(jsonEncode).join('\n');
      await file.writeAsString(
        content.isEmpty ? '' : '$content\n',
        flush: true,
      );
    } catch (_) {
      // Crash reporting must never cause another application failure.
    }
  }

  static Future<List<Map<String, Object?>>> _readEntries() async {
    final file = _reportFile;
    if (file == null || !await file.exists()) {
      return <Map<String, Object?>>[];
    }
    try {
      final lines = await file.readAsLines();
      return lines
          .where((line) => line.trim().isNotEmpty)
          .map((line) => Map<String, Object?>.from(jsonDecode(line) as Map))
          .toList(growable: true);
    } catch (_) {
      return <Map<String, Object?>>[];
    }
  }
}
