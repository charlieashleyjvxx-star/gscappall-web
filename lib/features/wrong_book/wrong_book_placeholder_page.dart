import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_providers.dart';
import '../../core/user_facing_error.dart';
import '../../domain/practice_models.dart';
import '../../domain/repositories/practice_repository.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/section_card.dart';
import '../profile/profile_support.dart';
import '../dictation/dictation_page.dart';
import '../evaluation/evaluation_placeholder_page.dart';
import '../shared/stage_scope_filter_banner.dart';
import '../shared/stage_scope_landing_panel.dart';
import '../shared/stage_scope_route_args.dart';
import 'wrong_question_detail_page.dart';
import 'wrong_question_retry_page.dart';

class WrongBookPlaceholderPage extends ConsumerStatefulWidget {
  const WrongBookPlaceholderPage({super.key, this.initialStageId});

  final String? initialStageId;

  @override
  ConsumerState<WrongBookPlaceholderPage> createState() =>
      _WrongBookPlaceholderPageState();
}

class _WrongBookPlaceholderPageState
    extends ConsumerState<WrongBookPlaceholderPage> {
  late final PracticeRepository _repository;
  String? _routeStageId;
  String? _routeSource;
  bool _onlyUnreviewed = true;
  PracticeMode? _selectedMode;
  PracticeMistakeType? _selectedType;
  String? _selectedSeverity;
  String? _selectedKnowledgePoint;
  String? _selectedStageId;
  _WrongBookGroupBy _groupBy = _WrongBookGroupBy.mode;
  bool _appliedGrowthReportDefaults = false;

  @override
  void initState() {
    super.initState();
    _selectedStageId = widget.initialStageId;
    _repository = ref.read(practiceRepositoryProvider);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = StageScopeRouteArgs.maybeOf(context);
    _routeStageId ??= args?.stageId;
    _routeSource ??= args?.source;
    if (widget.initialStageId == null &&
        _selectedStageId == null &&
        _routeStageId != null) {
      _selectedStageId = _routeStageId;
    }
    if (!_appliedGrowthReportDefaults &&
        _routeSource == 'growth-report' &&
        _selectedStageId != null) {
      _appliedGrowthReportDefaults = true;
      _onlyUnreviewed = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(wrongQuestionEntriesProvider(_query));

    return Scaffold(
      appBar: AppBar(
        title: const Text('错题本'),
        actions: [
          IconButton(
            onPressed: _refreshWrongQuestions,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, _) => EmptyState(
              title: '错题加载失败',
              description: UserFacingErrorMapper.message(
                error,
                fallbackMessage: '错题加载失败，请稍后重试。',
              ),
              icon: Icons.error_outline_rounded,
            ),
        data: (entries) {
          final visibleEntries = _filteredEntries(entries);
          final groups = _buildGroups(visibleEntries);
          final compactLayout = MediaQuery.sizeOf(context).width < 390;
          final pagePadding = compactLayout ? 16.0 : 20.0;
          final sectionGap = compactLayout ? 12.0 : 16.0;
          return SafeArea(
            child: RefreshIndicator(
              onRefresh: _refreshWrongQuestions,
              child: ListView(
                padding: EdgeInsets.all(pagePadding),
                children: [
                  if (visibleEntries.isNotEmpty) _buildSummary(visibleEntries),
                  if (_selectedStageId != null) ...[
                    const SizedBox(height: 12),
                    StageScopeLandingPanel(
                      stageId: _selectedStageId!,
                      filterKind: StageScopeFilterKind.wrongQuestions,
                      source: _routeSource,
                      onlyUnreviewed: _onlyUnreviewed,
                      onClearFilter: _clearFilters,
                      fallbackChallengeMapSource: 'wrong-question',
                      mapLabel: '回到该关卡章节',
                    ),
                  ],
                  SizedBox(height: sectionGap),
                  if (visibleEntries.isEmpty)
                    _buildEmptyWrongBook()
                  else ...[
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text('按条件查看'),
                      subtitle: const Text('需要精确查找时再展开。'),
                      children: [
                        _buildFilters(entries),
                        const SizedBox(height: 12),
                        _buildGroupingSwitch(),
                        const SizedBox(height: 12),
                        _buildStats(visibleEntries),
                      ],
                    ),
                    SizedBox(height: sectionGap),
                    for (final group in groups) ...[
                      _WrongQuestionGroupCard(
                        group: group,
                        onRetryGroup: () => _retryEntry(group.entries.first),
                        onOpenEntry: _openDetail,
                      ),
                      SizedBox(height: sectionGap),
                    ],
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyWrongBook() {
    return EmptyState(
      title: '现在没有要复习的错题',
      description: '可以先去练一轮，做错的句子会自动来到这里。',
      icon: Icons.task_alt_outlined,
      action: Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.center,
        children: [
          FilledButton.icon(
            onPressed:
                () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DictationPage()),
                ),
            icon: const Icon(Icons.edit_note_rounded),
            label: const Text('去练听写'),
          ),
          FilledButton.tonalIcon(
            onPressed:
                () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder:
                        (_) => const EvaluationPlaceholderPage(
                          initialMode: PracticeMode.evaluation,
                          pageTitle: '小测验',
                        ),
                  ),
                ),
            icon: const Icon(Icons.fact_check_rounded),
            label: const Text('去小测验'),
          ),
        ],
      ),
    );
  }

  WrongQuestionQuery get _query {
    return WrongQuestionQuery(
      practiceMode: _selectedMode,
      mistakeType: _selectedType,
      severity: _selectedSeverity,
      stageId: _selectedStageId,
      onlyUnreviewed: _onlyUnreviewed,
      limit: 500,
    );
  }

  List<WrongQuestionEntry> _filteredEntries(List<WrongQuestionEntry> entries) {
    return entries
        .where((entry) {
          return _selectedKnowledgePoint == null ||
              entry.knowledgePoint == _selectedKnowledgePoint;
        })
        .toList(growable: false);
  }

  Widget _buildSummary(List<WrongQuestionEntry> visibleEntries) {
    final pendingCount =
        visibleEntries.where((entry) => !entry.isReviewed).length;
    final highCount =
        visibleEntries.where((entry) => entry.severity == 'high').length;

    return SectionCard(
      title: '先复习还没掌握的',
      subtitle: '默认只看待复习错题。做对后标记已复习，列表会慢慢变少。',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Chip(
                avatar: const Icon(Icons.pending_actions_rounded, size: 18),
                label: Text(_onlyUnreviewed ? '待复习' : '全部错题'),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed:
                    () => setState(() => _onlyUnreviewed = !_onlyUnreviewed),
                icon: Icon(
                  _onlyUnreviewed
                      ? Icons.list_alt_rounded
                      : Icons.pending_actions_rounded,
                ),
                label: Text(_onlyUnreviewed ? '全部错题' : '回到待复习'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SummaryBox(
                  title: _onlyUnreviewed ? '待复习' : '当前列表',
                  value: '${visibleEntries.length}',
                  color: const Color(0xFFF6E0B8),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryBox(
                  title: '重点错题',
                  value: '$highCount',
                  color: const Color(0xFFFBE8E0),
                ),
              ),
            ],
          ),
          if (!_onlyUnreviewed && pendingCount > 0) ...[
            const SizedBox(height: 10),
            Text('其中 $pendingCount 道还没复习，建议先处理这些。'),
          ],
        ],
      ),
    );
  }

  Widget _buildFilters(List<WrongQuestionEntry> entries) {
    final knowledgePoints = entries
      .map((entry) => entry.knowledgePoint)
      .toSet()
      .toList(growable: false)..sort();
    final stageIds = entries
      .map((entry) => entry.stageId?.trim())
      .whereType<String>()
      .where((stageId) => stageId.isNotEmpty)
      .toSet()
      .toList(growable: false)..sort(
      (left, right) =>
          challengeStageLabel(left).compareTo(challengeStageLabel(right)),
    );

    return SectionCard(
      title: '更多筛选',
      subtitle: '默认先看待复习，需要缩小范围时再展开。',
      trailing: TextButton(onPressed: _clearFilters, child: const Text('清空')),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        title: const Text('按练习、错题类型或关卡筛选'),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FilterWrap(
                children: [
                  ChoiceChip(
                    label: const Text('全部模式'),
                    selected: _selectedMode == null,
                    onSelected: (_) => setState(() => _selectedMode = null),
                  ),
                  for (final mode in PracticeMode.values)
                    ChoiceChip(
                      label: Text(mode.label),
                      selected: _selectedMode == mode,
                      onSelected: (_) => setState(() => _selectedMode = mode),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              _FilterWrap(
                children: [
                  ChoiceChip(
                    label: const Text('全部错因'),
                    selected: _selectedType == null,
                    onSelected: (_) => setState(() => _selectedType = null),
                  ),
                  for (final type in PracticeMistakeType.values)
                    ChoiceChip(
                      label: Text(type.label),
                      selected: _selectedType == type,
                      onSelected: (_) => setState(() => _selectedType = type),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              _FilterWrap(
                children: [
                  ChoiceChip(
                    label: const Text('全部严重程度'),
                    selected: _selectedSeverity == null,
                    onSelected: (_) => setState(() => _selectedSeverity = null),
                  ),
                  for (final severity in const ['high', 'medium', 'low'])
                    ChoiceChip(
                      label: Text(_severityLabel(severity)),
                      selected: _selectedSeverity == severity,
                      onSelected:
                          (_) => setState(() => _selectedSeverity = severity),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String?>(
                initialValue: _selectedKnowledgePoint,
                decoration: const InputDecoration(labelText: '知识点'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('全部知识点'),
                  ),
                  for (final point in knowledgePoints)
                    DropdownMenuItem<String?>(value: point, child: Text(point)),
                ],
                onChanged:
                    (value) => setState(() => _selectedKnowledgePoint = value),
              ),
              if (stageIds.isNotEmpty) ...[
                const SizedBox(height: 10),
                _FilterWrap(
                  children: [
                    ChoiceChip(
                      label: const Text('全部关卡'),
                      selected: _selectedStageId == null,
                      onSelected:
                          (_) => setState(() => _selectedStageId = null),
                    ),
                    for (final stageId in stageIds)
                      ChoiceChip(
                        label: Text(challengeStageLabel(stageId)),
                        selected: _selectedStageId == stageId,
                        onSelected:
                            (_) => setState(() => _selectedStageId = stageId),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGroupingSwitch() {
    return SectionCard(
      title: '分组方式',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final groupBy in _WrongBookGroupBy.values)
            ChoiceChip(
              label: Text(groupBy.label),
              selected: _groupBy == groupBy,
              onSelected: (_) => setState(() => _groupBy = groupBy),
            ),
        ],
      ),
    );
  }

  Widget _buildStats(List<WrongQuestionEntry> entries) {
    return SectionCard(
      title: '筛选统计',
      subtitle: '帮助优先处理最集中的薄弱点。',
      child:
          entries.isEmpty
              ? const Text('当前条件下暂无统计。')
              : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StatsGroup(
                    title: '练习模式',
                    items: _countBy(
                      entries,
                      (entry) => entry.questionType.label,
                    ),
                    total: entries.length,
                  ),
                  const SizedBox(height: 14),
                  _StatsGroup(
                    title: '错题类型',
                    items: _countBy(
                      entries,
                      (entry) => entry.mistakeType.label,
                    ),
                    total: entries.length,
                  ),
                  const SizedBox(height: 14),
                  _StatsGroup(
                    title: '严重程度',
                    items: _countBy(
                      entries,
                      (entry) => _severityLabel(entry.severity),
                    ),
                    total: entries.length,
                  ),
                  const SizedBox(height: 14),
                  _StatsGroup(
                    title: '复习状态',
                    items: _countBy(
                      entries,
                      (entry) => entry.isReviewed ? '已复习' : '待复习',
                    ),
                    total: entries.length,
                  ),
                  const SizedBox(height: 14),
                  _StatsGroup(
                    title: '闯关关卡',
                    items: _countBy(entries, _wrongQuestionStageLabel),
                    total: entries.length,
                  ),
                ],
              ),
    );
  }

  List<_WrongQuestionGroup> _buildGroups(List<WrongQuestionEntry> entries) {
    final buckets = <String, List<WrongQuestionEntry>>{};
    for (final entry in entries) {
      final key = switch (_groupBy) {
        _WrongBookGroupBy.mode => entry.questionType.label,
        _WrongBookGroupBy.type => entry.mistakeType.label,
        _WrongBookGroupBy.severity => _severityLabel(entry.severity),
        _WrongBookGroupBy.stage => _wrongQuestionStageLabel(entry),
        _WrongBookGroupBy.knowledge => entry.knowledgePoint,
        _WrongBookGroupBy.review => entry.isReviewed ? '已复习' : '待复习',
      };
      buckets.putIfAbsent(key, () => <WrongQuestionEntry>[]).add(entry);
    }
    final groups = buckets.entries
        .map(
          (entry) =>
              _WrongQuestionGroup(title: entry.key, entries: entry.value),
        )
        .toList(growable: false);
    groups.sort(
      (left, right) => right.entries.length.compareTo(left.entries.length),
    );
    return groups;
  }

  List<_StatsItem> _countBy(
    List<WrongQuestionEntry> entries,
    String Function(WrongQuestionEntry entry) labelOf,
  ) {
    final counts = <String, int>{};
    for (final entry in entries) {
      final label = labelOf(entry);
      counts[label] = (counts[label] ?? 0) + 1;
    }
    final items = counts.entries
        .map((entry) => _StatsItem(label: entry.key, count: entry.value))
        .toList(growable: false);
    items.sort((left, right) => right.count.compareTo(left.count));
    return items;
  }

  Future<void> _refreshWrongQuestions() async {
    ref.invalidate(wrongQuestionEntriesProvider(_query));
    await ref.read(wrongQuestionEntriesProvider(_query).future);
  }

  void _clearFilters() {
    setState(() {
      _selectedMode = null;
      _selectedType = null;
      _selectedSeverity = null;
      _selectedKnowledgePoint = null;
      _selectedStageId = null;
      _onlyUnreviewed = true;
    });
  }

  Future<void> _retryEntry(WrongQuestionEntry entry) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => WrongQuestionRetryPage(entry: entry)),
    );
    if (mounted) {
      await _refreshWrongQuestions();
    }
  }

  Future<void> _openDetail(WrongQuestionEntry entry) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => CleanWrongQuestionDetailPage(
              repository: _repository,
              wrongQuestionId: entry.id,
            ),
      ),
    );
    if (mounted) {
      await _refreshWrongQuestions();
    }
  }
}

enum _WrongBookGroupBy {
  mode('练习模式'),
  type('错题类型'),
  severity('严重程度'),
  stage('闯关关卡'),
  knowledge('知识点'),
  review('复习状态');

  const _WrongBookGroupBy(this.label);

  final String label;
}

class _WrongQuestionGroup {
  const _WrongQuestionGroup({required this.title, required this.entries});

  final String title;
  final List<WrongQuestionEntry> entries;
}

class _WrongQuestionGroupCard extends StatelessWidget {
  const _WrongQuestionGroupCard({
    required this.group,
    required this.onRetryGroup,
    required this.onOpenEntry,
  });

  final _WrongQuestionGroup group;
  final VoidCallback onRetryGroup;
  final ValueChanged<WrongQuestionEntry> onOpenEntry;

  @override
  Widget build(BuildContext context) {
    final pendingCount =
        group.entries.where((entry) => !entry.isReviewed).length;
    return SectionCard(
      title: group.title,
      subtitle: '${group.entries.length} 题 · $pendingCount 题待复习',
      trailing: FilledButton.tonalIcon(
        onPressed: onRetryGroup,
        icon: const Icon(Icons.replay_rounded),
        label: const Text('重练本组'),
      ),
      child: Column(
        children: [
          for (final entry in group.entries.take(5))
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(entry.poemTitle),
              subtitle: Text(
                '${entry.poemAuthor} · ${entry.questionType.label} · ${entry.mistakeType.label} · ${_severityLabel(entry.severity)}',
              ),
              trailing: Chip(label: Text(entry.isReviewed ? '已复习' : '待复习')),
              onTap: () => onOpenEntry(entry),
            ),
          if (group.entries.length > 5)
            Align(
              alignment: Alignment.centerLeft,
              child: Text('还有 ${group.entries.length - 5} 题，可以继续通过筛选缩小范围。'),
            ),
        ],
      ),
    );
  }
}

class _FilterWrap extends StatelessWidget {
  const _FilterWrap({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 8, runSpacing: 8, children: children);
  }
}

class _StatsGroup extends StatelessWidget {
  const _StatsGroup({
    required this.title,
    required this.items,
    required this.total,
  });

  final String title;
  final List<_StatsItem> items;
  final int total;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        for (final item in items) ...[
          _StatsBar(item: item, total: total),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _StatsItem {
  const _StatsItem({required this.label, required this.count});

  final String label;
  final int count;
}

class _StatsBar extends StatelessWidget {
  const _StatsBar({required this.item, required this.total});

  final _StatsItem item;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : item.count / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(item.label)),
            Text('${item.count} 题'),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 8,
            value: ratio,
            backgroundColor: const Color(0xFFF1E7D8),
            color: const Color(0xFFC8773A),
          ),
        ),
      ],
    );
  }
}

class _SummaryBox extends StatelessWidget {
  const _SummaryBox({
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

String _severityLabel(String severity) {
  switch (severity) {
    case 'low':
      return '轻微';
    case 'high':
      return '重点';
    case 'medium':
    default:
      return '普通';
  }
}

String _wrongQuestionStageLabel(WrongQuestionEntry entry) {
  final label = challengeStageLabel(entry.stageId);
  return label.isEmpty ? '未关联关卡' : label;
}
