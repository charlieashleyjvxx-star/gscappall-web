import 'package:flutter/material.dart';

import '../../shared/widgets/section_card.dart';

class GameRuleCard extends StatelessWidget {
  const GameRuleCard({
    super.key,
    required this.goal,
    required this.rule,
    required this.completion,
  });

  final String goal;
  final String rule;
  final String completion;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '本局规则',
      subtitle: completion,
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        title: const Text('查看游戏规则'),
        children: [
          _RuleRow(label: '目标', value: goal),
          _RuleRow(label: '玩法', value: rule),
          _RuleRow(label: '完成', value: completion),
        ],
      ),
    );
  }
}

class GameResultCard extends StatelessWidget {
  const GameResultCard({
    super.key,
    required this.summary,
    required this.metrics,
    required this.primaryLabel,
    required this.onPrimary,
    required this.secondaryLabel,
    required this.onSecondary,
  });

  final String summary;
  final Map<String, String> metrics;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String secondaryLabel;
  final VoidCallback onSecondary;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '本局结果',
      subtitle: summary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final metric in metrics.entries)
                Chip(label: Text('${metric.key} ${metric.value}')),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 56,
            child: FilledButton.icon(
              onPressed: onPrimary,
              icon: const Icon(Icons.replay_rounded),
              label: Text(primaryLabel),
            ),
          ),
          const SizedBox(height: 4),
          TextButton(onPressed: onSecondary, child: Text(secondaryLabel)),
        ],
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 48,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
