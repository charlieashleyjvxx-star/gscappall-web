import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_providers.dart';
import '../../core/user_facing_error.dart';
import '../../domain/sync/sync_models.dart';
import 'sync_log_detail_page.dart';

enum _SyncLogTimeRange { all, today, last7Days, last30Days }

class SyncLogListPage extends ConsumerStatefulWidget {
  const SyncLogListPage({super.key});

  @override
  ConsumerState<SyncLogListPage> createState() => _SyncLogListPageState();
}

class _SyncLogListPageState extends ConsumerState<SyncLogListPage> {
  static const int _pageSize = 20;

  int _page = 0;
  SyncRunState? _stateFilter;
  _SyncLogTimeRange _timeRange = _SyncLogTimeRange.all;

  @override
  Widget build(BuildContext context) {
    final range = _resolveTimeRange(_timeRange);
    final query = (
      limit: _pageSize,
      offset: _page * _pageSize,
      state: _stateFilter,
      startedAfter: range.startedAfter,
      startedBefore: range.startedBefore,
    );
    final logsAsync = ref.watch(syncRunLogPageProvider(query));
    return Scaffold(
      appBar: AppBar(
        title: const Text('备份记录'),
        actions: [
          PopupMenuButton<_LogAction>(
            tooltip: '记录清理',
            onSelected: (action) => _handleAction(context, action),
            itemBuilder:
                (context) => const [
                  PopupMenuItem(
                    value: _LogAction.clearFailed,
                    child: Text('清理失败日志'),
                  ),
                  PopupMenuItem(
                    value: _LogAction.keepLatest100,
                    child: Text('只保留最近 100 条'),
                  ),
                ],
          ),
        ],
      ),
      body: logsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, _) => Center(
              child: Text(
                UserFacingErrorMapper.parentMessage(
                  error,
                  fallbackMessage: '备份记录加载失败，请稍后重试。',
                ),
              ),
            ),
        data: (logs) {
          return Column(
            children: [
              _FilterBar(
                selectedState: _stateFilter,
                selectedRange: _timeRange,
                onStateChanged: (state) {
                  setState(() {
                    _page = 0;
                    _stateFilter = state;
                  });
                },
                onRangeChanged: (range) {
                  setState(() {
                    _page = 0;
                    _timeRange = range;
                  });
                },
              ),
              Expanded(child: _buildLogList(context, logs)),
              _Pager(
                page: _page,
                canGoNext: logs.length == _pageSize,
                onPrevious:
                    _page == 0 ? null : () => setState(() => _page -= 1),
                onNext:
                    logs.length < _pageSize
                        ? null
                        : () => setState(() => _page += 1),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLogList(BuildContext context, List<SyncRunLogEntry> logs) {
    if (logs.isEmpty && _page == 0) {
      return const Center(child: Text('当前筛选条件下暂无备份记录'));
    }
    if (logs.isEmpty) {
      return const Center(child: Text('本页没有更多日志'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: logs.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final log = logs[index];
        final error = log.errorMessage;
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: _StateDot(state: log.state),
          title: Text(
            '${syncRunStateLabel(log.state)} · ${_formatMinute(log.startedAt)}',
          ),
          subtitle: Text(
            error == null || error.isEmpty
                ? '${syncRunTriggerLabel(log.trigger)} · 上传 ${log.pushedCount} 条，取回 ${log.pulledCount} 条，冲突 ${log.conflictCount} 个'
                : '${syncRunTriggerLabel(log.trigger)} · ${friendlySyncLogError(error)}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () {
            Navigator.of(context).pushNamed('/sync-log-detail', arguments: log);
          },
        );
      },
    );
  }

  Future<void> _handleAction(BuildContext context, _LogAction action) async {
    switch (action) {
      case _LogAction.clearFailed:
        await ref.read(syncStatusProvider.notifier).clearFailedLogs();
        if (!context.mounted) return;
        setState(() => _page = 0);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已清理失败备份记录')));
      case _LogAction.keepLatest100:
        await ref.read(syncStatusProvider.notifier).pruneLogs();
        if (!context.mounted) return;
        setState(() => _page = 0);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已清理旧备份记录，只保留最近 100 条')));
    }
  }
}

enum _LogAction { clearFailed, keepLatest100 }

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.selectedState,
    required this.selectedRange,
    required this.onStateChanged,
    required this.onRangeChanged,
  });

  final SyncRunState? selectedState;
  final _SyncLogTimeRange selectedRange;
  final ValueChanged<SyncRunState?> onStateChanged;
  final ValueChanged<_SyncLogTimeRange> onRangeChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Row(
          children: [
            ChoiceChip(
              label: const Text('全部状态'),
              selected: selectedState == null,
              onSelected: (_) => onStateChanged(null),
            ),
            const SizedBox(width: 8),
            for (final state in const [
              SyncRunState.success,
              SyncRunState.partialSuccess,
              SyncRunState.conflict,
              SyncRunState.failed,
            ]) ...[
              ChoiceChip(
                label: Text(syncRunStateLabel(state)),
                selected: selectedState == state,
                onSelected: (_) => onStateChanged(state),
              ),
              const SizedBox(width: 8),
            ],
            const SizedBox(width: 8),
            SegmentedButton<_SyncLogTimeRange>(
              segments: const [
                ButtonSegment(value: _SyncLogTimeRange.all, label: Text('全部')),
                ButtonSegment(
                  value: _SyncLogTimeRange.today,
                  label: Text('今天'),
                ),
                ButtonSegment(
                  value: _SyncLogTimeRange.last7Days,
                  label: Text('7 天'),
                ),
                ButtonSegment(
                  value: _SyncLogTimeRange.last30Days,
                  label: Text('30 天'),
                ),
              ],
              selected: {selectedRange},
              onSelectionChanged: (values) => onRangeChanged(values.single),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pager extends StatelessWidget {
  const _Pager({
    required this.page,
    required this.canGoNext,
    required this.onPrevious,
    required this.onNext,
  });

  final int page;
  final bool canGoNext;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          children: [
            OutlinedButton.icon(
              onPressed: onPrevious,
              icon: const Icon(Icons.chevron_left_rounded),
              label: const Text('上一页'),
            ),
            Expanded(
              child: Text(
                '第 ${page + 1} 页',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            FilledButton.icon(
              onPressed: canGoNext ? onNext : null,
              icon: const Icon(Icons.chevron_right_rounded),
              label: const Text('下一页'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StateDot extends StatelessWidget {
  const _StateDot({required this.state});

  final SyncRunState state;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = switch (state) {
      SyncRunState.success => colorScheme.tertiary,
      SyncRunState.partialSuccess => colorScheme.primary,
      SyncRunState.conflict || SyncRunState.failed => colorScheme.error,
      _ => colorScheme.outline,
    };
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

({DateTime? startedAfter, DateTime? startedBefore}) _resolveTimeRange(
  _SyncLogTimeRange range,
) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return switch (range) {
    _SyncLogTimeRange.all => (startedAfter: null, startedBefore: null),
    _SyncLogTimeRange.today => (
      startedAfter: today,
      startedBefore: today.add(const Duration(days: 1)),
    ),
    _SyncLogTimeRange.last7Days => (
      startedAfter: today.subtract(const Duration(days: 6)),
      startedBefore: today.add(const Duration(days: 1)),
    ),
    _SyncLogTimeRange.last30Days => (
      startedAfter: today.subtract(const Duration(days: 29)),
      startedBefore: today.add(const Duration(days: 1)),
    ),
  };
}

String _formatMinute(DateTime? value) {
  if (value == null) {
    return '未记录';
  }
  final local = value.toLocal();
  final year = local.year.toString().padLeft(4, '0');
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$year-$month-$day $hour:$minute';
}
