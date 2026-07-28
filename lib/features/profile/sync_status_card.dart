import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_providers.dart';
import '../../domain/sync/sync_models.dart';
import '../../shared/widgets/section_card.dart';
import 'sync_account_page.dart';
import 'sync_log_detail_page.dart';

class SyncStatusCard extends ConsumerWidget {
  const SyncStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncStatusAsync = ref.watch(syncStatusProvider);
    return SectionCard(
      title: '备份与多设备',
      subtitle: '给家长查看：本机学习数据是否已经备份。',
      child: syncStatusAsync.when(
        loading:
            () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(),
            ),
        error: (error, _) => Text('备份状态加载失败：${formatSyncError(error)}'),
        data: (snapshot) => _SyncStatusBody(snapshot: snapshot),
      ),
    );
  }
}

class _SyncStatusBody extends ConsumerWidget {
  const _SyncStatusBody({required this.snapshot});

  final SyncStatusSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final networkEnabled = ref.watch(cloudSyncApiProvider).config.enableNetwork;
    final settings = ref.watch(settingsProvider).asData?.value;
    final needsLogin =
        networkEnabled &&
        settings != null &&
        (settings.syncAccountId.trim().isEmpty ||
            settings.syncAuthToken.trim().isEmpty ||
            settings.syncRefreshToken.trim().isEmpty);
    final detail = needsLogin ? '请先登录备份账号，再进行数据备份。' : _syncDetailText(snapshot);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _SyncRow(
                label: '上次备份',
                value: _syncTimeLabel(snapshot.lastSuccessfulSyncAt),
              ),
            ),
            const SizedBox(width: 12),
            _SyncStateChip(snapshot: snapshot),
          ],
        ),
        _SyncRow(label: '待保护', value: '${snapshot.pendingTotal} 条'),
        _SyncRow(label: '最近结果', value: _syncStatusText(snapshot)),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          title: const Text('更多数据保护'),
          subtitle: const Text('记录和手动操作需要时再展开。'),
          children: [
            _PendingBreakdown(counts: snapshot.pendingCounts),
            if (detail != null) ...[
              const SizedBox(height: 8),
              Text(
                detail,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color:
                      snapshot.hasFailure || snapshot.hasConflicts
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (needsLogin) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SyncAccountPage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.cloud_sync_rounded),
                  label: const Text('登录备份账号'),
                ),
              ),
            ],
            _SyncLogPreview(logs: snapshot.logs),
            if (snapshot.logs.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushNamed('/sync-logs');
                  },
                  icon: const Icon(Icons.list_alt_rounded),
                  label: const Text('查看保护记录'),
                ),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed:
                      snapshot.isRunning
                          ? null
                          : () async {
                            final report = await ref
                                .read(syncStatusProvider.notifier)
                                .synchronize(trigger: SyncRunTrigger.manual);
                            if (!context.mounted) {
                              return;
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  report == null
                                      ? '备份失败，请查看状态提示。'
                                      : '备份完成：${_syncRunStateLabel(report.state)}',
                                ),
                              ),
                            );
                          },
                  icon:
                      snapshot.isRunning
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.sync_rounded),
                  label: Text(snapshot.isRunning ? '备份中' : '立即备份'),
                ),
                TextButton.icon(
                  onPressed:
                      snapshot.isRunning
                          ? null
                          : () =>
                              ref.read(syncStatusProvider.notifier).refresh(),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('刷新'),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _SyncLogPreview extends StatelessWidget {
  const _SyncLogPreview({required this.logs});

  final List<SyncRunLogEntry> logs;

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return const SizedBox.shrink();
    }
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      title: const Text('最近备份记录'),
      subtitle: const Text('家长排查问题时查看'),
      children: logs
          .take(5)
          .map((log) {
            return ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(
                '${_syncRunStateLabel(log.state)} · ${_syncTimeLabel(log.startedAt)}',
              ),
              subtitle: Text(
                log.errorMessage ??
                    '${syncRunTriggerLabel(log.trigger)} · 上传 ${log.pushedCount} 条，取回 ${log.pulledCount} 条，冲突 ${log.conflictCount} 个',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.of(
                  context,
                ).pushNamed('/sync-log-detail', arguments: log);
              },
            );
          })
          .toList(growable: false),
    );
  }
}

class _PendingBreakdown extends StatelessWidget {
  const _PendingBreakdown({required this.counts});

  final Map<SyncResourceType, int> counts;

