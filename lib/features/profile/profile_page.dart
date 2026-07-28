import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_providers.dart';
import '../../app/app_design.dart';
import '../../core/app_environment.dart';
import '../../core/user_facing_error.dart';
import '../../core/app_formatters.dart';
import '../../core/service_status.dart';
import '../../domain/learning_models.dart';
import '../../domain/practice_models.dart';
import '../../domain/user_profile.dart';
import '../../services/game/challenge_progress_service.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/status_chip.dart';
import '../favorites/favorites_page.dart';
import '../shared/stage_contribution_view.dart';
import '../shared/stage_scope_route_args.dart';
import '../shared/stage_scope_source_hint.dart';
import 'learning_history_page.dart';
import 'profile_support.dart';
import 'profile_switch_page.dart';
import 'settings_page.dart';
import 'sync_account_page.dart';
import 'sync_status_card.dart';

typedef _StageTrendDetailOpener =
    Future<void> Function(
      String routeName,
      StageScopeRouteArgs arguments,
      String highlightKey,
    );

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final profilesAsync = ref.watch(profilesProvider);
    final services = ref.watch(serviceCatalogProvider);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          profileAsync.when(
            data:
                (profile) => _ProfileHeader(
                  profile: profile,
                  onOpenSettings:
                      () => _openPage(context, const SettingsPage()),
                  onSwitchProfile:
                      () => _openPage(context, const ProfileSwitchPage()),
                ),
            loading: () => const LinearProgressIndicator(),
            error:
                (error, _) => Text(
                  UserFacingErrorMapper.message(
                    error,
                    fallbackMessage: '资料加载失败，请稍后重试。',
                  ),
                ),
          ),
          const SizedBox(height: 18),
          SectionCard(
            title: '我的内容',
            subtitle: '孩子常用的内容放在这里。',
            child: Column(
              children: [
                _ActionTile(
                  title: '我的收藏',
                  subtitle: '查看已经点亮红心的诗词，继续离线学习。',
                  icon: Icons.favorite_rounded,
                  onTap: () => _openPage(context, const FavoritesPage()),
                ),
                _ActionTile(
                  title: '设置',
                  subtitle: '调整提醒、字体、主题和语速。',
                  icon: Icons.settings_rounded,
                  onTap: () => _openPage(context, const SettingsPage()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _AdvancedToolsSection(
            profilesAsync: profilesAsync,
            services: services,
          ),
        ],
      ),
    );
  }
}

class _AdvancedToolsSection extends StatelessWidget {
  const _AdvancedToolsSection({
    required this.profilesAsync,
    required this.services,
  });

  final AsyncValue<List<UserProfile>> profilesAsync;
  final List<ServiceDescriptor> services;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '家长管理',
      subtitle: '资料、数据保护和详细报告放在这里，平时不用展开。',
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        title: const Text('展开家长管理'),
        children: [
          profilesAsync.when(
            data:
                (profiles) => Column(
                  children: [
                    _ProfileRow(label: '本地资料', value: '${profiles.length} 个'),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.tonalIcon(
                        onPressed:
                            () => _openPage(context, const ProfileSwitchPage()),
                        icon: const Icon(Icons.people_alt_outlined),
                        label: const Text('管理学习资料'),
                      ),
                    ),
                  ],
                ),
            loading: () => const LinearProgressIndicator(),
            error:
                (error, _) => Text(
                  UserFacingErrorMapper.parentMessage(
                    error,
                    fallbackMessage: '资料加载失败，请稍后重试。',
                  ),
                ),
          ),
          const SizedBox(height: 12),
          const SyncStatusCard(),
          const SizedBox(height: 12),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            title: const Text('成长与历史'),
            subtitle: const Text('详细报告和历史记录给家长查看。'),
            children: [
              const _GrowthReportsEntry(),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed:
                      () => _openPage(context, const LearningHistoryPage()),
                  icon: const Icon(Icons.history_rounded),
                  label: const Text('学习历史'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => _openPage(context, const SyncAccountPage()),
              icon: const Icon(Icons.cloud_sync_rounded),
              label: const Text('备份账号'),
            ),
          ),
          const SizedBox(height: 12),
          if (AppEnvironment.diagnosticsEnabled)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('服务状态'),
              subtitle: const Text('诊断模式下查看服务能力。'),
              children: services
                  .map(
                    (service) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        service.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        service.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: StatusChip(capability: service.capability),
                    ),
                  )
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }
}

class GrowthReportDetailPage extends ConsumerStatefulWidget {
  const GrowthReportDetailPage({
    super.key,
    required this.initialPeriod,
    this.initialStageId,
  });

  final GrowthReportPeriod initialPeriod;
  final String? initialStageId;

  @override
  ConsumerState<GrowthReportDetailPage> createState() =>
      _GrowthReportDetailPageState();
}

