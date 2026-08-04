import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_providers.dart';
import '../../core/app_formatters.dart';
import '../../domain/learning_models.dart';
import '../../domain/practice_models.dart';
import '../../domain/sync/sync_models.dart';
import '../../services/game/challenge_progress_service.dart';
import '../../shared/widgets/section_card.dart';
import 'game_session_widgets.dart';
import '../profile/profile_support.dart';
import '../shared/stage_contribution_view.dart';
import '../shared/stage_scope_detail_panel.dart';
import '../shared/stage_scope_route_args.dart';
import '../shared/stage_scope_source_hint.dart';

typedef ChallengePracticeCallback = Future<void> Function();

enum _MapRefreshSource { silent, practice, manual, syncReplay }

const Map<SyncResourceType, String> _syncReplayResourceTypes = {
  SyncResourceType.learningRecords: '学习记录已更新',
  SyncResourceType.challengeStageRewards: '星星奖励已更新',
  SyncResourceType.practiceReports: '练习报告已更新',
  SyncResourceType.wrongQuestions: '错题记录已更新',
};

Widget _floatingBannerTransition(Widget child, Animation<double> animation) {
  final curved = CurvedAnimation(
    parent: animation,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  return FadeTransition(
    opacity: curved,
    child: SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, -0.16),
        end: Offset.zero,
      ).animate(curved),
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.98, end: 1).animate(curved),
        child: child,
      ),
    ),
  );
}

class ChallengeStarRow extends StatelessWidget {
  const ChallengeStarRow({super.key, required this.stars});

  final int stars;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        3,
        (index) => Icon(
          index < stars ? Icons.star_rounded : Icons.star_border_rounded,
          size: 18,
          color: const Color(0xFFD49A35),
        ),
      ),
    );
  }
}

class ChallengeMapPage extends ConsumerStatefulWidget {
  const ChallengeMapPage({
    super.key,
    required this.stages,
    required this.onOpenJielong,
    required this.onOpenFeihualing,
    required this.onOpenDictation,
    this.onOpenGrowthReport,
    this.initialStageId,
    this.initialSource,
  });

  final List<ChallengeStageProgress> stages;
  final ChallengePracticeCallback onOpenJielong;
  final ChallengePracticeCallback onOpenFeihualing;
  final ChallengePracticeCallback onOpenDictation;
  final ChallengePracticeCallback? onOpenGrowthReport;
  final String? initialStageId;
  final String? initialSource;

  @override
  ConsumerState<ChallengeMapPage> createState() => _ChallengeMapPageState();
}

class _ChallengeMapPageState extends ConsumerState<ChallengeMapPage> {
  late List<ChallengeStageProgress> _stages = widget.stages;
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _stageKeys = {};
  Map<String, _StageChangeFeedback> _changeFeedback = const {};
  String? _routeStageId;
  String? _routeSource;
  String? _highlightStageId;
  bool _focusScheduled = false;
  Timer? _highlightTimer;
  Timer? _changeFeedbackTimer;
  String? _lastHandledSyncReportKey;
  List<String> _syncReplayReasonDetails = const [];

  String? get _focusStageId => widget.initialStageId ?? _routeStageId;
  String? get _focusSourceLabel => stageScopeSourceLabel(_routeSource);

