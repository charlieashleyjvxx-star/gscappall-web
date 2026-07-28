import 'package:flutter/material.dart';

import '../profile/profile_support.dart';
import 'stage_scope_filter_banner.dart';
import 'stage_scope_quick_links.dart';
import 'stage_scope_source_hint.dart';

class StageScopeLandingPanel extends StatelessWidget {
  const StageScopeLandingPanel({
    super.key,
    required this.stageId,
    required this.filterKind,
    required this.onClearFilter,
    required this.fallbackChallengeMapSource,
    required this.mapLabel,
    this.source,
    this.onlyUnreviewed = false,
  });

  final String stageId;
  final StageScopeFilterKind filterKind;
  final VoidCallback onClearFilter;
  final String fallbackChallengeMapSource;
  final String mapLabel;
  final String? source;
  final bool onlyUnreviewed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (source != null) ...[
          StageScopeFloatingBanner(
            stageLabel: challengeStageLabel(stageId),
            source: source,
          ),
          const SizedBox(height: 10),
        ],
        StageScopeFilterBanner(
          stageId: stageId,
          kind: filterKind,
          source: source,
          onlyUnreviewed: onlyUnreviewed,
          onClear: onClearFilter,
        ),
        const SizedBox(height: 10),
        StageScopeQuickLinks(
          stageId: stageId,
          challengeMapSource: source ?? fallbackChallengeMapSource,
          mapLabel: mapLabel,
        ),
      ],
    );
  }
}