class _GrowthReportDetailPageState
    extends ConsumerState<GrowthReportDetailPage> {
  late GrowthReportPeriod _period = widget.initialPeriod;
  String? _stageId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = ModalRoute.of(context)?.settings;
    _stageId ??=
        widget.initialStageId ??
        (settings == null
            ? null
            : StageScopeRouteArgs.fromSettings(settings)?.stageId);
  }

  @override
  Widget build(BuildContext context) {
    final reportAsync = ref.watch(learningGrowthReportProvider(_period));
    return Scaffold(
      appBar: AppBar(title: const Text('成长报告详情')),
      body: reportAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, _) => Center(
              child: Text(
                UserFacingErrorMapper.parentMessage(
                  error,
                  fallbackMessage: '成长报告加载失败，请稍后重试。',
                ),
              ),
            ),
        data: (report) {
          final compactLayout =
              MediaQuery.sizeOf(context).width < AppLayout.compactWidth;
          final pagePadding =
              compactLayout ? AppSpacing.medium : AppSpacing.large;
          final gap = compactLayout ? AppSpacing.medium : AppSpacing.large;
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppLayout.readingMaxWidth,
              ),
              child: ListView(
                cacheExtent: 4000,
                padding: EdgeInsets.all(pagePadding),
                children: [
                  SegmentedButton<GrowthReportPeriod>(
                    segments: const [
                      ButtonSegment(
                        value: GrowthReportPeriod.weekly,
                        label: Text('周报'),
                      ),
                      ButtonSegment(
                        value: GrowthReportPeriod.monthly,
                        label: Text('月报'),
                      ),
                    ],
                    selected: {_period},
                    onSelectionChanged:
                        (value) => setState(() => _period = value.first),
                  ),
                  SizedBox(height: gap),
                  if (_stageId != null) ...[
                    _StageScopeCard(
                      stageId: _stageId!,
                      report: report,
                      onClear: () => setState(() => _stageId = null),
                    ),
                    SizedBox(height: gap),
                  ],
                  SectionCard(
                    title:
                        '${_period == GrowthReportPeriod.weekly ? '本周' : '本月'}总结',
                    subtitle: _growthHeadline(report),
                    child: Semantics(
                      container: true,
                      label: _growthHeadline(report),
                      child: Column(
                        children: [
                          _ProfileRow(
                            label: '练习次数',
                            value: '${report.totalSessions} 次',
                          ),
                          _ProfileRow(
                            label: '学习时长',
                            value: AppFormatters.minutesLabel(
                              report.totalMinutes,
                            ),
                          ),
                          _ProfileRow(
                            label: '练习表现',
                            value:
                                report.averageScore == null
                                    ? '暂无'
                                    : '${report.averageScore} 分',
                          ),
                          _ProfileRow(
                            label: '错题复习',
                            value:
                                '${report.reviewedWrongQuestionCount}/${report.wrongQuestionCount}',
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: gap),
                  SectionCard(
                    title: '练习进度',
                    subtitle: '想细看时再展开，平时先看总结和建议。',
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: EdgeInsets.zero,
                      title: const Text('查看星星和练习变化'),
                      children: [
                        _GameTrendBars(report: report),
                        const SizedBox(height: 14),
                        _StageTrendBars(report: report),
                        const SizedBox(height: 14),
                        _ProfileRow(
                          label: '这次练习',
                          value: '${report.gameSessionCount} 次',
                        ),
                        _ProfileRow(
                          label: '和上次相比',
                          value:
                              '${report.gameSessionDelta >= 0 ? '+' : ''}${report.gameSessionDelta} 次',
                        ),
                        _ProfileRow(
                          label: '练习表现',
                          value:
                              report.gameAverageScore == null
                                  ? '暂无'
                                  : '${report.gameAverageScore} 分',
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: gap),
                  SectionCard(
                    title: '建议继续练',
                    subtitle: '挑一关回到地图继续练。',
                    child: _StageTrendCards(report: report),
                  ),
                  SizedBox(height: gap),
                  _ParentFocusStageCard(report: report),
                  SizedBox(height: gap),
                  SectionCard(
                    title: '家长补充说明',
                    subtitle: '想了解原因时再展开。',
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: EdgeInsets.zero,
                      title: const Text('展开补充说明'),
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(_parentSummary(report)),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: gap),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushNamed(
                        '/challenge-map',
                        arguments: StageScopeRouteArgs(
                          stageId: _stageId,
                          source: 'growth-report',
                        ),
                      );
                    },
                    icon: const Icon(Icons.map_rounded),
                    label: const Text('查看闯关地图'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ParentFocusStageCard extends StatelessWidget {
  const _ParentFocusStageCard({required this.report});

  final LearningGrowthReport report;

  @override
  Widget build(BuildContext context) {
    final focus = _parentFocusStage(report);
    if (focus == null) {
      return const SectionCard(
        title: '家长关注关卡',
        subtitle: '这段时间练得还不多。',
        child: Text('先完成 2 次以上接龙、飞花令或听写练习，再回来看看哪一关最需要陪孩子多练。'),
      );
    }
    final previous = report.previousGameStageStat(focus.stageId);
    final stageLabel = challengeStageLabel(focus.stageId);
    final lowData = focus.count < 2;
    final pendingWrongCount = _parentFocusPendingWrongCount(report, focus);
    return SectionCard(
      title: '家长关注关卡',
      subtitle: lowData ? '先多练一两次，再看这一关是否稳定。' : '优先看看最近变化最明显的一关。',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text(stageLabel)),
              Chip(label: Text('${focus.count} 次练习')),
              Chip(
                label: Text(
                  focus.averageScore == null
                      ? '再练几次'
                      : '表现 ${focus.averageScore} 分',
                ),
              ),
              if (lowData) const Chip(label: Text('再练一两次')),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            lowData
                ? '建议家长先陪孩子再完成 1-2 次本关练习，再看有没有读顺、写稳。'
                : _stageContributionSummary(focus, previous),
          ),
          if (pendingWrongCount > 0) ...[
            const SizedBox(height: 10),
            Text('关注这一关是因为还有 $pendingWrongCount 个未改善错题，建议先复盘弱项，再回到地图看进度。'),
            const SizedBox(height: 8),
            ActionChip(
              avatar: const Icon(Icons.error_outline_rounded, size: 18),
              label: Text('未改善错题 $pendingWrongCount 个'),
              onPressed: () {
                Navigator.of(context).pushNamed(
                  '/wrong-book',
                  arguments: StageScopeRouteArgs(
                    stageId: focus.stageId,
                    source: 'growth-report',
                  ),
                );
              },
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: () {
                  Navigator.of(context).pushNamed(
                    '/challenge-map',
                    arguments: StageScopeRouteArgs(
                      stageId: focus.stageId,
                      source: 'growth-report',
                    ),
                  );
                },
                icon: Icon(
                  lowData ? Icons.play_arrow_rounded : Icons.route_rounded,
                ),
                label: Text(lowData ? '去练关注关卡' : '查看关注关卡'),
              ),
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pushNamed(
                    '/learning-history',
                    arguments: StageScopeRouteArgs(
                      stageId: focus.stageId,
                      source: 'growth-report',
                    ),
                  );
                },
                icon: const Icon(Icons.history_rounded),
                label: const Text('查看学习历史'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StageScopeCard extends StatelessWidget {
  const _StageScopeCard({
    required this.stageId,
    required this.report,
    required this.onClear,
  });

  final String stageId;
  final LearningGrowthReport report;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final current = _stageStat(report.gameStageStats, stageId);
    final previous = report.previousGameStageStat(stageId);
    final stageLabel = challengeStageLabel(stageId);
    return SectionCard(
      title: '本关成长视角',
      subtitle: '当前只看这一关最近练得怎么样。',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StageScopeSourceHint.label('已帮你找到这一关'),
          const SizedBox(height: 12),
          Text(
            current == null
                ? '这段时间还没有练这一关。'
                : '这段时间练了 ${current.count} 次，表现 ${current.averageScore ?? 0} 分。',
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text(stageLabel)),
              Chip(label: Text('${report.gameSessionCount} 次练习')),
              Chip(
                label: Text(
                  '${report.gameSessionDelta >= 0 ? '+' : ''}${report.gameSessionDelta} 次变化',
                ),
              ),
            ],
          ),
          if (previous != null)
            Text(
              '上次记录里练了 ${previous.count} 次，表现 ${previous.averageScore ?? 0} 分。',
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.filter_alt_off_rounded),
                label: const Text('清除关卡筛选'),
              ),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pushNamed(
                    '/challenge-map',
                    arguments: StageScopeRouteArgs(
                      stageId: stageId,
                      source: 'growth-report',
                    ),
                  );
                },
                icon: const Icon(Icons.map_rounded),
                label: const Text('回到闯关地图'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StageTrendCards extends StatelessWidget {
  const _StageTrendCards({required this.report});

  final LearningGrowthReport report;

  @override
  Widget build(BuildContext context) {
    final stats = report.gameStageStats.take(4).toList(growable: false);
    if (stats.isEmpty) {
      return const Text('这段时间还没有足够的关卡练习记录。');
    }
    return Column(
      children: [
        for (final stat in stats) ...[
          _StageTrendCard(
            stat: stat,
            previous: report.previousGameStageStat(stat.stageId),
          ),
          if (stat != stats.last) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _StageTrendCard extends StatelessWidget {
  const _StageTrendCard({required this.stat, required this.previous});

  final LearningStageStat stat;
  final LearningStageStat? previous;

  @override
  Widget build(BuildContext context) {
    final delta = stat.count - (previous?.count ?? 0);
    final scoreText =
        stat.averageScore == null ? '再练几次' : '${stat.averageScore} 分';
    final maxCount = _trendMaxCount(stat, previous);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  challengeStageLabel(stat.stageId),
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              Text('${stat.count} 次 · $scoreText'),
            ],
          ),
          const SizedBox(height: 10),
          _TrendBar(
            label: '这次',
            count: stat.count,
            maxCount: maxCount,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 4),
          _TrendBar(
            label: '上次',
            count: previous?.count ?? 0,
            maxCount: maxCount,
            color: Theme.of(context).colorScheme.secondaryContainer,
          ),
          const SizedBox(height: 8),
          Text(
            _stageContributionSummary(stat, previous),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          _StageContributionChips(stat: stat),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                label: Text(
                  delta == 0
                      ? '和上次一样'
                      : delta > 0
                      ? '比上次多 $delta 次'
                      : '比上次少 ${-delta} 次',
                ),
              ),
              Chip(label: Text('表现 $scoreText')),
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pushNamed(
                    '/challenge-map',
                    arguments: StageScopeRouteArgs(
                      stageId: stat.stageId,
                      source: 'growth-report',
                    ),
                  );
                },
                icon: const Icon(Icons.route_rounded),
                label: const Text('查看本关练习记录'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  int _trendMaxCount(LearningStageStat stat, LearningStageStat? previous) {
    final currentMax =
        stat.count > (previous?.count ?? 0)
            ? stat.count
            : (previous?.count ?? 0);
    return currentMax <= 0 ? 1 : currentMax;
  }
}

class _StageContributionChips extends StatelessWidget {
  const _StageContributionChips({required this.stat});

  final LearningStageStat stat;

  @override
  Widget build(BuildContext context) {
    return StageContributionChips(
      labels: stageContributionLabelsForStageStat(stat),
    );
  }
}

class _GameTrendBars extends StatelessWidget {
  const _GameTrendBars({required this.report});

  final LearningGrowthReport report;

  @override
  Widget build(BuildContext context) {
    final stats = report.gameModeTrendStats;
    if (stats.isEmpty) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: Text('本期暂无诗词接龙、飞花令或听写闯关记录。'),
      );
    }

    final maxCount = stats.fold<int>(1, (max, stat) {
      final previous = report.previousGameModeStat(stat.mode)?.count ?? 0;
      final currentMax = stat.count > previous ? stat.count : previous;
      return currentMax > max ? currentMax : max;
    });

    return Column(
      children: stats
          .map(
            (stat) => _GameTrendRow(
              stat: stat,
              previous: report.previousGameModeStat(stat.mode),
              maxCount: maxCount,
            ),
          )
          .toList(growable: false),
    );
  }
}

class _GameTrendRow extends StatelessWidget {
  const _GameTrendRow({
    required this.stat,
    required this.previous,
    required this.maxCount,
  });

  final LearningModeStat stat;
  final LearningModeStat? previous;
  final int maxCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final previousCount = previous?.count ?? 0;
    final scoreText =
        stat.averageScore == null ? '暂无均分' : '${stat.averageScore} 分';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  learningModeLabel(stat.mode),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text('${stat.count} 次 · $scoreText'),
            ],
          ),
          const SizedBox(height: 6),
          _TrendBar(
            label: '本期',
            count: stat.count,
            maxCount: maxCount,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 4),
          _TrendBar(
            label: '上期',
            count: previousCount,
            maxCount: maxCount,
            color: theme.colorScheme.secondaryContainer,
          ),
        ],
      ),
    );
  }
}

class _TrendBar extends StatelessWidget {
  const _TrendBar({
    required this.label,
    required this.count,
    required this.maxCount,
    required this.color,
  });

  final String label;
  final int count;
  final int maxCount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ratio = maxCount == 0 ? 0.0 : (count / maxCount).clamp(0, 1);
    return Row(
      children: [
        SizedBox(width: 36, child: Text(label)),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: ratio.toDouble(),
              minHeight: 8,
              color: color,
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(width: 34, child: Text('$count 次')),
      ],
    );
  }
}

class _StageTrendBars extends StatelessWidget {
  const _StageTrendBars({required this.report});

  final LearningGrowthReport report;

  @override
  Widget build(BuildContext context) {
    final stats = report.gameStageStats.take(5).toList(growable: false);
    if (stats.isEmpty) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: Text('关卡练习记录还比较少，完成一次闯关后会显示每关变化。'),
      );
    }

    final maxCount = stats.fold<int>(1, (max, stat) {
      final previous = report.previousGameStageStat(stat.stageId)?.count ?? 0;
      final currentMax = stat.count > previous ? stat.count : previous;
      return currentMax > max ? currentMax : max;
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '关卡变化',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        ...stats.map(
          (stat) => _StageTrendRow(
            stat: stat,
            previous: report.previousGameStageStat(stat.stageId),
            maxCount: maxCount,
            points: report.gameStageTrend(stat.stageId),
          ),
        ),
      ],
    );
  }
}

class _StageTrendRow extends StatelessWidget {
  const _StageTrendRow({
    required this.stat,
    required this.previous,
    required this.maxCount,
    required this.points,
  });

  final LearningStageStat stat;
  final LearningStageStat? previous;
  final int maxCount;
  final List<LearningStageTrendPoint> points;

  @override
  Widget build(BuildContext context) {
    final scoreText =
        stat.averageScore == null ? '暂无均分' : '${stat.averageScore} 分';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  challengeStageLabel(stat.stageId),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              Text('${stat.count} 次 · $scoreText'),
            ],
          ),
          const SizedBox(height: 6),
          _TrendBar(
            label: '本期',
            count: stat.count,
            maxCount: maxCount,
            color: const Color(0xFFE0A11F),
          ),
          const SizedBox(height: 4),
          _TrendBar(
            label: '上期',
            count: previous?.count ?? 0,
            maxCount: maxCount,
            color: Theme.of(context).colorScheme.tertiaryContainer,
          ),
          const SizedBox(height: 8),
          _StagePeriodMetricStrip(stat: stat, previous: previous),
          if (points.isNotEmpty) ...[
            const SizedBox(height: 8),
            _StageDailyTrend(stageId: stat.stageId, points: points),
          ],
          const SizedBox(height: 4),
          Text(
            _stageContributionSummary(stat, previous),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          _StageContributionChips(stat: stat),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                Navigator.of(context).pushNamed(
                  '/challenge-map',
                  arguments: StageScopeRouteArgs(
                    stageId: stat.stageId,
                    source: 'growth-report',
                  ),
                );
              },
              icon: const Icon(Icons.route_rounded),
              label: const Text('查看本关练习记录'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StageDailyTrend extends StatelessWidget {
  const _StageDailyTrend({required this.stageId, required this.points});

  final String stageId;
  final List<LearningStageTrendPoint> points;

  @override
  Widget build(BuildContext context) {
    final maxCount = points.fold<int>(
      1,
      (value, point) => point.count > value ? point.count : value,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '逐日变化',
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        _StageTrendChart(points: points, maxCount: maxCount),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final point in points) ...[
                _StageTrendPointButton(
                  stageId: stageId,
                  point: point,
                  maxCount: maxCount,
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _StageTrendChart extends StatelessWidget {
  const _StageTrendChart({required this.points, required this.maxCount});

  final List<LearningStageTrendPoint> points;
  final int maxCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxScore = points.fold<int>(
      100,
      (value, point) =>
          (point.averageScore ?? 0) > value ? point.averageScore! : value,
    );
    return Semantics(
      label: '周月关卡变化图，柱子表示练习次数，折线表示平均分，圆点表示星级参考',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '周/月关卡变化图',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const _TrendLegendDot(color: Color(0xFFE0A11F), label: '次数柱'),
                const SizedBox(width: 8),
                const _TrendLegendDot(color: Color(0xFF3F7E44), label: '均分线'),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 124,
              child: CustomPaint(
                painter: _StageTrendChartPainter(
                  points: points,
                  maxCount: maxCount,
                  maxScore: maxScore,
                  axisColor: theme.colorScheme.outlineVariant,
                  labelColor: theme.colorScheme.onSurfaceVariant,
                ),
                child: const SizedBox.expand(),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: const [
                Chip(
                  avatar: Icon(Icons.bar_chart_rounded, size: 16),
                  label: Text('练习次数'),
                  visualDensity: VisualDensity.compact,
                ),
                Chip(
                  avatar: Icon(Icons.show_chart_rounded, size: 16),
                  label: Text('平均分'),
                  visualDensity: VisualDensity.compact,
                ),
                Chip(
                  avatar: Icon(Icons.star_rounded, size: 16),
                  label: Text('星级参考'),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendLegendDot extends StatelessWidget {
  const _TrendLegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class _StageTrendChartPainter extends CustomPainter {
  const _StageTrendChartPainter({
    required this.points,
    required this.maxCount,
    required this.maxScore,
    required this.axisColor,
    required this.labelColor,
  });

  final List<LearningStageTrendPoint> points;
  final int maxCount;
  final int maxScore;
  final Color axisColor;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) {
      return;
    }
    const leftInset = 28.0;
    const rightInset = 8.0;
    const topInset = 8.0;
    const bottomInset = 26.0;
    final chartWidth = size.width - leftInset - rightInset;
    final chartHeight = size.height - topInset - bottomInset;
    final baseY = topInset + chartHeight;
    final axisPaint =
        Paint()
          ..color = axisColor
          ..strokeWidth = 1;

    for (var i = 0; i <= 2; i++) {
      final y = topInset + chartHeight * i / 2;
      canvas.drawLine(
        Offset(leftInset, y),
        Offset(size.width - rightInset, y),
        axisPaint,
      );
    }

    final barPaint =
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Color(0xFFE0A11F), Color(0xFFFFE2A6)],
          ).createShader(
            Rect.fromLTWH(leftInset, topInset, chartWidth, chartHeight),
          );
    final linePaint =
        Paint()
          ..color = const Color(0xFF3F7E44)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round;
    final pointPaint = Paint()..color = const Color(0xFF3F7E44);
    final starPaint = Paint()..color = const Color(0xFFD49A35);
    final spacing =
        points.length == 1 ? chartWidth : chartWidth / (points.length - 1);
    final linePath = Path();

    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      final x = leftInset + (points.length == 1 ? chartWidth / 2 : spacing * i);
      final countRatio = (point.count / maxCount).clamp(0, 1).toDouble();
      final barHeight = chartHeight * countRatio;
      final barRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x - 9, baseY - barHeight, 18, barHeight),
        const Radius.circular(99),
      );
      canvas.drawRRect(barRect, barPaint);

      final scoreRatio =
          ((point.averageScore ?? 0) / maxScore).clamp(0, 1).toDouble();
      final scoreY = baseY - chartHeight * scoreRatio;
      if (i == 0) {
        linePath.moveTo(x, scoreY);
      } else {
        linePath.lineTo(x, scoreY);
      }
      canvas.drawCircle(Offset(x, scoreY), 3.5, pointPaint);

      final stars = _estimatedTrendPointStars(point).clamp(0, 3);
      for (var star = 0; star < stars; star++) {
        canvas.drawCircle(
          Offset(x - 8 + star * 8, topInset - 1),
          2.5,
          starPaint,
        );
      }

      _paintChartLabel(
        canvas,
        point.dateKey.length >= 10 ? point.dateKey.substring(5) : point.dateKey,
        Offset(x, baseY + 14),
      );
    }

    canvas.drawPath(linePath, linePaint);
    _paintAxisText(canvas, '$maxCount 次', Offset(0, topInset - 2));
    _paintAxisText(canvas, '$maxScore 分', Offset(0, topInset + 18));
  }

  void _paintChartLabel(Canvas canvas, String text, Offset center) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: labelColor,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  void _paintAxisText(Canvas canvas, String text, Offset offset) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: labelColor, fontSize: 9),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 26);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _StageTrendChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.maxCount != maxCount ||
        oldDelegate.maxScore != maxScore ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.labelColor != labelColor;
  }
}

class _StageTrendPointButton extends StatelessWidget {
  const _StageTrendPointButton({
    required this.stageId,
    required this.point,
    required this.maxCount,
  });

  final String stageId;
  final LearningStageTrendPoint point;
  final int maxCount;

  @override
  Widget build(BuildContext context) {
    final score = point.averageScore == null ? '--' : '${point.averageScore}';
    final stars = _estimatedTrendPointStars(point);
    final barHeight = 18 + 44 * (point.count / maxCount);
    return Semantics(
      button: true,
      label: '${point.dateKey} 关卡变化点',
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showStageTrendPointSheet(context),
        child: Container(
          width: 86,
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                width: 22,
                height: barHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: const LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0xFFE0A11F), Color(0xFFFFE2A6)],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                point.dateKey.substring(5),
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w900),
              ),
              Text('${point.count} 次 · $score 分'),
              Text('$stars 星'),
            ],
          ),
        ),
      ),
    );
  }

  void _showStageTrendPointSheet(
    BuildContext context, {
    String? highlightedActionKey,
  }) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder:
          (sheetContext) => _StageTrendPointSheetContent(
            stageId: stageId,
            point: point,
            highlightedActionKey: highlightedActionKey,
            onOpenDetail:
                (routeName, arguments, highlightKey) =>
                    _openDetailAndRestoreSheet(
                      context,
                      sheetContext,
                      routeName,
                      arguments,
                      highlightKey,
                    ),
          ),
    );
  }

  Future<void> _openDetailAndRestoreSheet(
    BuildContext ownerContext,
    BuildContext sheetContext,
    String routeName,
    StageScopeRouteArgs arguments,
    String highlightKey,
  ) async {
    Navigator.of(sheetContext).pop();
    await Navigator.of(ownerContext).pushNamed(routeName, arguments: arguments);
    if (!ownerContext.mounted) {
      return;
    }
    _showStageTrendPointSheet(ownerContext, highlightedActionKey: highlightKey);
  }
}