  @override
  void initState() {
    super.initState();
    _routeSource = widget.initialSource;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = StageScopeRouteArgs.maybeOf(context);
    _routeStageId ??= args?.stageId;
    _routeSource ??= args?.source;
    _scheduleInitialFocus();
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _changeFeedbackTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<SyncStatusSnapshot>>(syncStatusProvider, (
      previous,
      next,
    ) {
      final report = next.asData?.value.lastReport;
      if (report == null || !_shouldRefreshMapForSyncReplay(report)) {
        return;
      }
      final reportKey = _syncReportKey(report);
      if (_lastHandledSyncReportKey == reportKey ||
          previous?.asData?.value.lastReport == report) {
        return;
      }
      _lastHandledSyncReportKey = reportKey;
      _syncReplayReasonDetails = _syncReplayDetails(report);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        unawaited(_refreshStages(source: _MapRefreshSource.syncReplay));
      });
    });
    final groups = _groupStages(_stages);
    return Scaffold(
      appBar: AppBar(
        title: const Text('闯关地图'),
        actions: [
          IconButton(
            onPressed: () => _refreshStages(source: _MapRefreshSource.manual),
            tooltip: '刷新地图进度',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: () => _refreshStages(source: _MapRefreshSource.manual),
              child: ListView(
                controller: _scrollController,
                cacheExtent: 10000,
                padding: const EdgeInsets.all(20),
                children: [
                  _MapHero(stages: _stages),
                  const SizedBox(height: 16),
                  for (final group in groups.entries) ...[
                    SectionCard(
                      title: group.key,
                      subtitle: _groupSubtitle(group.key),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ChapterProgressPanel(
                            title: group.key,
                            stages: group.value
                                .map((entry) => entry.value)
                                .toList(growable: false),
                            focusedStageId: _focusStageId,
                            focusSourceLabel: _focusSourceLabel,
                            onOpenDetail:
                                () => _openChapterDetail(
                                  group.key,
                                  group.value
                                      .map((entry) => entry.value)
                                      .toList(growable: false),
                                ),
                          ),
                          const SizedBox(height: 12),
                          for (final entry in group.value)
                            _buildRouteNode(
                              entry,
                              chapterTitle: group.key,
                              chapterStages: group.value
                                  .map((entry) => entry.value)
                                  .toList(growable: false),
                              isLast: entry.key == group.value.last.key,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              top: 12,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 420),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInOutCubic,
                transitionBuilder: _floatingBannerTransition,
                child:
                    _highlightStageId == null
                        ? const SizedBox.shrink(key: ValueKey('no-focus'))
                        : StageScopeFloatingBanner(
                          key: ValueKey('focus-${_highlightStageId!}'),
                          stageLabel: challengeStageLabel(_highlightStageId!),
                          sourceLabel: _focusSourceLabel,
                          message: stageScopeSourceMessage(
                            stageLabel: challengeStageLabel(_highlightStageId!),
                            source: _routeSource,
                          ),
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  GlobalKey _stageKey(String stageId) {
    return _stageKeys.putIfAbsent(stageId, () => GlobalKey());
  }

  Widget _buildRouteNode(
    MapEntry<int, ChallengeStageProgress> entry, {
    required String chapterTitle,
    required List<ChallengeStageProgress> chapterStages,
    required bool isLast,
  }) {
    final stage = entry.value;
    final isFocused = _highlightStageId == stage.rule.id;
    final feedback = _changeFeedback[stage.rule.id];
    return _ChallengeRouteNode(
      key: _stageKey(stage.rule.id),
      index: entry.key,
      isLast: isLast,
      stage: stage,
      locked: const ChallengeProgressService().isStageLocked(
        _stages,
        entry.key,
      ),
      highlighted: isFocused || feedback != null,
      changeFeedback:
          isFocused
              ? _StageChangeFeedback(summary: _focusHighlightMessage(stage))
              : feedback,
      focusLabel: isFocused ? _focusSourceLabel : null,
      onTap: () => _openStage(entry.key, stage),
      onOpenChapterDetail:
          isFocused
              ? () => _openChapterDetail(chapterTitle, chapterStages)
              : null,
    );
  }

  Map<String, List<MapEntry<int, ChallengeStageProgress>>> _groupStages(
    List<ChallengeStageProgress> stages,
  ) {
    final groups = <String, List<MapEntry<int, ChallengeStageProgress>>>{};
    for (final entry in stages.asMap().entries) {
      final key =
          '${entry.value.rule.chapter} 路 ${_groupTitle(entry.value.rule.mode)}';
      groups.putIfAbsent(key, () => []).add(entry);
    }
    return groups;
  }

  String _groupTitle(String mode) {
    return switch (mode) {
      'poetry_jielong' => '接龙路线',
      'feihualing' => '飞花令路线',
      'dictation' => '综合复盘',
      _ => '拓展挑战',
    };
  }

  String _groupSubtitle(String title) {
    if (title.contains('接龙路线')) {
      return '完成接龙后，星星会自动更新。';
    }
    if (title.contains('飞花令路线')) {
      return '多完成几句，星星会慢慢点亮。';
    }
    if (title.contains('综合复盘')) {
      return '听写和错题复习都会帮助点亮这一关。';
    }
    return '更多玩法会继续加入地图。';
  }

  void _scheduleInitialFocus() {
    if (_focusScheduled || _focusStageId == null) {
      return;
    }
    _focusScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _scrollToStage(_focusStageId!);
      }
    });
  }

  Future<void> _scrollToStage(String stageId) async {
    final context = _stageKeys[stageId]?.currentContext;
    setState(() {
      _highlightStageId = stageId;
    });
    if (context != null) {
      await Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        alignment: 0.14,
      );
    } else if (_scrollController.hasClients) {
      final index = _stages.indexWhere((stage) => stage.rule.id == stageId);
      if (index >= 0) {
        await _scrollController.animateTo(
          (220 + index * 180)
              .clamp(0, _scrollController.position.maxScrollExtent)
              .toDouble(),
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
        );
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 80));
    final retryContext = _stageKeys[stageId]?.currentContext;
    if (mounted && retryContext != null && retryContext.mounted) {
      await Scrollable.ensureVisible(
        retryContext,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        alignment: 0.14,
      );
    }
    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _highlightStageId == stageId) {
        setState(() => _highlightStageId = null);
      }
    });
  }

  String _focusHighlightMessage(ChallengeStageProgress stage) {
    return stageScopeSourceMessage(
      stageLabel: stage.rule.title,
      source: _routeSource,
    );
  }

  Future<void> _refreshStages({
    _MapRefreshSource source = _MapRefreshSource.silent,
  }) async {
    final repository = ref.read(learningRepositoryProvider);
    final service = ref.read(challengeProgressServiceProvider);
    final previous = {for (final stage in _stages) stage.rule.id: stage};
    final progress = await repository.fetchChallengeModeProgress();
    final nextStages = service
        .defaultRules()
        .map((rule) {
          final modeProgress = progress[rule.mode];
          return service.evaluate(
            rule: rule,
            bestScore: modeProgress?.bestScore ?? 0,
            completedLines: modeProgress?.completedLines ?? 0,
            totalSessions: modeProgress?.totalSessions ?? 0,
          );
        })
        .toList(growable: false);
    final feedbackByStage = <String, _StageChangeFeedback>{};
    for (final stage in nextStages) {
      final old = previous[stage.rule.id];
      final feedback =
          old == null ? null : _stageChangeFeedback(old, stage, source);
      if (feedback != null) {
        feedbackByStage[stage.rule.id] = feedback;
      }
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _stages = nextStages;
      _changeFeedback =
          source == _MapRefreshSource.silent ? const {} : feedbackByStage;
    });
    _changeFeedbackTimer?.cancel();
    if (source != _MapRefreshSource.silent && feedbackByStage.isNotEmpty) {
      _changeFeedbackTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) {
          setState(() => _changeFeedback = const {});
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('闯关地图已刷新：${feedbackByStage.length} 个关卡变化。')),
      );
    }
  }

  _StageChangeFeedback? _stageChangeFeedback(
    ChallengeStageProgress previous,
    ChallengeStageProgress current,
    _MapRefreshSource source,
  ) {
    final scoreDelta = current.bestScore - previous.bestScore;
    final lineDelta = current.completedLines - previous.completedLines;
    final starDelta = current.stars - previous.stars;
    final details = <String>[
      if (source == _MapRefreshSource.syncReplay) ..._syncReplayReasonDetails,
      if (starDelta > 0) '星级提升 +$starDelta 星',
      if (scoreDelta > 0) '最好成绩 +$scoreDelta 分',
      if (lineDelta > 0) '完成句数 +$lineDelta',
    ];
    if (details.isEmpty) {
      return null;
    }
    return _StageChangeFeedback(
      summary: '${current.rule.title} ${_refreshSourceLabel(source)}',
      details: details,
    );
  }

  String _refreshSourceLabel(_MapRefreshSource source) {
    return switch (source) {
      _MapRefreshSource.practice => '本次练习已记录',
      _MapRefreshSource.manual => '手动刷新发现变化',
      _MapRefreshSource.syncReplay => '进度已更新',
      _MapRefreshSource.silent => '进度已记录',
    };
  }

  bool _shouldRefreshMapForSyncReplay(SyncRunReport report) {
    if (report.state == SyncRunState.failed ||
        report.state == SyncRunState.placeholder) {
      return false;
    }
    return _syncReplayDetails(report).isNotEmpty;
  }

  String _syncReportKey(SyncRunReport report) {
    return [
      report.finishedAt.microsecondsSinceEpoch,
      report.trigger.name,
      report.state.name,
      for (final entry in _syncReplayResourceTypes.entries)
        '${entry.key.name}:${report.pulledCounts[entry.key] ?? 0}',
    ].join(':');
  }

  List<String> _syncReplayDetails(SyncRunReport report) {
    return [
      for (final entry in _syncReplayResourceTypes.entries)
        if ((report.pulledCounts[entry.key] ?? 0) > 0)
          '${entry.value} ${report.pulledCounts[entry.key]} 条',
    ];
  }

  void _openStage(int index, ChallengeStageProgress stage) {
    if (const ChallengeProgressService().isStageLocked(_stages, index)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('先完成上一关，才能解锁这一关。')));
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (_) => ChallengeStageDetailPage(
              stage: stage,
              onStartPractice: () => _openPractice(stage.rule.mode),
            ),
      ),
    );
  }

  void _openChapterDetail(String title, List<ChallengeStageProgress> stages) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (_) => ChallengeChapterDetailPage(
              title: title,
              stages: stages,
              initialStageId: _focusStageId,
              initialSource: _routeSource,
              onStartPractice: _openPractice,
              onOpenGrowthReport: widget.onOpenGrowthReport,
            ),
      ),
    );
  }

  Future<void> _openPractice(String mode) async {
    switch (mode) {
      case 'poetry_jielong':
        await widget.onOpenJielong();
        break;
      case 'feihualing':
        await widget.onOpenFeihualing();
        break;
      case 'dictation':
        await widget.onOpenDictation();
        break;
      default:
        await widget.onOpenJielong();
    }
    await _refreshStages(source: _MapRefreshSource.practice);
  }
}

