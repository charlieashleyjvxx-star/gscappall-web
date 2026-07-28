import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_providers.dart';
import '../../core/user_facing_error.dart';
import '../../core/app_constants.dart';
import '../../domain/learning_models.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/poem_pinyin_text.dart';

class StudyCardsPage extends ConsumerStatefulWidget {
  const StudyCardsPage({super.key});

  @override
  ConsumerState<StudyCardsPage> createState() => _StudyCardsPageState();
}

class _StudyCardsPageState extends ConsumerState<StudyCardsPage> {
  bool _showBack = false;
  bool _showMore = false;
  int _index = 0;
  _StudyCardViewMode _viewMode = _StudyCardViewMode.originalWithPinyin;
  StudyCardQuery _query = const StudyCardQuery();
  late Future<_StudyCardPageData> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadPageData();
  }

  @override
  Widget build(BuildContext context) {
    final showPinyin = ref.watch(pinyinVisibleProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('学习卡片'),
        actions: [
          IconButton(
            onPressed: _refreshCards,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '重新加载',
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<_StudyCardPageData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return EmptyState(
                title: '学习卡片加载失败',
                description: UserFacingErrorMapper.message(
                  snapshot.error!,
                  fallbackMessage: '学习卡片加载失败，请稍后重试。',
                ),
                icon: Icons.error_outline_rounded,
                action: FilledButton(
                  onPressed: _refreshCards,
                  child: const Text('重新加载'),
                ),
              );
            }

            final data = snapshot.data ?? const _StudyCardPageData.empty();
            final deck = data.deck;
            if (deck.isEmpty) {
              return EmptyState(
                title: '当前筛选下还没有卡片',
                description: '可以切回全部卡片，或先收藏几首常练诗词。',
                icon: Icons.style_outlined,
                action: FilledButton(
                  onPressed: () {
                    setState(() {
                      _query = const StudyCardQuery();
                      _index = 0;
                      _showBack = false;
                      _future = _loadPageData();
                    });
                  },
                  child: const Text('显示全部卡片'),
                ),
              );
            }

            final currentIndex = _index.clamp(0, deck.length - 1);
            final currentEntry = deck[currentIndex];
            final size = MediaQuery.sizeOf(context);
            final compactWidth = size.width < 390;
            final compactHeight = size.height < 760;
            final pagePadding = compactWidth ? 16.0 : 20.0;
            final cardHeight =
                compactHeight ? (compactWidth ? 340.0 : 370.0) : 420.0;
            final sectionGap = compactWidth ? 12.0 : 16.0;

            return ListView(
              padding: EdgeInsets.all(pagePadding),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '第 ${currentIndex + 1} / ${deck.length} 张',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => setState(() => _showMore = !_showMore),
                      icon: Icon(
                        _showMore
                            ? Icons.expand_less_rounded
                            : Icons.tune_rounded,
                      ),
                      label: Text(_showMore ? '收起' : '更多'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => setState(() => _showBack = !_showBack),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    height: cardHeight,
                    padding: EdgeInsets.all(compactWidth ? 18 : 24),
                    decoration: BoxDecoration(
                      color: _showBack ? const Color(0xFFF7ECD4) : Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 22,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child:
                        _showBack
                            ? _StudyCardBack(
                              entry: currentEntry,
                              showPinyin:
                                  showPinyin &&
                                  _viewMode ==
                                      _StudyCardViewMode.originalWithPinyin,
                              hideHints:
                                  _viewMode == _StudyCardViewMode.selfTest,
                              onEditNote:
                                  () => _editNote(currentEntry, currentIndex),
                            )
                            : _StudyCardFront(
                              entry: currentEntry,
                              mode: _viewMode,
                              globalShowPinyin: showPinyin,
                            ),
                  ),
                ),
                SizedBox(height: sectionGap),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed:
                            currentIndex == 0
                                ? null
                                : () {
                                  setState(() {
                                    _index = currentIndex - 1;
                                    _showBack = false;
                                  });
                                },
                        icon: const Icon(Icons.chevron_left_rounded),
                        label: const Text('上一张'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed:
                            currentIndex >= deck.length - 1
                                ? null
                                : () {
                                  setState(() {
                                    _index = currentIndex + 1;
                                    _showBack = false;
                                  });
                                },
                        icon: const Icon(Icons.chevron_right_rounded),
                        label: const Text('下一张'),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: sectionGap),
                _StudyCardActions(
                  entry: currentEntry,
                  preferredIndex: currentIndex,
                  onToggleFavorite: _toggleFavorite,
                  onEditNote: _editNote,
                  onMarkReview: _markReview,
                ),
                if (_showMore) ...[
                  SizedBox(height: sectionGap),
                  _StudyCardMorePanel(
                    query: _query,
                    options: data.options,
                    entry: currentEntry,
                    preferredIndex: currentIndex,
                    mode: _viewMode,
                    globalShowPinyin: showPinyin,
                    onQueryChanged: _updateQuery,
                    onModeChanged: (mode) {
                      setState(() {
                        _viewMode = mode;
                        _showBack = false;
                      });
                    },
                    onToggleFavorite: _toggleFavorite,
                    onEditNote: _editNote,
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Future<_StudyCardPageData> _loadPageData() async {
    await ref
        .read(poemRepositoryProvider)
        .importSeedIfNeeded(seedVersion: AppConstants.seedVersion);
    final deck = await ref.read(studyCardDeckProvider(_query).future);
    final options = await ref.read(studyCardFilterOptionsProvider.future);
    return _StudyCardPageData(deck: deck, options: options);
  }

  Future<void> _reloadCards({int? keepPoemId, int? preferredIndex}) async {
    final future = _loadPageData();
    setState(() {
      _showBack = false;
      _future = future;
    });

    final _StudyCardPageData data;
    try {
      data = await future;
    } catch (_) {
      return;
    }
    if (!mounted) {
      return;
    }

    var nextIndex = 0;
    if (data.deck.isNotEmpty) {
      if (keepPoemId != null) {
        final keepIndex = data.deck.indexWhere(
          (entry) => entry.poem.id == keepPoemId,
        );
        nextIndex =
            keepIndex >= 0
                ? keepIndex
                : (preferredIndex ?? 0).clamp(0, data.deck.length - 1);
      } else if (preferredIndex != null) {
        nextIndex = preferredIndex.clamp(0, data.deck.length - 1);
      }
    }

    setState(() => _index = nextIndex);
  }

  Future<void> _markReview({
    required StudyCardDeckEntry entry,
    required bool remembered,
    required int preferredIndex,
  }) async {
    await ref
        .read(learningRepositoryProvider)
        .markStudyCardReview(poemId: entry.poem.id, remembered: remembered);
    ref.invalidate(learningSummaryProvider);
    ref.invalidate(recentLearningRecordsProvider);
    ref.invalidate(learningHistoryProvider);
    ref.invalidate(studyCardDeckProvider);
    await _reloadCards(preferredIndex: preferredIndex);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(remembered ? '已安排后续复习节奏' : '已加入待复习队列，明天再看一遍')),
    );
  }

  Future<void> _toggleFavorite({
    required StudyCardDeckEntry entry,
    required int preferredIndex,
  }) async {
    await ref
        .read(poemRepositoryProvider)
        .setFavorite(entry.poem.id, !entry.isFavorite);
    ref.invalidate(favoritesProvider);
    ref.invalidate(learningSummaryProvider);
    ref.invalidate(studyCardDeckProvider);

    await _reloadCards(
      keepPoemId:
          _query.filterType == StudyCardFilterType.favorites
              ? null
              : entry.poem.id,
      preferredIndex: preferredIndex,
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(entry.isFavorite ? '已取消收藏' : '已加入收藏')),
    );
  }

  Future<void> _editNote(StudyCardDeckEntry entry, int preferredIndex) async {
    final note = StudyCardNoteDraft.normalizeSubmitted(
      await _showNoteSheet(entry.progress.note),
    );
    if (note == null) {
      return;
    }

    await ref
        .read(learningRepositoryProvider)
        .saveStudyCardNote(poemId: entry.poem.id, note: note);
    ref.invalidate(studyCardDeckProvider);
    await _reloadCards(
      keepPoemId: entry.poem.id,
      preferredIndex: preferredIndex,
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(note.isEmpty ? '笔记已清空' : '笔记已保存')));
  }

  Future<String?> _showNoteSheet(String? initialNote) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _StudyCardNoteSheet(initialNote: initialNote ?? ''),
    );
  }

  void _updateQuery(StudyCardQuery query) {
    setState(() {
      _query = query;
      _index = 0;
      _showBack = false;
      _future = _loadPageData();
    });
  }

  void _refreshCards() {
    setState(() {
      _index = 0;
      _showBack = false;
      _future = _loadPageData();
    });
  }
}