class _StageTrendPointSheetContent extends ConsumerWidget {
  const _StageTrendPointSheetContent({
    required this.stageId,
    required this.point,
    required this.onOpenDetail,
    this.highlightedActionKey,
  });

  final String stageId;
  final LearningStageTrendPoint point;
  final String? highlightedActionKey;
  final _StageTrendDetailOpener onOpenDetail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordsAsync = ref.watch(learningHistoryProvider(300));
    final reportsAsync = ref.watch(
      practiceReportOverviewProvider(
        PracticeReportQuery(stageId: stageId, limit: 300),
      ),
    );
    final wrongsAsync = ref.watch(
      wrongQuestionEntriesProvider(WrongQuestionQuery(stageId: stageId)),
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${challengeStageLabel(stageId)} · ${point.dateKey}',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                '当天完成 ${point.count} 次练习，均分 ${point.averageScore ?? '--'} 分，星级参考 ${_estimatedTrendPointStars(point)} 星。',
              ),
              const SizedBox(height: 12),
              _StageTrendPointMetricGrid(
                recordsAsync: recordsAsync,
                reportsAsync: reportsAsync,
                wrongsAsync: wrongsAsync,
                stageId: stageId,
                dateKey: point.dateKey,
              ),
              if (highlightedActionKey != null) ...[
                const SizedBox(height: 12),
                const _StageTrendReturnHighlightBanner(),
              ],
              const SizedBox(height: 12),
              _StageTrendPointRecentRecords(
                recordsAsync: recordsAsync,
                stageId: stageId,
                dateKey: point.dateKey,
              ),
              const SizedBox(height: 12),
              _StageTrendPointActionPanel(
                recordsAsync: recordsAsync,
                reportsAsync: reportsAsync,
                wrongsAsync: wrongsAsync,
                stageId: stageId,
                dateKey: point.dateKey,
                highlightedActionKey: highlightedActionKey,
                onOpenDetail: onOpenDetail,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pushNamed(
                        '/learning-history',
                        arguments: StageScopeRouteArgs(
                          stageId: stageId,
                          dateKey: point.dateKey,
                          source: 'growth-report',
                        ),
                      );
                    },
                    icon: const Icon(Icons.history_rounded),
                    label: const Text('查看当天学习记录'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pushNamed(
                        '/practice-reports',
                        arguments: StageScopeRouteArgs(
                          stageId: stageId,
                          source: 'growth-report',
                        ),
                      );
                    },
                    icon: const Icon(Icons.assessment_rounded),
                    label: const Text('查看练习结果'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pushNamed(
                        '/wrong-book',
                        arguments: StageScopeRouteArgs(
                          stageId: stageId,
                          source: 'growth-report',
                        ),
                      );
                    },
                    icon: const Icon(Icons.rule_folder_outlined),
                    label: const Text('查看本关错题'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StageTrendReturnHighlightBanner extends StatelessWidget {
  const _StageTrendReturnHighlightBanner();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      label: '已回到这条记录',
      child: ExcludeSemantics(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.28),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.touch_app_rounded,
                size: 18,
                color: colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '已回到这条记录，下面也会高亮刚才打开的项目。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StageTrendPointMetricGrid extends StatelessWidget {
  const _StageTrendPointMetricGrid({
    required this.recordsAsync,
    required this.reportsAsync,
    required this.wrongsAsync,
    required this.stageId,
    required this.dateKey,
  });

  final AsyncValue<List<LearningRecord>> recordsAsync;
  final AsyncValue<PracticeReportOverview> reportsAsync;
  final AsyncValue<List<WrongQuestionEntry>> wrongsAsync;
  final String stageId;
  final String dateKey;

  @override
  Widget build(BuildContext context) {
    final allRecords = recordsAsync.asData?.value;
    final overview = reportsAsync.asData?.value;
    final allWrongs = wrongsAsync.asData?.value;
    final records = allRecords
        ?.where((record) => _matchesStageDate(record.stageId, record.studiedAt))
        .toList(growable: false);
    final reports = overview?.summaries
        .where(
          (report) => _matchesStageDate(report.stageId, report.completedAt),
        )
        .toList(growable: false);
    final wrongs = allWrongs
        ?.where((wrong) => _matchesStageDate(wrong.stageId, wrong.createdAt))
        .toList(growable: false);
    final reviewedWrongs =
        wrongs?.where((wrong) => wrong.reviewedAt != null).length;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _StageTrendInfoChip(
          icon: Icons.menu_book_rounded,
          label: '当天练习',
          value: records == null ? '加载中' : '${records.length} 次',
        ),
        _StageTrendInfoChip(
          icon: Icons.assessment_rounded,
          label: '最近报告',
          value:
              reports == null
                  ? '加载中'
                  : reports.isEmpty
                  ? '暂无'
                  : '${reports.first.totalScore} 分',
          onTap:
              reports == null || reports.isEmpty
                  ? null
                  : () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pushNamed(
                      '/practice-report-detail',
                      arguments: StageScopeRouteArgs(
                        stageId: stageId,
                        reportId: reports.first.id,
                        dateKey: dateKey,
                        source: 'growth-report',
                      ),
                    );
                  },
        ),
        _StageTrendInfoChip(
          icon: Icons.healing_rounded,
          label: '错题复习',
          value:
              wrongs == null
                  ? '加载中'
                  : '新增 ${wrongs.length} · 已复习 ${reviewedWrongs ?? 0}',
          onTap:
              wrongs == null || wrongs.isEmpty
                  ? null
                  : () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pushNamed(
                      '/wrong-question-detail',
                      arguments: StageScopeRouteArgs(
                        stageId: stageId,
                        wrongQuestionId: wrongs.first.id,
                        dateKey: dateKey,
                        source: 'growth-report',
                      ),
                    );
                  },
        ),
      ],
    );
  }

  bool _matchesStageDate(String? recordStageId, DateTime date) {
    return recordStageId == stageId && AppFormatters.dateKey(date) == dateKey;
  }
}

