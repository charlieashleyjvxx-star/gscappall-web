import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_providers.dart';
import '../../core/user_facing_error.dart';
import '../../domain/poem.dart';
import '../../services/game/challenge_progress_service.dart';
import '../../services/game/feihualing_service.dart';
import '../../shared/widgets/section_card.dart';
import 'game_session_widgets.dart';

class FeihualingPage extends ConsumerStatefulWidget {
  const FeihualingPage({super.key});

  @override
  ConsumerState<FeihualingPage> createState() => _FeihualingPageState();
}

class _FeihualingPageState extends ConsumerState<FeihualingPage> {
  final TextEditingController _controller = TextEditingController();
  final Set<String> _usedKeys = <String>{};
  final List<FeihualingLine> _answers = <FeihualingLine>[];

  FeihualingTheme? _theme;
  String? _message;
  bool _saved = false;
  bool _pointsAwarded = false;
  FeihualingReport? _report;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final poemsFuture = ref.watch(poemRepositoryProvider).fetchPoems();

    return Scaffold(
      appBar: AppBar(title: const Text('飞花令')),
      body: FutureBuilder<List<Poem>>(
        future: poemsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                UserFacingErrorMapper.message(
                  snapshot.error!,
                  fallbackMessage: '诗词库加载失败，请稍后重试。',
                ),
              ),
            );
          }

          final service = ref.watch(feihualingServiceProvider);
          final poems = snapshot.data ?? const <Poem>[];
          final themes = service.buildThemePool(poems);
          final bank = service.buildLineBank(poems);
          if (themes.isEmpty || bank.isEmpty) {
            return const Center(child: Text('本地诗词库暂无可用飞花令主题。'));
          }

          final theme = _theme;
          return SafeArea(
            child:
                theme == null
                    ? _ThemePicker(
                      themes: themes,
                      onSelect: (selected) {
                        setState(() {
                          _theme = selected;
                          _message = null;
                        });
                      },
                    )
                    : _buildPracticeView(service, bank, themes, theme),
          );
        },
      ),
    );
  }

  Widget _buildPracticeView(
    FeihualingService service,
    List<FeihualingLine> bank,
    List<FeihualingTheme> themes,
    FeihualingTheme theme,
  ) {
    final suggestions = service.suggestionsForTheme(
      bank,
      theme.character,
      usedKeys: _usedKeys,
    );

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _FeihualingHero(
          theme: theme,
          answerCount: _answers.length,
          saved: _saved,
        ),
        const SizedBox(height: 16),
        if (_report != null) ...[
          GameResultCard(
            summary: _report!.summary,
            metrics: {
              '主题': _report!.themeCharacter,
              '句数': '${_report!.lineCount}',
              '得分': '${_report!.score}',
              '星星': _pointsAwarded ? '已获得' : '今天已记录',
            },
            primaryLabel: '再来一局',
            onPrimary: () => _resetRound(theme),
            secondaryLabel: '换一个主题',
            onSecondary: _backToThemes,
          ),
        ] else ...[
          SectionCard(
            title: '接一句',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: '输入带“${theme.character}”的诗句',
                    hintText:
                        suggestions.isEmpty
                            ? '例如输入完整诗句'
                            : suggestions.first.text,
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _submit(service, bank, theme),
                ),
                const SizedBox(height: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton.icon(
                      onPressed: () => _submit(service, bank, theme),
                      icon: const Icon(Icons.local_florist_rounded),
                      label: const Text('答一句'),
                    ),
                    TextButton.icon(
                      onPressed:
                          suggestions.isEmpty
                              ? null
                              : () {
                                _controller.text = suggestions.first.text;
                              },
                      icon: const Icon(Icons.tips_and_updates_rounded),
                      label: const Text('给我提示'),
                    ),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text('更多操作'),
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => _resetRound(theme),
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('重新开始本局'),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: _backToThemes,
                            child: const Text('换一个主题'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (_message != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _message!,
                    style: TextStyle(
                      color:
                          _message!.startsWith('答对')
                              ? const Color(0xFF3F7D45)
                              : Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: '提示',
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('展开提示'),
              children:
                  suggestions.isEmpty
                      ? const [Text('暂无候选，可以换主题继续。')]
                      : suggestions
                          .map(
                            (line) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(line.text),
                              subtitle: Text(
                                '《${line.poem.title}》${line.poem.author}',
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () {
                                _controller.text = line.text;
                              },
                            ),
                          )
                          .toList(growable: false),
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: '本轮答案',
            child:
                _answers.isEmpty
                    ? const Text('还没有答句。')
                    : Column(
                      children: _answers
                          .asMap()
                          .entries
                          .map(
                            (entry) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFFFFF2D6),
                                child: Text('${entry.key + 1}'),
                              ),
                              title: Text(entry.value.text),
                              subtitle: Text(
                                '《${entry.value.poem.title}》${entry.value.poem.author}',
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: '换个主题',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: themes
                  .take(10)
                  .map(
                    (item) => ChoiceChip(
                      label: Text(item.character),
                      selected: item.character == theme.character,
                      onSelected: (_) {
                        setState(() {
                          _theme = item;
                          _resetRoundState();
                        });
                      },
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _submit(
    FeihualingService service,
    List<FeihualingLine> bank,
    FeihualingTheme theme,
  ) async {
    final result = service.validateTurn(
      bank: bank,
      input: _controller.text,
      themeCharacter: theme.character,
      usedKeys: _usedKeys,
    );

    if (!mounted) {
      return;
    }
    setState(() {
      _message = result.message;
      if (result.accepted && result.line != null) {
        _answers.add(result.line!);
        _usedKeys.add(result.line!.key);
        _controller.clear();
      }
    });

    if (result.accepted && !_saved && _answers.length >= 3) {
      final report = service.buildReport(
        themeCharacter: theme.character,
        lineCount: _answers.length,
      );
      final stageId = const ChallengeProgressService().stageIdForResult(
        mode: 'feihualing',
        score: report.score,
        completedLines: _answers.length,
      );
      await ref
          .read(learningRepositoryProvider)
          .logLearningRecord(
            poemId: result.line!.poem.id,
            mode: 'feihualing',
            durationMinutes: _answers.length * 2,
            score: report.score,
            note: report.summary,
            stageId: stageId,
          );
      final pointsAwarded = await ref
          .read(learningRepositoryProvider)
          .awardActivityPoints(
            activityType: 'feihualing',
            points: report.points,
          );
      _refreshLearningProviders();
      if (mounted) {
        setState(() {
          _saved = true;
          _pointsAwarded = pointsAwarded;
          _report = report;
          _message = pointsAwarded ? '挑战完成，星星已记录。' : '挑战完成，今天已经记录过一次。';
        });
      }
    }
  }

  void _resetRound(FeihualingTheme theme) {
    setState(() {
      _theme = theme;
      _resetRoundState();
    });
  }

  void _backToThemes() {
    setState(() {
      _theme = null;
      _resetRoundState();
    });
  }

  void _resetRoundState() {
    _controller.clear();
    _usedKeys.clear();
    _answers.clear();
    _message = null;
    _saved = false;
    _pointsAwarded = false;
    _report = null;
  }

  void _refreshLearningProviders() {
    ref.invalidate(learningSummaryProvider);
    ref.invalidate(learningGrowthReportProvider);
    ref.invalidate(dailyPoemProgressProvider);
    ref.invalidate(recentLearningRecordsProvider);
    ref.invalidate(learningHistoryProvider);
  }
}

class _ThemePicker extends StatelessWidget {
  const _ThemePicker({required this.themes, required this.onSelect});

  final List<FeihualingTheme> themes;
  final ValueChanged<FeihualingTheme> onSelect;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFC7A6), Color(0xFFFFF3E9)],
            ),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '选择飞花令主题字',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: '推荐主题',
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: themes
                .map(
                  (theme) => ActionChip(
                    label: Text('${theme.character} · ${theme.hitCount}'),
                    onPressed: () => onSelect(theme),
                  ),
                )
                .toList(growable: false),
          ),
        ),
      ],
    );
  }
}

class _FeihualingHero extends StatelessWidget {
  const _FeihualingHero({
    required this.theme,
    required this.answerCount,
    required this.saved,
  });

  final FeihualingTheme theme;
  final int answerCount;
  final bool saved;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFC7A6), Color(0xFFFFF3E9)],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          Container(
            width: 76,
            height: 76,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Text(
              theme.character,
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: const Color(0xFF8A5A12),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('本轮主题字', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 6),
                Text(
                  '已答 $answerCount 句${saved ? ' · 已记录' : ''}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
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
