import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_providers.dart';
import '../../core/user_facing_error.dart';
import '../../core/app_formatters.dart';
import '../../domain/learning_models.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/section_card.dart';
import '../shared/stage_scope_detail_panel.dart';
import '../shared/stage_scope_filter_banner.dart';
import '../shared/stage_scope_landing_panel.dart';
import '../shared/stage_scope_route_args.dart';
import 'profile_support.dart';

class LearningHistoryPage extends ConsumerStatefulWidget {
  const LearningHistoryPage({
    super.key,
    this.initialStageId,
    this.initialDateKey,
  });

  final String? initialStageId;
  final String? initialDateKey;

  @override
  ConsumerState<LearningHistoryPage> createState() =>
      _LearningHistoryPageState();
}

class _LearningHistoryPageState extends ConsumerState<LearningHistoryPage> {
  LearningHistoryFilter _filter = LearningHistoryFilter.all;
  String? _stageFilter;
  String? _routeStageId;
  String? _routeSource;
  String? _dateFilter;

  @override
  void initState() {
    super.initState();
    _stageFilter = widget.initialStageId;
    _dateFilter = widget.initialDateKey;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = StageScopeRouteArgs.maybeOf(context);
    _routeStageId ??= args?.stageId;
    _routeSource ??= args?.source;
    if (widget.initialDateKey == null) {
      _dateFilter ??= args?.dateKey;
    }
    if (widget.initialStageId == null &&
        _stageFilter == null &&
        _routeStageId != null) {
      _stageFilter = _routeStageId;
    }
  }

  @override
  Widget build(BuildContext context) {
    final recordsAsync = ref.watch(learningHistoryProvider(80));
    final stageFilter = _stageFilter;

    return Scaffold(
      appBar: AppBar(title: const Text('学习历史')),
      body: recordsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, _) => Center(
              child: Text(
                UserFacingErrorMapper.message(
                  error,
                  fallbackMessage: '学习历史加载失败，请稍后重试。',
                ),
              ),
            ),
        data: (records) {
          final stageIds = records
            .map((record) => record.stageId?.trim())
            .whereType<String>()
            .where((stageId) => stageId.isNotEmpty)
            .toSet()
            .toList(growable: false)..sort(
            (left, right) =>
                challengeStageLabel(left).compareTo(challengeStageLabel(right)),
          );
          final scope = LearningHistoryFilterScope(
            filter: _filter,
            stageId: _stageFilter,
            dateKey: _dateFilter,
          );
          final filtered = records.where(scope.matches).toList(growable: false);
          final totalMinutes = filtered.fold<int>(
            0,
            (sum, record) => sum + record.durationMinutes,
          );

          if (filtered.isEmpty) {
            return const EmptyState(
              title: '还没有学习记录',
              description: '先完成一次朗读、背诵、每日诗或学习卡，再回来查看成长轨迹。',
              icon: Icons.history_rounded,
            );
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _HistorySummaryCard(
                totalCount: filtered.length,
                totalMinutes: totalMinutes,
                filter: _filter,
              ),
              if (stageFilter != null) ...[
                const SizedBox(height: 14),
                StageScopeLandingPanel(
                  stageId: stageFilter,
                  filterKind: StageScopeFilterKind.learningHistory,
                  source: _routeSource,
                  onClearFilter: () => setState(() => _stageFilter = null),
                  fallbackChallengeMapSource: 'learning-record',
                  mapLabel: '回到该关卡章节',
                ),
              ],
              if (_dateFilter != null) ...[
                const SizedBox(height: 10),
                _HistoryDateFilterBanner(
                  dateKey: _dateFilter!,
                  onClear: () => setState(() => _dateFilter = null),
                ),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: LearningHistoryFilter.values
                    .map(
                      (filter) => ChoiceChip(
                        label: Text(filter.label),
                        selected: _filter == filter,
                        onSelected: (_) => setState(() => _filter = filter),
                      ),
                    )
                    .toList(growable: false),
              ),
              if (stageIds.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ChoiceChip(
                      label: const Text('全部关卡'),
                      selected: _stageFilter == null,
                      onSelected: (_) => setState(() => _stageFilter = null),
                    ),
                    for (final stageId in stageIds)
                      ChoiceChip(
                        label: Text(challengeStageLabel(stageId)),
                        selected: _stageFilter == stageId,
                        onSelected:
                            (_) => setState(() => _stageFilter = stageId),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              ...filtered.map((record) => _HistoryTile(record: record)),
            ],
          );
        },
      ),
    );
  }
}

