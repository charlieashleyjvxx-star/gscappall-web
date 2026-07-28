import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gscappall/features/profile/profile_support.dart';
import 'package:gscappall/features/shared/stage_scope_detail_panel.dart';
import 'package:gscappall/features/shared/stage_scope_source_hint.dart';

void main() {
  test('source hint uses distinct visual specs for key entry points', () {
    expect(debugStageScopeSourceIcon('growth-report'), Icons.insights_rounded);
    expect(debugStageScopeSourceIcon('sync-log'), Icons.sync_alt_rounded);
    expect(
      debugStageScopeSourceIcon('wrong-question'),
      Icons.rule_folder_rounded,
    );
    expect(
      debugStageScopeSourceBackground('growth-report'),
      isNot(debugStageScopeSourceBackground('sync-log')),
    );
    expect(
      debugStageScopeSourceForeground('wrong-question'),
      isNot(debugStageScopeSourceForeground('growth-report')),
    );
  });

  testWidgets('floating source banner collapses after a short highlight', (
    tester,
  ) async {
    final stageLabel = challengeStageLabel('jielong_entry');
    final sourceLabel = stageScopeSourceLabel('growth-report')!;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StageScopeFloatingBanner(
            stageLabel: stageLabel,
            source: 'growth-report',
          ),
        ),
      ),
    );

    expect(find.textContaining(stageLabel), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    expect(find.text('$sourceLabel · $stageLabel'), findsOneWidget);
  });

  testWidgets('detail source panel shows floating banner with stage context', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StageScopeDetailSourcePanel(
            source: 'sync-log',
            stageId: 'jielong_entry',
            focusLabel: 'Detail',
          ),
        ),
      ),
    );

    expect(find.byType(StageScopeFloatingBanner), findsOneWidget);
    expect(find.byType(StageScopeSourceHint), findsNothing);
    expect(
      find.textContaining(stageScopeSourceLabel('sync-log')!),
      findsOneWidget,
    );
    expect(find.textContaining('Detail'), findsOneWidget);
    expect(
      find.textContaining(challengeStageLabel('jielong_entry')),
      findsOneWidget,
    );
  });

  testWidgets('detail source panel falls back to source chip without stage', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StageScopeDetailSourcePanel(
            source: 'notification',
            focusLabel: 'Detail',
          ),
        ),
      ),
    );

    expect(find.byType(StageScopeFloatingBanner), findsNothing);
    expect(find.byType(StageScopeSourceHint), findsOneWidget);
    expect(find.text(stageScopeSourceLabel('notification')!), findsOneWidget);
  });

  testWidgets('detail source panel hides when source is absent', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StageScopeDetailSourcePanel(
            source: null,
            stageId: 'jielong_entry',
            focusLabel: 'Detail',
          ),
        ),
      ),
    );

    expect(find.byType(StageScopeFloatingBanner), findsNothing);
    expect(find.byType(StageScopeSourceHint), findsNothing);
  });

  testWidgets('evidence actions render shared buttons and callbacks', (
    tester,
  ) async {
    final tapped = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StageScopeEvidenceActions(
            actions: [
              StageScopeEvidenceAction(
                label: '查看学习记录详情',
                icon: Icons.history_edu_outlined,
                onPressed: () => tapped.add('record'),
              ),
              StageScopeEvidenceAction(
                label: '查看报告',
                icon: Icons.assessment_outlined,
                onPressed: () => tapped.add('report'),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('查看相关记录'), findsOneWidget);
    expect(find.text('查看学习记录详情'), findsOneWidget);
    expect(find.text('查看报告'), findsOneWidget);
    expect(find.byIcon(Icons.history_edu_outlined), findsOneWidget);
    expect(find.byIcon(Icons.assessment_outlined), findsOneWidget);

    await tester.tap(find.text('查看报告'));
    expect(tapped, ['report']);
  });
}
