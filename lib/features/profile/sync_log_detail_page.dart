import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_providers.dart';
import '../../core/app_environment.dart';
import '../../core/user_facing_error.dart';
import '../../domain/sync/sync_models.dart';
import '../shared/stage_scope_route_args.dart';
import 'profile_support.dart';

class SyncLogDetailPage extends ConsumerWidget {
  const SyncLogDetailPage({super.key, required this.log});

  final SyncRunLogEntry log;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final error = log.errorMessage?.trim();
    final requestIds = extractSyncRequestIds(log.notes);
    final stageIds = extractSyncStageIds(log);
    final shortcutStageId = stageIds.length == 1 ? stageIds.single : null;
    final reportIds = extractSyncReportIds(log);
    final wrongQuestionIds = extractSyncWrongQuestionIds(log);
    final learningRecordIds = extractSyncLearningRecordIds(log);
    return Scaffold(
      appBar: AppBar(title: const Text('备份记录详情')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Section(
            title: '执行结果',
            children: [
              _InfoRow(label: '状态', value: syncRunStateLabel(log.state)),
              _InfoRow(label: '触发方式', value: syncRunTriggerLabel(log.trigger)),
              _InfoRow(label: '开始时间', value: formatSyncLogTime(log.startedAt)),
              _InfoRow(label: '结束时间', value: formatSyncLogTime(log.finishedAt)),
              _InfoRow(label: '创建时间', value: formatSyncLogTime(log.createdAt)),
            ],
          ),
          const SizedBox(height: 12),
          _Section(
            title: '数据量',
            children: [
              _InfoRow(label: '推送', value: '${log.pushedCount} 条'),
              _InfoRow(label: '拉取', value: '${log.pulledCount} 条'),
              _InfoRow(label: '冲突', value: '${log.conflictCount} 个'),
            ],
          ),
          if (requestIds.isNotEmpty) ...[
            const SizedBox(height: 12),
            _Section(
              title: AppEnvironment.diagnosticsEnabled ? '技术记录' : '排查信息',
              children: [
                Text(
                  AppEnvironment.diagnosticsEnabled
                      ? '诊断模式：可用排查编号查看本次备份请求。'
                      : '联系客服时可提供以下排查编号。',
                ),
                const SizedBox(height: 12),
                for (final entry in requestIds.entries)
                  _RequestIdTile(
                    label: entry.key == 'push' ? '推送请求' : '拉取请求',
                    requestId: entry.value,
                    onView:
                        AppEnvironment.diagnosticsEnabled
                            ? () =>
                                _showServerRequestLog(context, ref, entry.value)
                            : null,
                  ),
              ],
            ),
          ],
          if (stageIds.isNotEmpty) ...[
            const SizedBox(height: 12),
            _Section(
              title: '相关关卡入口',
              children: [
                const Text('从备份记录中识别到关卡上下文，可直接跳到对应复盘页面。'),
                const SizedBox(height: 12),
                for (final stageId in stageIds)
                  _StageRouteTile(stageId: stageId),
              ],
            ),
          ],
          if (reportIds.isNotEmpty ||
              wrongQuestionIds.isNotEmpty ||
              learningRecordIds.isNotEmpty) ...[
            const SizedBox(height: 12),
            _Section(
              title: '相关详情入口',
              children: [
                const Text('从备份记录中识别到具体报告、错题或学习记录编号，可直接打开详情。'),
                const SizedBox(height: 12),
                for (final id in reportIds)
                  _RecordRouteTile(
                    routeName: '/practice-report-detail',
                    args: StageScopeRouteArgs(
                      stageId: shortcutStageId,
                      reportId: id,
                      source: 'sync-log',
                    ),
                    icon: Icons.article_outlined,
                    label: '报告 #$id',
                    description: '查看这份报告详情',
                  ),
                for (final id in wrongQuestionIds)
                  _RecordRouteTile(
                    routeName: '/wrong-question-detail',
                    args: StageScopeRouteArgs(
                      stageId: shortcutStageId,
                      wrongQuestionId: id,
                      source: 'sync-log',
                    ),
                    icon: Icons.quiz_outlined,
                    label: '错题 #$id',
                    description: '查看这道错题并继续复习',
                  ),
                for (final id in learningRecordIds)
                  _RecordRouteTile(
                    routeName: '/learning-record-detail',
                    args: StageScopeRouteArgs(
                      stageId: shortcutStageId,
                      learningRecordId: id,
                      source: 'sync-log',
                    ),
                    icon: Icons.history_edu_outlined,
                    label: '学习记录 #$id',
                    description: '查看这次练习对应哪一关',
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          _Section(
            title: '错误说明',
            children: [
              SelectableText(
                error == null || error.isEmpty
                    ? '无错误信息'
                    : friendlySyncLogError(error),
              ),
              if (AppEnvironment.diagnosticsEnabled &&
                  error != null &&
                  error.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  '原始错误',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                SelectableText(error),
              ],
            ],
          ),
          if (AppEnvironment.diagnosticsEnabled) ...[
            const SizedBox(height: 12),
            _Section(
              title: '备份详细信息',
              children:
                  log.notes.isEmpty
                      ? [const Text('无详细信息')]
                      : log.notes
                          .map(
                            (note) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: SelectableText(friendlySyncNote(note)),
                            ),
                          )
                          .toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showServerRequestLog(
    BuildContext context,
    WidgetRef ref,
    String requestId,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final future = ref
            .read(cloudSyncApiProvider)
            .fetchRequestLogs(requestId: requestId);
        return _ServerRequestLogSheet(requestId: requestId, future: future);
      },
    );
  }
}

class _StageRouteTile extends StatelessWidget {
  const _StageRouteTile({required this.stageId});

  final String stageId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            challengeStageLabel(stageId),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StageRouteButton(
                routeName: '/practice-reports',
                stageId: stageId,
                icon: Icons.assessment_outlined,
                label: '本关报告',
              ),
              _StageRouteButton(
                routeName: '/wrong-book',
                stageId: stageId,
                icon: Icons.rule_folder_outlined,
                label: '本关错题',
              ),
              _StageRouteButton(
                routeName: '/learning-history',
                stageId: stageId,
                icon: Icons.history_rounded,
                label: '本关历史',
              ),
              _StageRouteButton(
                routeName: '/growth-report',
                stageId: stageId,
                icon: Icons.insights_rounded,
                label: '本关成长',
              ),
              _StageRouteButton(
                routeName: '/challenge-map',
                stageId: stageId,
                icon: Icons.map_rounded,
                label: '回到地图',
                source: 'sync-log',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StageRouteButton extends StatelessWidget {
  const _StageRouteButton({
    required this.routeName,
    required this.stageId,
    required this.icon,
    required this.label,
    this.source,
  });

  final String routeName;
  final String stageId;
  final IconData icon;
  final String label;
  final String? source;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed:
          () => Navigator.of(context).pushNamed(
            routeName,
            arguments: StageScopeRouteArgs(stageId: stageId, source: source),
          ),
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

class _RecordRouteTile extends StatelessWidget {
  const _RecordRouteTile({
    required this.routeName,
    required this.args,
    required this.icon,
    required this.label,
    required this.description,
  });

  final String routeName;
  final StageScopeRouteArgs args;
  final IconData icon;
  final String label;
  final String description;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(description),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => Navigator.of(context).pushNamed(routeName, arguments: args),
    );
  }
}

class _RequestIdTile extends StatelessWidget {
  const _RequestIdTile({
    required this.label,
    required this.requestId,
    required this.onView,
  });

  final String label;
  final String requestId;
  final VoidCallback? onView;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: SelectableText(requestId),
      trailing: Wrap(
        spacing: 4,
        children: [
          IconButton(
            tooltip: '复制排查编号',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: requestId));
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('已复制排查编号')));
              }
            },
            icon: const Icon(Icons.copy_rounded),
          ),
          if (onView != null)
            IconButton(
              tooltip: '查看技术记录',
              onPressed: onView,
              icon: const Icon(Icons.manage_search_rounded),
            ),
        ],
      ),
    );
  }
}