class LearningHistoryFilterScope {
  const LearningHistoryFilterScope({
    this.filter = LearningHistoryFilter.all,
    this.stageId,
    this.dateKey,
  });

  final LearningHistoryFilter filter;
  final String? stageId;
  final String? dateKey;

  bool matches(LearningRecord record) {
    if (!_matchesMode(record)) {
      return false;
    }
    if (stageId != null && record.stageId != stageId) {
      return false;
    }
    if (dateKey == null) {
      return true;
    }
    return AppFormatters.dateKey(record.studiedAt) == dateKey ||
        record.studiedAt.toIso8601String().startsWith(dateKey!);
  }

  bool _matchesMode(LearningRecord record) {
    switch (filter) {
      case LearningHistoryFilter.all:
        return true;
      case LearningHistoryFilter.reading:
        return record.mode == 'read' || record.mode == 'reading';
      case LearningHistoryFilter.recite:
        return record.mode == 'recite' || record.mode == 'recite_practice';
      case LearningHistoryFilter.daily:
        return record.mode == 'daily_poem' ||
            record.mode == 'daily_poem_review';
      case LearningHistoryFilter.cards:
        return record.mode == 'study_card';
    }
  }
}

class _HistoryDateFilterBanner extends StatelessWidget {
  const _HistoryDateFilterBanner({
    required this.dateKey,
    required this.onClear,
  });

  final String dateKey;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: colorScheme.primaryContainer.withValues(alpha: 0.72),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.insights_rounded,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '来自成长报告变化点',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '当前只看 $dateKey 练过这一关的学习记录，方便对照当天变化。',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: onClear,
              icon: const Icon(Icons.filter_alt_off_rounded),
              label: const Text('清除日期筛选，查看完整历史'),
            ),
          ],
        ),
      ),
    );
  }
}

class LearningRecordDetailPage extends ConsumerWidget {
  const LearningRecordDetailPage({super.key, required this.recordId});

  final int recordId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordsAsync = ref.watch(learningHistoryProvider(300));
    final routeArgs = StageScopeRouteArgs.maybeOf(context);
    final source = routeArgs?.source;
    final routeStageId = routeArgs?.stageId?.trim();