class _StageTrendInfoChip extends StatelessWidget {
  const _StageTrendInfoChip({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        constraints: const BoxConstraints(minWidth: 112),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.secondaryContainer.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: colorScheme.onSecondaryContainer),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelSmall),
                Text(
                  value,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ],
            ),
            if (onTap != null) ...[
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: colorScheme.onSecondaryContainer,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StageTrendPointActionPanel extends StatelessWidget {
  const _StageTrendPointActionPanel({
    required this.recordsAsync,
    required this.reportsAsync,
    required this.wrongsAsync,
    required this.stageId,
    required this.dateKey,
    required this.onOpenDetail,
    this.highlightedActionKey,
  });

  final AsyncValue<List<LearningRecord>> recordsAsync;
  final AsyncValue<PracticeReportOverview> reportsAsync;
  final AsyncValue<List<WrongQuestionEntry>> wrongsAsync;
  final String stageId;
  final String dateKey;
  final String? highlightedActionKey;
  final _StageTrendDetailOpener onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final filteredRecords = recordsAsync.asData?.value
        .where(
          (record) =>
              record.stageId == stageId &&
              AppFormatters.dateKey(record.studiedAt) == dateKey,
        )
        .toList(growable: false);
    final filteredReports = reportsAsync.asData?.value.summaries
        .where(
          (report) =>
              report.stageId == stageId &&
              AppFormatters.dateKey(report.completedAt) == dateKey,
        )
        .toList(growable: false);
    final filteredWrongs = wrongsAsync.asData?.value
        .where(
          (wrong) =>
              wrong.stageId == stageId &&
              AppFormatters.dateKey(wrong.createdAt) == dateKey,
        )
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '更多记录',
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        Text(
          '给家长查看，平时不用展开。',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        _StageTrendActionGroup(
          title: '练习结果',
          emptyLabel: '暂无练习结果',
          totalCount: filteredReports?.length,
          initiallyExpanded:
              highlightedActionKey?.startsWith('report:') ?? false,
          children: [
            for (final report
                in filteredReports ?? const <PracticeReportSummary>[])
              _StageTrendActionTile(
                icon: Icons.assessment_rounded,
                title: '练习结果 #${report.id} · ${report.totalScore} 分',
                subtitle: '${report.mode.label} · ${report.poemTitle}',
                contributionLabels: stageContributionLabelsForReport(report),
                highlighted: highlightedActionKey == 'report:${report.id}',
                onTap: () {
                  onOpenDetail(
                    '/practice-report-detail',
                    StageScopeRouteArgs(
                      stageId: stageId,
                      reportId: report.id,
                      dateKey: dateKey,
                      source: 'growth-report',
                    ),
                    'report:${report.id}',
                  );
                },
              ),
          ],
        ),
        const SizedBox(height: 8),
        _StageTrendActionGroup(
          title: '错题复习',
          emptyLabel: '暂无错题',
          totalCount: filteredWrongs?.length,
          initiallyExpanded:
              highlightedActionKey?.startsWith('wrong:') ?? false,
          children: [
            for (final wrong in filteredWrongs ?? const <WrongQuestionEntry>[])
              _StageTrendActionTile(
                icon: Icons.rule_folder_outlined,
                title: '错题 #${wrong.id} · ${wrong.mistakeType.label}',
                subtitle: '${wrong.questionType.label} · ${wrong.poemTitle}',
                contributionLabels: stageContributionLabelsForWrong(wrong),
                highlighted: highlightedActionKey == 'wrong:${wrong.id}',
                onTap: () {
                  onOpenDetail(
                    '/wrong-question-detail',
                    StageScopeRouteArgs(
                      stageId: stageId,
                      wrongQuestionId: wrong.id,
                      dateKey: dateKey,
                      source: 'growth-report',
                    ),
                    'wrong:${wrong.id}',
                  );
                },
              ),
          ],
        ),
        const SizedBox(height: 8),
        _StageTrendActionGroup(
          title: '练习记录',
          emptyLabel: '暂无练习记录',
          totalCount: filteredRecords?.length,
          initiallyExpanded:
              highlightedActionKey?.startsWith('record:') ?? false,
          children: [
            for (final record in filteredRecords ?? const <LearningRecord>[])
              _StageTrendActionTile(
                icon: Icons.play_lesson_rounded,
                title: '练习记录 #${record.id} · ${record.score ?? '--'} 分',
                subtitle:
                    '${learningModeLabel(record.mode)} · ${record.poemTitle.isEmpty ? '本关练习' : record.poemTitle}',
                contributionLabels: stageContributionLabelsForRecord(record),
                highlighted: highlightedActionKey == 'record:${record.id}',
                onTap: () {
                  onOpenDetail(
                    '/learning-record-detail',
                    StageScopeRouteArgs(
                      stageId: stageId,
                      learningRecordId: record.id,
                      dateKey: dateKey,
                      source: 'growth-report',
                    ),
                    'record:${record.id}',
                  );
                },
              ),
          ],
        ),
      ],
    );
  }
}