class ChallengeStageDetailPage extends ConsumerStatefulWidget {
  const ChallengeStageDetailPage({
    super.key,
    required this.stage,
    required this.onStartPractice,
  });

  final ChallengeStageProgress stage;
  final ChallengePracticeCallback onStartPractice;

  @override
  ConsumerState<ChallengeStageDetailPage> createState() =>
      _ChallengeStageDetailPageState();
}

class _ChallengeStageDetailPageState
    extends ConsumerState<ChallengeStageDetailPage> {
  bool _rewardChecked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_rewardChecked) {
      _rewardChecked = true;
      _maybeShowReward();
    }
  }

  Future<void> _maybeShowReward() async {
    final stars = widget.stage.stars;
    if (stars <= 0) {
      return;
    }
    final shouldShow = await ref
        .read(learningRepositoryProvider)
        .markChallengeRewardClaimed(
          stageId: widget.stage.rule.id,
          stars: stars,
        );
    if (!mounted || !shouldShow) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      showDialog<void>(
        context: context,
        builder:
            (_) => AlertDialog(
              title: Text(stars >= 3 ? '三星通关奖励' : '闯关奖励'),
              content: Text('${widget.stage.rule.title} 已达到 $stars 星，奖励已记录。'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('知道了'),
                ),
              ],
            ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final stage = widget.stage;
    return Scaffold(
      appBar: AppBar(title: Text(stage.rule.title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            SectionCard(
              title: stage.rule.title,
              subtitle: stage.rule.description,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text(stage.statusLabel)),
                  Chip(label: Text('最好 ${stage.bestScore} 分')),
                  Chip(label: Text('练习 ${stage.totalSessions} 次')),
                ],
              ),
            ),
            const SizedBox(height: 12),
            GameRuleCard(
              goal: stage.rule.title,
              rule: stage.rule.description,
              completion: '完成 ${stage.rule.requiredLines} 句后结算本关星级。',
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: '奖励',
              subtitle: '孩子先看星星，想知道规则时再展开。',
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: const Text('查看怎么得星星'),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.tonalIcon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder:
                                (_) => ChallengeRewardDetailPage(stage: stage),
                          ),
                        );
                      },
                      icon: const Icon(Icons.workspace_premium_rounded),
                      label: const Text('打开说明'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _RecentStageRecordSection(
              stage: stage,
              onStartPractice: (_) => widget.onStartPractice(),
            ),
            const SizedBox(height: 12),
            _StageActionLinks(stage: stage),
            FilledButton.icon(
              onPressed: () async {
                await widget.onStartPractice();
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('开始练习'),
            ),
          ],
        ),
      ),
    );
  }
}

class ChallengeChapterDetailPage extends ConsumerStatefulWidget {
  const ChallengeChapterDetailPage({
    super.key,
    required this.title,
    required this.stages,
    required this.onStartPractice,
    this.initialStageId,
    this.initialSource,
    this.onOpenGrowthReport,
  });

  final String title;
  final List<ChallengeStageProgress> stages;
  final String? initialStageId;
  final String? initialSource;
  final Future<void> Function(String mode) onStartPractice;
  final ChallengePracticeCallback? onOpenGrowthReport;

  @override
  ConsumerState<ChallengeChapterDetailPage> createState() =>
      _ChallengeChapterDetailPageState();
}

