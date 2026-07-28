import 'package:flutter/material.dart';

import '../../domain/learning_models.dart';
import '../../domain/practice_models.dart';
import '../../shared/widgets/section_card.dart';

class StageContributionCard extends StatelessWidget {
  const StageContributionCard({
    super.key,
    required this.title,
    required this.summary,
    required this.labels,
    this.subtitle,
    this.padding = const EdgeInsets.all(20),
  });

  final String title;
  final String? subtitle;
  final String summary;
  final List<String> labels;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: title,
      subtitle: subtitle,
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(summary),
          const SizedBox(height: 10),
          StageContributionChips(labels: labels),
        ],
      ),
    );
  }
}

class StageProgressEvidenceCard extends StatelessWidget {
  const StageProgressEvidenceCard({
    super.key,
    required this.evidenceLabel,
    required this.title,
    required this.stageLabel,
    required this.scoreLabel,
    required this.dateLabel,
    required this.modeLabel,
    required this.modeIcon,
    required this.summary,
    required this.labels,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.padding = const EdgeInsets.all(12),
    this.highlighted = false,
  });

  final String evidenceLabel;
  final String title;
  final String stageLabel;
  final String scoreLabel;
  final String dateLabel;
  final String modeLabel;
  final IconData modeIcon;
  final String? subtitle;
  final String summary;
  final List<String> labels;
  final VoidCallback? onTap;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors:
              highlighted
                  ? const [Color(0xFFFFF4D9), Color(0xFFFFE7A6)]
                  : [
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.78),
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.56),
                  ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color:
              highlighted
                  ? colorScheme.primary.withValues(alpha: 0.72)
                  : colorScheme.outlineVariant.withValues(alpha: 0.72),
          width: highlighted ? 1.4 : 1,
        ),
        boxShadow:
            highlighted
                ? [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.16),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
                : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0C7),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(modeIcon, color: const Color(0xFF7A4B00)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      evidenceLabel,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        Chip(
                          avatar: const Icon(Icons.flag_rounded, size: 16),
                          label: Text('关卡：$stageLabel'),
                          visualDensity: VisualDensity.compact,
                        ),
                        Chip(
                          avatar: const Icon(
                            Icons.sports_score_rounded,
                            size: 16,
                          ),
                          label: Text(scoreLabel),
                          visualDensity: VisualDensity.compact,
                        ),
                        Chip(
                          avatar: const Icon(
                            Icons.calendar_month_rounded,
                            size: 16,
                          ),
                          label: Text(dateLabel),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitle ?? '$modeLabel · 这条记录会用于判断本关分数、句数或错题复习是否有变化。',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          StageContributionCard(
            title: '本次练习',
            summary: summary,
            labels: labels,
            padding: const EdgeInsets.all(12),
          ),
        ],
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: card,
      ),
    );
  }
}

class StageContributionChips extends StatelessWidget {
  const StageContributionChips({super.key, required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final label in labels)
          Builder(
            builder: (context) {
              final spec = _StageContributionVisualSpec.fromLabel(label);
              return Chip(
                avatar: Icon(spec.icon, size: 16, color: spec.foreground),
                label: Text(label),
                labelStyle: TextStyle(
                  color: spec.foreground,
                  fontWeight: FontWeight.w700,
                ),
                visualDensity: VisualDensity.compact,
                side: BorderSide.none,
                backgroundColor: spec.background,
              );
            },
          ),
      ],
    );
  }
}

class StageContributionLegend extends StatelessWidget {
  const StageContributionLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return const StageContributionChips(
      labels: ['完成句数 · 示例', '分数进步 · 示例', '错题复习 · 示例', '报告/错题已记录'],
    );
  }
}

enum _StageContributionTone {
  lines,
  score,
  wrong,
  sync,
  reviewed,
  pending,
  progress,
}

class _StageContributionVisualSpec {
  const _StageContributionVisualSpec({
    required this.tone,
    required this.icon,
    required this.background,
    required this.foreground,
  });

