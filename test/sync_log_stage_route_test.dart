import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gscappall/domain/sync/sync_models.dart';
import 'package:gscappall/features/profile/sync_log_detail_page.dart';
import 'package:gscappall/features/shared/stage_scope_route_args.dart';

void main() {
  test('extracts stage ids from sync notes and errors', () {
    final log = _log(
      notes: const [
        'applied remote dto {"stageId":"jielong_entry"}',
        'stage_id=dictation_checkpoint',
      ],
      errorMessage: 'conflict stageId:feihualing_theme',
    );

    expect(extractSyncStageIds(log), {
      'jielong_entry',
      'dictation_checkpoint',
      'feihualing_theme',
    });
  });

  test('extracts report and wrong question ids from sync notes and errors', () {
    final log = _log(
      notes: const [
        'push ack {"reportId":42,"wrongQuestionId":7,"learningRecordId":5}',
        'apply report_id=43 wrong_question_id=8 learning_record_id=6',
      ],
      errorMessage:
          'conflict reportId:44 wrongQuestionId=9 learningRecordId=10',
    );

    expect(extractSyncReportIds(log), {42, 43, 44});
    expect(extractSyncWrongQuestionIds(log), {7, 8, 9});
    expect(extractSyncLearningRecordIds(log), {5, 6, 10});
  });

  testWidgets('sync log stage shortcut opens named route with stage args', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final pushedSettings = <RouteSettings>[];
    final log = _log(
      notes: const ['applied remote dto {"stageId":"jielong_entry"}'],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: SyncLogDetailPage(log: log),
          onGenerateRoute: (settings) {
            pushedSettings.add(settings);
            final stageId = StageScopeRouteArgs.fromSettings(settings)?.stageId;
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => Scaffold(body: Text('${settings.name}:$stageId')),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final reportButton = find.text('本关报告').first;
    await tester.tap(reportButton);
    await tester.pumpAndSettle();

    expect(pushedSettings.last.name, '/practice-reports');
    expect(
      StageScopeRouteArgs.fromSettings(pushedSettings.last)?.stageId,
      'jielong_entry',
    );
    expect(find.text('/practice-reports:jielong_entry'), findsOneWidget);
  });

  testWidgets('sync log record shortcut opens detail named routes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final pushedSettings = <RouteSettings>[];
    final log = _log(
      notes: const [
        'applied remote dto {"stageId":"jielong_entry"}',
        'push ack {"reportId":42,"wrongQuestionId":7}',
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: SyncLogDetailPage(log: log),
          onGenerateRoute: (settings) {
            pushedSettings.add(settings);
            final args = StageScopeRouteArgs.fromSettings(settings);
            return MaterialPageRoute<void>(
              settings: settings,
              builder:
                  (_) => Scaffold(
                    body: Text(
                      '${settings.name}:${args?.reportId}:${args?.wrongQuestionId}:${args?.stageId}',
                    ),
                  ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('报告 #42'));
    await tester.pumpAndSettle();

    expect(pushedSettings.last.name, '/practice-report-detail');
    var routeArgs = StageScopeRouteArgs.fromSettings(pushedSettings.last);
    expect(routeArgs?.reportId, 42);
    expect(routeArgs?.source, 'sync-log');
    expect(routeArgs?.stageId, 'jielong_entry');
    expect(
      find.text('/practice-report-detail:42:null:jielong_entry'),
      findsOneWidget,
    );

    Navigator.of(
      tester.element(
        find.text('/practice-report-detail:42:null:jielong_entry'),
      ),
    ).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('错题 #7'));
    await tester.pumpAndSettle();

    expect(pushedSettings.last.name, '/wrong-question-detail');
    routeArgs = StageScopeRouteArgs.fromSettings(pushedSettings.last);
    expect(routeArgs?.wrongQuestionId, 7);
    expect(routeArgs?.source, 'sync-log');
    expect(routeArgs?.stageId, 'jielong_entry');
    expect(
      find.text('/wrong-question-detail:null:7:jielong_entry'),
      findsOneWidget,
    );
  });

  testWidgets('sync log learning record shortcut opens detail named route', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final pushedSettings = <RouteSettings>[];
    final log = _log(
      notes: const [
        'applied remote dto {"stageId":"jielong_entry"}',
        'push ack {"learningRecordId":5}',
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: SyncLogDetailPage(log: log),
          onGenerateRoute: (settings) {
            pushedSettings.add(settings);
            final args = StageScopeRouteArgs.fromSettings(settings);
            return MaterialPageRoute<void>(
              settings: settings,
              builder:
                  (_) => Scaffold(
                    body: Text(
                      '${settings.name}:${args?.learningRecordId}:${args?.stageId}',
                    ),
                  ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('学习记录 #5'));
    await tester.pumpAndSettle();

    expect(pushedSettings.last.name, '/learning-record-detail');
    expect(
      StageScopeRouteArgs.fromSettings(pushedSettings.last)?.learningRecordId,
      5,
    );
    expect(
      StageScopeRouteArgs.fromSettings(pushedSettings.last)?.source,
      'sync-log',
    );
    expect(
      StageScopeRouteArgs.fromSettings(pushedSettings.last)?.stageId,
      'jielong_entry',
    );
    expect(
      find.text('/learning-record-detail:5:jielong_entry'),
      findsOneWidget,
    );
  });
}

SyncRunLogEntry _log({List<String> notes = const [], String? errorMessage}) {
  return SyncRunLogEntry(
    id: 1,
    state: SyncRunState.success,
    startedAt: DateTime(2026, 5, 21, 8),
    finishedAt: DateTime(2026, 5, 21, 8, 1),
    pushedCount: 1,
    pulledCount: 1,
    conflictCount: 0,
    trigger: SyncRunTrigger.manual,
    errorMessage: errorMessage,
    notes: notes,
    createdAt: DateTime(2026, 5, 21, 8, 1),
  );
}
