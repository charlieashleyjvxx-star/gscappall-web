import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gscappall/features/shared/stage_contribution_view.dart';

void main() {
  test('stage contribution labels map to stable visual tones', () {
    expect(debugStageContributionToneForLabel('完成句数 · 约 4 句接龙'), 'lines');
    expect(debugStageContributionToneForLabel('分数进步 · 88 分'), 'score');
    expect(debugStageContributionToneForLabel('错题复习 · 听写复盘'), 'wrong');
    expect(debugStageContributionToneForLabel('报告/错题已记录'), 'sync');
    expect(debugStageContributionToneForLabel('已复习'), 'reviewed');
    expect(debugStageContributionToneForLabel('待复习'), 'pending');
    expect(debugStageContributionToneForLabel('练习进度 · 完成练习'), 'progress');

    expect(
      debugStageContributionIconForLabel('完成句数 · 约 4 句接龙'),
      Icons.format_list_numbered_rounded,
    );
    expect(
      debugStageContributionIconForLabel('分数进步 · 88 分'),
      Icons.stacked_line_chart_rounded,
    );
    expect(
      debugStageContributionIconForLabel('错题复习 · 听写复盘'),
      Icons.rule_folder_rounded,
    );
    expect(
      debugStageContributionBackgroundForLabel('报告/错题已记录'),
      const Color(0xFFE7F0FF),
    );
  });

  testWidgets('stage contribution chips render semantic color groups', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StageContributionChips(
            labels: [
              '完成句数 · 约 4 句接龙',
              '分数进步 · 88 分',
              '错题复习 · 听写复盘',
              '报告/错题已记录',
            ],
          ),
        ),
      ),
    );

    expect(find.text('完成句数 · 约 4 句接龙'), findsOneWidget);
    expect(find.text('分数进步 · 88 分'), findsOneWidget);
    expect(find.text('错题复习 · 听写复盘'), findsOneWidget);
    expect(find.text('报告/错题已记录'), findsOneWidget);
    expect(find.byIcon(Icons.format_list_numbered_rounded), findsOneWidget);
    expect(find.byIcon(Icons.stacked_line_chart_rounded), findsOneWidget);
    expect(find.byIcon(Icons.rule_folder_rounded), findsOneWidget);
    expect(find.byIcon(Icons.sync_alt_rounded), findsOneWidget);
  });

  testWidgets('stage contribution card uses shared title summary and chips', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StageContributionCard(
            title: '关卡进步',
            subtitle: '统一说明',
            summary: '这次练习已计入本关进度。',
            labels: ['练习进度 · 完成练习', '待复习'],
          ),
        ),
      ),
    );

    expect(find.text('关卡进步'), findsOneWidget);
    expect(find.text('统一说明'), findsOneWidget);
    expect(find.text('这次练习已计入本关进度。'), findsOneWidget);
    expect(find.text('练习进度 · 完成练习'), findsOneWidget);
    expect(find.text('待复习'), findsOneWidget);
    expect(find.byIcon(Icons.auto_graph_rounded), findsOneWidget);
    expect(find.byIcon(Icons.pending_actions_rounded), findsOneWidget);
  });

  testWidgets('stage progress evidence card renders shared metadata and taps', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StageProgressEvidenceCard(
            evidenceLabel: '练习记录卡',
            title: '咏鹅',
            stageLabel: '接龙入门',
            scoreLabel: '92 分',
            dateLabel: '05-26',
            modeLabel: '诗词接龙',
            modeIcon: Icons.account_tree_rounded,
            summary: '这次接龙约完成 4 句，分数 92 分。',
            labels: const ['完成句数 · 约 4 句接龙', '分数进步 · 92 分'],
            trailing: const Icon(Icons.chevron_right_rounded, size: 18),
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('练习记录卡'), findsOneWidget);
    expect(find.text('咏鹅'), findsOneWidget);
    expect(find.text('关卡：接龙入门'), findsOneWidget);
    expect(find.text('92 分'), findsOneWidget);
    expect(find.text('05-26'), findsOneWidget);
    expect(find.textContaining('诗词接龙'), findsOneWidget);
    expect(find.text('完成句数 · 约 4 句接龙'), findsOneWidget);
    expect(find.byIcon(Icons.account_tree_rounded), findsOneWidget);

    await tester.tap(find.text('咏鹅'));
    expect(tapped, isTrue);
  });
}