  factory _StageContributionVisualSpec.fromLabel(String label) {
    final tone = _toneForContributionLabel(label);
    return switch (tone) {
      _StageContributionTone.lines => const _StageContributionVisualSpec(
        tone: _StageContributionTone.lines,
        icon: Icons.format_list_numbered_rounded,
        background: Color(0xFFFFF0C7),
        foreground: Color(0xFF7A4B00),
      ),
      _StageContributionTone.score => const _StageContributionVisualSpec(
        tone: _StageContributionTone.score,
        icon: Icons.stacked_line_chart_rounded,
        background: Color(0xFFE5F2D8),
        foreground: Color(0xFF245A16),
      ),
      _StageContributionTone.wrong => const _StageContributionVisualSpec(
        tone: _StageContributionTone.wrong,
        icon: Icons.rule_folder_rounded,
        background: Color(0xFFFFE4DC),
        foreground: Color(0xFF8A2B13),
      ),
      _StageContributionTone.sync => const _StageContributionVisualSpec(
        tone: _StageContributionTone.sync,
        icon: Icons.sync_alt_rounded,
        background: Color(0xFFE7F0FF),
        foreground: Color(0xFF1E4F8F),
      ),
      _StageContributionTone.reviewed => const _StageContributionVisualSpec(
        tone: _StageContributionTone.reviewed,
        icon: Icons.task_alt_rounded,
        background: Color(0xFFE3F6EA),
        foreground: Color(0xFF17633A),
      ),
      _StageContributionTone.pending => const _StageContributionVisualSpec(
        tone: _StageContributionTone.pending,
        icon: Icons.pending_actions_rounded,
        background: Color(0xFFFFEFD7),
        foreground: Color(0xFF7A4B00),
      ),
      _StageContributionTone.progress => const _StageContributionVisualSpec(
        tone: _StageContributionTone.progress,
        icon: Icons.auto_graph_rounded,
        background: Color(0xFFEDE7DD),
        foreground: Color(0xFF5A4A37),
      ),
    };
  }

  final _StageContributionTone tone;
  final IconData icon;
  final Color background;
  final Color foreground;
}

_StageContributionTone _toneForContributionLabel(String label) {
  if (label.startsWith('完成句数')) {
    return _StageContributionTone.lines;
  }
  if (label.startsWith('分数进步')) {
    return _StageContributionTone.score;
  }
  if (label.startsWith('错题复习') || label.startsWith('错题类型')) {
    return _StageContributionTone.wrong;
  }
  if (label.contains('已记录')) {
    return _StageContributionTone.sync;
  }
  if (label == '已复习') {
    return _StageContributionTone.reviewed;
  }
  if (label == '待复习') {
    return _StageContributionTone.pending;
  }
  return _StageContributionTone.progress;
}

@visibleForTesting
String debugStageContributionToneForLabel(String label) {
  return _toneForContributionLabel(label).name;
}

@visibleForTesting
IconData debugStageContributionIconForLabel(String label) {
  return _StageContributionVisualSpec.fromLabel(label).icon;
}

@visibleForTesting
Color debugStageContributionBackgroundForLabel(String label) {
  return _StageContributionVisualSpec.fromLabel(label).background;
}

@visibleForTesting
Color debugStageContributionForegroundForLabel(String label) {
  return _StageContributionVisualSpec.fromLabel(label).foreground;
}

List<String> stageContributionLabelsForRecord(LearningRecord record) {
  final estimatedLines = (record.durationMinutes ~/ 2).clamp(1, 999);
  final labels = <String>[
    switch (record.mode) {
      'poetry_jielong' => '完成句数 · 约 $estimatedLines 句接龙',
      'feihualing' => '完成句数 · 约 $estimatedLines 句飞花令',
      'dictation' => '错题复习 · 听写复盘',
      _ => '练习进度 · 完成练习',
    },
  ];
  if (record.score != null) {
    labels.add('分数进步 · ${record.score} 分');
  }
  if (record.mode == 'dictation') {
    labels.add('报告/错题已记录');
  }
  return labels;
}

String stageContributionSummaryForRecord(LearningRecord record) {
  final estimatedLines = (record.durationMinutes ~/ 2).clamp(1, 999);
  final scoreText = record.score == null ? '本次未记录分数' : '分数 ${record.score} 分';
  return switch (record.mode) {
    'poetry_jielong' =>
      '这次接龙约完成 $estimatedLines 句，$scoreText，用来判断本关句数和分数是否有提升。',
    'feihualing' => '这次飞花令约完成 $estimatedLines 句，$scoreText，用来判断主题字答句是否更稳定。',
    'dictation' => '这次听写会同时记录报告和错题，重点看错字是否减少、复盘是否完成。',
    _ => '这次练习已计入本关进度，$scoreText。',
  };
}

