import 'package:flutter/material.dart';

import 'stage_scope_route_args.dart';

class StageScopeQuickLinks extends StatelessWidget {
  const StageScopeQuickLinks({
    super.key,
    required this.stageId,
    this.challengeMapSource = 'practice-report',
    this.mapLabel = '回到地图',
  });

  final String stageId;
  final String? challengeMapSource;
  final String mapLabel;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.tonalIcon(
          onPressed: () {
            Navigator.of(context).pushNamed(
              '/growth-report',
              arguments: StageScopeRouteArgs(stageId: stageId),
            );
          },
          icon: const Icon(Icons.insights_rounded),
          label: const Text('本关成长'),
        ),
        FilledButton.tonalIcon(
          onPressed: () {
            Navigator.of(context).pushNamed(
              '/challenge-map',
              arguments: StageScopeRouteArgs(
                stageId: stageId,
                source: challengeMapSource,
              ),
            );
          },
          icon: const Icon(Icons.map_rounded),
          label: Text(mapLabel),
        ),
      ],
    );
  }
}