class _StudyCardPageData {
  const _StudyCardPageData({required this.deck, required this.options});

  const _StudyCardPageData.empty()
    : deck = const <StudyCardDeckEntry>[],
      options = const StudyCardFilterOptions(
        dynasties: <String>[],
        authors: <String>[],
        categories: <String>[],
      );

  final List<StudyCardDeckEntry> deck;
  final StudyCardFilterOptions options;
}

enum _StudyCardViewMode { originalWithPinyin, originalOnly, selfTest }

class _StudyCardModeSelector extends StatelessWidget {
  const _StudyCardModeSelector({
    required this.mode,
    required this.globalShowPinyin,
    required this.onChanged,
  });

  final _StudyCardViewMode mode;
  final bool globalShowPinyin;
  final ValueChanged<_StudyCardViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE8D9BC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '学习模式',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            globalShowPinyin
                ? '按当前目标选择提示强度，轻点卡片翻面查看内容。'
                : '全局拼音已关闭，如需拼音可到“我的/设置”打开。',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF6B5B45),
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<_StudyCardViewMode>(
            selected: {mode},
            showSelectedIcon: false,
            onSelectionChanged: (selection) => onChanged(selection.single),
            segments: const [
              ButtonSegment(
                value: _StudyCardViewMode.originalWithPinyin,
                label: Text('原文+拼音'),
                icon: Icon(Icons.translate_rounded),
              ),
              ButtonSegment(
                value: _StudyCardViewMode.originalOnly,
                label: Text('只看原文'),
                icon: Icon(Icons.menu_book_rounded),
              ),
              ButtonSegment(
                value: _StudyCardViewMode.selfTest,
                label: Text('自测'),
                icon: Icon(Icons.visibility_off_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StudyCardFilterPanel extends StatelessWidget {
  const _StudyCardFilterPanel({
    required this.query,
    required this.options,
    required this.onQueryChanged,
  });

  final StudyCardQuery query;
  final StudyCardFilterOptions options;
  final ValueChanged<StudyCardQuery> onQueryChanged;

  @override
  Widget build(BuildContext context) {
    final optionValues = _optionValues();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE8D9BC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '筛选卡片',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: StudyCardFilterType.values
                .map((type) {
                  final selected = query.filterType == type;
                  return ChoiceChip(
                    label: Text(_filterLabel(type)),
                    selected: selected,
                    onSelected: (_) {
                      onQueryChanged(
                        StudyCardQuery(
                          filterType: type,
                          filterValue:
                              type == query.filterType
                                  ? query.filterValue
                                  : null,
                        ),
                      );
                    },
                  );
                })
                .toList(growable: false),
          ),
          if (query.requiresValue && optionValues.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: optionValues
                  .map((value) {
                    final selected = query.filterValue == value;
                    return FilterChip(
                      label: Text(value),
                      selected: selected,
                      onSelected: (_) {
                        onQueryChanged(
                          query.copyWith(
                            filterValue: selected ? null : value,
                            clearValue: selected,
                          ),
                        );
                      },
                    );
                  })
                  .toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }

  List<String> _optionValues() {
    switch (query.filterType) {
      case StudyCardFilterType.dynasty:
        return options.dynasties;
      case StudyCardFilterType.author:
        return options.authors;
      case StudyCardFilterType.category:
        return options.categories;
      case StudyCardFilterType.all:
      case StudyCardFilterType.favorites:
      case StudyCardFilterType.dueReview:
      case StudyCardFilterType.newCards:
      case StudyCardFilterType.mastered:
        return const <String>[];
    }
  }

  String _filterLabel(StudyCardFilterType type) {
    switch (type) {
      case StudyCardFilterType.all:
        return '全部';
      case StudyCardFilterType.dynasty:
        return '按朝代';
      case StudyCardFilterType.author:
        return '按作者';
      case StudyCardFilterType.category:
        return '按主题';
      case StudyCardFilterType.favorites:
        return '只看收藏';
      case StudyCardFilterType.dueReview:
        return '待复习';
      case StudyCardFilterType.newCards:
        return '新卡片';
      case StudyCardFilterType.mastered:
        return '已记住';
    }
  }
}

class _StudyCardActions extends StatelessWidget {
  const _StudyCardActions({
    required this.entry,
    required this.preferredIndex,
    required this.onToggleFavorite,
    required this.onEditNote,
    required this.onMarkReview,
  });

  final StudyCardDeckEntry entry;
  final int preferredIndex;
  final Future<void> Function({
    required StudyCardDeckEntry entry,
    required int preferredIndex,
  })
  onToggleFavorite;
  final Future<void> Function(StudyCardDeckEntry entry, int preferredIndex)
  onEditNote;
  final Future<void> Function({
    required StudyCardDeckEntry entry,
    required bool remembered,
    required int preferredIndex,
  })
  onMarkReview;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 360;
        final review = FilledButton.tonalIcon(
          onPressed:
              () => onMarkReview(
                entry: entry,
                remembered: false,
                preferredIndex: preferredIndex,
              ),
          icon: const Icon(Icons.replay_rounded),
          label: const Text('再看一遍'),
        );
        final remembered = FilledButton.icon(
          onPressed:
              () => onMarkReview(
                entry: entry,
                remembered: true,
                preferredIndex: preferredIndex,
              ),
          icon: const Icon(Icons.done_rounded),
          label: const Text('我记住了'),
        );

        if (!twoColumns) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [remembered, const SizedBox(height: 8), review],
          );
        }

        return Row(
          children: [
            Expanded(child: review),
            const SizedBox(width: 12),
            Expanded(child: remembered),
          ],
        );
      },
    );
  }
}

