import 'package:flutter/material.dart';

import '../../services/speech/speech_recognition_service.dart';

class RecognitionDebugCard extends StatelessWidget {
  const RecognitionDebugCard({
    super.key,
    required this.snapshot,
    this.nativeState,
    this.title = '识别调试信息',
  });

  final SpeechRecognitionDebugSnapshot snapshot;
  final String? nativeState;
  final String title;

  @override
  Widget build(BuildContext context) {
    final metrics = <(String, String)>[
      ('后端', snapshot.selectedBackend),
      ('状态', nativeState ?? snapshot.currentState),
      ('模型文件', snapshot.modelFilesReady ? '已就绪' : '未就绪'),
      ('首次出字', _formatLatency(snapshot.firstPartialLatencyMs)),
      ('最终结果', _formatLatency(snapshot.finalLatencyMs)),
      ('Partial 次数', '${snapshot.partialResultCount}'),
      ('Decode 次数', '${snapshot.decodeCycles}'),
      ('端点结束', snapshot.endpointDetected ? '已触发' : '未触发'),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: metrics
                  .map(
                    (item) => _MetricChip(label: item.$1, value: item.$2),
                  )
                  .toList(growable: false),
            ),
            if (snapshot.diagnostics.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                snapshot.diagnostics.join('  |  '),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(height: 1.5),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatLatency(int? value) {
    if (value == null) {
      return '未产生';
    }
    return '${value}ms';
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 118),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7EEDC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
