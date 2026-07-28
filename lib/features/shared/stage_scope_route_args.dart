import 'package:flutter/material.dart';

@immutable
class StageScopeRouteArgs {
  const StageScopeRouteArgs({
    this.stageId,
    this.reportId,
    this.wrongQuestionId,
    this.learningRecordId,
    this.growthPeriod,
    this.dateKey,
    this.source,
  });

  final String? stageId;
  final int? reportId;
  final int? wrongQuestionId;
  final int? learningRecordId;
  final String? growthPeriod;
  final String? dateKey;
  final String? source;

  static StageScopeRouteArgs? fromSettings(RouteSettings settings) {
    final arguments = settings.arguments;
    if (arguments is StageScopeRouteArgs) {
      return arguments;
    }
    if (arguments is String && arguments.isNotEmpty) {
      return StageScopeRouteArgs(stageId: arguments);
    }
    if (arguments is Map) {
      final stageId = _stringValue(arguments['stageId']);
      final reportId = _intValue(arguments['reportId']);
      final wrongQuestionId = _intValue(arguments['wrongQuestionId']);
      final learningRecordId = _intValue(arguments['learningRecordId']);
      final growthPeriod = _stringValue(arguments['growthPeriod']);
      final dateKey = _stringValue(arguments['dateKey']);
      final source = _stringValue(arguments['source']);
      if (stageId != null ||
          reportId != null ||
          wrongQuestionId != null ||
          learningRecordId != null ||
          growthPeriod != null ||
          dateKey != null ||
          source != null) {
        return StageScopeRouteArgs(
          stageId: stageId,
          reportId: reportId,
          wrongQuestionId: wrongQuestionId,
          learningRecordId: learningRecordId,
          growthPeriod: growthPeriod,
          dateKey: dateKey,
          source: source,
        );
      }
    }
    return null;
  }

  static StageScopeRouteArgs? maybeOf(BuildContext context) {
    final settings = ModalRoute.of(context)?.settings;
    return settings == null ? null : fromSettings(settings);
  }

  RouteSettings toRouteSettings({String? name}) {
    return RouteSettings(name: name, arguments: this);
  }

  static String? _stringValue(Object? value) {
    if (value is! String) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static int? _intValue(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is String) {
      return int.tryParse(value.trim());
    }
    return null;
  }
}