String stageContributionShortSummaryForRecord(LearningRecord record) {
  final estimatedLines = (record.durationMinutes ~/ 2).clamp(1, 999);
  final scoreText = record.score == null ? '本次未记录分数' : '分数 ${record.score} 分';
  return switch (record.mode) {
    'poetry_jielong' => '这次接龙约完成 $estimatedLines 句，$scoreText。',
    'feihualing' => '这次飞花令约完成 $estimatedLines 句，$scoreText。',
    'dictation' => '这次听写已记录错题和报告，重点看错字是否减少。',
    _ => '这次练习已计入本关进度，$scoreText。',
  };
}

List<String> stageContributionLabelsForStageStat(LearningStageStat stat) {
  final estimatedLines = (stat.minutes ~/ 2).clamp(1, 999);
  final labels = <String>[
    if (stat.stageId.startsWith('jielong'))
      '完成句数 · 约 $estimatedLines 句接龙'
    else if (stat.stageId.startsWith('feihualing'))
      '完成句数 · 约 $estimatedLines 句飞花令'
    else if (stat.stageId.startsWith('dictation'))
      '错题复习 · 听写复盘'
    else
      '练习进度 · 完成练习',
  ];
  if (stat.averageScore != null) {
    labels.add('分数进步 · ${stat.averageScore} 分');
  }
  if (stat.stageId.startsWith('dictation')) {
    labels.add('报告/错题已记录');
  }
  return labels;
}

String stageContributionModeTextForStage(String stageId, int estimatedLines) {
  if (stageId.startsWith('jielong')) {
    return '接龙句数约 $estimatedLines 句';
  }
  if (stageId.startsWith('feihualing')) {
    return '飞花令答句约 $estimatedLines 句';
  }
  if (stageId.startsWith('dictation')) {
    return '听写复盘已计入错题复习';
  }
  return '闯关练习已计入地图';
}

String stageContributionSummaryForReport(PracticeReportSummary summary) {
  final stageId = summary.stageId ?? '';
  if (stageId.startsWith('jielong')) {
    return '这次练习记录了本关分数，帮助判断接龙是否更稳定。';
  }
  if (stageId.startsWith('feihualing')) {
    return '这次练习记录了本关分数，帮助判断飞花令是否更稳定。';
  }
  if (stageId.startsWith('dictation')) {
    return '这份报告会把听写分数和新增错题一起记录，重点看错字是否减少。';
  }
  return '这份报告已计入本关进度。';
}

List<String> stageContributionLabelsForReport(PracticeReportSummary summary) {
  final stageId = summary.stageId ?? '';
  final labels = <String>[
    if (stageId.startsWith('jielong'))
      '完成句数 · 接龙报告'
    else if (stageId.startsWith('feihualing'))
      '完成句数 · 飞花令报告'
    else if (stageId.startsWith('dictation'))
      '错题复习 · 听写复盘'
    else
      '练习进度 · 完成练习',
    '分数进步 · ${summary.totalScore} 分',
  ];
  if (summary.generatedWrongCount > 0) {
    labels.add('报告/错题已记录');
  }
  return labels;
}

String stageContributionSummaryForWrong(WrongQuestionEntry entry) {
  final stageId = entry.stageId ?? '';
  if (stageId.startsWith('jielong')) {
    return '这道错题提示接龙练习还需要复盘，重点看句子衔接是否稳定。';
  }
  if (stageId.startsWith('feihualing')) {
    return '这道错题提示飞花令答句还需要复盘，重点看主题字和原句是否匹配。';
  }
  if (stageId.startsWith('dictation')) {
    return '这道错题会进入听写复盘，重点看同类错字是否减少。';
  }
  return '这道错题已计入本关弱项，可作为后续复练依据。';
}

List<String> stageContributionLabelsForWrong(WrongQuestionEntry entry) {
  final stageId = entry.stageId ?? '';
  return [
    if (stageId.startsWith('jielong'))
      '完成句数 · 接龙复盘'
    else if (stageId.startsWith('feihualing'))
      '完成句数 · 飞花令复盘'
    else if (stageId.startsWith('dictation'))
      '错题复习 · 听写复盘'
    else
      '练习进度 · 弱项复盘',
    '错题类型 · ${entry.mistakeType.label}',
    entry.isReviewed ? '已复习' : '待复习',
  ];
}
