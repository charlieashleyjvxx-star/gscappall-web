import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_providers.dart';
import '../../app/app_design.dart';
import '../../core/user_facing_error.dart';
import '../../domain/poem.dart';
import '../../domain/practice_models.dart';
import '../../domain/repositories/practice_repository.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/section_card.dart';
import '../evaluation/evaluation_placeholder_page.dart';
import '../evaluation/evaluation_result_page.dart';
import '../wrong_book/wrong_book_placeholder_page.dart';

class DictationPage extends ConsumerStatefulWidget {
  const DictationPage({super.key});

  @override
  ConsumerState<DictationPage> createState() => _DictationPageState();
}

class _DictationPageState extends ConsumerState<DictationPage> {
  final TextEditingController _answerController = TextEditingController();

  late final PracticeRepository _repository;
  List<Poem> _poems = const [];
  PracticeSession? _session;
  PracticeReport? _report;
  DictationDifficulty _difficulty = DictationDifficulty.standard;
  DictationAnswerMode _answerMode = DictationAnswerMode.fullText;
  int? _selectedPoemId;
  int _currentIndex = 0;
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _showAnswerHint = false;
  Object? _loadError;
  final Map<int, String> _answers = <int, String>{};
  final Map<int, PracticeLineResult> _results = <int, PracticeLineResult>{};

