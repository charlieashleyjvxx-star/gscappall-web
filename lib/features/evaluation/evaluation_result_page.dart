import 'package:flutter/material.dart';

import '../../domain/practice_models.dart';
import '../../shared/widgets/section_card.dart';

enum EvaluationResultAction { restart, openWrongBook }

class EvaluationResultPage extends StatelessWidget {
  const EvaluationResultPage({super.key, required this.report});

  final PracticeReport report;

  @override
  Widget build(BuildContext context) {
    final dominantMistake = report.dominantMistakeType;

    return Scaffold(
      appBar: AppBar(title: const Text('测评结果')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            SectionCard(
              title: report.summaryLabel,
              subtitle: '${report.poem.title} · ${report.poem.author}',
              trailing: Chip(label: Text('总分 ${report.totalScore}')),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          title: '正确句数',
                          value:
                              '${report.correctCount}/${report.totalQuestions}',
                          color: const Color(0xFFE7F4E4),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MetricCard(
                          title: '正确率',
                          value: '${(report.accuracy * 100).round()}%',
                          color: const Color(0xFFF6E0B8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          title: '新增错题',
                          value: '${report.generatedWrongCount}',
                          color: const Color(0xFFFBE8E0),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MetricCard(
                          title: '当前判断',
                          value: report.scoreLevel,
                          color: const Color(0xFFE9EDF7),
                        ),
                      ),
                    ],
                  ),
                  if (dominantMistake != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      '本轮主要问题：${dominantMistake.label}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            SectionCard(
              title: '复习建议',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: report.suggestions
                    .map(
                      (suggestion) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(
                                Icons.tips_and_updates_outlined,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(suggestion)),
                          ],
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
            const SizedBox(height: 18),
            SectionCard(
              title: '逐题结果',
              child: Column(
                children: report.results
                    .map(
                      (result) => Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color:
                              result.isCorrect
                                  ? const Color(0xFFE7F4E4)
                                  : const Color(0xFFFBE8E0),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '第 ${result.question.lineIndex + 1} 句',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Chip(
                                  label: Text(
                                    result.isCorrect
                                        ? '正确 ${result.score}'
                                        : '${result.mistakeType?.label ?? '待复习'} ${result.score}',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '你的答案：${result.answer.isEmpty ? '未作答' : result.answer}',
                            ),
                            const SizedBox(height: 6),
                            Text('标准答案：${result.question.expectedAnswer}'),
                            const SizedBox(height: 6),
                            Text(result.feedback),
                          ],
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop(EvaluationResultAction.restart);
                    },
                    icon: const Icon(Icons.replay_rounded),
                    label: const Text('再练一次'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(
                        context,
                      ).pop(EvaluationResultAction.openWrongBook);
                    },
                    icon: const Icon(Icons.rule_folder_outlined),
                    label: const Text('去错题本'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