class _ChallengeChapterDetailPageState
    extends ConsumerState<ChallengeChapterDetailPage> {
  bool _rewardChecked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_rewardChecked) {
      _rewardChecked = true;
      _maybeShowReward();
    }
  }

  Future<void> _maybeShowReward() async {
    if (widget.stages.any((stage) => stage.stars == 0)) {
      return;
    }
    final stars = widget.stages.every((stage) => stage.stars >= 3) ? 3 : 1;
    final shouldShow = await ref
        .read(learningRepositoryProvider)
        .markChallengeRewardClaimed(
          stageId: 'chapter:${widget.title}',
          stars: stars,
        );
    if (!mounted || !shouldShow) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        showDialog<void>(
          context: context,
          builder:
              (_) => AlertDialog(
                title: Text(stars >= 3 ? '章节三星奖励' : '章节通关奖励'),
                content: const Text('章节奖励已记录，换设备时也会保留。'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('知道了'),
                  ),
                ],
              ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scoped = widget.stages.firstWhere(
      (stage) => stage.rule.id == widget.initialStageId,
      orElse: () => widget.stages.first,
    );
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: FutureBuilder<List<_ChapterRecommendation>>(
        future: _loadRecommendations(ref),
        builder: (context, snapshot) {
          final recommendations =
              snapshot.data ??
              widget.stages.map(_ChapterRecommendation.fromStage).toList();
          final target = recommendations.first.stage;
          final compactLayout = MediaQuery.sizeOf(context).width < 390;
          final pagePadding = compactLayout ? 16.0 : 20.0;
          final gap = compactLayout ? 10.0 : 12.0;
          return SafeArea(
            child: Stack(
              children: [
                ListView(
                  padding: EdgeInsets.all(pagePadding),
                  children: [
                    if (widget.initialSource != null)
                      const SizedBox(height: 76),
                    if (widget.initialStageId != null) ...[
                      _FocusedChapterStageSection(
                        stage: scoped,
                        source: widget.initialSource,
                        onStartPractice: widget.onStartPractice,
                      ),
                      SizedBox(height: gap),
                    ],
                    _ChapterProgressPanel(
                      title: widget.title,
                      stages: widget.stages,
                    ),
                    SizedBox(height: gap),
                    if (widget.initialSource != null) ...[
                      StageScopeSourceHint(source: widget.initialSource),
                      if (widget.onOpenGrowthReport != null) ...[
                        const SizedBox(height: 8),
                        FilledButton.tonalIcon(
                          onPressed: widget.onOpenGrowthReport,
                          icon: const Icon(Icons.insights_rounded),
                          label: const Text('查看成长报告'),
                        ),
                      ],
                      SizedBox(height: gap),
                    ],
                    SectionCard(
                      title: '章节路线',
                      subtitle: '需要看全章进度时再展开。',
                      child: ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: EdgeInsets.zero,
                        title: const Text('展开路线'),
                        children: [
                          _ChapterStageRail(
                            stages: widget.stages,
                            focusedStageId: widget.initialStageId,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: gap),
                    SectionCard(
                      title: '推荐练习',
                      subtitle: '优先补最需要再练的一关。',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ChapterRecommendationSummary(
                            recommendation: recommendations.first,
                          ),
                          const SizedBox(height: 10),
                          FilledButton.icon(
                            onPressed:
                                () => widget.onStartPractice(target.rule.mode),
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: Text(
                              '开始${_modePracticeLabel(target.rule.mode)}',
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: gap),
                    SectionCard(
                      title: '星星奖励',
                      subtitle: '想看奖励规则时再展开。',
                      child: ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: EdgeInsets.zero,
                        title: const Text('查看怎么得星星'),
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(_chapterRewardSummary(widget.stages)),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: gap),
                    SectionCard(
                      title: '更多练习',
                      subtitle: '想回看以前练过什么时再展开。',
                      child: ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: EdgeInsets.zero,
                        title: const Text('查看练过的内容'),
                        children: [
                          _ChapterHistorySection(
                            stages: widget.stages,
                            focusedStageId: widget.initialStageId,
                            embedded: true,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: gap),
                    _StageActionLinks(stage: scoped),
                    if (widget.onOpenGrowthReport != null)
                      FilledButton.tonalIcon(
                        onPressed: widget.onOpenGrowthReport,
                        icon: const Icon(Icons.insights_rounded),
                        label: const Text('查看成长报告'),
                      ),
                  ],
                ),
                if (widget.initialSource != null)
                  Positioned(
                    left: 20,
                    right: 20,
                    top: 12,
                    child: StageScopeFloatingBanner(
                      stageLabel: challengeStageLabel(scoped.rule.id),
                      sourceLabel: stageScopeSourceLabel(widget.initialSource),
                      message: stageScopeSourceMessage(
                        stageLabel: challengeStageLabel(scoped.rule.id),
                        source: widget.initialSource,
                        targetLabel: '章节详情',
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<List<_ChapterRecommendation>> _loadRecommendations(
    WidgetRef ref,
  ) async {
    final practiceRepository = ref.read(practiceRepositoryProvider);
    final recommendations = <_ChapterRecommendation>[];
    for (final stage in widget.stages) {
      final wrongs = await practiceRepository.fetchWrongQuestions(
        query: WrongQuestionQuery(
          stageId: stage.rule.id,
          onlyUnreviewed: true,
          limit: 50,
        ),
      );
      recommendations.add(
        _ChapterRecommendation(
          stage: stage,
          unreviewedWrongCount: wrongs.length,
        ),
      );
    }
    recommendations.sort(_compareChapterRecommendation);
    return recommendations;
  }
}

int _compareChapterRecommendation(
  _ChapterRecommendation left,
  _ChapterRecommendation right,
) {
  final wrongCompare = right.unreviewedWrongCount.compareTo(
    left.unreviewedWrongCount,
  );
  if (wrongCompare != 0) {
    return wrongCompare;
  }
  final starCompare = left.stage.stars.compareTo(right.stage.stars);
  if (starCompare != 0) {
    return starCompare;
  }
  final scoreCompare = left.stage.bestScore.compareTo(right.stage.bestScore);
  if (scoreCompare != 0) {
    return scoreCompare;
  }
  return left.stage.completedLines.compareTo(right.stage.completedLines);
}

class _ChapterRecommendation {
  const _ChapterRecommendation({
    required this.stage,
    this.unreviewedWrongCount = 0,
  });

  factory _ChapterRecommendation.fromStage(ChallengeStageProgress stage) {
    return _ChapterRecommendation(stage: stage);
  }

  final ChallengeStageProgress stage;
  final int unreviewedWrongCount;

  List<String> get reasons {
    final values = <String>[];
    if (unreviewedWrongCount > 0) {
      values.add('未改善错题 $unreviewedWrongCount 个，优先复盘');
    }
    final missingStars = 3 - stage.stars;
    if (missingStars > 0) {
      values.add('还差 $missingStars 星到三星');
    }
    if (stage.bestScore < stage.rule.requiredScore) {
      values.add('最好 ${stage.bestScore}/${stage.rule.requiredScore} 分，优先提分');
    }
    if (stage.completedLines < stage.rule.requiredLines) {
      values.add(
        '完成 ${stage.completedLines}/${stage.rule.requiredLines} 句，先补完成量',
      );
    }
    if (values.isEmpty) {
      values.add('已三星通关，可以继续刷新最好成绩');
    }
    return values;
  }
}

class _ChapterRecommendationSummary extends StatelessWidget {
  const _ChapterRecommendationSummary({required this.recommendation});

  final _ChapterRecommendation recommendation;

  @override
  Widget build(BuildContext context) {
    final stage = recommendation.stage;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          stage.rule.title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final reason in recommendation.reasons)
              Chip(label: Text(reason)),
          ],
        ),
      ],
    );
  }
}

class ChallengeRewardDetailPage extends StatelessWidget {
  const ChallengeRewardDetailPage({super.key, required this.stage});

  final ChallengeStageProgress stage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('星星奖励')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SectionCard(
            title: '星级奖励进度',
            subtitle: '每次点亮新星星都会记下来。',
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(title: Text('点亮关卡')),
                ListTile(title: Text('达标分数')),
                ListTile(title: Text('三星挑战')),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: '换设备也保留',
            subtitle: '孩子已经拿到的星星奖励会继续保留。',
            child: Text('关卡：${stage.rule.title}\n星级：${stage.stars}/3'),
          ),
        ],
      ),
    );
  }
}

class _ChapterStageRail extends StatelessWidget {
  const _ChapterStageRail({required this.stages, required this.focusedStageId});

  final List<ChallengeStageProgress> stages;
  final String? focusedStageId;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final completed = stages.where((stage) => stage.stars > 0).length;
    final locked = stages.length - completed;
    final threeStar = stages.where((stage) => stage.stars >= 3).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7E8),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE7BD65)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.account_tree_rounded,
                    color: Color(0xFF9C6B00),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '章节路线连接',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '按顺序点亮关卡，上一关获得星级后，下一关才会进入可练状态。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  const Chip(label: Text('路线节点状态')),
                  Chip(label: Text('已点亮 $completed 关')),
                  Chip(label: Text('已三星 $threeStar 关')),
                  Chip(label: Text(locked == 0 ? '本章已全部解锁' : '待解锁 $locked 关')),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        for (final entry in stages.asMap().entries)
          _ChapterStageBadge(
            stage: entry.value,
            index: entry.key,
            focused: entry.value.rule.id == focusedStageId,
            isLast: entry.key == stages.length - 1,
          ),
      ],
    );
  }
}

class _ChapterStageBadge extends StatelessWidget {
  const _ChapterStageBadge({
    required this.stage,
    required this.index,
    required this.focused,
    required this.isLast,
  });

  final ChallengeStageProgress stage;
  final int index;
  final bool focused;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusColor =
        stage.stars >= 3
            ? const Color(0xFF3F7E44)
            : stage.stars > 0
            ? const Color(0xFFD49A35)
            : colorScheme.outline;
    final statusBackground =
        stage.stars >= 3
            ? const Color(0xFFE8F5E9)
            : stage.stars > 0
            ? const Color(0xFFFFF4D9)
            : colorScheme.surfaceContainerHighest;
    final statusLabel =
        stage.stars >= 3
            ? '已三星'
            : stage.stars > 0
            ? '已点亮'
            : '待解锁';
    final nodeColor =
        focused
            ? colorScheme.primary
            : stage.stars > 0
            ? const Color(0xFFD49A35)
            : colorScheme.outline;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              width: focused ? 38 : 32,
              height: focused ? 38 : 32,
              decoration: BoxDecoration(
                color: focused ? const Color(0xFFFFE8AA) : colorScheme.surface,
                shape: BoxShape.circle,
                border: Border.all(color: nodeColor, width: focused ? 3 : 2),
                boxShadow:
                    focused
                        ? [
                          BoxShadow(
                            color: colorScheme.primary.withValues(alpha: 0.22),
                            blurRadius: 14,
                            spreadRadius: 2,
                          ),
                        ]
                        : null,
              ),
              alignment: Alignment.center,
              child: Text(
                '${index + 1}',
                style: TextStyle(color: nodeColor, fontWeight: FontWeight.w900),
              ),
            ),
            if (!isLast)
              Container(
                width: 3,
                height: 34,
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color:
                      stage.stars > 0
                          ? const Color(0xFFE7BD65)
                          : colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            margin: EdgeInsets.only(bottom: isLast ? 0 : 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:
                  focused
                      ? const Color(0xFFFFF4D9)
                      : colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color:
                    focused ? colorScheme.primary : colorScheme.outlineVariant,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        challengeStageLabel(stage.rule.id),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 260),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: statusBackground,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: statusColor),
                      ),
                      child: Text(
                        statusLabel,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    ChallengeStarRow(stars: stage.stars),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          minHeight: 6,
                          value: stage.stars / 3,
                          backgroundColor: colorScheme.outlineVariant,
                          color:
                              stage.stars >= 3
                                  ? const Color(0xFF3F7E44)
                                  : const Color(0xFFD49A35),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (focused) StageScopeSourceHint.label('当前定位'),
                    Chip(
                      label: Text(
                        stage.stars == 0
                            ? '未解锁'
                            : '${stage.stars}/3 星 · ${stage.statusLabel}',
                      ),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: colorScheme.surface,
                    ),
                    Chip(
                      label: Text('最好 ${stage.bestScore} 分'),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: colorScheme.surface,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  stage.nextGoal,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StageHighlightCard extends StatelessWidget {
  const _StageHighlightCard({required this.highlighted, required this.child});

  final bool highlighted;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedScale(
      scale: highlighted ? 1.015 : 1,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: highlighted ? const Color(0xFFFFF4D9) : colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
                highlighted
                    ? colorScheme.primary.withValues(alpha: 0.72)
                    : Colors.transparent,
            width: highlighted ? 1.6 : 1,
          ),
          boxShadow:
              highlighted
                  ? [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.22),
                      blurRadius: 22,
                      spreadRadius: 2,
                    ),
                  ]
                  : null,
        ),
        child: child,
      ),
    );
  }
}

