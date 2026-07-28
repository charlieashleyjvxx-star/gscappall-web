import 'package:flutter/material.dart';

import '../profile/profile_support.dart';

enum StageScopeFilterKind { wrongQuestions, practiceReports, learningHistory }

class StageScopeFilterBanner extends StatelessWidget {
  const StageScopeFilterBanner({
    super.key,
    required this.stageId,
    required this.kind,
    required this.onClear,
    this.source,
    this.onlyUnreviewed = false,
  });

  final String stageId;
  final StageScopeFilterKind kind;
  final VoidCallback onClear;
  final String? source;
  final bool onlyUnreviewed;

  @override
  Widget build(BuildContext context) {
    final stageLabel = challengeStageLabel(stageId);
    final fromGrowthReport = source == 'growth-report';
    final description = _description(
      stageLabel: stageLabel,
      fromGrowthReport: fromGrowthReport,
    );
    final helper = _helperText(fromGrowthReport);
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8D8B8)),
      ),
      child: Row(
        children: [
          Icon(
            fromGrowthReport
                ? Icons.insights_rounded
                : Icons.filter_alt_rounded,
            color: const Color(0xFF946600),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                if (helper != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    helper,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.clear_all_rounded),
            label: Text(_clearLabel(fromGrowthReport)),
          ),
        ],
      ),
    );
  }

  String _description({
    required String stageLabel,
    required bool fromGrowthReport,
  }) {
    return switch (kind) {
      StageScopeFilterKind.wrongQuestions =>
        fromGrowthReport && onlyUnreviewed
            ? '先看 $stageLabel 待复习错题'
            : onlyUnreviewed
            ? '当前只看：$stageLabel 待复习错题'
            : '当前只看「$stageLabel」相关错题',
      StageScopeFilterKind.practiceReports =>
        fromGrowthReport ? '先看 $stageLabel 练习结果' : '当前只看「$stageLabel」相关报告',
      StageScopeFilterKind.learningHistory =>
        fromGrowthReport ? '先看 $stageLabel 最近练习' : '当前只看「$stageLabel」相关历史',
    };
  }

  String? _helperText(bool fromGrowthReport) {
    if (!fromGrowthReport || kind != StageScopeFilterKind.wrongQuestions) {
      return null;
    }
    return '可以先复习还没掌握的题，再回到闯关地图继续练。';
  }

  String _clearLabel(bool fromGrowthReport) {
    if (!fromGrowthReport) {
      return '清除筛选';
    }
    return switch (kind) {
      StageScopeFilterKind.wrongQuestions => '查看全部错题',
      StageScopeFilterKind.practiceReports => '查看全部报告',
      StageScopeFilterKind.learningHistory => '查看全部历史',
    };
  }
}
