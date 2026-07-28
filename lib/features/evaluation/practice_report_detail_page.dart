import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_providers.dart';
import '../../core/user_facing_error.dart';
import '../../domain/practice_models.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/section_card.dart';
import '../shared/stage_contribution_view.dart';
import '../shared/stage_scope_detail_panel.dart';
import '../shared/stage_scope_route_args.dart';

class CleanPracticeReportDetailPage extends ConsumerWidget {
  const CleanPracticeReportDetailPage({super.key, required this.reportId});

  final int reportId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(practiceReportDetailProvider(reportId));
    final routeArgs = StageScopeRouteArgs.maybeOf(context);
    final source = routeArgs?.source;
    final routeStageId = routeArgs?.stageId?.trim();

    return Scaffold(
      appBar: AppBar(title: const Text('报告详情')),
      body: report.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, _) => EmptyState(
              title: '报告详情加载失败',
              description: UserFacingErrorMapper.message(
                error,
                fallbackMessage: '报告详情加载失败，请稍后重试。',
              ),
              icon: Icons.error_outline_rounded,
            ),
        data: (detail) {
          if (detail == null) {
            return const EmptyState(
              title: '没有找到这份报告',
              description: '它可能已经被清理，或当前资料无权查看。',
              icon: Icons.find_in_page_outlined,
            );
          }

          final summary = detail.summary;
          final summaryStageId = summary.stageId?.trim();
          final stageId =
              summaryStageId != null && summaryStageId.isNotEmpty
                  ? summaryStageId
                  : routeStageId;
          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (source != null) ...[
                  StageScopeDetailSourcePanel(
                    source: source,
                    stageId: stageId,
                    focusLabel: '报告详情',
                  ),
                  const SizedBox(height: 12),
                ],
                SectionCard(
                  title: summary.poemTitle,
                  subtitle:
                      '${summary.poemAuthor} · ${summary.mode.label} · ${_formatDateTime(summary.completedAt)}',
                  trailing: Chip(label: Text('${summary.totalScore} 分')),
                  child: Row(
                    children: [
                      Expanded(
                        child: _MetricChip(
                          title: '正确率',
                          value:
                              '${summary.correctCount}/${summary.totalQuestions}',
                          color: const Color(0xFFE7F4E4),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MetricChip(
                          title: '新增错题',
                          value: '${summary.generatedWrongCount}',
                          color: const Color(0xFFFBE8E0),
                        ),
                      ),
                    ],
                  ),
                ),
                if ((summary.stageId ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _ReportContributionCard(summary: summary),
                ],
                if ((summary.stageId ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  SectionCard(
                    title: '关联关卡',
                    subtitle: '本次练习会计入闯关地图和成长报告。',
                    child: StageScopeDetailEvidencePanel(
                      title: '本关报告记录',
                      description: '这份报告会用于闯关地图星级、成长报告和本关复盘。',
                      stageId: summary.stageId!,
                      source: source,
                      fallbackChallengeMapSource: 'practice-report',
                      actions: [
                        StageScopeEvidenceAction(
                          label: '查看本关错题',
                          icon: Icons.rule_folder_outlined,
                          onPressed: () {
                            Navigator.of(context).pushNamed(
                              '/wrong-book',
                              arguments: StageScopeRouteArgs(
                                stageId: summary.stageId!,
                                source: 'practice-report',
                              ),
                            );
                          },
                        ),
                        StageScopeEvidenceAction(
                          label: '查看学习历史',
                          icon: Icons.history_edu_outlined,
                          onPressed: () {
                            Navigator.of(context).pushNamed(
                              '/learning-history',
                              arguments: StageScopeRouteArgs(
                                stageId: summary.stageId!,
                                source: 'practice-report',
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
                if (detail.suggestions.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  SectionCard(
                    title: '复习建议',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final suggestion in detail.suggestions) ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.tips_and_updates_outlined,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text(suggestion)),
                            ],
                          ),
                          if (suggestion != detail.suggestions.last)
                            const SizedBox(height: 10),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                for (final item in detail.items) ...[
                  _ReportItemCard(item: item),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ReportContributionCard extends StatelessWidget {
  const _ReportContributionCard({required this.summary});

  final PracticeReportSummary summary;

  @override
  Widget build(BuildContext context) {
    return StageContributionCard(
      title: '关卡进步',
      subtitle: '这份报告会计入成长报告和闯关地图。',
      summary: stageContributionSummaryForReport(summary),
      labels: stageContributionLabelsForReport(summary),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.title,
    required this.value,
    required this.color,
  });

  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _ReportItemCard extends StatelessWidget {
  const _ReportItemCard({required this.item});

  final PracticeReportItem item;

  @override
  Widget build(BuildContext context) {
    final color =
        item.isCorrect ? const Color(0xFFE7F4E4) : const Color(0xFFFBE8E0);
    return SectionCard(
      title: '第 ${item.lineIndex + 1} 题',
      subtitle: item.prompt,
      trailing: Chip(
        label: Text(item.isCorrect ? '通过' : item.mistakeType?.label ?? '待复习'),
        backgroundColor: color,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TextBlock(label: '你的答案', value: item.userAnswer),
          const SizedBox(height: 10),
          _TextBlock(label: '标准答案', value: item.expectedAnswer),
          const SizedBox(height: 10),
          _TextBlock(label: '反馈', value: item.feedback),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Chip(label: Text('${item.score} 分')),
          ),
        ],
      ),
    );
  }
}

class _TextBlock extends StatelessWidget {
  const _TextBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(value.isEmpty ? '未作答' : value),
      ],
    );
  }
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$month/$day $hour:$minute';
}
