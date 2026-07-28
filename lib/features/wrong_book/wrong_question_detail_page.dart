import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_providers.dart';
import '../../domain/practice_models.dart';
import '../../domain/repositories/practice_repository.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/section_card.dart';
import '../profile/profile_support.dart';
import '../shared/stage_contribution_view.dart';
import '../shared/stage_scope_detail_panel.dart';
import '../shared/stage_scope_route_args.dart';
import 'wrong_question_retry_page.dart';

class CleanWrongQuestionDetailPage extends ConsumerStatefulWidget {
  const CleanWrongQuestionDetailPage({
    super.key,
    required this.wrongQuestionId,
    this.repository,
  });

  final int wrongQuestionId;
  final PracticeRepository? repository;

  @override
  ConsumerState<CleanWrongQuestionDetailPage> createState() =>
      _CleanWrongQuestionDetailPageState();
}

class _CleanWrongQuestionDetailPageState
    extends ConsumerState<CleanWrongQuestionDetailPage> {
  WrongQuestionEntry? _entry;
  bool _isLoading = true;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  @override
  Widget build(BuildContext context) {
    final entry = _entry;
    final routeArgs = StageScopeRouteArgs.maybeOf(context);
    final source = routeArgs?.source;
    final routeStageId = routeArgs?.stageId?.trim();
    final entryStageId = entry?.stageId?.trim();
    final stageId =
        entryStageId != null && entryStageId.isNotEmpty
            ? entryStageId
            : routeStageId;

    return Scaffold(
      appBar: AppBar(title: const Text('错题详情')),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : entry == null
              ? const EmptyState(
                title: '没有找到这道错题',
                description: '它可能已经被清理，请返回上一页刷新。',
                icon: Icons.search_off_rounded,
              )
              : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (source != null) ...[
                    StageScopeDetailSourcePanel(
                      source: source,
                      stageId: stageId,
                      focusLabel: '错题详情',
                    ),
                    const SizedBox(height: 12),
                  ],
                  SectionCard(
                    title: entry.poemTitle,
                    subtitle:
                        '${entry.poemAuthor} · ${entry.questionType.label} · ${entry.knowledgePoint}',
                    trailing: Chip(label: Text(entry.mistakeType.label)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DetailRow(label: '题目', value: entry.prompt),
                        _DetailRow(
                          label: '你的答案',
                          value:
                              entry.userAnswer.isEmpty
                                  ? '未作答'
                                  : entry.userAnswer,
                        ),
                        _DetailRow(label: '标准答案', value: entry.correctAnswer),
                        _DetailRow(
                          label: '严重程度',
                          value: _severityLabel(entry.severity),
                        ),
                        if ((entry.stageId ?? '').trim().isNotEmpty)
                          _DetailRow(
                            label: '闯关关卡',
                            value: challengeStageLabel(entry.stageId!),
                          ),
                        _DetailRow(
                          label: '复习状态',
                          value: entry.isReviewed ? '已复习' : '待复习',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  if ((entry.stageId ?? '').trim().isNotEmpty) ...[
                    _WrongContributionCard(entry: entry),
                    const SizedBox(height: 18),
                  ],
                  if ((entry.stageId ?? '').trim().isNotEmpty) ...[
                    SectionCard(
                      title: '本关复盘',
                      subtitle: '这道错题会帮助找到不熟的关卡，可继续看报告或回到地图练。',
                      child: StageScopeDetailEvidencePanel(
                        title: '本关错题记录',
                        description: '这道错题会放进成长报告，也会帮助找到本关还不熟的地方。',
                        stageId: entry.stageId!,
                        source: source,
                        fallbackChallengeMapSource: 'wrong-question',
                        actions: [
                          StageScopeEvidenceAction(
                            label: '查看本关报告',
                            icon: Icons.assessment_outlined,
                            onPressed: () {
                              Navigator.of(context).pushNamed(
                                '/practice-reports',
                                arguments: StageScopeRouteArgs(
                                  stageId: entry.stageId!,
                                  source: 'wrong-question',
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
                                  stageId: entry.stageId!,
                                  source: 'wrong-question',
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed:
                              _isUpdating
                                  ? null
                                  : () async {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder:
                                            (_) => WrongQuestionRetryPage(
                                              entry: entry,
                                            ),
                                      ),
                                    );
                                    if (mounted) {
                                      await _loadDetail();
                                    }
                                  },
                          icon: const Icon(Icons.replay_rounded),
                          label: const Text('按原题再练'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed:
                              entry.isReviewed || _isUpdating
                                  ? null
                                  : _markReviewed,
                          icon: const Icon(Icons.task_alt_rounded),
                          label: const Text('标记已复习'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
    );
  }

  Future<void> _loadDetail() async {
    final PracticeRepository repository =
        widget.repository ?? ref.read(practiceRepositoryProvider);
    final entry = await repository.fetchWrongQuestionDetail(
      widget.wrongQuestionId,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _entry = entry;
      _isLoading = false;
      _isUpdating = false;
    });
  }

  Future<void> _markReviewed() async {
    setState(() => _isUpdating = true);
    final PracticeRepository repository =
        widget.repository ?? ref.read(practiceRepositoryProvider);
    await repository.markWrongQuestionReviewed(widget.wrongQuestionId);
    if (!mounted) {
      return;
    }
    await _loadDetail();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已标记为已复习')));
  }
}

class _WrongContributionCard extends StatelessWidget {
  const _WrongContributionCard({required this.entry});

  final WrongQuestionEntry entry;

  @override
  Widget build(BuildContext context) {
    return StageContributionCard(
      title: '关卡进步',
      subtitle: '这道错题会用于成长报告和闯关地图。',
      summary: stageContributionSummaryForWrong(entry),
      labels: stageContributionLabelsForWrong(entry),
    );
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

String _severityLabel(String severity) {
  if (severity == 'high') {
    return '高';
  }
  if (severity == 'medium') {
    return '中';
  }
  return '低';
}