class _ServerRequestLogSheet extends StatelessWidget {
  const _ServerRequestLogSheet({required this.requestId, required this.future});

  final String requestId;
  final Future<Map<String, dynamic>> future;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: FutureBuilder<Map<String, dynamic>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '技术记录加载失败：${friendlySyncLogError(snapshot.error.toString())}',
                ),
              );
            }
            final json = snapshot.data ?? const <String, dynamic>{};
            final items = (json['items'] as List? ?? const []);
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  '技术记录',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                SelectableText('排查编号：$requestId'),
                const SizedBox(height: 16),
                if (items.isEmpty)
                  const Text('没有查到技术记录。请确认备份服务正在运行、账号仍有效，并且该记录来自当前服务。')
                else
                  ...items.map((item) {
                    final entry = Map<String, dynamic>.from(item as Map);
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _serverRequestSummary(entry),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                Chip(
                                  label: Text(
                                    '状态码 ${entry['statusCode'] ?? '未知'}',
                                  ),
                                ),
                                Chip(
                                  label: Text(
                                    '耗时 ${entry['durationMs'] ?? 0} ms',
                                  ),
                                ),
                                Chip(
                                  label: Text(
                                    '错误码 ${entry['errorCode'] ?? '无'}',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: () async {
                                await Clipboard.setData(
                                  ClipboardData(
                                    text: _serverRequestDiagnostic(entry),
                                  ),
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('已复制排查信息')),
                                  );
                                }
                              },
                              icon: const Icon(Icons.copy_all_rounded),
                              label: const Text('复制排查信息'),
                            ),
                            SelectableText(
                              const JsonEncoder.withIndent('  ').convert(entry),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

String _serverRequestSummary(Map<String, dynamic> entry) {
  final method = entry['method'] ?? 'UNKNOWN';
  final path = entry['path'] ?? 'unknown';
  final statusCode = entry['statusCode'];
  final statusText =
      statusCode is int && statusCode >= 200 && statusCode < 300 ? '成功' : '异常';
  return '$statusText 路 $method $path';
}

String _serverRequestDiagnostic(Map<String, dynamic> entry) {
  final buffer =
      StringBuffer()
        ..writeln('备份请求排查信息')
        ..writeln('requestId: ${entry['requestId'] ?? 'unknown'}')
        ..writeln('method: ${entry['method'] ?? 'unknown'}')
        ..writeln('path: ${entry['path'] ?? 'unknown'}')
        ..writeln('statusCode: ${entry['statusCode'] ?? 'unknown'}')
        ..writeln('durationMs: ${entry['durationMs'] ?? 'unknown'}')
        ..writeln('errorCode: ${entry['errorCode'] ?? 'none'}')
        ..writeln('deviceId: ${entry['deviceId'] ?? 'unknown'}')
        ..writeln('createdAt: ${entry['createdAt'] ?? 'unknown'}')
        ..writeln()
        ..write(const JsonEncoder.withIndent('  ').convert(entry));
  return buffer.toString();
}

String friendlySyncLogError(String raw) {
  if (raw.contains('Connection closed before full header was received')) {
    return '备份服务连接中断。通常是本机备份服务被关闭、重启，或真机转发断开。请确认备份服务正在运行后重试。';
  }
  if (raw.contains('Connection refused')) {
    return '无法连接备份服务。请确认备份服务已启动，并检查真机转发或局域网地址。';
  }
  if (raw.contains('401') || raw.toLowerCase().contains('unauthorized')) {
    return '备份账号登录已失效，请重新登录。';
  }
  if (raw.contains('timeout') || raw.contains('timed out')) {
    return '备份请求超时，请检查网络或备份服务状态。';
  }
  return UserFacingErrorMapper.parentMessage(
    raw,
    fallbackMessage: '备份失败，请稍后重试。',
  );
}

String friendlySyncNote(String note) {
  if (note.startsWith('Push request id:')) {
    return '上传排查编号：${note.substring('Push request id:'.length).trim()}';
  }
  if (note.startsWith('Pull request id:')) {
    return '取回排查编号：${note.substring('Pull request id:'.length).trim()}';
  }
  return note;
}

String syncRunStateLabel(SyncRunState state) {
  return switch (state) {
    SyncRunState.success => '成功',
    SyncRunState.partialSuccess => '部分成功',
    SyncRunState.conflict => '存在冲突',
    SyncRunState.failed => '失败',
    SyncRunState.idle => '空闲',
    SyncRunState.placeholder => '未开始',
  };
}

String syncRunTriggerLabel(SyncRunTrigger trigger) {
  return switch (trigger) {
    SyncRunTrigger.manual => '手动备份',
    SyncRunTrigger.loginInitial => '登录后首次备份',
    SyncRunTrigger.foregroundAuto => '前台自动备份',
    SyncRunTrigger.startupAuto => '启动自动备份',
    SyncRunTrigger.unknown => '未知方式',
  };
}

String formatSyncLogTime(DateTime? value) {
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

Map<String, String> extractSyncRequestIds(List<String> notes) {
  final result = <String, String>{};
  for (final note in notes) {
    if (note.startsWith('Push request id:')) {
      final value = note.substring('Push request id:'.length).trim();
      if (value.isNotEmpty) {
        result['push'] = value;
      }
    }
    if (note.startsWith('Pull request id:')) {
      final value = note.substring('Pull request id:'.length).trim();
      if (value.isNotEmpty) {
        result['pull'] = value;
      }
    }
  }
  return result;
}

Set<String> extractSyncStageIds(SyncRunLogEntry log) {
  final values = <String>{};
  for (final source in _syncTextSources(log)) {
    for (final match in _stageIdPatterns.expand(
      (pattern) => pattern.allMatches(source),
    )) {
      final value = match.group(1)?.trim();
      if (value != null && value.isNotEmpty) {
        values.add(value);
      }
    }
  }
  return values;
}

Set<int> extractSyncReportIds(SyncRunLogEntry log) {
  return _extractSyncIntValues(log, _reportIdPatterns);
}

Set<int> extractSyncWrongQuestionIds(SyncRunLogEntry log) {
  return _extractSyncIntValues(log, _wrongQuestionIdPatterns);
}

Set<int> extractSyncLearningRecordIds(SyncRunLogEntry log) {
  return _extractSyncIntValues(log, _learningRecordIdPatterns);
}

Iterable<String> _syncTextSources(SyncRunLogEntry log) {
  return [...log.notes, if (log.errorMessage != null) log.errorMessage!];
}

Set<int> _extractSyncIntValues(SyncRunLogEntry log, List<RegExp> patterns) {
  final values = <int>{};
  for (final source in _syncTextSources(log)) {
    for (final match in patterns.expand(
      (pattern) => pattern.allMatches(source),
    )) {
      final value = int.tryParse(match.group(1)?.trim() ?? '');
      if (value != null && value > 0) {
        values.add(value);
      }
    }
  }
  return values;
}

final _stageIdPatterns = <RegExp>[
  RegExp(r'"stageId"\s*:\s*"([^"]+)"'),
  RegExp(r"'stageId'\s*:\s*'([^']+)'"),
  RegExp(r'\bstageId\s*[:=]\s*([A-Za-z0-9_:\-\u4e00-\u9fa5路\s]+)'),
  RegExp(r'\bstage_id\s*[:=]\s*([A-Za-z0-9_:\-\u4e00-\u9fa5路\s]+)'),
];

final _reportIdPatterns = <RegExp>[
  RegExp(r'"reportId"\s*:\s*(\d+)'),
  RegExp(r"'reportId'\s*:\s*(\d+)"),
  RegExp(r'\breportId\s*[:=]\s*(\d+)'),
  RegExp(r'\breport_id\s*[:=]\s*(\d+)'),
];

final _wrongQuestionIdPatterns = <RegExp>[
  RegExp(r'"wrongQuestionId"\s*:\s*(\d+)'),
  RegExp(r"'wrongQuestionId'\s*:\s*(\d+)"),
  RegExp(r'\bwrongQuestionId\s*[:=]\s*(\d+)'),
  RegExp(r'\bwrong_question_id\s*[:=]\s*(\d+)'),
];

final _learningRecordIdPatterns = <RegExp>[
  RegExp(r'"learningRecordId"\s*:\s*(\d+)'),
  RegExp(r"'learningRecordId'\s*:\s*(\d+)"),
  RegExp(r'\blearningRecordId\s*[:=]\s*(\d+)'),
  RegExp(r'\blearning_record_id\s*[:=]\s*(\d+)'),
];