  @override
  void initState() {
    super.initState();
    _repository = ref.read(practiceRepositoryProvider);
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
        title: const Text('独立听写'),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _bootstrap,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '重新加载听写',
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _loadError != null
              ? EmptyState(
                title: '听写加载失败',
                description: UserFacingErrorMapper.message(
                  _loadError!,
                  fallbackMessage: '听写内容加载失败，请稍后重试。',
                ),
                icon: Icons.error_outline_rounded,
                action: FilledButton.icon(
                  onPressed: _bootstrap,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('重试'),
                ),
              )
              : _poems.isEmpty
              ? const EmptyState(
                title: '还没有可练习的诗词',
                description: '请先完成种子数据导入，再进入听写训练。',
                icon: Icons.edit_note_rounded,
              )
              : SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppLayout.readingMaxWidth,
                    ),
                    child: ListView(
                      padding: const EdgeInsets.all(AppSpacing.large),
                      children: [
                        if (_report != null)
                          _buildReportSummary(_report!)
                        else if (_session != null)
                          _buildLinePractice(_session!),
                        const SizedBox(height: 16),
                        _buildTrainingHome(),
                      ],
                    ),
                  ),
                ),
              ),
    );
  }

  Widget _buildTrainingHome() {
    final compactLayout =
        MediaQuery.sizeOf(context).width < AppLayout.compactWidth;
    final selectedPoem = _poems.cast<Poem?>().firstWhere(
      (poem) => poem?.id == _selectedPoemId,
      orElse: () => null,
    );
    return SectionCard(
      title: '练习设置',
      subtitle:
          selectedPoem == null
              ? null
              : '${selectedPoem.title} · ${_difficulty.label} · ${_answerMode.label}',
      padding: const EdgeInsets.all(AppSpacing.large),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        title: const Text('更换诗词或模式'),
        children: [
          DropdownButtonFormField<int>(
            isExpanded: true,
            initialValue: _selectedPoemId,
            decoration: const InputDecoration(labelText: '练习诗词'),
            items: _poems
                .map(
                  (poem) => DropdownMenuItem<int>(
                    value: poem.id,
                    child: Text(
                      '${poem.title} · ${poem.author}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) async {
              if (value == null || value == _selectedPoemId) {
                return;
              }
              _selectedPoemId = value;
              await _restartSession();
            },
          ),
          SizedBox(height: compactLayout ? 10 : 14),
          const Text('难度'),
          SizedBox(height: compactLayout ? 6 : 8),
          Wrap(
            spacing: compactLayout ? 6 : 8,
            runSpacing: compactLayout ? 6 : 8,
            children: [
              for (final difficulty in DictationDifficulty.values)
                ChoiceChip(
                  visualDensity:
                      compactLayout
                          ? VisualDensity.compact
                          : VisualDensity.standard,
                  label: Text(difficulty.label),
                  selected: _difficulty == difficulty,
                  onSelected: (_) async {
                    setState(() => _difficulty = difficulty);
                    await _restartSession();
                  },
                ),
            ],
          ),
          SizedBox(height: compactLayout ? 10 : 14),
          const Text('作答方式'),
          SizedBox(height: compactLayout ? 6 : 8),
          Wrap(
            spacing: compactLayout ? 6 : 8,
            runSpacing: compactLayout ? 6 : 8,
            children: [
              for (final mode in DictationAnswerMode.values)
                ChoiceChip(
                  visualDensity:
                      compactLayout
                          ? VisualDensity.compact
                          : VisualDensity.standard,
                  label: Text(mode.label),
                  selected: _answerMode == mode,
                  onSelected: (_) async {
                    setState(() => _answerMode = mode);
                    await _restartSession();
                  },
                ),
            ],
          ),
          SizedBox(height: compactLayout ? 12 : 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isSubmitting ? null : _restartSession,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('重新开始'),
            ),
          ),
          SizedBox(height: compactLayout ? 8 : 10),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            title: const Text('更多'),
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const PracticeReportHistoryPage(),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        visualDensity:
                            compactLayout
                                ? VisualDensity.compact
                                : VisualDensity.standard,
                        padding: EdgeInsets.symmetric(
                          horizontal: compactLayout ? 10 : 14,
                          vertical: compactLayout ? 10 : 12,
                        ),
                      ),
                      icon: const Icon(Icons.history_rounded),
                      label: const Text('历史'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const WrongBookPlaceholderPage(),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        visualDensity:
                            compactLayout
                                ? VisualDensity.compact
                                : VisualDensity.standard,
                        padding: EdgeInsets.symmetric(
                          horizontal: compactLayout ? 10 : 14,
                          vertical: compactLayout ? 10 : 12,
                        ),
                      ),
                      icon: const Icon(Icons.rule_folder_outlined),
                      label: const Text('错题本'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLinePractice(PracticeSession session) {
    final question = session.questions[_currentIndex];
    final result = _results[_currentIndex];

    return Column(
      children: [
        SectionCard(
          title: session.poem.title,
          subtitle:
              '${session.poem.dynasty} · ${session.poem.author} · ${session.difficulty.label} · ${session.answerMode.label}',
          trailing: Chip(
            label: Text('第 ${_currentIndex + 1}/${session.questions.length} 句'),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                label:
                    '听写进度，第 ${_currentIndex + 1} 句，共 ${session.questions.length} 句',
                child: LinearProgressIndicator(
                  value: (_currentIndex + 1) / session.questions.length,
                ),
              ),
              const SizedBox(height: AppSpacing.large),
              Text(
                question.prompt,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              if (_showAnswerHint) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE8BD),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text('提示答案：${question.expectedAnswer}'),
                ),
              ],
              const SizedBox(height: 16),
              Semantics(
                textField: true,
                label: '输入第 ${_currentIndex + 1} 句答案',
                child: TextField(
                  controller: _answerController,
                  onChanged: (_) {
                    if (result != null) {
                      setState(() => _results.remove(_currentIndex));
                    }
                  },
                  maxLines: 3,
                  minLines: 3,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText:
                        _answerMode == DictationAnswerMode.fillBlank
                            ? '补齐隐藏字，也可以写完整句'
                            : '把这一句完整默写在这里',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    onPressed: _isSubmitting ? null : _checkAndContinue,
                    icon: Icon(
                      result == null
                          ? Icons.fact_check_outlined
                          : _currentIndex >= session.questions.length - 1
                          ? Icons.flag_rounded
                          : Icons.chevron_right_rounded,
                    ),
                    label: Text(
                      result == null
                          ? '检查这一句'
                          : _currentIndex >= session.questions.length - 1
                          ? '完成本次听写'
                          : '练下一句',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed:
                        () =>
                            setState(() => _showAnswerHint = !_showAnswerHint),
                    icon: const Icon(Icons.lightbulb_outline_rounded),
                    label: Text(_showAnswerHint ? '收起提示' : '显示提示'),
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
                            label: const Text('返回上一句'),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
        if (result != null) ...[
          const SizedBox(height: 16),
          _LineFeedbackCard(result: result),
        ],
      ],
    );
  }

  Widget _buildReportSummary(PracticeReport report) {
    return SectionCard(
      title: '本轮听写完成',
      subtitle: '${report.poem.title} · ${report.poem.author}',
      trailing: Chip(label: Text('${report.totalScore} 分')),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _MetricBox(
                  title: '正确句数',
                  value: '${report.correctCount}/${report.totalQuestions}',
                  color: const Color(0xFFE7F4E4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricBox(
                  title: '写入错题',
                  value: '${report.generatedWrongCount}',
                  color: const Color(0xFFFBE8E0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _openResultPage(report),
                  icon: const Icon(Icons.assessment_outlined),
                  label: const Text('报告详情'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _restartSession,
                  icon: const Icon(Icons.replay_rounded),
                  label: const Text('再练一次'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _bootstrap() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final poems = await _repository.fetchPracticePoems();
      if (!mounted) {
        return;
      }
      _poems = poems;
      _selectedPoemId ??= poems.isEmpty ? null : poems.first.id;
      if (_selectedPoemId != null) {
        _session = await _createSession();
      }
      if (!mounted) {
        return;
      }
      _resetDrafts();
      setState(() => _isLoading = false);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadError = error;
        _isLoading = false;
      });
    }
  }

  Future<PracticeSession> _createSession() {
    return _repository.createSession(
      mode: PracticeMode.dictation,
      poemId: _selectedPoemId,
      difficulty: _difficulty,
      answerMode: _answerMode,
    );
  }

  Future<void> _restartSession() async {
    if (_selectedPoemId == null) {
      return;
    }
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final session = await _createSession();
      if (!mounted) {
        return;
      }
      setState(() {
        _session = session;
        _report = null;
        _isLoading = false;
        _resetDrafts();
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadError = error;
        _isLoading = false;
      });
    }
  }

  void _previousQuestion() {
    _saveCurrentAnswer();
    setState(() {
      _currentIndex -= 1;
      _showAnswerHint = false;
      _syncAnswerController();
    });
  }

  Future<void> _checkAndContinue() async {
    final session = _session;
    if (session == null) {
      return;
    }
    final existingResult = _results[_currentIndex];
    if (existingResult != null) {
      if (_currentIndex >= session.questions.length - 1) {
        await _submitSession();
        return;
      }
      setState(() {
        _currentIndex += 1;
        _showAnswerHint = false;
        _syncAnswerController();
      });
      return;
    }

    _saveCurrentAnswer();
    final result = _repository.evaluateAnswer(
      question: session.questions[_currentIndex],
      answer: _answers[_currentIndex] ?? '',
    );
    setState(() => _results[_currentIndex] = result);
  }

  Future<void> _submitSession() async {
    final session = _session;
    if (session == null) {
      return;
    }
    _saveCurrentAnswer();
    setState(() => _isSubmitting = true);
    late final PracticeReport report;
    try {
      report = await _repository.completeSession(
        session: session,
        answers: _answers,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            UserFacingErrorMapper.message(
              error,
              fallbackMessage: '听写报告保存失败，请稍后重试。',
            ),
          ),
        ),
      );
      return;
    }

    ref.invalidate(learningSummaryProvider);
    ref.invalidate(recentLearningRecordsProvider);
    ref.invalidate(practiceReportSummariesProvider);
    ref.invalidate(practiceReportOverviewProvider);
    ref.invalidate(wrongQuestionEntriesProvider);

    if (!mounted) {
      return;
    }
    setState(() {
      _report = report;
      _isSubmitting = false;
      _results
        ..clear()
        ..addEntries(
          report.results.asMap().entries.map(
            (entry) => MapEntry(entry.key, entry.value),
          ),
        );
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('听写报告已保存，得分 ${report.totalScore}。')));
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
    final value = _answerController.text.trim();
    final previousValue = _answers[_currentIndex];
    _answers[_currentIndex] = value;
    if (previousValue != value) {
      _results.remove(_currentIndex);
    }
  }

  void _resetDrafts() {
    _currentIndex = 0;
    _answers.clear();
    _results.clear();
    _showAnswerHint = false;
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

class _LineFeedbackCard extends StatelessWidget {
  const _LineFeedbackCard({required this.result});

  final PracticeLineResult result;

  @override
  Widget build(BuildContext context) {
    final color =
        result.isCorrect ? const Color(0xFFE7F4E4) : const Color(0xFFFBE8E0);
    return SectionCard(
      title: result.isCorrect ? '本句通过' : '错字分析',
      subtitle: result.feedback,
      trailing: Chip(
        label: Text(
          result.isCorrect ? '${result.score} 分' : result.mistakeType!.label,
        ),
        backgroundColor: color,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TextBlock(label: '你的答案', value: result.answer),
          const SizedBox(height: 10),
          _TextBlock(label: '标准答案', value: result.question.expectedAnswer),
          if (result.characterAnalysis.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final issue in result.characterAnalysis)
                  Chip(label: Text(issue.label)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TextBlock extends StatelessWidget {
  const _TextBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(value.isEmpty ? '未作答' : value),
      ],
    );
  }
}

class _MetricBox extends StatelessWidget {
  const _MetricBox({
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