    return Scaffold(
      appBar: AppBar(title: const Text('学习记录详情')),
      body: recordsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, _) => Center(
              child: Text(
                UserFacingErrorMapper.message(
                  error,
                  fallbackMessage: '学习记录加载失败，请稍后重试。',
                ),
              ),
            ),
        data: (records) {
          final record = records.cast<LearningRecord?>().firstWhere(
            (record) => record?.id == recordId,
            orElse: () => null,
          );
          if (record == null) {
            return const EmptyState(
              title: '没有找到这条学习记录',
              description: '它可能已经被清理，或当前资料无权查看。',
              icon: Icons.search_off_rounded,
            );
          }
          final stageId = record.stageId;
          final recordStageId = stageId?.trim();
          final displayStageId =
              recordStageId != null && recordStageId.isNotEmpty
                  ? recordStageId
                  : routeStageId;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (source != null) ...[
                StageScopeDetailSourcePanel(
                  source: source,
                  stageId: displayStageId,
                  focusLabel: '学习记录',
                ),
                const SizedBox(height: 12),
              ],
              SectionCard(
                title:
                    record.poemTitle.isEmpty
                        ? learningModeLabel(record.mode)
                        : record.poemTitle,
                subtitle: record.poemAuthor,
                trailing:
                    record.score == null
                        ? null
                        : Chip(label: Text('${record.score} 分')),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DetailRow(
                      label: '练习模式',
                      value: learningModeLabel(record.mode),
                    ),
                    _DetailRow(
                      label: '学习时间',
                      value: AppFormatters.shortDate(
                        record.studiedAt.toLocal(),
                      ),
                    ),
                    _DetailRow(
                      label: '练习时长',
                      value: '${record.durationMinutes} 分钟',
                    ),
                    if (challengeStagePrefix(stageId).isNotEmpty)
                      _DetailRow(
                        label: '闯关关卡',
                        value: challengeStageLabel(stageId!),
                      ),
                    if ((record.note ?? '').trim().isNotEmpty)
                      _DetailRow(label: '备注', value: record.note!.trim()),
                  ],
                ),
              ),
              if (stageId != null && stageId.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                SectionCard(
                  title: '关卡进步',
                  subtitle: '这条学习记录已经计入对应关卡进度。',
                  child: StageScopeDetailEvidencePanel(
                    title: '本关学习记录',
                    description:
                        '${_recordStageContribution(record).replaceFirst('关卡：${challengeStageLabel(stageId)}；', '')}。这条记录会用于判断本关分数、句数或错题复习是否有变化。',
                    stageId: stageId,
                    source: source,
                    fallbackChallengeMapSource: 'learning-record',
                    mapLabel: '回到该关卡章节',
                    actions: [
                      StageScopeEvidenceAction(
                        label: '查看本关报告',
                        icon: Icons.assessment_outlined,
                        onPressed: () {
                          Navigator.of(context).pushNamed(
                            '/practice-reports',
                            arguments: StageScopeRouteArgs(
                              stageId: stageId,
                              source: 'learning-record',
                            ),
                          );
                        },
                      ),
                      StageScopeEvidenceAction(
                        label: '查看本关错题',
                        icon: Icons.rule_folder_outlined,
                        onPressed: () {
                          Navigator.of(context).pushNamed(
                            '/wrong-book',
                            arguments: StageScopeRouteArgs(
                              stageId: stageId,
                              source: 'learning-record',
                            ),
                          );
                        },
                      ),
                      StageScopeEvidenceAction(
                        label: '查看学习历史',
                        icon: Icons.history_edu_outlined,
                        onPressed: () {
                          Navigator.of(context).pushNamed(
                            '/learning-history',
                            arguments: StageScopeRouteArgs(
                              stageId: stageId,
                              source: 'learning-record',
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

String _recordStageContribution(LearningRecord record) {
  final stageId = record.stageId;
  if (stageId == null || stageId.trim().isEmpty) {
    return '这条记录暂未绑定闯关关卡。';
  }
  final parts = <String>[
    '关卡：${challengeStageLabel(stageId)}',
    '练习方式：${learningModeLabel(record.mode)}',
    _recordModeContribution(record),
  ];
  if (record.score != null) {
    parts.add('练习分数：${record.score} 分');
  }
  if (record.durationMinutes > 0) {
    parts.add('练习时长：${record.durationMinutes} 分钟');
  }
  return '${parts.join('；')}。';
}

String _recordModeContribution(LearningRecord record) {
  final estimatedLines = (record.durationMinutes ~/ 2).clamp(1, 999);
  return switch (record.mode) {
    'poetry_jielong' => '完成句数：约 $estimatedLines 句接龙',
    'feihualing' => '完成句数：约 $estimatedLines 句飞花令',
    'dictation' => '错题复习：听写结果会进入报告和错题复盘',
    _ => '练习进度：完成一次闯关练习',
  };
}

enum LearningHistoryFilter {
  all('全部'),
  reading('朗读'),
  recite('背诵'),
  daily('每日诗'),
  cards('学习卡');

  const LearningHistoryFilter(this.label);

  final String label;
}

class _HistorySummaryCard extends StatelessWidget {
  const _HistorySummaryCard({
    required this.totalCount,
    required this.totalMinutes,
    required this.filter,
  });

  final int totalCount;
  final int totalMinutes;
  final LearningHistoryFilter filter;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: _HistoryMetric(
              label:
                  filter == LearningHistoryFilter.all
                      ? '总记录数'
                      : '${filter.label}记录',
              value: '$totalCount',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _HistoryMetric(label: '累计时长', value: '$totalMinutes 分钟'),
          ),
        ],
      ),
    );
  }
}

class _HistoryMetric extends StatelessWidget {
  const _HistoryMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F3E6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
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

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.record});

  final LearningRecord record;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFF6E4BE),
          child: Icon(
            _iconForMode(record.mode),
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(
          record.poemTitle.isEmpty
              ? learningModeLabel(record.mode)
              : record.poemTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(learningModeLabel(record.mode)),
            if (challengeStagePrefix(record.stageId).isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(challengeStagePrefix(record.stageId)),
            ],
            const SizedBox(height: 2),
            Text(recentRecordSubtitle(record)),
            if ((record.note ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(record.note!, maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ],
        ),
        trailing:
            record.score == null
                ? null
                : Text(
                  '${record.score} 分',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
        onTap:
            () => Navigator.of(context).pushNamed(
              '/learning-record-detail',
              arguments: StageScopeRouteArgs(
                learningRecordId: record.id,
                stageId: record.stageId,
              ),
            ),
      ),
    );
  }

  IconData _iconForMode(String mode) {
    switch (mode) {
      case 'daily_poem':
      case 'daily_poem_review':
        return Icons.wb_sunny_outlined;
      case 'study_card':
        return Icons.style_outlined;
      case 'read':
      case 'reading':
        return Icons.record_voice_over_rounded;
      case 'recite':
      case 'recite_practice':
        return Icons.psychology_alt_rounded;
      default:
        return Icons.auto_stories_outlined;
    }
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

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
            width: 82,
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