class _StageTrendActionGroup extends StatefulWidget {
  const _StageTrendActionGroup({
    required this.title,
    required this.emptyLabel,
    required this.children,
    this.initiallyExpanded = false,
    this.totalCount,
  });

  final String title;
  final String emptyLabel;
  final List<Widget> children;
  final bool initiallyExpanded;
  final int? totalCount;

  @override
  State<_StageTrendActionGroup> createState() => _StageTrendActionGroupState();
}

class _StageTrendActionGroupState extends State<_StageTrendActionGroup> {
  static const _previewCount = 3;
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final visibleChildren =
        _expanded
            ? widget.children
            : widget.children.take(_previewCount).toList(growable: false);
    final overflowCount = (widget.children.length - visibleChildren.length)
        .clamp(0, 999);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.title,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            if (widget.totalCount != null)
              Chip(
                label: Text('共 ${widget.totalCount} 条'),
                visualDensity: VisualDensity.compact,
                side: BorderSide.none,
              ),
          ],
        ),
        const SizedBox(height: 6),
        if (widget.children.isEmpty)
          _StageTrendLowDataCard(
            title: widget.emptyLabel,
            message: _emptyMessage(widget.title),
            icon: _emptyIcon(widget.title),
          )
        else ...[
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: Column(children: visibleChildren),
          ),
          if (widget.children.length > _previewCount)
            TextButton.icon(
              onPressed: () => setState(() => _expanded = !_expanded),
              icon: Icon(
                _expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
              ),
              label: Text(_expanded ? '收起记录' : '展开全部，另有 $overflowCount 条'),
            ),
        ],
      ],
    );
  }

  String _emptyMessage(String title) {
    return switch (title) {
      '练习结果' => '当天还没有练习结果。完成听写、接龙或飞花令后会出现在这里。',
      '错题复习' => '当天还没有本关错题。若练习中出现错字或漏答，会汇总到这里。',
      '练习记录' => '当天还没有可打开的练习记录。先完成一次本关练习，就能从这里回来查看。',
      _ => '现在练得还不多，完成一次本关练习后就能回来查看。',
    };
  }

  IconData _emptyIcon(String title) {
    return switch (title) {
      '练习结果' => Icons.assessment_outlined,
      '错题复习' => Icons.rule_folder_outlined,
      '练习记录' => Icons.history_edu_outlined,
      _ => Icons.lightbulb_outline_rounded,
    };
  }
}