class _StageChangeFeedback {
  const _StageChangeFeedback({required this.summary, this.details = const []});

  final String summary;
  final List<String> details;
}

class _StageChangeFeedbackView extends StatelessWidget {
  const _StageChangeFeedbackView({super.key, required this.feedback});

  final _StageChangeFeedback feedback;

  @override
  Widget build(BuildContext context) {
    final sourceDetails = feedback.details
        .where((detail) => detail.contains('已更新'))
        .toList(growable: false);
    final contributionDetails = feedback.details
        .where((detail) => !detail.contains('已更新'))
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(feedback.summary),
        if (sourceDetails.isNotEmpty) ...[
          const SizedBox(height: 6),
          _FeedbackChipGroup(
            title: '更新记录',
            details: sourceDetails,
            backgroundColor: const Color(0xFFEAF1FF),
          ),
        ],
        if (contributionDetails.isNotEmpty) ...[
          const SizedBox(height: 6),
          _FeedbackChipGroup(
            title: '本次提升',
            details: contributionDetails,
            backgroundColor: const Color(0xFFFFE8AA),
          ),
        ],
      ],
    );
  }
}

class _FeedbackChipGroup extends StatelessWidget {
  const _FeedbackChipGroup({
    required this.title,
    required this.details,
    required this.backgroundColor,
  });

  final String title;
  final List<String> details;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        for (final detail in details)
          Chip(
            label: Text(detail),
            visualDensity: VisualDensity.compact,
            side: BorderSide.none,
            backgroundColor: backgroundColor,
          ),
      ],
    );
  }
}

class _RouteConnector extends StatelessWidget {
  const _RouteConnector({required this.index, required this.locked});

  final int index;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final color =
        locked
            ? Theme.of(context).colorScheme.outlineVariant
            : const Color(0xFFE7BD65);
    return CircleAvatar(
      backgroundColor: locked ? Colors.white : const Color(0xFFFFF4D9),
      foregroundColor: locked ? color : const Color(0xFF9C6B00),
      child: Text('${index + 1}'),
    );
  }
}

class _MapHero extends StatelessWidget {
  const _MapHero({required this.stages});

  final List<ChallengeStageProgress> stages;

  @override
  Widget build(BuildContext context) {
    final unlocked = stages.where((stage) => stage.stars > 0).length;
    final stars = stages.fold<int>(0, (sum, stage) => sum + stage.stars);
    return SectionCard(
      title: '诗词闯关路线',
      subtitle: '按顺序点亮关卡。上一关至少获得 1 星后，下一关才会解锁。',
      child: Wrap(
        spacing: 8,
        children: [
          Chip(label: Text('已解锁 $unlocked/${stages.length}')),
          Chip(label: Text('累计 $stars 星')),
        ],
      ),
    );
  }
}

class _ChapterProgressPanel extends StatelessWidget {
  const _ChapterProgressPanel({
    required this.title,
    required this.stages,
    this.focusedStageId,
    this.focusSourceLabel,
    this.onOpenDetail,
  });

  final String title;
  final List<ChallengeStageProgress> stages;
  final String? focusedStageId;
  final String? focusSourceLabel;
  final VoidCallback? onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final completed = stages.where((stage) => stage.stars > 0).length;
    final stars = stages.fold<int>(0, (sum, stage) => sum + stage.stars);
    final maxStars = stages.length * 3;
    final completionLabel =
        stars == maxStars
            ? '本章已三星'
            : completed == stages.length
            ? '章节已通关'
            : '还差 ${stages.length - completed} 关点亮本章';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('章节完成度 $completed/${stages.length}'),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: maxStars == 0 ? 0 : stars / maxStars),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            Chip(label: Text('$stars/$maxStars 星')),
            Chip(label: Text(completionLabel)),
            if (focusedStageId != null)
              Chip(label: Text('当前回跳：${challengeStageLabel(focusedStageId)}')),
            if (focusSourceLabel != null)
              StageScopeSourceHint.label(focusSourceLabel!),
            if (onOpenDetail != null)
              FilledButton.tonalIcon(
                onPressed: onOpenDetail,
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('查看章节详情'),
              ),
          ],
        ),
      ],
    );
  }
}

class _ChallengeRouteNode extends StatelessWidget {
  const _ChallengeRouteNode({
    super.key,
    required this.index,
    required this.isLast,
    required this.stage,
    required this.locked,
    required this.highlighted,
    required this.onTap,
    this.changeFeedback,
    this.focusLabel,
    this.onOpenChapterDetail,
  });