class _StudyCardMorePanel extends StatelessWidget {
  const _StudyCardMorePanel({
    required this.query,
    required this.options,
    required this.entry,
    required this.preferredIndex,
    required this.mode,
    required this.globalShowPinyin,
    required this.onQueryChanged,
    required this.onModeChanged,
    required this.onToggleFavorite,
    required this.onEditNote,
  });

  final StudyCardQuery query;
  final StudyCardFilterOptions options;
  final StudyCardDeckEntry entry;
  final int preferredIndex;
  final _StudyCardViewMode mode;
  final bool globalShowPinyin;
  final ValueChanged<StudyCardQuery> onQueryChanged;
  final ValueChanged<_StudyCardViewMode> onModeChanged;
  final Future<void> Function({
    required StudyCardDeckEntry entry,
    required int preferredIndex,
  })
  onToggleFavorite;
  final Future<void> Function(StudyCardDeckEntry entry, int preferredIndex)
  onEditNote;

  @override
  Widget build(BuildContext context) {
    final favorite = OutlinedButton.icon(
      onPressed:
          () => onToggleFavorite(entry: entry, preferredIndex: preferredIndex),
      icon: Icon(
        entry.isFavorite
            ? Icons.favorite_rounded
            : Icons.favorite_border_rounded,
      ),
      label: Text(entry.isFavorite ? '取消收藏' : '加入收藏'),
    );
    final note = OutlinedButton.icon(
      onPressed: () => onEditNote(entry, preferredIndex),
      icon: const Icon(Icons.sticky_note_2_outlined),
      label: Text(entry.progress.hasNote ? '编辑笔记' : '写笔记'),
    );

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      initiallyExpanded: true,
      title: const Text('更多设置'),
      subtitle: const Text('换卡片、提示方式和笔记放在这里。'),
      children: [
        _StudyCardModeSelector(
          mode: mode,
          globalShowPinyin: globalShowPinyin,
          onChanged: onModeChanged,
        ),
        if (mode == _StudyCardViewMode.selfTest) ...[
          const SizedBox(height: 12),
          const _SelfTestHint(),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: favorite),
            const SizedBox(width: 8),
            Expanded(child: note),
          ],
        ),
        const SizedBox(height: 12),
        _StudyCardProgressPanel(entry: entry),
        const SizedBox(height: 12),
        _StudyCardFilterPanel(
          query: query,
          options: options,
          onQueryChanged: onQueryChanged,
        ),
      ],
    );
  }
}