  @override
  Widget build(BuildContext context) {
    final active = counts.entries.where((entry) => entry.value > 0).toList();
    if (active.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 8),
        child: Text(
          '没有待上传变更。',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      title: Text('待保护记录', style: Theme.of(context).textTheme.bodyMedium),
      subtitle: Text(_pendingCountsLabel(counts)),
      children: active
          .map(
            (entry) => _SyncRow(
              label: _syncResourceLabel(entry.key),
              value: '${entry.value} 条',
            ),
          )
          .toList(growable: false),
    );
  }
}

class _SyncStateChip extends StatelessWidget {
  const _SyncStateChip({required this.snapshot});

  final SyncStatusSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isWarning = snapshot.hasFailure || snapshot.hasConflicts;
    final color =
        snapshot.isRunning
            ? colorScheme.primary
            : isWarning
            ? colorScheme.error
            : colorScheme.tertiary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        snapshot.isRunning
            ? '备份中'
            : isWarning
            ? '需处理'
            : '正常',
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _SyncRow extends StatelessWidget {
  const _SyncRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

String formatSyncError(Object error) {
  final raw = error.toString();
  if (raw.contains('SocketException') ||
      raw.contains('HandshakeException') ||
      raw.contains('Failed host lookup')) {
    return '网络不可用，请稍后重试。';
  }
  if (raw.contains('Unauthorized') ||
      raw.contains('401') ||
      raw.contains('403')) {
    return '账号登录状态已失效，请重新登录后再备份。';
  }
  if (raw.contains('timeout') || raw.contains('TimeoutException')) {
    return '备份请求超时，请检查网络后重试。';
  }
  if (raw.contains('UnsupportedError')) {
    return '网络备份服务暂未开启。';
  }
  return '备份失败，请稍后重试。';
}

String _syncTimeLabel(DateTime? value) {
  if (value == null) {
    return '尚未备份';
  }
  final local = value.toLocal();
  final year = local.year.toString().padLeft(4, '0');
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$year-$month-$day $hour:$minute';
}

String _syncStatusText(SyncStatusSnapshot snapshot) {
  if (snapshot.isRunning) {
    return '正在备份';
  }
  if (snapshot.hasFailure) {
    return '备份失败';
  }
  if (snapshot.hasConflicts) {
    return '存在冲突';
  }
  final state = snapshot.lastRunState;
  if (state == null) {
    return '未运行';
  }
  return _syncRunStateLabel(state);
}

String? _syncDetailText(SyncStatusSnapshot snapshot) {
  if (snapshot.lastErrorMessage != null) {
    return formatSyncError(snapshot.lastErrorMessage!);
  }
  final report = snapshot.lastReport;
  if (report == null) {
    return null;
  }
  if (report.conflicts.isNotEmpty) {
    return '发现 ${report.conflicts.length} 个冲突，待上传数据已保留。';
  }
  final pushed = report.pushedCounts.values.fold<int>(
    0,
    (sum, value) => sum + value,
  );
  final pulled = report.pulledCounts.values.fold<int>(
    0,
    (sum, value) => sum + value,
  );
  return '本次推送 $pushed 条，拉取 $pulled 条。';
}

String _pendingCountsLabel(Map<SyncResourceType, int> counts) {
  final active = counts.entries.where((entry) => entry.value > 0).toList();
  if (active.isEmpty) {
    return '没有待上传变更。';
  }
  return active
      .map((entry) => '${_syncResourceLabel(entry.key)} ${entry.value}')
      .join('，');
}

String _syncRunStateLabel(SyncRunState state) {
  return switch (state) {
    SyncRunState.idle => '空闲',
    SyncRunState.placeholder => '未开始',
    SyncRunState.success => '成功',
    SyncRunState.partialSuccess => '部分成功',
    SyncRunState.conflict => '存在冲突',
    SyncRunState.failed => '失败',
  };
}

String _syncResourceLabel(SyncResourceType resource) {
  return switch (resource) {
    SyncResourceType.poems => '诗词',
    SyncResourceType.favorites => '收藏',
    SyncResourceType.learningRecords => '学习记录',
    SyncResourceType.studyCardProgress => '学习卡',
    SyncResourceType.reciteRecords => '背诵',
    SyncResourceType.wrongQuestions => '错题',
    SyncResourceType.practiceReports => '报告',
    SyncResourceType.dailyPoemRecords => '每日诗',
    SyncResourceType.userPoints => '积分',
    SyncResourceType.challengeStageRewards => '闯关奖励',
    SyncResourceType.settings => '设置',
    SyncResourceType.userProfiles => '资料',
  };
}