  final int index;
  final bool isLast;
  final ChallengeStageProgress stage;
  final bool locked;
  final bool highlighted;
  final VoidCallback onTap;
  final _StageChangeFeedback? changeFeedback;
  final String? focusLabel;
  final VoidCallback? onOpenChapterDetail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: _StageHighlightCard(
        highlighted: highlighted,
        child: ListTile(
          onTap: onTap,
          leading: _RouteConnector(index: index, locked: locked),
          title: Text('${index + 1}. ${stage.rule.title}'),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (focusLabel != null) StageScopeSourceHint.label(focusLabel!),
              AnimatedSize(
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 420),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInOutCubic,
                  transitionBuilder:
                      (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SizeTransition(
                          sizeFactor: animation,
                          axisAlignment: -1,
                          child: child,
                        ),
                      ),
                  child:
                      highlighted
                          ? _StageChangeFeedbackView(
                            key: ValueKey(
                              changeFeedback?.summary ?? 'stage-feedback',
                            ),
                            feedback:
                                changeFeedback ??
                                const _StageChangeFeedback(
                                  summary: '刚刚刷新，地图进度已记录。',
                                ),
                          )
                          : const SizedBox.shrink(key: ValueKey('empty')),
                ),
              ),
              if (onOpenChapterDetail != null) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: onOpenChapterDetail,
                    icon: const Icon(Icons.account_tree_rounded),
                    label: const Text('查看所在章节详情'),
                  ),
                ),
              ],
              Text(locked ? '上一关完成后解锁' : stage.rule.description),
              Text(
                locked
                    ? '未解锁'
                    : '${stage.statusLabel} 路 最好 ${stage.bestScore} 分',
              ),
            ],
          ),
          trailing: isLast ? const Icon(Icons.flag_rounded) : null,
        ),
      ),
    );
  }
}

enum RecentStageRecordFilterValue {
  all('全部'),
  score('分数提升'),
  lines('完成句数');

  const RecentStageRecordFilterValue(this.label);

  final String label;
}

class RecentStageRecordFilterTabs extends StatelessWidget {
  const RecentStageRecordFilterTabs({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final RecentStageRecordFilterValue selected;
  final ValueChanged<RecentStageRecordFilterValue> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<RecentStageRecordFilterValue>(
      segments: [
        for (final filter in RecentStageRecordFilterValue.values)
          ButtonSegment(value: filter, label: Text(filter.label)),
      ],
      selected: {selected},
      onSelectionChanged: (selection) => onChanged(selection.single),
    );
  }
}

class _RecentStageRecordSection extends ConsumerStatefulWidget {
  const _RecentStageRecordSection({
    required this.stage,
    required this.onStartPractice,
  });

  final ChallengeStageProgress stage;
  final Future<void> Function(String mode) onStartPractice;

  @override
  ConsumerState<_RecentStageRecordSection> createState() =>
      _RecentStageRecordSectionState();
}

class _RecentStageRecordSectionState
    extends ConsumerState<_RecentStageRecordSection> {
  RecentStageRecordFilterValue _filter = RecentStageRecordFilterValue.all;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<LearningRecord>>(
      future: ref
          .read(learningRepositoryProvider)
          .fetchChallengeModeHistory(
            mode: widget.stage.rule.mode,
            stageId: widget.stage.rule.id,
            limit: 3,
          ),
      builder: (context, snapshot) {
        final records = snapshot.data ?? const <LearningRecord>[];
        final filteredRecords = _filterRecords(records);
        return SectionCard(
          title: '最近练习',
          subtitle: '看看最近 3 次是怎么练这一关的。',
          child:
              records.isEmpty
                  ? _RecentStageEmptyState(
                    filter: RecentStageRecordFilterValue.all,
                    onStartPractice:
                        () => widget.onStartPractice(widget.stage.rule.mode),
                  )
                  : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _RecentStageRecordTrendSummary(
                        stageId: widget.stage.rule.id,
                        records: records,
                      ),
                      const SizedBox(height: 12),
                      RecentStageRecordFilterTabs(
                        selected: _filter,
                        onChanged: (filter) => setState(() => _filter = filter),
                      ),
                      const SizedBox(height: 10),
                      _RecentStageFilterExplanation(
                        filter: _filter,
                        records: filteredRecords,
                      ),
                      const SizedBox(height: 10),
                      if (filteredRecords.isEmpty)
                        _RecentStageEmptyState(
                          filter: _filter,
                          onStartPractice:
                              () => widget.onStartPractice(
                                widget.stage.rule.mode,
                              ),
                          onShowAll: () {
                            if (_filter != RecentStageRecordFilterValue.all) {
                              setState(
                                () =>
                                    _filter = RecentStageRecordFilterValue.all,
                              );
                            }
                          },
                        )
                      else
                        ...filteredRecords.map(
                          (record) =>
                              _RecordTile(stage: widget.stage, record: record),
                        ),
                    ],
                  ),
        );
      },
    );
  }

  List<LearningRecord> _filterRecords(List<LearningRecord> records) {
    return switch (_filter) {
      RecentStageRecordFilterValue.all => records,
      RecentStageRecordFilterValue.score => records
          .where((record) => (record.score ?? 0) > 0)
          .toList(growable: false),
      RecentStageRecordFilterValue.lines => records
          .where(
            (record) =>
                record.mode == 'poetry_jielong' ||
                record.mode == 'feihualing' ||
                record.mode == 'dictation',
          )
          .toList(growable: false),
    };
  }
}

class _RecentStageFilterExplanation extends StatelessWidget {
  const _RecentStageFilterExplanation({
    required this.filter,
    required this.records,
  });