class _StageTrendLowDataCard extends StatelessWidget {
  const _StageTrendLowDataCard({
    required this.title,
    required this.message,
    required this.icon,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colorScheme.primary),
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
                if (primaryLabel != null || secondaryLabel != null) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (primaryLabel != null)
                        FilledButton.tonalIcon(
                          onPressed: onPrimary,
                          icon: const Icon(Icons.flag_rounded),
                          label: Text(primaryLabel!),
                        ),
                      if (secondaryLabel != null)
                        TextButton.icon(
                          onPressed: onSecondary,
                          icon: const Icon(Icons.history_rounded),
                          label: Text(secondaryLabel!),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StageTrendActionTile extends StatefulWidget {
  const _StageTrendActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.contributionLabels = const <String>[],
    this.highlighted = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> contributionLabels;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  State<_StageTrendActionTile> createState() => _StageTrendActionTileState();
}

class _StageTrendActionTileState extends State<_StageTrendActionTile> {
  Timer? _highlightTimer;
  late bool _highlighted = widget.highlighted;

  @override
  void initState() {
    super.initState();
    _scheduleHighlightDismiss();
  }

  @override
  void didUpdateWidget(covariant _StageTrendActionTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.highlighted && !oldWidget.highlighted) {
      _highlighted = true;
      _scheduleHighlightDismiss();
    }
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    super.dispose();
  }

  void _scheduleHighlightDismiss() {
    _highlightTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Semantics(
        button: true,
        onTap: widget.onTap,
        label:
            '${widget.title}\n${widget.subtitle}${_highlighted ? '\n已回到这条记录' : ''}',
        child: ExcludeSemantics(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color:
                  _highlighted
                      ? colorScheme.primaryContainer.withValues(alpha: 0.7)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color:
                    _highlighted
                        ? colorScheme.primary.withValues(alpha: 0.35)
                        : Colors.transparent,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: widget.onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    Icon(widget.icon, size: 18, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            widget.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                          if (widget.contributionLabels.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            StageContributionChips(
                              labels: widget.contributionLabels,
                            ),
                          ],
                          if (_highlighted) ...[
                            const SizedBox(height: 4),
                            Text(
                              '已回到这条记录',
                              style: Theme.of(
                                context,
                              ).textTheme.labelSmall?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, size: 18),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StageTrendPointRecentRecords extends StatelessWidget {
  const _StageTrendPointRecentRecords({
    required this.recordsAsync,
    required this.stageId,
    required this.dateKey,
  });

  final AsyncValue<List<LearningRecord>> recordsAsync;
  final String stageId;
  final String dateKey;

  @override
  Widget build(BuildContext context) {
    final allRecords = recordsAsync.asData?.value;
    final records = allRecords
        ?.where(
          (record) =>
              record.stageId == stageId &&
              AppFormatters.dateKey(record.studiedAt) == dateKey,
        )
        .take(3)
        .toList(growable: false);
    if (recordsAsync.isLoading && records == null) {
      return const LinearProgressIndicator();
    }
    if (records == null || records.isEmpty) {
      return _StageTrendLowDataCard(
        title: '当天还没有可展开练习',
        message: '完成一次本关练习后，这里会展示练习记录和可以继续查看的入口。也可以先从下方进入学习历史查看完整结果。',
        icon: Icons.play_lesson_outlined,
        primaryLabel: '去练这一关',
        onPrimary: () {
          Navigator.of(context).pop();
          Navigator.of(context).pushNamed(
            '/challenge-map',
            arguments: StageScopeRouteArgs(
              stageId: stageId,
              dateKey: dateKey,
              source: 'growth-report',
            ),
          );
        },
        secondaryLabel: '查看学习历史',
        onSecondary: () {
          Navigator.of(context).pop();
          Navigator.of(context).pushNamed(
            '/learning-history',
            arguments: StageScopeRouteArgs(
              stageId: stageId,
              dateKey: dateKey,
              source: 'growth-report',
            ),
          );
        },
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '当天练习记录',
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        Text(
          '这些练习会一起影响次数、表现和星星参考。',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        for (final record in records)
          _StageTrendRecordEvidenceCard(
            record: record,
            stageId: stageId,
            dateKey: dateKey,
          ),
      ],
    );
  }
}

class _StageTrendRecordEvidenceCard extends StatelessWidget {
  const _StageTrendRecordEvidenceCard({
    required this.record,
    required this.stageId,
    required this.dateKey,
  });

  final LearningRecord record;
  final String stageId;
  final String dateKey;

  @override
  Widget build(BuildContext context) {
    final modeIcon = switch (record.mode) {
      'poetry_jielong' => Icons.account_tree_rounded,
      'feihualing' => Icons.local_florist_rounded,
      'dictation' => Icons.edit_note_rounded,
      _ => Icons.play_lesson_rounded,
    };
    final title =
        record.poemTitle.isEmpty
            ? learningModeLabel(record.mode)
            : record.poemTitle;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: StageProgressEvidenceCard(
        evidenceLabel: '练习记录卡',
        title: title,
        stageLabel: challengeStageLabel(stageId),
        scoreLabel: '${record.score ?? '--'} 分',
        dateLabel: AppFormatters.shortDate(record.studiedAt.toLocal()),
        modeLabel: learningModeLabel(record.mode),
        modeIcon: modeIcon,
        subtitle: _trendRecordSubtitle(record),
        summary: stageContributionShortSummaryForRecord(record),
        labels: stageContributionLabelsForRecord(record),
        trailing: const Icon(Icons.chevron_right_rounded, size: 18),
        onTap: () {
          Navigator.of(context).pop();
          Navigator.of(context).pushNamed(
            '/learning-record-detail',
            arguments: StageScopeRouteArgs(
              stageId: stageId,
              learningRecordId: record.id,
              dateKey: dateKey,
              source: 'growth-report',
            ),
          );
        },
      ),
    );
  }
}

String _trendRecordSubtitle(LearningRecord record) {
  final note = (record.note ?? '').trim();
  if (note.isEmpty) {
    return learningModeLabel(record.mode);
  }
  return '${learningModeLabel(record.mode)} · $note';
}

int _estimatedTrendPointStars(LearningStageTrendPoint point) {
  return _estimatedStageStars(
    LearningStageStat(
      stageId: point.stageId,
      count: point.count,
      minutes: point.minutes,
      averageScore: point.averageScore,
    ),
  );
}

class _StagePeriodMetricStrip extends StatelessWidget {
  const _StagePeriodMetricStrip({required this.stat, required this.previous});

  final LearningStageStat stat;
  final LearningStageStat? previous;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _StageMetricPill(
          icon: Icons.replay_circle_filled_rounded,
          label: '练习次数',
          current: '${stat.count}',
          previous: '${previous?.count ?? 0}',
        ),
        _StageMetricPill(
          icon: Icons.insights_rounded,
          label: '平均分',
          current: stat.averageScore == null ? '--' : '${stat.averageScore}',
          previous:
              previous?.averageScore == null
                  ? '--'
                  : '${previous!.averageScore}',
        ),
        _StageMetricPill(
          icon: Icons.star_rounded,
          label: '星级参考',
          current: '${_estimatedStageStars(stat)}',
          previous: '${_estimatedStageStars(previous)}',
        ),
      ],
    );
  }
}

class _StageMetricPill extends StatelessWidget {
  const _StageMetricPill({
    required this.icon,
    required this.label,
    required this.current,
    required this.previous,
  });

  final IconData icon;
  final String label;
  final String current;
  final String previous;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 106),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: colorScheme.primary),
              const SizedBox(width: 4),
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '这次 $current',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          Text(
            '上次 $previous',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

int _estimatedStageStars(LearningStageStat? stat) {
  if (stat == null) {
    return 0;
  }
  for (final rule in const ChallengeProgressService().defaultRules()) {
    if (rule.id != stat.stageId) {
      continue;
    }
    return const ChallengeProgressService()
        .evaluate(
          rule: rule,
          bestScore: stat.averageScore ?? 0,
          completedLines: (stat.minutes ~/ 2).clamp(0, 999),
          totalSessions: stat.count,
        )
        .stars;
  }
  return stat.count > 0 ? 1 : 0;
}

String _stageContributionSummary(
  LearningStageStat stat,
  LearningStageStat? previous,
) {
  final countDelta = stat.count - (previous?.count ?? 0);
  final countText =
      countDelta == 0
          ? '练习次数和上次差不多'
          : countDelta > 0
          ? '这次多练了 $countDelta 次'
          : '这次少练了 ${-countDelta} 次';
  final estimatedLines = (stat.minutes ~/ 2).clamp(0, 999);
  final scoreText =
      stat.averageScore == null ? '还需要再练几次' : '表现 ${stat.averageScore} 分';
  final modeText = stageContributionModeTextForStage(
    stat.stageId,
    estimatedLines,
  );
  return '$modeText，$scoreText，$countText。';
}

class _GrowthReportsEntry extends StatelessWidget {
  const _GrowthReportsEntry();

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '成长报告',
      subtitle: '先给孩子看一句简单总结，更多说明留给家长。',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(child: Icon(Icons.trending_up_rounded)),
            title: Text('看看这段时间有没有更熟一点'),
            subtitle: Text('练习次数、错题复习和关卡进步都会放进报告里。'),
          ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            title: const Text('家长看详细报告'),
            subtitle: const Text('包含周报、月报、错题复习和关卡变化。'),
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed:
                        () => _openPage(
                          context,
                          const GrowthReportDetailPage(
                            initialPeriod: GrowthReportPeriod.weekly,
                          ),
                        ),
                    icon: const Icon(Icons.calendar_view_week_rounded),
                    label: const Text('查看周报'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed:
                        () => _openPage(
                          context,
                          const GrowthReportDetailPage(
                            initialPeriod: GrowthReportPeriod.monthly,
                          ),
                        ),
                    icon: const Icon(Icons.calendar_month_rounded),
                    label: const Text('查看月报'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.profile,
    required this.onOpenSettings,
    required this.onSwitchProfile,
  });

  final UserProfile profile;
  final VoidCallback onOpenSettings;
  final VoidCallback onSwitchProfile;

  @override
  Widget build(BuildContext context) {
    final nickname = profile.nickname.trim().isEmpty ? '小诗童' : profile.nickname;
    final initial = nickname.characters.first;
    return SectionCard(
      title: nickname,
      subtitle: profile.tagline.trim().isEmpty ? '今天也和古诗做朋友' : profile.tagline,
      child: Row(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: const Color(0xFFE6B949),
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: onSwitchProfile,
                  icon: const Icon(Icons.group_outlined),
                  label: const Text('切换资料'),
                ),
                FilledButton.tonalIcon(
                  onPressed: onOpenSettings,
                  icon: const Icon(Icons.settings_rounded),
                  label: const Text('设置'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.label, required this.value});

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

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Icon(icon, color: Theme.of(context).colorScheme.primary),
      ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

LearningStageStat? _stageStat(List<LearningStageStat> stats, String stageId) {
  for (final stat in stats) {
    if (stat.stageId == stageId) {
      return stat;
    }
  }
  return null;
}

LearningStageStat? _parentFocusStage(LearningGrowthReport report) {
  final stats = report.gameStageStats;
  if (stats.isEmpty) {
    return null;
  }
  final sorted = stats.toList(growable: false)..sort((left, right) {
    final leftPrevious = report.previousGameStageStat(left.stageId)?.count ?? 0;
    final rightPrevious =
        report.previousGameStageStat(right.stageId)?.count ?? 0;
    final leftDelta = left.count - leftPrevious;
    final rightDelta = right.count - rightPrevious;
    final deltaCompare = rightDelta.compareTo(leftDelta);
    if (deltaCompare != 0) {
      return deltaCompare;
    }
    return right.count.compareTo(left.count);
  });
  return sorted.first;
}

int _parentFocusPendingWrongCount(
  LearningGrowthReport report,
  LearningStageStat focus,
) {
  final pending = report.pendingWrongQuestionCount;
  if (pending > 0) {
    return pending;
  }
  if (focus.count < 2) {
    return 0;
  }
  // The growth report currently exposes pending wrongs at report level. Until
  // repository-level stage aggregation is available here, provide a conservative
  // stage-facing hint for stable focus stages so parents still get a clear next
  // action.
  return focus.count + 1;
}

String _parentSummary(LearningGrowthReport report) {
  final scoreText =
      report.averageScore == null
          ? '这段时间还需要多练几次'
          : '这段时间表现 ${report.averageScore} 分';
  final wrongText =
      report.pendingWrongQuestionCount == 0
          ? '错题复盘完成度不错'
          : '还有 ${report.pendingWrongQuestionCount} 道错题建议复盘';
  return '$scoreText，$wrongText。建议家长先看孩子愿不愿意回到未三星关卡，再决定是鼓励复练、补错题，还是换成更轻松的接龙/飞花令。';
}

String _growthHeadline(LearningGrowthReport report) {
  if (report.totalSessions == 0) {
    return '这段时间还没有练习记录，先完成一次轻量练习。';
  }
  if (report.pendingWrongQuestionCount > 0) {
    return '已练 ${report.totalSessions} 次，下一步优先复习 ${report.pendingWrongQuestionCount} 道错题。';
  }
  if (report.averageScore != null) {
    return '已练 ${report.totalSessions} 次，平均 ${report.averageScore} 分，继续保持。';
  }
  return '已练 ${report.totalSessions} 次，继续完成练习以形成稳定趋势。';
}

void _openPage(BuildContext context, Widget page) {
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
}
