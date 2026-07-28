import 'package:flutter_test/flutter_test.dart';
import 'package:gscappall/app/notification_route_payload.dart';

void main() {
  test('notification payload routes daily poem reminders', () {
    final route = routeFromNotificationPayload('daily_poem_07:30_1');

    expect(route?.name, '/daily-poem');
    expect(route?.stageId, isNull);
  });

  test('notification payload routes stage shortcut to challenge map', () {
    final route = routeFromNotificationPayload('stage:jielong_entry');

    expect(route?.name, '/challenge-map');
    expect(route?.stageId, 'jielong_entry');
    expect(route?.routeArgs?.source, 'notification');
  });

  test('notification payload routes explicit named route with stage scope', () {
    final route = routeFromNotificationPayload(
      'route:/practice-reports?stageId=dictation_checkpoint',
    );

    expect(route?.name, '/practice-reports');
    expect(route?.stageId, 'dictation_checkpoint');
    expect(route?.routeArgs?.source, 'notification');
  });

  test('notification payload routes report and wrong question details', () {
    final reportRoute = routeFromNotificationPayload(
      'route:/practice-report-detail?reportId=42&stageId=jielong_entry',
    );
    final wrongRoute = routeFromNotificationPayload(
      'route:/wrong-question-detail?wrongQuestionId=7',
    );

    expect(reportRoute?.name, '/practice-report-detail');
    expect(reportRoute?.stageId, 'jielong_entry');
    expect(reportRoute?.reportId, 42);
    expect(reportRoute?.routeArgs?.reportId, 42);
    expect(reportRoute?.routeArgs?.source, 'notification');
    expect(wrongRoute?.name, '/wrong-question-detail');
    expect(wrongRoute?.wrongQuestionId, 7);
    expect(wrongRoute?.routeArgs?.wrongQuestionId, 7);
    expect(wrongRoute?.routeArgs?.source, 'notification');
  });

  test(
    'notification payload routes learning record and growth report period',
    () {
      final recordRoute = routeFromNotificationPayload(
        'route:/learning-record-detail?learningRecordId=99&stageId=jielong_entry',
      );
      final growthRoute = routeFromNotificationPayload(
        'route:/growth-report?period=monthly&stageId=feihualing_entry',
      );

      expect(recordRoute?.name, '/learning-record-detail');
      expect(recordRoute?.learningRecordId, 99);
      expect(recordRoute?.routeArgs?.learningRecordId, 99);
      expect(recordRoute?.routeArgs?.source, 'notification');
      expect(recordRoute?.stageId, 'jielong_entry');
      expect(growthRoute?.name, '/growth-report');
      expect(growthRoute?.growthPeriod, 'monthly');
      expect(growthRoute?.routeArgs?.growthPeriod, 'monthly');
      expect(growthRoute?.routeArgs?.source, 'notification');
      expect(growthRoute?.stageId, 'feihualing_entry');
    },
  );

  test('notification payload ignores invalid values', () {
    expect(routeFromNotificationPayload(null), isNull);
    expect(routeFromNotificationPayload(''), isNull);
    expect(routeFromNotificationPayload('unknown'), isNull);
    expect(routeFromNotificationPayload('stage:'), isNull);
  });
}
