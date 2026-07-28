import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_providers.dart';
import '../../app/app_design.dart';
import '../../core/user_facing_error.dart';
import '../../domain/learning_models.dart';
import '../../domain/poem.dart';
import '../../domain/practice_models.dart';
import '../../services/game/challenge_progress_service.dart';
import '../../shared/widgets/poem_pinyin_text.dart';
import '../../shared/widgets/section_card.dart';
import '../dictation/dictation_page.dart';
import '../evaluation/evaluation_placeholder_page.dart';
import '../reading/reading_placeholder_page.dart';
import '../recite/recite_placeholder_page.dart';
import '../wrong_book/wrong_book_placeholder_page.dart';
import 'challenge_map_page.dart';
import 'feihualing_page.dart';
import 'poetry_jielong_page.dart';

class GamePage extends ConsumerStatefulWidget {
  const GamePage({super.key});

  @override
  ConsumerState<GamePage> createState() => _GamePageState();
}

class _GamePageState extends ConsumerState<GamePage> {
  late Future<_GameHubSnapshot> _snapshotFuture;

  @override
  void initState() {
    super.initState();
    _snapshotFuture = _loadSnapshot();
  }

  @override
  Widget build(BuildContext context) {
    final todayAsync = ref.watch(todayPoemProvider);
    final summaryAsync = ref.watch(learningSummaryProvider);
    final showPinyin = ref.watch(pinyinVisibleProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('练习'),
        actions: [
          IconButton(
            onPressed: _refreshAll,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '刷新练习页',
          ),
        ],
      ),
      body: ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SafeArea(
          top: false,
          child: FutureBuilder<_GameHubSnapshot>(
            future: _snapshotFuture,
            builder: (context, snapshot) {
              final hub = snapshot.data;
              final summary = summaryAsync.asData?.value;
              final todayBundle = todayAsync.asData?.value;
              final recommendedPoem =
                  todayBundle?.poem ?? hub?.practicePoems.firstOrNull;

              return RefreshIndicator(
                onRefresh: _refreshAll,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppLayout.readingMaxWidth,
                    ),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.large,
                        AppSpacing.medium,
                        AppSpacing.large,
                        AppSpacing.xLarge,
                      ),
                      children: [
                        _GameHeroCard(
                          summary: summary,
                          todayBundle: todayBundle,
                          pendingWrongCount: hub?.pendingWrongCount ?? 0,
                          onPrimaryAction:
                              hub != null && hub.pendingWrongCount > 0
                                  ? () => _openPage(
                                    const WrongBookPlaceholderPage(),
                                  )
                                  : () => _openPage(
                                    ReadingPlaceholderPage(
                                      poemId: recommendedPoem?.id,
                                    ),
                                  ),
                          onSecondaryAction:
                              () => _openPage(
                                RecitePlaceholderPage(
                                  poemId: recommendedPoem?.id,
                                ),
                              ),
                        ),
                        const SizedBox(height: 16),
                        if (snapshot.connectionState ==
                                ConnectionState.waiting &&
                            hub == null)
                          const Card(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: LinearProgressIndicator(),
                            ),
                          )
                        else if (snapshot.hasError && hub == null)
                          SectionCard(
                            title: '练习入口加载失败',
                            subtitle: '下拉可重试，已有练习页不受影响。',
                            child: Text(
                              UserFacingErrorMapper.message(
                                snapshot.error!,
                                fallbackMessage: '练习入口加载失败，请稍后重试。',
                              ),
                            ),
                          )
                        else if (hub != null) ...[
                          _RecommendedPoemCard(
                            poem: recommendedPoem,
                            showPinyin: showPinyin,
                          ),
                          const SizedBox(height: 16),
                          _GameEntryGrid(
                            entries: [
                              _GameEntryData(
                                title: '朗读',
                                subtitle: '先把字音和节奏读顺。',
                                icon: Icons.graphic_eq_rounded,
                                color: const Color(0xFFFFC86B),
                                onTap:
                                    () => _openPage(
                                      ReadingPlaceholderPage(
                                        poemId: recommendedPoem?.id,
                                      ),
                                    ),
                              ),
                              _GameEntryData(
                                title: '背诵',
                                subtitle: '遮住提示，试着自己背出来。',
                                icon: Icons.auto_stories_rounded,
                                color: const Color(0xFFC9E8A5),
                                onTap:
                                    () => _openPage(
                                      RecitePlaceholderPage(
                                        poemId: recommendedPoem?.id,
                                      ),
                                    ),
                              ),
                              _GameEntryData(
                                title: '听写',
                                subtitle: '逐句默写，错了就进错题本。',
                                icon: Icons.edit_note_rounded,
                                color: const Color(0xFFB6E3FF),
                                onTap: () => _openPage(const DictationPage()),
                              ),
                              _GameEntryData(
                                title: '小测验',
                                subtitle: '做几道题，看看哪里还不熟。',
                                icon: Icons.fact_check_rounded,
                                color: const Color(0xFFFFB7A5),
                                onTap:
                                    () => _openPage(
                                      const EvaluationPlaceholderPage(
                                        initialMode: PracticeMode.evaluation,
                                        pageTitle: '小测验',
                                      ),
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _ChallengeMapSection(
                            stages: hub.challengeStages,
                            onOpenMap:
                                () => _openPage(
                                  ChallengeMapPage(
                                    stages: hub.challengeStages,
                                    onOpenJielong:
                                        () => _openPage(
                                          const PoetryJielongPage(),
                                        ),
                                    onOpenFeihualing:
                                        () => _openPage(const FeihualingPage()),
                                    onOpenDictation:
                                        () => _openPage(const DictationPage()),
                                  ),
                                ),
                            onOpenJielong:
                                () => _openPage(const PoetryJielongPage()),
                            onOpenFeihualing:
                                () => _openPage(const FeihualingPage()),
                            onOpenDictation:
                                () => _openPage(const DictationPage()),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<_GameHubSnapshot> _loadSnapshot() async {
    final practiceRepository = ref.read(practiceRepositoryProvider);
    final learningRepository = ref.read(learningRepositoryProvider);
    final challengeService = ref.read(challengeProgressServiceProvider);
    final practicePoems = await practiceRepository.fetchPracticePoems(limit: 8);
    final wrongEntries = await practiceRepository.fetchWrongQuestions(
      query: const WrongQuestionQuery(limit: 200),
    );
    final modeProgress = await learningRepository.fetchChallengeModeProgress();
    final challengeStages = challengeService
        .defaultRules()
        .map((rule) {
          final progress = modeProgress[rule.mode];
          return challengeService.evaluate(
            rule: rule,
            bestScore: progress?.bestScore ?? 0,
            completedLines: progress?.completedLines ?? 0,
            totalSessions: progress?.totalSessions ?? 0,
          );
        })
        .toList(growable: false);

    var pendingWrongCount = 0;
    for (final entry in wrongEntries) {
      if (!entry.isReviewed) {
        pendingWrongCount += 1;
      }
    }

    return _GameHubSnapshot(
      practicePoems: practicePoems,
      pendingWrongCount: pendingWrongCount,
      challengeStages: challengeStages,
    );
  }

  Future<void> _refreshAll() async {
    ref.invalidate(todayPoemProvider);
    ref.invalidate(learningSummaryProvider);
    ref.invalidate(recentLearningRecordsProvider);

    final future = _loadSnapshot();
    setState(() {
      _snapshotFuture = future;
    });
    await future;
  }

  Future<void> _openPage(Widget page) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => page));
    if (!mounted) {
      return;
    }
    await _refreshAll();
  }
}

class _GameHeroCard extends StatelessWidget {
  const _GameHeroCard({
    required this.summary,
    required this.todayBundle,
    required this.pendingWrongCount,
    required this.onPrimaryAction,
    required this.onSecondaryAction,
  });

  final LearningSummary? summary;
  final DailyPoemBundle? todayBundle;
  final int pendingWrongCount;
  final Future<void> Function() onPrimaryAction;
  final Future<void> Function() onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final todayPoem = todayBundle?.poem;
    final compactLayout =
        MediaQuery.sizeOf(context).width < AppLayout.compactWidth;
    return Container(
      padding: EdgeInsets.all(
        compactLayout ? AppSpacing.large : AppSpacing.xLarge,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadii.feature),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '今天练哪一步？',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            todayPoem == null
                ? '先朗读，再背诵或听写。'
                : '今日推荐：《${todayPoem.title}》。先读准，再练习。',
          ),
          if (!compactLayout) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _HeroStatPill(
                  label: '连续',
                  value: '${summary?.streakDays ?? 0} 天',
                ),
                _HeroStatPill(
                  label: '时长',
                  value: '${summary?.totalMinutes ?? 0} 分钟',
                ),
                _HeroStatPill(label: '待复习', value: '$pendingWrongCount 题'),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: onPrimaryAction,
                icon: Icon(
                  pendingWrongCount > 0
                      ? Icons.inventory_2_rounded
                      : Icons.graphic_eq_rounded,
                ),
                label: Text(pendingWrongCount > 0 ? '先复习错题' : '读一读'),
              ),
              FilledButton.tonalIcon(
                onPressed: onSecondaryAction,
                icon: const Icon(Icons.auto_stories_rounded),
                label: const Text('背一背'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecommendedPoemCard extends StatelessWidget {
  const _RecommendedPoemCard({required this.poem, required this.showPinyin});

  final Poem? poem;
  final bool showPinyin;

  @override
  Widget build(BuildContext context) {
    final poem = this.poem;
    final compactLayout =
        MediaQuery.sizeOf(context).width < AppLayout.compactWidth;
    return SectionCard(
      title: '今日热身',
      subtitle: compactLayout ? null : '先看今天推荐的诗，再从下面四个入口开始练。',
      child:
          poem == null
              ? const Text('导入诗词后，这里会显示今日推荐。')
              : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '《${poem.title}》 ${poem.dynasty} · ${poem.author}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  PoemPinyinText(
                    poem: poem,
                    showPinyin: showPinyin,
                    variant: PoemPinyinTextVariant.preview,
                    maxVisibleLines: compactLayout ? 1 : 2,
                    alignment: Alignment.centerLeft,
                  ),
                ],
              ),
    );
  }
}

class _ChallengeMapSection extends StatelessWidget {
  const _ChallengeMapSection({
    required this.stages,
    required this.onOpenMap,
    required this.onOpenJielong,
    required this.onOpenFeihualing,
    required this.onOpenDictation,
  });

  final List<ChallengeStageProgress> stages;
  final Future<void> Function() onOpenMap;
  final Future<void> Function() onOpenJielong;
  final Future<void> Function() onOpenFeihualing;
  final Future<void> Function() onOpenDictation;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '更多挑战',
      subtitle: '想多练一会儿时，再打开路线和关卡。',
      trailing: TextButton.icon(
        onPressed: onOpenMap,
        icon: const Icon(Icons.map_rounded),
        label: const Text('打开地图'),
      ),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        title: const Text('查看推荐关卡'),
        subtitle: const Text('默认先完成上面的基础练习。'),
        children: stages
            .map(
              (stage) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ChallengeStageCard(
                  stage: stage,
                  onTap: _tapForMode(stage.rule.mode),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  Future<void> Function() _tapForMode(String mode) {
    switch (mode) {
      case 'poetry_jielong':
        return onOpenJielong;
      case 'feihualing':
        return onOpenFeihualing;
      case 'dictation':
        return onOpenDictation;
      default:
        return onOpenJielong;
    }
  }
}

class _ChallengeStageCard extends StatelessWidget {
  const _ChallengeStageCard({required this.stage, required this.onTap});

  final ChallengeStageProgress stage;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.card),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFFFFF2D6),
                  child: Icon(
                    _modeIcon(stage.rule.mode),
                    color: const Color(0xFF8A5A12),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stage.rule.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '最好 ${stage.bestScore} 分 · 完成 ${stage.completedLines}/${stage.rule.requiredLines}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                ChallengeStarRow(stars: stage.stars),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: stage.lineProgress,
                backgroundColor: const Color(0xFFF1E7D2),
                color: const Color(0xFFD49A35),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _modeIcon(String mode) {
    switch (mode) {
      case 'poetry_jielong':
        return Icons.link_rounded;
      case 'feihualing':
        return Icons.local_florist_rounded;
      case 'dictation':
        return Icons.edit_note_rounded;
      default:
        return Icons.flag_rounded;
    }
  }
}

class _GameEntryGrid extends StatelessWidget {
  const _GameEntryGrid({required this.entries});

  final List<_GameEntryData> entries;

  @override
  Widget build(BuildContext context) {
    final compactLayout =
        MediaQuery.sizeOf(context).width < AppLayout.compactWidth;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: compactLayout ? 10 : 12,
        crossAxisSpacing: compactLayout ? 10 : 12,
        childAspectRatio: compactLayout ? 1.34 : 1.08,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) => _GameEntryCard(entry: entries[index]),
    );
  }
}

class _GameEntryCard extends StatelessWidget {
  const _GameEntryCard({required this.entry});

  final _GameEntryData entry;

  @override
  Widget build(BuildContext context) {
    final compactLayout =
        MediaQuery.sizeOf(context).width < AppLayout.compactWidth;
    return Semantics(
      button: true,
      label: '${entry.title}，${entry.subtitle}',
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.feature),
        onTap: entry.onTap,
        child: Container(
          padding: EdgeInsets.all(compactLayout ? 13 : 16),
          decoration: BoxDecoration(
            color: entry.color,
            borderRadius: BorderRadius.circular(AppRadii.feature),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                entry.icon,
                size: compactLayout ? 26 : 30,
                color: const Color(0xFF5F4211),
              ),
              const Spacer(),
              Text(
                entry.title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              SizedBox(height: compactLayout ? 4 : 6),
              Text(
                entry.subtitle,
                maxLines: compactLayout ? 1 : 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroStatPill extends StatelessWidget {
  const _HeroStatPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label $value',
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _GameHubSnapshot {
  const _GameHubSnapshot({
    required this.practicePoems,
    required this.pendingWrongCount,
    required this.challengeStages,
  });

  final List<Poem> practicePoems;
  final int pendingWrongCount;
  final List<ChallengeStageProgress> challengeStages;
}

class _GameEntryData {
  const _GameEntryData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Future<void> Function() onTap;
}
