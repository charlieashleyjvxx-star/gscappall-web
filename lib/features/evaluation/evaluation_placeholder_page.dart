import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_providers.dart';
import '../../core/user_facing_error.dart';
import '../../domain/poem.dart';
import '../../domain/practice_models.dart';
import '../../domain/repositories/practice_repository.dart';
import '../../services/game/challenge_progress_service.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/section_card.dart';
import 'practice_report_detail_page.dart';
import '../profile/profile_support.dart';
import '../shared/stage_scope_filter_banner.dart';
import '../shared/stage_scope_landing_panel.dart';
import '../shared/stage_scope_route_args.dart';
import '../wrong_book/wrong_book_placeholder_page.dart';
import 'evaluation_result_page.dart';

class EvaluationPlaceholderPage extends ConsumerStatefulWidget {
  const EvaluationPlaceholderPage({
    super.key,
    this.initialMode = PracticeMode.dictation,
    this.lockMode = false,
    this.pageTitle,
  });

  final PracticeMode initialMode;
  final bool lockMode;
  final String? pageTitle;

  @override
  ConsumerState<EvaluationPlaceholderPage> createState() =>
      _EvaluationPlaceholderPageState();
}

class _EvaluationPlaceholderPageState
    extends ConsumerState<EvaluationPlaceholderPage> {
  final TextEditingController _answerController = TextEditingController();

  late final PracticeRepository _practiceRepository;
  late PracticeMode _mode;
  bool _isLoading = true;
  bool _isSubmitting = false;
  List<Poem> _poems = const [];
  PracticeSession? _session;
  PracticeReport? _report;
  int? _selectedPoemId;
  int _currentIndex = 0;
  final Map<int, String> _answers = <int, String>{};
  final Map<int, PracticeLineResult> _draftResults =
      <int, PracticeLineResult>{};

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _practiceRepository = ref.read(practiceRepositoryProvider);
    _bootstrap();
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pageTitle ?? '小测验'),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _poems.isEmpty
              ? const EmptyState(
                title: '还没有可用于练习的诗词',
                description: '请先完成种子导入，再进入听写或测评。',
                icon: Icons.quiz_outlined,
              )
              : SafeArea(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _buildHeader(context),
                    const SizedBox(height: 18),
                    if (_report != null)
                      _buildLastReportSummary(context, _report!)
                    else if (_session != null)
                      _buildSession(context, _session!),
                  ],
                ),
              ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final isStandaloneDictation =
        widget.lockMode && _mode == PracticeMode.dictation;
    final compactLayout = MediaQuery.sizeOf(context).width < 390;
    return SectionCard(
      title: isStandaloneDictation ? '听写练习' : '小测验',
      subtitle:
          isStandaloneDictation ? '按诗句逐题默写，做错的句子会进入错题本。' : '做几道小题，看看这首诗掌握得怎么样。',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (widget.lockMode)
                Chip(label: Text(_mode.label))
              else
                for (final mode in PracticeMode.values)
                  ChoiceChip(
                    label: Text(mode.label),
                    selected: _mode == mode,
                    onSelected: (_) => _switchMode(mode),
                  ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: _selectedPoemId,
            decoration: const InputDecoration(labelText: '选择练习诗词'),
            items: _poems
                .map(
                  (poem) => DropdownMenuItem<int>(
                    value: poem.id,
                    child: Text('${poem.title} · ${poem.author}'),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value == null || value == _selectedPoemId) {
                return;
              }
              _selectedPoemId = value;
              _restartSession();
            },
          ),
          const SizedBox(height: 12),
          _PracticeHeaderActions(
            compactLayout: compactLayout,
            primaryLabel: _report == null ? '重新开始' : '再测一次',
            onRestart: _isLoading || _isSubmitting ? null : _restartSession,
            onOpenWrongBook:
                () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const WrongBookPlaceholderPage(),
                  ),
                ),
            onOpenReports:
                () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PracticeReportHistoryPage(),
                  ),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildSession(BuildContext context, PracticeSession session) {
    final question = session.questions[_currentIndex];
    final preview = _draftResults[_currentIndex];

    return Column(
      children: [
        SectionCard(
          title: session.poem.title,
          subtitle:
              '${session.poem.dynasty} · ${session.poem.author} · ${session.mode.label}',
          trailing: Chip(
            label: Text(
              '第 ${_currentIndex + 1} / ${session.questions.length} 题',
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                question.prompt,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                question.hint,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _answerController,
                onChanged: (_) {
                  if (preview != null) {
                    setState(() => _draftResults.remove(_currentIndex));
                  }
                },
                maxLines: 3,
                minLines: 3,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText:
                      _mode == PracticeMode.dictation
                          ? '把这一句诗默写在这里，先检查再进入下一题'
                          : '在这里输入你的答案',
                ),
              ),
              if (preview != null) ...[
                const SizedBox(height: 16),
                _InlineFeedback(result: preview),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        SectionCard(
          title: '当前进度',
          child: Row(
            children: [
              Expanded(
                child: _MetricChip(
                  title: '已作答',
                  value: '${_answers.length}/${session.questions.length}',
                  color: const Color(0xFFF6E0B8),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricChip(
                  title: '已校验',
                  value: '${_draftResults.length}/${session.questions.length}',
                  color: const Color(0xFFE7F4E4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 56,
              child: FilledButton.icon(
                onPressed:
                    _isSubmitting
                        ? null
                        : (_mode == PracticeMode.dictation
                            ? _checkAndContinue
                            : _nextOrSubmitEvaluation),
                icon: Icon(
                  _mode == PracticeMode.dictation && preview == null
                      ? Icons.fact_check_outlined
                      : _currentIndex >= session.questions.length - 1
                      ? Icons.flag_rounded
                      : Icons.chevron_right_rounded,
                ),
                label: Text(
                  _mode == PracticeMode.dictation && preview == null
                      ? '检查这一题'
                      : _currentIndex >= session.questions.length - 1
                      ? (_mode == PracticeMode.dictation ? '完成听写' : '提交测评')
                      : '下一题',
                ),
              ),
            ),
            if (_currentIndex > 0)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('更多操作'),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _previousQuestion,
                      icon: const Icon(Icons.chevron_left_rounded),
                      label: const Text('返回上一题'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildLastReportSummary(BuildContext context, PracticeReport report) {
    return SectionCard(
      title: '刚刚完成一轮 ${report.mode.label}',
      subtitle: '${report.poem.title} · ${report.poem.author}',
      trailing: Chip(label: Text('总分 ${report.totalScore}')),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _MetricChip(
                  title: '正确句数',
                  value: '${report.correctCount}/${report.totalQuestions}',
                  color: const Color(0xFFE7F4E4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricChip(
                  title: '新增错题',
                  value: '${report.generatedWrongCount}',
                  color: const Color(0xFFFBE8E0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 56,
                child: FilledButton.icon(
                  onPressed: () => _openResultPage(report),
                  icon: const Icon(Icons.assessment_outlined),
                  label: const Text('查看结果页'),
                ),
              ),
              const SizedBox(height: 4),
              TextButton.icon(
                onPressed: _restartSession,
                icon: const Icon(Icons.replay_rounded),
                label: const Text('再练一次'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _bootstrap() async {
    setState(() => _isLoading = true);

    final poems = await _practiceRepository.fetchPracticePoems();
    if (!mounted) {
      return;
    }

    _poems = poems;
    _selectedPoemId ??= poems.isEmpty ? null : poems.first.id;
    if (_selectedPoemId != null) {
      _session = await _practiceRepository.createSession(
        mode: _mode,
        poemId: _selectedPoemId,
      );
    }

    if (!mounted) {
      return;
    }

    _resetSessionDrafts();
    setState(() => _isLoading = false);
  }

  Future<void> _refresh() async => _bootstrap();

  Future<void> _restartSession() async {
    if (_selectedPoemId == null) {
      return;
    }

    setState(() => _isLoading = true);
    final session = await _practiceRepository.createSession(
      mode: _mode,
      poemId: _selectedPoemId,
    );

    if (!mounted) {
      return;
    }

    _report = null;
    setState(() {
      _session = session;
      _isLoading = false;
      _resetSessionDrafts();
    });
  }

  Future<void> _switchMode(PracticeMode mode) async {
    if (_mode == mode) {
      return;
    }
    _mode = mode;
    await _restartSession();
  }

  void _previousQuestion() {
    _saveCurrentAnswer();
    setState(() {
      _currentIndex -= 1;
      _syncAnswerController();
    });
  }

  Future<void> _checkAndContinue() async {
    final session = _session;
    if (session == null) {
      return;
    }

    final existingResult = _draftResults[_currentIndex];
    if (existingResult != null) {
      if (_currentIndex >= session.questions.length - 1) {
        await _submitSession();
        return;
      }
      setState(() {
        _currentIndex += 1;
        _syncAnswerController();
      });
      return;
    }

    _saveCurrentAnswer();
    final result = _practiceRepository.evaluateAnswer(
      question: session.questions[_currentIndex],
      answer: _answers[_currentIndex] ?? '',
    );
    setState(() => _draftResults[_currentIndex] = result);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.isCorrect
                ? '本句正确，可以进入下一题。'
                : '已记录为 ${result.mistakeType?.label ?? '待复习'}。',
          ),
        ),
      );
    }
  }

  Future<void> _nextOrSubmitEvaluation() async {
    final session = _session;
    if (session == null) {
      return;
    }

    _saveCurrentAnswer();
    if (_currentIndex >= session.questions.length - 1) {
      await _submitSession();
      return;
    }

    setState(() {
      _currentIndex += 1;
      _syncAnswerController();
    });
  }

  Future<void> _submitSession() async {
    final session = _session;
    if (session == null) {
      return;
    }

    _saveCurrentAnswer();
    setState(() => _isSubmitting = true);

    final report = await _practiceRepository.completeSession(
      session: session,
      answers: _answers,
    );

    ref.invalidate(learningSummaryProvider);
    ref.invalidate(recentLearningRecordsProvider);
    ref.invalidate(practiceReportSummariesProvider);

    if (!mounted) {
      return;
    }

    setState(() {
      _report = report;
      _isSubmitting = false;
      _draftResults
        ..clear()
        ..addEntries(
          report.results.asMap().entries.map(
            (entry) => MapEntry(entry.key, entry.value),
          ),
        );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${report.mode.label}已完成，得分 ${report.totalScore}。'),
      ),
    );

    await _openResultPage(report);
  }

  Future<void> _openResultPage(PracticeReport report) async {
    final action = await Navigator.of(context).push<EvaluationResultAction>(
      MaterialPageRoute(builder: (_) => EvaluationResultPage(report: report)),
    );

    if (!mounted || action == null) {
      return;
    }

    switch (action) {
      case EvaluationResultAction.restart:
        await _restartSession();
      case EvaluationResultAction.openWrongBook:
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const WrongBookPlaceholderPage()),
        );
    }
  }

  void _saveCurrentAnswer() {
    final currentValue = _answerController.text.trim();
    final previousValue = _answers[_currentIndex];
    _answers[_currentIndex] = currentValue;
    if (previousValue != currentValue) {
      _draftResults.remove(_currentIndex);
    }
  }

  void _resetSessionDrafts() {
    _currentIndex = 0;
    _answers.clear();
    _draftResults.clear();
    _syncAnswerController();
  }

  void _syncAnswerController() {
    _answerController
      ..text = _answers[_currentIndex] ?? ''
      ..selection = TextSelection.fromPosition(
        TextPosition(offset: _answerController.text.length),
      );
  }
}

class PracticeReportHistoryPage extends ConsumerStatefulWidget {
  const PracticeReportHistoryPage({super.key, this.initialStageId});

  final String? initialStageId;

  @override
  ConsumerState<PracticeReportHistoryPage> createState() =>
      _PracticeReportHistoryPageState();
}

class _PracticeReportHistoryPageState
    extends ConsumerState<PracticeReportHistoryPage> {
  String? _routeStageId;
  String? _routeSource;
  PracticeMode? _modeFilter;
  PracticeScoreBand? _scoreBandFilter;
  PracticeMistakeType? _mistakeTypeFilter;
  String? _stageFilter;

  @override
  void initState() {
    super.initState();
    _stageFilter = widget.initialStageId;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = StageScopeRouteArgs.maybeOf(context);
    _routeStageId ??= args?.stageId;
    _routeSource ??= args?.source;
    if (widget.initialStageId == null &&
        _stageFilter == null &&
        _routeStageId != null) {
      _stageFilter = _routeStageId;
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = PracticeReportQuery(
      mode: _modeFilter,
      scoreBand: _scoreBandFilter,
      mistakeType: _mistakeTypeFilter,
      stageId: _stageFilter,
      limit: 200,
    );
    final overview = ref.watch(practiceReportOverviewProvider(query));

    return Scaffold(
      appBar: AppBar(title: const Text('练习报告')),
      body: overview.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, _) => EmptyState(
              title: '报告加载失败',
              description: UserFacingErrorMapper.message(
                error,
                fallbackMessage: '报告加载失败，请稍后重试。',
              ),
              icon: Icons.error_outline_rounded,
            ),
        data: (overview) {
          final reports = overview.summaries;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _PracticeReportStatsCard(stats: overview.stats),
              if (_stageFilter != null) ...[
                const SizedBox(height: 12),
                StageScopeLandingPanel(
                  stageId: _stageFilter!,
                  filterKind: StageScopeFilterKind.practiceReports,
                  source: _routeSource,
                  onClearFilter: () => setState(() => _stageFilter = null),
                  fallbackChallengeMapSource: 'practice-report',
                  mapLabel: '回到该关卡章节',
                ),
              ],
              const SizedBox(height: 12),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('筛选报告'),
                subtitle: const Text('需要查找某类练习时再展开。'),
                children: [
                  _PracticeReportFilterCard(
                    modeFilter: _modeFilter,
                    scoreBandFilter: _scoreBandFilter,
                    mistakeTypeFilter: _mistakeTypeFilter,
                    stageFilter: _stageFilter,
                    onModeChanged:
                        (value) => setState(() => _modeFilter = value),
                    onScoreBandChanged:
                        (value) => setState(() => _scoreBandFilter = value),
                    onMistakeTypeChanged:
                        (value) => setState(() => _mistakeTypeFilter = value),
                    onStageChanged:
                        (value) => setState(() => _stageFilter = value),
                    onClear: _clearFilters,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (reports.isEmpty)
                const EmptyState(
                  title: '没有符合条件的报告',
                  description: '可以清除筛选，或先完成更多练习。',
                  icon: Icons.filter_alt_off_outlined,
                )
              else
                for (final report in reports) ...[
                  _PracticeReportHistoryTile(record: report),
                  const SizedBox(height: 12),
                ],
            ],
          );
        },
      ),
    );
  }

  void _clearFilters() {
    setState(() {
      _modeFilter = null;
      _scoreBandFilter = null;
      _mistakeTypeFilter = null;
      _stageFilter = null;
    });
  }
}

class _PracticeReportStatsCard extends StatelessWidget {
  const _PracticeReportStatsCard({required this.stats});

  final PracticeReportStats stats;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '报告统计',
      subtitle: '家长可查看最近 ${stats.totalReports} 份练习报告。',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _MetricChip(
                  title: '平均分',
                  value: '${stats.averageScore}',
                  color: const Color(0xFFE7F4E4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricChip(
                  title: '听写/测评',
                  value: '${stats.dictationCount}/${stats.evaluationCount}',
                  color: const Color(0xFFF6E0B8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text('朗读：${stats.readingCount}')),
              Chip(label: Text('背诵：${stats.recitationCount}')),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in stats.scoreBands.entries)
                Chip(label: Text('${entry.key.label}: ${entry.value}')),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in stats.mistakeTypes.entries)
                if (entry.value > 0)
                  Chip(label: Text('${entry.key.label}: ${entry.value}')),
            ],
          ),
        ],
      ),
    );
  }
}

class _PracticeReportFilterCard extends StatelessWidget {
  const _PracticeReportFilterCard({
    required this.modeFilter,
    required this.scoreBandFilter,
    required this.mistakeTypeFilter,
    required this.stageFilter,
    required this.onModeChanged,
    required this.onScoreBandChanged,
    required this.onMistakeTypeChanged,
    required this.onStageChanged,
    required this.onClear,
  });

  final PracticeMode? modeFilter;
  final PracticeScoreBand? scoreBandFilter;
  final PracticeMistakeType? mistakeTypeFilter;
  final String? stageFilter;
  final ValueChanged<PracticeMode?> onModeChanged;
  final ValueChanged<PracticeScoreBand?> onScoreBandChanged;
  final ValueChanged<PracticeMistakeType?> onMistakeTypeChanged;
  final ValueChanged<String?> onStageChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '筛选',
      trailing: TextButton(onPressed: onClear, child: const Text('清空')),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FilterWrap(
            children: [
              ChoiceChip(
                label: const Text('全部模式'),
                selected: modeFilter == null,
                onSelected: (_) => onModeChanged(null),
              ),
              for (final mode in PracticeMode.values)
                ChoiceChip(
                  label: Text(mode.label),
                  selected: modeFilter == mode,
                  onSelected: (_) => onModeChanged(mode),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _FilterWrap(
            children: [
              ChoiceChip(
                label: const Text('全部分数'),
                selected: scoreBandFilter == null,
                onSelected: (_) => onScoreBandChanged(null),
              ),
              for (final band in PracticeScoreBand.values)
                ChoiceChip(
                  label: Text(band.label),
                  selected: scoreBandFilter == band,
                  onSelected: (_) => onScoreBandChanged(band),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _FilterWrap(
            children: [
              ChoiceChip(
                label: const Text('全部错因'),
                selected: mistakeTypeFilter == null,
                onSelected: (_) => onMistakeTypeChanged(null),
              ),
              for (final type in PracticeMistakeType.values)
                ChoiceChip(
                  label: Text(type.label),
                  selected: mistakeTypeFilter == type,
                  onSelected: (_) => onMistakeTypeChanged(type),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _FilterWrap(
            children: [
              ChoiceChip(
                label: const Text('全部关卡'),
                selected: stageFilter == null,
                onSelected: (_) => onStageChanged(null),
              ),
              for (final stageId in _reportStageFilterIds)
                ChoiceChip(
                  label: Text(challengeStageLabel(stageId)),
                  selected: stageFilter == stageId,
                  onSelected: (_) => onStageChanged(stageId),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

const _reportStageFilterIds = <String>[
  'dictation_checkpoint',
  'dictation_review',
];

class _FilterWrap extends StatelessWidget {
  const _FilterWrap({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 8, runSpacing: 8, children: children);
  }
}

String _practiceReportStageLabel(PracticeReportSummary summary) {
  final persistedStageId = summary.stageId;
  if (persistedStageId != null && persistedStageId.isNotEmpty) {
    return challengeStageLabel(persistedStageId);
  }
  if (summary.mode != PracticeMode.dictation) {
    return '';
  }
  final stageId = const ChallengeProgressService().stageIdForResult(
    mode: 'dictation',
    score: summary.totalScore,
    completedLines: summary.totalQuestions,
  );
  return challengeStageLabel(stageId);
}

class _PracticeReportHistoryTile extends StatelessWidget {
  const _PracticeReportHistoryTile({required this.record});

  final PracticeReportSummary record;

  @override
  Widget build(BuildContext context) {
    final stageLabel = _practiceReportStageLabel(record);
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFF6E0B8),
          child: Icon(
            record.mode == PracticeMode.dictation
                ? Icons.edit_note_rounded
                : Icons.assessment_outlined,
          ),
        ),
        title: Text('${record.poemTitle} · ${record.mode.label}'),
        subtitle: Text(
          [
            record.poemAuthor,
            if (stageLabel.isNotEmpty) stageLabel,
            _formatDateTime(record.completedAt),
            '正确 ${record.correctCount}/${record.totalQuestions} · 新增错题 ${record.generatedWrongCount}',
          ].join('\n'),
        ),
        isThreeLine: true,
        trailing: Chip(label: Text('${record.totalScore} 分')),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder:
                  (_) => CleanPracticeReportDetailPage(reportId: record.id),
            ),
          );
        },
      ),
    );
  }
}

class _InlineFeedback extends StatelessWidget {
  const _InlineFeedback({required this.result});

  final PracticeLineResult result;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:
            result.isCorrect
                ? const Color(0xFFE7F4E4)
                : const Color(0xFFFBE8E0),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            result.isCorrect
                ? '本句通过'
                : '本句待复习 · ${result.mistakeType?.label ?? '待复习'}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(result.feedback),
          if (!result.isCorrect) ...[
            const SizedBox(height: 6),
            Text('标准答案：${result.question.expectedAnswer}'),
          ],
        ],
      ),
    );
  }
}

class _PracticeHeaderActions extends StatelessWidget {
  const _PracticeHeaderActions({
    required this.compactLayout,
    required this.primaryLabel,
    required this.onRestart,
    required this.onOpenWrongBook,
    required this.onOpenReports,
  });

  final bool compactLayout;
  final String primaryLabel;
  final VoidCallback? onRestart;
  final VoidCallback onOpenWrongBook;
  final VoidCallback onOpenReports;

  @override
  Widget build(BuildContext context) {
    final primary = FilledButton.icon(
      onPressed: onRestart,
      icon: const Icon(Icons.play_arrow_rounded),
      label: Text(primaryLabel),
    );

    final secondary = [
      OutlinedButton.icon(
        onPressed: onOpenWrongBook,
        icon: const Icon(Icons.rule_folder_outlined),
        label: const Text('错题本'),
      ),
      OutlinedButton.icon(
        onPressed: onOpenReports,
        icon: const Icon(Icons.history_rounded),
        label: const Text('报告'),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        primary,
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          title: const Text('更多'),
          children: [Wrap(spacing: 8, runSpacing: 8, children: secondary)],
        ),
      ],
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
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

String _formatDateTime(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)} '
      '${two(value.hour)}:${two(value.minute)}';
}
