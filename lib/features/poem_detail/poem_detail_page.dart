import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_providers.dart';
import '../../app/app_design.dart';
import '../../core/user_facing_error.dart';
import '../../domain/poem.dart';
import '../../services/audio/audio_player_service.dart';
import '../../shared/widgets/poem_pinyin_text.dart';
import '../../shared/widgets/section_card.dart';
import '../reading/reading_placeholder_page.dart';

enum _DetailTab {
  content('原文'),
  annotation('注释'),
  translation('译文'),
  appreciation('赏析'),
  author('作者'),
  extension('拓展');

  const _DetailTab(this.label);

  final String label;
}

class PoemDetailPage extends ConsumerStatefulWidget {
  const PoemDetailPage({super.key, required this.poemId});

  final int poemId;

  @override
  ConsumerState<PoemDetailPage> createState() => _PoemDetailPageState();
}

class _PoemDetailPageState extends ConsumerState<PoemDetailPage> {
  _DetailTab _tab = _DetailTab.annotation;
  late Future<_DetailViewData?> _future;
  late final AudioPlayerService _audioPlayerService;
  _DetailTab? _playingTab;
  bool _isPreparingNarration = false;

  @override
  void initState() {
    super.initState();
    _audioPlayerService = ref.read(audioPlayerServiceProvider);
    _future = _load();
  }

