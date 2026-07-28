import 'package:flutter/material.dart';

import '../profile/profile_support.dart';
import 'stage_scope_quick_links.dart';
import 'stage_scope_source_hint.dart';

class StageScopeDetailSourcePanel extends StatelessWidget {
  const StageScopeDetailSourcePanel({
    super.key,
    required this.source,
    this.stageId,
    required this.focusLabel,
  });

  final String? source;
  final String? stageId;
  final String focusLabel;

  @override
  Widget build(BuildContext context) {
    if (source == null) {
      return const SizedBox.shrink();
    }

    final trimmedStageId = stageId?.trim();
    if (trimmedStageId != null && trimmedStageId.isNotEmpty) {
      final sourceLabel =
          stageScopeSourceLabel(source) ?? '\u6765\u6e90\u56de\u8df3';
      final stageLabel = challengeStageLabel(trimmedStageId);
      return StageScopeFloatingBanner(
        stageLabel: stageLabel,
        source: source,
        message: '$sourceLabel / $focusLabel: $stageLabel',
      );
    }

    return StageScopeSourceHint(source: source);
  }
}

class StageScopeDetailQuickLinks extends StatelessWidget {
  const StageScopeDetailQuickLinks({
    super.key,
    required this.stageId,
    required this.fallbackChallengeMapSource,
    this.source,
    this.mapLabel = '\u56de\u5230\u5730\u56fe',
  });

  final String stageId;
  final String fallbackChallengeMapSource;
  final String? source;
  final String mapLabel;

  @override
  Widget build(BuildContext context) {
    return StageScopeQuickLinks(
      stageId: stageId,
      challengeMapSource: source ?? fallbackChallengeMapSource,
      mapLabel: mapLabel,
    );
  }
}

class StageScopeDetailEvidencePanel extends StatelessWidget {
  const StageScopeDetailEvidencePanel({
    super.key,
    required this.title,
    required this.description,
    required this.stageId,
    required this.fallbackChallengeMapSource,
    this.source,
    this.mapLabel = '回到地图',
    this.actions = const <StageScopeEvidenceAction>[],
  });

  final String title;
  final String description;
  final String stageId;
  final String fallbackChallengeMapSource;
  final String? source;
  final String mapLabel;
  final List<StageScopeEvidenceAction> actions;

  @override
  Widget build(BuildContext context) {
    final stageLabel = challengeStageLabel(stageId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(description),
        const SizedBox(height: 10),
        Chip(
          avatar: const Icon(Icons.flag_rounded, size: 16),
          label: Text('关卡：$stageLabel'),
          visualDensity: VisualDensity.compact,
        ),
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 12),
          StageScopeEvidenceActions(actions: actions),
        ],
        const SizedBox(height: 12),
        StageScopeDetailQuickLinks(
          stageId: stageId,
          source: source,
          fallbackChallengeMapSource: fallbackChallengeMapSource,
          mapLabel: mapLabel,
        ),
      ],
    );
  }
}

class StageScopeEvidenceAction {
  const StageScopeEvidenceAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
}

class StageScopeEvidenceActions extends StatelessWidget {
  const StageScopeEvidenceActions({
    super.key,
    this.title = '查看相关记录',
    required this.actions,
  });

  final String title;
  final List<StageScopeEvidenceAction> actions;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final action in actions)
              OutlinedButton.icon(
                onPressed: action.onPressed,
                icon: Icon(action.icon),
                label: Text(action.label),
              ),
          ],
        ),
      ],
    );
  }
}