class _SelfTestHint extends StatelessWidget {
  const _SelfTestHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF6EE),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        '自测模式会先隐藏译文、注释和笔记。先在心里背出内容，再翻面核对，最后用“再看一遍”或“我记住了”安排下次复习。',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: const Color(0xFF315D3B),
          height: 1.5,
        ),
      ),
    );
  }
}

class _StudyCardFront extends StatelessWidget {
  const _StudyCardFront({
    required this.entry,
    required this.mode,
    required this.globalShowPinyin,
  });

  final StudyCardDeckEntry entry;
  final _StudyCardViewMode mode;
  final bool globalShowPinyin;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            mode == _StudyCardViewMode.selfTest ? '先自测，再翻面核对' : '轻点卡片翻面',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const Spacer(),
          Center(
            child: Column(
              children: [
                Text(
                  entry.poem.title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text('${entry.poem.dynasty} · ${entry.poem.author}'),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (entry.poem.category.isNotEmpty)
                      Chip(label: Text(entry.poem.category)),
                    Chip(label: Text('难度 ${entry.poem.difficulty}')),
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),
          _NotePreview(progress: entry.progress),
        ],
      ),
    );
  }
}

class _StudyCardBack extends StatelessWidget {
  const _StudyCardBack({
    required this.entry,
    required this.showPinyin,
    required this.hideHints,
    required this.onEditNote,
  });

