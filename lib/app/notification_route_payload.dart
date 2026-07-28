import '../features/shared/stage_scope_route_args.dart';

class NotificationRoutePayload {
  const NotificationRoutePayload({
    required this.name,
    this.stageId,
    this.reportId,
    this.wrongQuestionId,
    this.learningRecordId,
    this.growthPeriod,
    this.source,
  });

  final String name;
  final String? stageId;
  final int? reportId;
  final int? wrongQuestionId;
  final int? learningRecordId;
  final String? growthPeriod;
  final String? source;

  StageScopeRouteArgs? get routeArgs {
    if (stageId == null &&
        reportId == null &&
        wrongQuestionId == null &&
        learningRecordId == null &&
        growthPeriod == null &&
        source == null) {
      return null;
    }
    return StageScopeRouteArgs(
      stageId: stageId,
      reportId: reportId,
      wrongQuestionId: wrongQuestionId,
      learningRecordId: learningRecordId,
      growthPeriod: growthPeriod,
      source: source,
    );
  }
}

NotificationRoutePayload? routeFromNotificationPayload(String? payload) {
  final value = payload?.trim();
  if (value == null || value.isEmpty) {
    return null;
  }
  if (value == 'daily_poem' || value.startsWith('daily_poem_')) {
    return const NotificationRoutePayload(name: '/daily-poem');
  }
  if (value.startsWith('stage:')) {
    final stageId = value.substring('stage:'.length).trim();
    return stageId.isEmpty
        ? null
        : NotificationRoutePayload(
          name: '/challenge-map',
          stageId: stageId,
          source: 'notification',
        );
  }
  if (value.startsWith('route:')) {
    final uri = Uri.tryParse(value.substring('route:'.length));
    if (uri == null || uri.path.isEmpty) {
      return null;
    }
    final stageId = uri.queryParameters['stageId']?.trim();
    final reportId = int.tryParse(uri.queryParameters['reportId'] ?? '');
    final wrongQuestionId = int.tryParse(
      uri.queryParameters['wrongQuestionId'] ?? '',
    );
    final learningRecordId = int.tryParse(
      uri.queryParameters['learningRecordId'] ?? '',
    );
    final growthPeriod = _growthPeriodValue(uri.queryParameters['period']);
    return NotificationRoutePayload(
      name: uri.path,
      stageId: stageId == null || stageId.isEmpty ? null : stageId,
      reportId: reportId,
      wrongQuestionId: wrongQuestionId,
      learningRecordId: learningRecordId,
      growthPeriod: growthPeriod,
      source: 'notification',
    );
  }
  return null;
}

String? _growthPeriodValue(String? value) {
  final normalized = value?.trim().toLowerCase();
  if (normalized == 'weekly' || normalized == 'week') {
    return 'weekly';
  }
  if (normalized == 'monthly' || normalized == 'month') {
    return 'monthly';
  }
  return null;
}