  final RecentStageRecordFilterValue filter;
  final List<LearningRecord> records;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final icon = switch (filter) {
      RecentStageRecordFilterValue.all => Icons.fact_check_rounded,
      RecentStageRecordFilterValue.score => Icons.trending_up_rounded,
      RecentStageRecordFilterValue.lines => Icons.format_list_numbered_rounded,
    };
    final title = switch (filter) {
      RecentStageRecordFilterValue.all => '全部练习',
      RecentStageRecordFilterValue.score => '分数进步',
      RecentStageRecordFilterValue.lines => '完成量',
    };
    final description = switch (filter) {
      RecentStageRecordFilterValue.all => '按时间看看孩子最近练了什么。',
      RecentStageRecordFilterValue.score => '只看带分数的记录，用来判断本关是否真的比上次更稳。',
      RecentStageRecordFilterValue.lines => '只看能体现完成量的练习，接龙、飞花令和听写都会计入。',
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$title · ${records.length} 条',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentStageEmptyState extends StatelessWidget {
  const _RecentStageEmptyState({
    required this.filter,
    this.onStartPractice,
    this.onShowAll,
  });

  final RecentStageRecordFilterValue filter;
  final VoidCallback? onStartPractice;
  final VoidCallback? onShowAll;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final actionLabel = switch (filter) {
      RecentStageRecordFilterValue.all => '继续练这一关',
      RecentStageRecordFilterValue.score => '去做一次练习',
      RecentStageRecordFilterValue.lines => '去补句数练习',
    };
    final actionHint = switch (filter) {
      RecentStageRecordFilterValue.all => '完成一次练习后，这里会出现新记录',
      RecentStageRecordFilterValue.score => '先练一次',
      RecentStageRecordFilterValue.lines => '先多完成几句',
    };
    final title = switch (filter) {
      RecentStageRecordFilterValue.all => '本关还没有练习记录',
      RecentStageRecordFilterValue.score => '暂时还没有进步记录',
      RecentStageRecordFilterValue.lines => '暂时还没有完成记录',
    };
    final message = switch (filter) {
      RecentStageRecordFilterValue.all => '完成一次本关练习后，这里会显示最近练了什么。',
      RecentStageRecordFilterValue.score => '可以先完成一次听写、接龙或飞花令，再回来看看有没有进步。',
      RecentStageRecordFilterValue.lines => '这里先看完成句数。想看其他练习，可以切回“全部”。',
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.8),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline_rounded, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: onStartPractice,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(actionLabel),
                    ),
                    Text(actionHint),
                    if (filter != RecentStageRecordFilterValue.all)
                      _ShowAllRecordsRecoveryAction(onPressed: onShowAll),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShowAllRecordsRecoveryAction extends StatelessWidget {
  const _ShowAllRecordsRecoveryAction({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: 0.96 + value * 0.04,
            alignment: Alignment.centerLeft,
            child: child,
          ),
        );
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFFFF4D9),
                  colorScheme.primaryContainer.withValues(alpha: 0.72),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.45),
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.13),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.replay_rounded, color: colorScheme.primary),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '看全部练习',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '回到这一关的全部练习',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.keyboard_arrow_right_rounded,
                  color: colorScheme.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentStageRecordTrendSummary extends StatelessWidget {
  const _RecentStageRecordTrendSummary({
    required this.stageId,
    required this.records,
  });

  final String stageId;
  final List<LearningRecord> records;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final scoredRecords = records
        .where((record) => record.score != null)
        .toList(growable: false);
    final bestScore = scoredRecords.fold<int?>(
      null,
      (best, record) =>
          best == null || record.score! > best ? record.score : best,
    );
    final latest = records.isEmpty ? null : records.first;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE7BD65)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights_rounded, color: Color(0xFF9C6B00)),
              const SizedBox(width: 8),
              Text(
                '最近练习变化',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text('最近 ${records.length} 次')),
              Chip(label: Text('最高分 ${bestScore ?? '--'}')),
              if (latest != null)
                Chip(
                  label: Text(
                    '最近 ${AppFormatters.shortDate(latest.studiedAt.toLocal())}',
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 96,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final entry
                    in records.reversed.toList().asMap().entries) ...[
                  Expanded(
                    child: _RecentStageScoreBar(
                      stageId: stageId,
                      index: entry.key + 1,
                      record: entry.value,
                    ),
                  ),
                  if (entry.key != records.length - 1) const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '柱子越高，说明这次练得越稳。家长可点开查看更多记录。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentStageScoreBar extends StatelessWidget {
  const _RecentStageScoreBar({
    required this.stageId,
    required this.index,
    required this.record,
  });

  final String stageId;
  final int index;
  final LearningRecord record;

  @override
  Widget build(BuildContext context) {
    final score = record.score ?? 0;
    final ratio = (score / 100).clamp(0, 1).toDouble();
    return Semantics(
      button: true,
      label: '第 $index 次练习记录 ${record.score ?? '--'} 分',
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.of(context).pushNamed(
            '/learning-record-detail',
            arguments: StageScopeRouteArgs(
              stageId: stageId,
              learningRecordId: record.id,
              source: 'chapter-detail',
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                record.score == null ? '--' : '$score',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: FractionallySizedBox(
                    heightFactor: ratio == 0 ? 0.08 : ratio,
                    widthFactor: 0.58,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: const LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Color(0xFFE0A11F), Color(0xFFFFE2A6)],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text('第 $index 次', style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _FocusedChapterStageSection extends StatelessWidget {
  const _FocusedChapterStageSection({
    required this.stage,
    required this.onStartPractice,
    this.source,
  });

  final ChallengeStageProgress stage;
  final Future<void> Function(String mode) onStartPractice;
  final String? source;

  @override
  Widget build(BuildContext context) {
    final stageLabel = challengeStageLabel(stage.rule.id);
    return SectionCard(
      title: source == null ? '当前聚焦关卡' : '当前关卡与最近练习',
      subtitle:
          source == null
              ? '从成长报告或地图回跳过来时，先看这一关最近练得怎样。'
              : stageScopeSourceMessage(
                stageLabel: stageLabel,
                source: source,
                targetLabel: '章节详情',
              ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (source != null) ...[
            StageScopeSourceHint(source: source),
            const SizedBox(height: 12),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text(stageLabel)),
              Chip(label: Text('${stage.stars}/3 星')),
              Chip(label: Text('最好 ${stage.bestScore} 分')),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => onStartPractice(stage.rule.mode),
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text('继续练这一关 · ${_modePracticeLabel(stage.rule.mode)}'),
          ),
          const SizedBox(height: 12),
          _RecentStageRecordSection(
            stage: stage,
            onStartPractice: onStartPractice,
          ),
          const SizedBox(height: 12),
          _StageActionLinks(stage: stage),
        ],
      ),
    );
  }
}

enum _ChapterHistoryScope {
  all('全部'),
  focused('当前关卡'),
  sameMode('同玩法');

  const _ChapterHistoryScope(this.label);

  final String label;
}

class _ChapterHistorySection extends ConsumerStatefulWidget {
  const _ChapterHistorySection({
    required this.stages,
    this.focusedStageId,
    this.embedded = false,
  });

  final List<ChallengeStageProgress> stages;
  final String? focusedStageId;
  final bool embedded;

  @override
  ConsumerState<_ChapterHistorySection> createState() =>
      _ChapterHistorySectionState();
}

class _ChapterHistorySectionState
    extends ConsumerState<_ChapterHistorySection> {
  _ChapterHistoryScope _scope = _ChapterHistoryScope.all;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<LearningRecord>>(
      future: _load(ref),
      builder: (context, snapshot) {
        final records = _filterRecords(
          snapshot.data ?? const <LearningRecord>[],
        );
        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<_ChapterHistoryScope>(
              segments: [
                for (final scope in _ChapterHistoryScope.values)
                  ButtonSegment(value: scope, label: Text(scope.label)),
              ],
              selected: {_scope},
              onSelectionChanged:
                  (selection) => setState(() => _scope = selection.single),
            ),
            const SizedBox(height: 12),
            if (records.isEmpty)
              Text(_emptyText())
            else
              Column(
                children: records
                    .map(
                      (record) => _RecordTile(
                        stage: _stageForRecord(record),
                        record: record,
                      ),
                    )
                    .toList(growable: false),
              ),
          ],
        );
        if (widget.embedded) {
          return content;
        }
        return SectionCard(
          title: '更多练习',
          subtitle: '想回看以前练过什么时再展开。',
          child: content,
        );
      },
    );
  }

  Future<List<LearningRecord>> _load(WidgetRef ref) async {
    final repository = ref.read(learningRepositoryProvider);
    final records = <LearningRecord>[];
    for (final stage in widget.stages) {
      records.addAll(
        await repository.fetchChallengeModeHistory(
          mode: stage.rule.mode,
          stageId: stage.rule.id,
          limit: 5,
        ),
      );
    }
    records.sort((a, b) => b.studiedAt.compareTo(a.studiedAt));
    return records;
  }

  List<LearningRecord> _filterRecords(List<LearningRecord> records) {
    final focusedStageId = widget.focusedStageId;
    ChallengeStageProgress? focusedStage;
    for (final stage in widget.stages) {
      if (stage.rule.id == focusedStageId) {
        focusedStage = stage;
        break;
      }
    }
    final focusedMode = focusedStage?.rule.mode;
    return switch (_scope) {
      _ChapterHistoryScope.all => records,
      _ChapterHistoryScope.focused =>
        focusedStageId == null
            ? records
            : records
                .where((record) => record.stageId == focusedStageId)
                .toList(growable: false),
      _ChapterHistoryScope.sameMode =>
        focusedMode == null
            ? records
            : records
                .where((record) => record.mode == focusedMode)
                .toList(growable: false),
    };
  }

  ChallengeStageProgress _stageForRecord(LearningRecord record) {
    for (final stage in widget.stages) {
      if (stage.rule.id == record.stageId) {
        return stage;
      }
    }
    return widget.stages.first;
  }

  String _emptyText() {
    return switch (_scope) {
      _ChapterHistoryScope.all => '本章节还没有历史记录，先完成一次推荐练习吧。',
      _ChapterHistoryScope.focused => '当前关卡还没有历史记录，点击“继续练这一关”后会显示在这里。',
      _ChapterHistoryScope.sameMode => '同玩法暂时没有更多历史记录，可以先完成一次本玩法练习。',
    };
  }
}

class _RecordTile extends StatefulWidget {
  const _RecordTile({required this.stage, required this.record});

  final ChallengeStageProgress stage;
  final LearningRecord record;

  @override
  State<_RecordTile> createState() => _RecordTileState();
}

class _RecordTileState extends State<_RecordTile> {
  bool _returnHighlighted = false;
  Timer? _highlightTimer;

  @override
  void dispose() {
    _highlightTimer?.cancel();
    super.dispose();
  }

  Future<void> _openAndHighlight(
    String routeName,
    StageScopeRouteArgs args,
  ) async {
    await _openScopedRouteAndRestoreRecord(context, routeName, args);
    if (!mounted) {
      return;
    }
    _highlightTimer?.cancel();
    setState(() => _returnHighlighted = true);
    _highlightTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => _returnHighlighted = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final stage = widget.stage;
    final record = widget.record;
    final stageId = stage.rule.id;
    final modeIcon = switch (record.mode) {
      'poetry_jielong' => Icons.account_tree_rounded,
      'feihualing' => Icons.local_florist_rounded,
      'dictation' => Icons.edit_note_rounded,
      _ => Icons.history_edu_rounded,
    };
    final scoreLabel = record.score == null ? '未记分' : '${record.score} 分';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StageProgressEvidenceCard(
            evidenceLabel: '练习记录卡',
            title: record.poemTitle,
            stageLabel: challengeStageLabel(stageId),
            scoreLabel: scoreLabel,
            dateLabel: AppFormatters.shortDate(record.studiedAt.toLocal()),
            modeLabel: learningModeLabel(record.mode),
            modeIcon: modeIcon,
            summary: stageContributionSummaryForRecord(record),
            labels: stageContributionLabelsForRecord(record),
            highlighted: _returnHighlighted,
            trailing: const Icon(Icons.chevron_right_rounded, size: 18),
            onTap: () {
              _openAndHighlight(
                '/learning-record-detail',
                StageScopeRouteArgs(
                  learningRecordId: record.id,
                  stageId: stageId,
                  source: 'chapter-detail',
                ),
              );
            },
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child:
                _returnHighlighted
                    ? const Padding(
                      key: ValueKey('return-highlight'),
                      padding: EdgeInsets.only(top: 8),
                      child: Chip(
                        avatar: Icon(Icons.my_location_rounded, size: 16),
                        label: Text('已回到这条记录'),
                        visualDensity: VisualDensity.compact,
                        side: BorderSide.none,
                        backgroundColor: Color(0xFFFFE8AA),
                      ),
                    )
                    : const SizedBox.shrink(key: ValueKey('no-highlight')),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: StageScopeEvidenceActions(
              actions: [
                StageScopeEvidenceAction(
                  label: '查看练习记录',
                  icon: Icons.history_edu_outlined,
                  onPressed: () {
                    _openAndHighlight(
                      '/learning-record-detail',
                      StageScopeRouteArgs(
                        learningRecordId: record.id,
                        stageId: stageId,
                        source: 'chapter-detail',
                      ),
                    );
                  },
                ),
                StageScopeEvidenceAction(
                  label: '查看练习结果',
                  icon: Icons.assessment_outlined,
                  onPressed: () {
                    _openAndHighlight(
                      '/practice-reports',
                      StageScopeRouteArgs(
                        stageId: stageId,
                        source: 'chapter-detail',
                      ),
                    );
                  },
                ),
                StageScopeEvidenceAction(
                  label: '查看错题',
                  icon: Icons.rule_folder_outlined,
                  onPressed: () {
                    _openAndHighlight(
                      '/wrong-book',
                      StageScopeRouteArgs(
                        stageId: stageId,
                        source: 'chapter-detail',
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _openScopedRouteAndRestoreRecord(
  BuildContext context,
  String routeName,
  StageScopeRouteArgs args,
) async {
  await Navigator.of(context).pushNamed(routeName, arguments: args);
  if (!context.mounted) {
    return;
  }
  await Scrollable.ensureVisible(
    context,
    duration: const Duration(milliseconds: 320),
    curve: Curves.easeOutCubic,
    alignment: 0.18,
  );
}

class _StageActionLinks extends StatelessWidget {
  const _StageActionLinks({required this.stage});

  final ChallengeStageProgress stage;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '本关复习',
      subtitle: '孩子先继续练；家长需要时再看记录。',
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        title: const Text('展开本关记录'),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed:
                      () => Navigator.of(context).pushNamed(
                        '/wrong-book',
                        arguments: StageScopeRouteArgs(stageId: stage.rule.id),
                      ),
                  icon: const Icon(Icons.rule_folder_outlined),
                  label: const Text('本关错题'),
                ),
                FilledButton.tonalIcon(
                  onPressed:
                      () => Navigator.of(context).pushNamed(
                        '/practice-reports',
                        arguments: StageScopeRouteArgs(stageId: stage.rule.id),
                      ),
                  icon: const Icon(Icons.assessment_outlined),
                  label: const Text('练习结果'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _modePracticeLabel(String mode) {
  return switch (mode) {
    'poetry_jielong' => '接龙练习',
    'feihualing' => '飞花令',
    'dictation' => '听写复盘',
    _ => '练习',
  };
}

String _chapterRewardSummary(List<ChallengeStageProgress> stages) {
  final completed = stages.where((stage) => stage.stars > 0).length;
  final stars = stages.fold<int>(0, (sum, stage) => sum + stage.stars);
  final maxStars = stages.length * 3;
  return '已点亮 $completed/${stages.length} 关，累计 $stars/$maxStars 星。';
}
