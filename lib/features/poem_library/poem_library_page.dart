import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_providers.dart';
import '../../app/app_design.dart';
import '../../core/user_facing_error.dart';
import '../../domain/poem.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/poem_list_tile.dart';
import '../poem_detail/poem_detail_page.dart';

class PoemLibraryPage extends ConsumerStatefulWidget {
  const PoemLibraryPage({super.key});

  @override
  ConsumerState<PoemLibraryPage> createState() => _PoemLibraryPageState();
}

class _PoemLibraryPageState extends ConsumerState<PoemLibraryPage> {
  final TextEditingController _searchController = TextEditingController();
  PoemQuery _query = const PoemQuery();
  late Future<List<Poem>> _future;

  @override
  void initState() {
    super.initState();
    _query = ref.read(poemLibraryQueryProvider).copyWith(clearGrade: true);
    if (ref.read(poemLibraryQueryProvider).grade != null) {
      ref.read(poemLibraryQueryProvider.notifier).setQuery(_query);
    }
    _searchController.text = _query.search;
    _future = _loadPoems();
    ref.listenManual<PoemQuery>(poemLibraryQueryProvider, (previous, next) {
      if (!mounted) {
        return;
      }

      setState(() {
        _query = next.copyWith(clearGrade: true);
        _searchController.value = TextEditingValue(
          text: _query.search,
          selection: TextSelection.collapsed(offset: _query.search.length),
        );
        _future = _loadPoems();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(poemStatsProvider);
    final showPinyin = ref.watch(pinyinVisibleProvider);
    final compactLayout =
        MediaQuery.sizeOf(context).width < AppLayout.compactWidth;
    final pagePadding = compactLayout ? AppSpacing.medium : AppSpacing.large;

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppLayout.readingMaxWidth,
          ),
          child: ListView(
            padding: EdgeInsets.all(pagePadding),
            children: [
              Text('诗词库', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.medium),
              Semantics(
                textField: true,
                label: '搜索诗词',
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: '搜索标题、作者、原文片段',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                  onSubmitted: (value) => _applySearch(value),
                ),
              ),
              const SizedBox(height: AppSpacing.small),
              statsAsync.when(
                data: (stats) => _buildTaxonomyDropdowns(context, stats),
                loading: () => const SizedBox.shrink(),
                error: (error, _) => const SizedBox.shrink(),
              ),
              const SizedBox(height: AppSpacing.medium),
              FutureBuilder<List<Poem>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: LinearProgressIndicator(),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return EmptyState(
                      title: '诗词库加载失败',
                      description: UserFacingErrorMapper.message(
                        snapshot.error!,
                        fallbackMessage: '诗词库加载失败，请稍后重试。',
                      ),
                      icon: Icons.error_outline_rounded,
                      action: FilledButton.icon(
                        onPressed: () => setState(() => _future = _loadPoems()),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('重试'),
                      ),
                    );
                  }

                  final poems = snapshot.data ?? const <Poem>[];
                  if (poems.isEmpty) {
                    return EmptyState(
                      title: '没有找到符合条件的诗词',
                      description: '试试清空筛选，或者换一个关键词。',
                      action: FilledButton(
                        onPressed: _clearFilters,
                        child: const Text('清空筛选'),
                      ),
                    );
                  }

                  return Column(
                    children: poems
                        .map(
                          (poem) => PoemListTile(
                            poem: poem,
                            showPinyin: showPinyin,
                            onTap:
                                () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder:
                                        (_) => PoemDetailPage(poemId: poem.id),
                                  ),
                                ),
                          ),
                        )
                        .toList(growable: false),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaxonomyDropdowns(BuildContext context, PoemStats stats) {
    final categories = stats.categoryCounts.keys.toList(growable: false);
    final dynasties = stats.dynastyCounts.keys.toList(growable: false);
    categories.sort();
    dynasties.sort();

    return Row(
      children: [
        Expanded(
          child: _FilterDropdown(
            label: '主题',
            value: _query.category ?? '',
            values: categories,
            onChanged:
                (value) => _updateQuery(
                  value == null || value.isEmpty
                      ? _query.copyWith(clearCategory: true)
                      : _query.copyWith(category: value),
                ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _FilterDropdown(
            label: '朝代',
            value: _query.dynasty ?? '',
            values: dynasties,
            onChanged:
                (value) => _updateQuery(
                  value == null || value.isEmpty
                      ? _query.copyWith(clearDynasty: true)
                      : _query.copyWith(dynasty: value),
                ),
          ),
        ),
      ],
    );
  }

  Future<List<Poem>> _loadPoems() {
    return ref.read(poemRepositoryProvider).fetchPoems(query: _query);
  }

  void _applySearch(String value) {
    _updateQuery(_query.copyWith(search: value.trim()));
  }

  void _clearFilters() {
    _searchController.clear();
    _updateQuery(const PoemQuery());
  }

  void _updateQuery(PoemQuery query) {
    final next = query.copyWith(clearGrade: true);
    ref.read(poemLibraryQueryProvider.notifier).setQuery(next);
    setState(() {
      _query = next;
      _future = _loadPoems();
    });
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      key: ValueKey('$label-$value'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
      items: [
        DropdownMenuItem(value: '', child: Text('全部$label')),
        for (final value in values)
          DropdownMenuItem(value: value, child: Text(value)),
      ],
      onChanged: onChanged,
    );
  }
}