  final StudyCardDeckEntry entry;
  final bool showPinyin;
  final bool hideHints;
  final VoidCallback onEditNote;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  showPinyin ? '原文与拼音' : '原文',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onEditNote,
                icon: const Icon(Icons.sticky_note_2_outlined),
                label: Text(entry.progress.hasNote ? '编辑笔记' : '写笔记'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          PoemPinyinText(
            poem: entry.poem,
            showPinyin: showPinyin,
            variant: PoemPinyinTextVariant.study,
          ),
          if (!hideHints && entry.poem.translation.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SectionText(title: '译文', body: entry.poem.translation),
          ],
          if (!hideHints && entry.progress.hasNote) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '我的笔记',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(onPressed: onEditNote, child: const Text('编辑')),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F0DE),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                entry.progress.note!,
                style: const TextStyle(height: 1.6),
              ),
            ),
          ],
          if (!hideHints && entry.poem.annotation.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SectionText(title: '注释', body: entry.poem.annotation),
          ],
        ],
      ),
    );
  }
}

class _StudyCardProgressPanel extends StatelessWidget {
  const _StudyCardProgressPanel({required this.entry});

  final StudyCardDeckEntry entry;

  @override
  Widget build(BuildContext context) {
    final statusTheme = _statusTheme(entry.progress.memoryStatus);
    final nextReviewText =
        entry.isDueForReview
            ? '今天该复习'
            : StudyCardReviewSchedule.nextReviewLabel(
              entry.progress.nextReviewAt,
            );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE8D9BC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '复习进度',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              Chip(
                label: Text(statusTheme.label),
                backgroundColor: statusTheme.background,
                labelStyle: TextStyle(color: statusTheme.foreground),
              ),
              Chip(label: Text('复习 ${entry.progress.reviewCount} 次')),
              Chip(label: Text(nextReviewText)),
            ],
          ),
          if (entry.progress.hasNote) ...[
            const SizedBox(height: 12),
            Text(
              '笔记预览：${entry.progress.notePreview}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF6B5B45),
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  _StatusTheme _statusTheme(String memoryStatus) {
    switch (memoryStatus) {
      case 'learning':
        return const _StatusTheme(
          label: '学习中',
          background: Color(0xFFE9F6FF),
          foreground: Color(0xFF225F8A),
        );
      case 'review':
        return const _StatusTheme(
          label: '待复习',
          background: Color(0xFFFFF1D8),
          foreground: Color(0xFF8A5A12),
        );
      case 'mastered':
        return const _StatusTheme(
          label: '已记住',
          background: Color(0xFFE8F6E9),
          foreground: Color(0xFF2D6B39),
        );
      case 'new':
      default:
        return const _StatusTheme(
          label: '新卡片',
          background: Color(0xFFF2F0EA),
          foreground: Color(0xFF5D5447),
        );
    }
  }
}

class _StudyCardNoteSheet extends StatefulWidget {
  const _StudyCardNoteSheet({required this.initialNote});

  final String initialNote;

  @override
  State<_StudyCardNoteSheet> createState() => _StudyCardNoteSheetState();
}

class _StudyCardNoteSheetState extends State<_StudyCardNoteSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialNote);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '学习笔记',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            '写下记忆提示、易混字词，或给这首诗起一个自己的小标题。',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF6B5B45),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            minLines: 4,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText: '例如：第二句容易混，复习时先默背再看拼音。',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              TextButton(
                onPressed: () => _closeWith(''),
                child: const Text('清空笔记'),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => _closeWith(null),
                child: const Text('取消'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => _closeWith(_controller.text),
                child: const Text('保存'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _closeWith(String? value) {
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(value);
  }
}

class _SectionText extends StatelessWidget {
  const _SectionText({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(body, style: const TextStyle(height: 1.6)),
      ],
    );
  }
}

class _NotePreview extends StatelessWidget {
  const _NotePreview({required this.progress});

  final StudyCardProgress progress;

  @override
  Widget build(BuildContext context) {
    if (!progress.hasNote) {
      return Text(
        '翻面后可查看原文、译文和笔记',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF6B5B45)),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8EA),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '笔记：${progress.notePreview}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: const Color(0xFF6B5B45),
          height: 1.4,
        ),
      ),
    );
  }
}

class _StatusTheme {
  const _StatusTheme({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;
}