  @override
  void dispose() {
    unawaited(_audioPlayerService.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showPinyin = ref.watch(pinyinVisibleProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('诗词详情'),
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _future = _load();
              });
            },
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '重新加载诗词详情',
          ),
        ],
      ),
      body: FutureBuilder<_DetailViewData?>(
        future: _future,
        builder: (context, snapshot) {
          final detail = snapshot.data;
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xLarge),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      UserFacingErrorMapper.message(
                        snapshot.error!,
                        fallbackMessage: '诗词详情加载失败，请稍后重试。',
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.large),
                    FilledButton.icon(
                      onPressed: () => setState(() => _future = _load()),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('重试'),
                    ),
                  ],
                ),
              ),
            );
          }
          if (detail == null) {
            return const Center(child: Text('没有找到对应诗词。'));
          }

          final poem = detail.poem;
          final compactLayout =
              MediaQuery.sizeOf(context).width < AppLayout.compactWidth;
          final pagePadding =
              compactLayout ? AppSpacing.medium : AppSpacing.large;
          const sectionGap = AppSpacing.medium;
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppLayout.readingMaxWidth,
              ),
              child: ListView(
                padding: EdgeInsets.all(pagePadding),
                children: [
                  _PoemHeaderCard(
                    poem: poem,
                    isFavorite: detail.isFavorite,
                    onFavoriteToggle: _toggleFavorite,
                  ),
                  SizedBox(height: sectionGap),
                  SectionCard(
                    title: '原文',
                    child: PoemPinyinText(
                      poem: detail.poem,
                      showPinyin: showPinyin,
                      variant: PoemPinyinTextVariant.detail,
                    ),
                  ),
                  SizedBox(height: sectionGap),
                  _NextStepAdvice(
                    onOpenReading: () => _openReadingPractice(poem.id),
                  ),
                  SizedBox(height: sectionGap),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _DetailTab.values
                          .where((tab) => tab != _DetailTab.content)
                          .map((tab) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(tab.label),
                                selected: _tab == tab,
                                onSelected: (_) {
                                  if (_playingTab != null) {
                                    unawaited(_stopNarration());
                                  }
                                  setState(() {
                                    _tab = tab;
                                  });
                                },
                              ),
                            );
                          })
                          .toList(growable: false),
                    ),
                  ),
                  SizedBox(height: sectionGap),
                  SectionCard(
                    title: _tab.label,
                    trailing: IconButton.filledTonal(
                      onPressed:
                          _canNarrate(detail)
                              ? () => _toggleNarration(detail)
                              : null,
                      tooltip:
                          _playingTab == _tab
                              ? '停止播放${_tab.label}'
                              : '播放${_tab.label}',
                      icon:
                          _isPreparingNarration && _playingTab == _tab
                              ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : Icon(
                                _playingTab == _tab
                                    ? Icons.stop_rounded
                                    : Icons.volume_up_rounded,
                              ),
                    ),
                    child: Text(
                      _contentFor(detail),
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(height: 1.8),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<_DetailViewData?> _load() async {
    final poem = await ref
        .read(poemRepositoryProvider)
        .fetchPoemById(widget.poemId);
    if (poem == null) {
      return null;
    }
    final isFavorite = await ref
        .read(poemRepositoryProvider)
        .isFavorite(widget.poemId);
    return _DetailViewData(poem: poem, isFavorite: isFavorite);
  }

  Future<void> _toggleFavorite() async {
    final detail = await _future;
    if (detail == null) {
      return;
    }
    await ref
        .read(poemRepositoryProvider)
        .setFavorite(detail.poem.id, !detail.isFavorite);
    ref.invalidate(favoritesProvider);
    ref.invalidate(learningSummaryProvider);
    setState(() {
      _future = _load();
    });
  }

  String _contentFor(_DetailViewData detail) {
    final poem = detail.poem;
    return switch (_tab) {
      _DetailTab.content =>
        poem.lines.isEmpty ? poem.content : poem.lines.join('\n'),
      _DetailTab.annotation =>
        poem.annotation.isEmpty ? '暂无注释。' : poem.annotation,
      _DetailTab.translation =>
        poem.translation.isEmpty ? '暂无译文。' : poem.translation,
      _DetailTab.appreciation =>
        poem.appreciation.isEmpty ? '暂无赏析。' : poem.appreciation,
      _DetailTab.author =>
        poem.authorIntro.isEmpty ? '暂无作者介绍。' : poem.authorIntro,
      _DetailTab.extension =>
        poem.extension.isEmpty ? '暂无拓展内容。' : poem.extension,
    };
  }

  String _narrationContentFor(_DetailViewData detail) {
    final poem = detail.poem;
    return switch (_tab) {
      _DetailTab.content => poem.lines.join('\n'),
      _DetailTab.annotation => poem.annotation,
      _DetailTab.translation => poem.translation,
      _DetailTab.appreciation => poem.appreciation,
      _DetailTab.author => poem.authorIntro,
      _DetailTab.extension => poem.extension,
    }.trim();
  }

  bool _canNarrate(_DetailViewData detail) {
    return !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        !_isPreparingNarration &&
        _narrationContentFor(detail).isNotEmpty;
  }

  Future<void> _toggleNarration(_DetailViewData detail) async {
    if (_playingTab == _tab) {
      await _stopNarration();
      return;
    }

    await _audioPlayerService.stop();
    final narrationTab = _tab;
    final narrationText = _narrationContentFor(detail);
    if (narrationText.isEmpty || !mounted) {
      return;
    }

    setState(() {
      _playingTab = narrationTab;
      _isPreparingNarration = true;
    });

    try {
      final synthesized = await ref
          .read(textToSpeechServiceProvider)
          .synthesizeToFile(
            text:
                narrationTab == _DetailTab.content
                    ? _poeticNarrationText(detail.poem.lines)
                    : narrationText,
            cacheKey:
                'poem_${detail.poem.id}_${narrationTab.name}_child_voice_v2',
            speechRate: narrationTab == _DetailTab.content ? 0.82 : 0.9,
            pitch: narrationTab == _DetailTab.content ? 1.03 : 1.0,
          );
      if (!mounted || _playingTab != narrationTab) {
        return;
      }
      setState(() {
        _isPreparingNarration = false;
      });
      await _audioPlayerService.play(synthesized.filePath);
    } catch (error) {
      if (mounted && _playingTab == narrationTab) {
        final message = UserFacingErrorMapper.message(
          error,
          fallbackMessage: '内容语音暂时无法播放，请稍后重试。',
        );
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted && _playingTab == narrationTab) {
        setState(() {
          _playingTab = null;
          _isPreparingNarration = false;
        });
      }
    }
  }

  Future<void> _stopNarration() async {
    await _audioPlayerService.stop();
    if (!mounted) {
      return;
    }
    setState(() {
      _playingTab = null;
      _isPreparingNarration = false;
    });
  }

  String _poeticNarrationText(Iterable<String> lines) {
    return lines
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map(
          (line) => line
              .replaceAll('，', '，  ')
              .replaceAll('。', '。   ')
              .replaceAll('？', '？   ')
              .replaceAll('！', '！   '),
        )
        .join('   ');
  }

  void _openReadingPractice(int poemId) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ReadingPlaceholderPage(poemId: poemId)),
    );
  }
}

class _DetailViewData {
  const _DetailViewData({required this.poem, required this.isFavorite});

  final Poem poem;
  final bool isFavorite;
}

class _PoemHeaderCard extends StatelessWidget {
  const _PoemHeaderCard({
    required this.poem,
    required this.isFavorite,
    required this.onFavoriteToggle,
  });

  final Poem poem;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(
          MediaQuery.sizeOf(context).width < AppLayout.compactWidth
              ? AppSpacing.medium
              : AppSpacing.large,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    poem.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    poem.author.isEmpty
                        ? poem.dynasty
                        : '${poem.dynasty} · ${poem.author}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton.filledTonal(
              onPressed: onFavoriteToggle,
              tooltip: isFavorite ? '取消收藏' : '收藏',
              visualDensity: VisualDensity.compact,
              icon: Icon(
                isFavorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NextStepAdvice extends StatelessWidget {
  const _NextStepAdvice({required this.onOpenReading});

  final VoidCallback onOpenReading;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '开始练习',
      padding: const EdgeInsets.all(AppSpacing.large),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: FilledButton.icon(
          onPressed: onOpenReading,
          icon: const Icon(Icons.graphic_eq_rounded),
          label: const Text('开始朗读'),
        ),
      ),
    );
  }
}
